<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Avisos, Base, Enrutador, ErrorHttp, Gemini, Procesos, Respuesta, Serializadores, Sesion, Similitud, Solicitud, Validar};

/**
 * Reportes de mascotas perdidas/encontradas y sus coincidencias.
 * Al crear un reporte se compara con los reportes contrarios de otras personas (simulación por
 * palabras, ver Similitud.php) y se guardan las coincidencias que superen el umbral.
 */
final class Reportes
{
    // Coincidencias en las que participa el usuario que consulta, de cualquiera de los dos lados:
    // dueño del reporte de PÉRDIDA (rp) o del de HALLAZGO (re). Así las dos personas pueden encontrarse.
    private const DESDE = 'FROM coincidencias c
          JOIN reportes rp ON rp.id = c.reporte_perdido_id
          JOIN reportes re ON re.id = c.reporte_encontrado_id';
    /** Condición de "es mía". Parámetros: [usuario, usuario] */
    private const MIA = '(rp.usuario_id = ? OR re.usuario_id = ?)';
    // Cada persona descarta por su cuenta (coincidencias_descartadas es por usuario). Parámetro: [usuario]
    private const DESCARTADA = 'EXISTS (SELECT 1 FROM coincidencias_descartadas d WHERE d.coincidencia_id = c.id AND d.usuario_id = ?)';

    public static function registrar(Enrutador $r): void
    {
        $r->grupo('', [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('usuario')], static function (Enrutador $r): void {
            $r->post('/reportes', [self::class, 'crear']);
            $r->post('/reportes/{id}/reunido', [self::class, 'reunido']);
            $r->post('/coincidencias/{id}/sena', [self::class, 'responderSena']);
            $r->get('/coincidencias', [self::class, 'listar']);
            $r->get('/coincidencias/resumen', [self::class, 'resumen']);
            $r->post('/coincidencias/restaurar', [self::class, 'restaurar']);
            $r->post('/coincidencias/{id}/descartar', [self::class, 'descartar']);
        });
    }

    /** Cuántos candidatos (los de texto más parecido) ve la IA en cada reporte nuevo. */
    private const CANDIDATOS_IA = 5;

    /**
     * POST /api/reportes — Alerta de mascota perdida o encontrada (HU-5) y búsqueda de coincidencias (HU-8).
     * Cuerpo: { tipo: perdida|encontrada, descripcion, zona, foto, especie?: perro|gato|otro, nombre?, confirmarDuplicado? }
     *
     * Se publica AL INSTANTE (la persona no espera a la IA):
     *  1. Si la misma foto ya está en otro reporte del mismo tipo, se avisa antes (posible duplicado).
     *  2. Se guarda el reporte y se buscan coincidencias por descripción y zona (Similitud.php).
     *  3. Se publica la alerta en el foro (muro).
     *  4. La IA (Gemini) trabaja EN SEGUNDO PLANO (procesarIa): analiza la foto, compara las fotos de
     *     los candidatos y actualiza las coincidencias. Si Gemini falla, se reintenta solo más tarde.
     */
    public static function crear(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $tipo = Validar::enumerado($b['tipo'] ?? null, 'El tipo de reporte', ['perdida', 'encontrada']);
        $descripcion = Validar::texto($b['descripcion'] ?? null, 'Las señas', min: 10, max: 600);
        $zona = Validar::texto($b['zona'] ?? null, 'La zona', min: 2, max: 120);
        $especie = ($b['especie'] ?? '') === '' ? null : Validar::enumerado($b['especie'], 'La especie', ['perro', 'gato', 'otro']);
        // «Se me perdió» lleva nombre; «La encontré» no (no se sabe) pero sí dónde está la mascota ahora
        $nombre = $tipo === 'perdida' ? Validar::texto($b['nombre'] ?? '', 'El nombre', max: 60, opcional: true) : '';
        $color = Validar::texto($b['color'] ?? '', 'El color', max: 40, opcional: true);
        $tamano = ($b['tamano'] ?? '') === '' ? null : Validar::enumerado($b['tamano'], 'El tamaño', ['pequeño', 'mediano', 'grande']);
        $collar = Validar::texto($b['collar'] ?? '', 'El collar o placa', max: 80, opcional: true);
        $fechaEvento = self::fechaEvento($b['fecha'] ?? null);
        $situacion = $tipo === 'encontrada' && ($b['situacion'] ?? '') !== ''
            ? Validar::enumerado($b['situacion'], 'Dónde está la mascota', array_keys(self::SITUACIONES))
            : null;
        [$latitud, $longitud] = self::punto($b['latitud'] ?? null, $b['longitud'] ?? null);
        // Seña secreta: solo el dueño la escribe y NUNCA se publica (sirve para verificar a quien dice que la encontró)
        $senaSecreta = $tipo === 'perdida' ? Validar::texto($b['senaSecreta'] ?? '', 'La seña secreta', max: 200, opcional: true) : '';
        $foto = Archivos::resolverFoto($b['foto'] ?? null, 'La foto');
        if ($foto === '') {
            throw new ErrorHttp(400, 'Toma una foto o sube un archivo.');
        }
        $usuario = $s->usuario;
        $confirmado = ($b['confirmarDuplicado'] ?? false) === true; // «es otra mascota, publicar de todos modos»
        $huella = self::huellaFoto($foto);
        $mio = ['descripcion' => self::textoComparable(['descripcion' => $descripcion, 'color' => $color, 'tamano' => $tamano, 'collar' => $collar], null), 'zona' => $zona];
        $esMismaFoto = static fn (int $otroId, array $c): bool => ($huella !== null && $c['huella'] === $huella) || $c['foto'] === $foto;

        // 1) ¿La MISMA foto ya está en otro reporte del mismo tipo? (rápido, sin IA; la IA revisa después las parecidas)
        if (!$confirmado) {
            $duplicados = array_column(array_filter(
                self::candidatos($mio, $tipo, $especie, null, self::DIAS_DUPLICADO),
                static fn ($c, $otroId) => $esMismaFoto($otroId, $c),
                ARRAY_FILTER_USE_BOTH,
            ), 'fila');
            if ($duplicados !== []) {
                throw new ErrorHttp(409, $tipo === 'perdida'
                    ? 'Parece que esta mascota ya fue reportada como perdida. Revisa si es la misma antes de publicar.'
                    : 'Parece que alguien ya reportó haber encontrado a esta mascota. Revisa si es la misma antes de publicar.', [
                    'codigo' => 'posible-duplicado',
                    'foto' => $foto, // la foto ya quedó guardada: se puede reenviar esta ruta sin volver a subirla
                    'duplicados' => array_map([self::class, 'resumenDuplicado'], array_slice($duplicados, 0, 3)),
                ]);
            }
        }

        // 2) El reporte (la IA queda pendiente) y coincidencias por texto
        $conIa = Gemini::disponible();
        $id = Base::insertar(
            'INSERT INTO reportes (usuario_id, tipo, descripcion, zona, foto, foto_alt, especie, nombre, foto_huella, ia_estado,
                                   color, tamano, collar, fecha_evento, situacion, latitud, longitud, sena_secreta, creado_en)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ' . ($fechaEvento ? "TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS')" : '?') . ', ?, ?, ?, ?, ?)',
            [$usuario['id'], $tipo, $descripcion, $zona, $foto, "Foto del reporte de {$usuario['nombre']}", $especie, $nombre ?: null,
                $huella, $conIa ? 'pendiente' : 'sin_ia', $color ?: null, $tamano, $collar ?: null, $fechaEvento, $situacion,
                $latitud, $longitud, $senaSecreta ?: null, Base::ahora()],
        );
        $miPunto = $latitud !== null ? [$latitud, $longitud] : null;
        $contrarios = self::candidatos($mio, $tipo === 'perdida' ? 'encontrada' : 'perdida', $especie, (int) $usuario['id']);
        $nuevas = self::guardarCoincidencias($id, $tipo, $contrarios, [], $esMismaFoto, $miPunto);

        // 3) Alerta en el foro (ligada al reporte: así sale en su pestaña del muro)
        self::publicarAlerta($id, $usuario, Base::uno('SELECT * FROM reportes WHERE id = ?', [$id]));

        // 4) La IA, en segundo plano
        if ($conIa) {
            Procesos::artisan(['ia:procesar', (string) $id]);
        }

        $fila = Base::uno('SELECT * FROM reportes WHERE id = ?', [$id]);
        return Respuesta::json([
            'ok' => true, 'reporte' => Serializadores::reporte($fila), 'coincidenciasNuevas' => $nuevas['total'],
            'iaPendiente' => $conIa, 'iaUsada' => false, 'analisisIA' => null,
        ], 201);
    }

    /**
     * POST /api/reportes/{id}/reunido — «¡Ya apareció!»: quien publicó la alerta la cierra.
     * La alerta pasa a la pestaña «Reunidos» del muro y deja de buscar coincidencias.
     */
    public static function reunido(Solicitud $s): array
    {
        $id = Validar::idDeRuta($s->parametro('id'));
        $r = Base::uno('SELECT id, usuario_id, estado FROM reportes WHERE id = ?', [$id]);
        if ($r === null || (int) $r['usuario_id'] !== (int) $s->usuario['id']) {
            throw new ErrorHttp(404, 'Esa alerta no existe o no es tuya.');
        }
        if ($r['estado'] !== 'reunido') {
            Base::ejecutar("UPDATE reportes SET estado = 'reunido', reunido_en = ? WHERE id = ?", [Base::ahora(), $id]);
        }
        return ['ok' => true, 'estado' => 'reunido'];
    }

    /**
     * POST /api/coincidencias/{id}/sena — { respuesta }: quien encontró la mascota describe la seña
     * particular que pidió el dueño. Después de responder ya ve el contacto del dueño, y el dueño ve
     * la respuesta junto a su seña secreta para decidir si es real. Se responde una sola vez.
     */
    public static function responderSena(Solicitud $s): array
    {
        $id = Validar::idDeRuta($s->parametro('id'));
        $f = Base::uno(
            'SELECT c.respuesta_sena, rp.sena_secreta, re.usuario_id AS quien_encontro ' . self::DESDE . ' WHERE c.id = ?',
            [$id],
        );
        if ($f === null || (int) $f['quien_encontro'] !== (int) $s->usuario['id']) {
            throw new ErrorHttp(404, 'Esa coincidencia no existe o no es tuya.');
        }
        if (($f['sena_secreta'] ?? '') === '') {
            throw new ErrorHttp(409, 'El dueño no pidió una seña para esta mascota.');
        }
        if (($f['respuesta_sena'] ?? '') !== '') {
            throw new ErrorHttp(409, 'Ya respondiste. El dueño revisará tu respuesta.');
        }
        $respuesta = Validar::texto($s->cuerpo()['respuesta'] ?? null, 'Tu respuesta', min: 3, max: 300);
        Base::ejecutar('UPDATE coincidencias SET respuesta_sena = ?, respondida_en = ? WHERE id = ?', [$respuesta, Base::ahora(), $id]);
        return ['ok' => true];
    }

    /* ---------- IA en segundo plano ---------- */

    /** Reintentos si Gemini falla: a los 2, 5, 15 y 30 minutos; después se deja sin IA. */
    private const ESPERAS_REINTENTO = [2, 5, 15, 30];

    /**
     * Procesa con la IA un reporte pendiente (lo llama «php artisan ia:procesar»).
     * Devuelve 'listo', 'reintentar', 'fallo' u 'ocupado' (otro proceso lo tiene o aún no toca).
     */
    public static function procesarIa(int $id): string
    {
        // Lo "aparta" solo un proceso: si dos lo intentan, el UPDATE gana una sola vez
        $apartado = Base::ejecutar(
            "UPDATE reportes SET ia_estado = 'procesando', ia_intentos = ia_intentos + 1,
                    ia_siguiente = SYS_EXTRACT_UTC(SYSTIMESTAMP) + NUMTODSINTERVAL(10, 'MINUTE')
              WHERE id = ? AND ia_estado IN ('pendiente', 'procesando')
                AND (ia_siguiente IS NULL OR ia_siguiente <= SYS_EXTRACT_UTC(SYSTIMESTAMP))",
            [$id],
        );
        if ($apartado === 0) {
            return 'ocupado';
        }
        $r = Base::uno('SELECT * FROM reportes WHERE id = ?', [$id]);
        @set_time_limit(300);

        $analisis = ($r['analisis_ia'] ?? '') !== '' ? json_decode($r['analisis_ia'], true) : null;
        $analisis = is_array($analisis) ? $analisis : Gemini::analizarMascota($r['foto'], $r['descripcion']);
        if ($analisis === null) {
            return self::reintentarIa($r);
        }
        $especie = $r['especie'] ?? null ?: ($analisis['especie'] ?? null);
        Base::ejecutar('UPDATE reportes SET analisis_ia = ?, especie = ? WHERE id = ?', [json_encode($analisis, JSON_UNESCAPED_UNICODE), $especie, $id]);

        // Candidatos contrarios (coincidencias) y del mismo tipo (¿la misma mascota ya tenía alerta?)
        $huella = $r['foto_huella'] ?? null;
        $mio = ['descripcion' => self::textoComparable($r, $analisis), 'zona' => $r['zona']];
        $contrarios = self::candidatos($mio, $r['tipo'] === 'perdida' ? 'encontrada' : 'perdida', $especie, (int) $r['usuario_id']);
        $mismos = array_filter(
            self::candidatos($mio, $r['tipo'], $especie, null, self::DIAS_DUPLICADO),
            static fn ($c, $otroId) => $otroId !== $id && ($c['texto'] >= self::TEXTO_MIN_DUPLICADO || ($huella !== null && $c['huella'] === $huella)),
            ARRAY_FILTER_USE_BOTH,
        );
        $paraIa = array_slice($contrarios, 0, self::CANDIDATOS_IA, true) + array_slice($mismos, 0, self::CANDIDATOS_DUPLICADO, true);
        $mismaFotoIa = [];
        $porIa = $paraIa === [] ? [] : Gemini::compararFotos($r['foto'], $r['descripcion'], array_map(static fn ($c) => $c['foto'], $paraIa), $mismaFotoIa);
        if ($porIa === null) {
            return self::reintentarIa($r); // el análisis ya quedó guardado; falta comparar las fotos
        }
        $esMismaFoto = static fn (int $otroId, array $c): bool =>
            ($huella !== null && $c['huella'] === $huella) || $c['foto'] === $r['foto'] || isset($mismaFotoIa[(string) $otroId]);

        $miPunto = ($r['latitud'] ?? null) !== null ? [(float) $r['latitud'], (float) $r['longitud']] : null;
        self::guardarCoincidencias($id, $r['tipo'], $contrarios, $porIa, $esMismaFoto, $miPunto);

        // Posible duplicado que solo la IA reconoce (p. ej. la misma foto reenviada por WhatsApp)
        $duplicadoDe = null;
        foreach ($mismos as $otroId => $c) {
            $ia = $porIa[(string) $otroId] ?? null;
            if ($esMismaFoto($otroId, $c) || ($ia !== null && $ia >= self::SIMILITUD_DUPLICADO)) {
                $duplicadoDe = $otroId;
                break;
            }
        }
        Base::ejecutar("UPDATE reportes SET ia_estado = 'listo', ia_siguiente = NULL, duplicado_de = ? WHERE id = ?", [$duplicadoDe, $id]);
        return 'listo';
    }

    private static function reintentarIa(array $r): string
    {
        $intentos = (int) $r['ia_intentos'];
        if ($intentos > count(self::ESPERAS_REINTENTO)) {
            Base::ejecutar("UPDATE reportes SET ia_estado = 'fallo', ia_siguiente = NULL WHERE id = ?", [$r['id']]);
            return 'fallo';
        }
        Base::ejecutar(
            "UPDATE reportes SET ia_estado = 'pendiente', ia_siguiente = SYS_EXTRACT_UTC(SYSTIMESTAMP) + NUMTODSINTERVAL(?, 'MINUTE') WHERE id = ?",
            [self::ESPERAS_REINTENTO[$intentos - 1], $r['id']],
        );
        return 'reintentar';
    }

    /** Ids de reportes con IA pendiente cuyo turno ya llegó (para reintentar). */
    public static function pendientesIa(int $limite = 10): array
    {
        return array_map('intval', array_column(Base::todos(
            "SELECT id FROM reportes WHERE ia_estado IN ('pendiente', 'procesando')
                AND (ia_siguiente IS NULL OR ia_siguiente <= SYS_EXTRACT_UTC(SYSTIMESTAMP))
              ORDER BY id FETCH FIRST $limite ROWS ONLY",
        ), 'id'));
    }

    /** Si hay reportes esperando a la IA, lanza el proceso que los atiende (como mucho uno cada minuto). */
    private static function despertarIa(): void
    {
        if (!Gemini::disponible() || self::pendientesIa(1) === []) {
            return;
        }
        $marca = sys_get_temp_dir() . '/huellapp-ia-despertar';
        if (is_file($marca) && filemtime($marca) > time() - 60) {
            return;
        }
        @touch($marca);
        Procesos::artisan(['ia:procesar']);
    }

    /** Dónde está ahora una mascota encontrada (formulario «La encontré»). */
    private const SITUACIONES = [
        'conmigo' => 'La tengo yo, está a salvo',
        'refugio' => 'La llevé a un refugio o veterinaria',
        'vista' => 'Solo la vi, no la pude resguardar',
    ];

    /** Punto del mapa: los dos valores o ninguno (opcional). */
    private static function punto(mixed $lat, mixed $lng): array
    {
        if (($lat === null || $lat === '') && ($lng === null || $lng === '')) {
            return [null, null];
        }
        if (!is_numeric($lat) || !is_numeric($lng) || abs((float) $lat) > 90 || abs((float) $lng) > 180) {
            throw new ErrorHttp(400, 'La ubicación del mapa no es válida. Vuelve a marcarla.');
        }
        return [round((float) $lat, 6), round((float) $lng, 6)];
    }

    /** Distancia en km entre dos puntos [lat, lng] (fórmula del haversine). null si falta alguno. */
    public static function distanciaKm(?array $a, ?array $b): ?float
    {
        if ($a === null || $b === null) {
            return null;
        }
        [$lat1, $lng1] = array_map('deg2rad', $a);
        [$lat2, $lng2] = array_map('deg2rad', $b);
        $h = sin(($lat2 - $lat1) / 2) ** 2 + cos($lat1) * cos($lat2) * sin(($lng2 - $lng1) / 2) ** 2;
        return 6371 * 2 * asin(min(1, sqrt($h)));
    }

    /** Puntos que suma o resta la distancia a la similitud (sin mapa no cambia nada). */
    private static function ajustePorDistancia(?float $km): int
    {
        return match (true) {
            $km === null => 0,
            $km <= 1 => 10,
            $km <= 3 => 6,
            $km <= 8 => 0,
            $km <= 20 => -10,
            default => -25,
        };
    }

    /** Fecha y hora en que se perdió o la vieron: opcional, no futura y de máximo un año atrás. */
    private static function fechaEvento(mixed $valor): ?string
    {
        if ($valor === null || $valor === '') {
            return null;
        }
        $fecha = is_string($valor) ? date_create_immutable($valor) : false;
        if ($fecha === false || $fecha->getTimestamp() > time() + 3600 || $fecha->getTimestamp() < strtotime('-1 year')) {
            throw new ErrorHttp(400, 'Revisa la fecha: no puede ser futura ni de hace más de un año.');
        }
        return $fecha->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:s');
    }

    /**
     * Texto con el que se compara un reporte: señas + color, tamaño y collar del formulario
     * + rasgos detectados por la IA. Recibe la fila del reporte (o un arreglo con esas llaves).
     */
    private static function textoComparable(array $r, ?array $analisis): string
    {
        $texto = trim(implode(' ', array_filter([$r['descripcion'] ?? '', $r['color'] ?? '', $r['tamano'] ?? '', $r['collar'] ?? ''])));
        if (!$analisis) {
            return $texto;
        }
        return "$texto {$analisis['raza']} {$analisis['color']} {$analisis['tamano']} {$analisis['senas']}";
    }

    /** Reportes del mismo tipo que se revisan como posible duplicado: los de los últimos 90 días. */
    private const DIAS_DUPLICADO = 90;
    /** Cuántos reportes del mismo tipo ve la IA para buscar duplicados, y desde qué parecido por texto. */
    private const CANDIDATOS_DUPLICADO = 3;
    private const TEXTO_MIN_DUPLICADO = 25;
    /** Desde qué parecido de FOTO (IA) se considera que es la misma mascota ya reportada. */
    private const SIMILITUD_DUPLICADO = 85;

    /** SHA-256 del archivo de la foto subida (null si es una imagen del sitio, no subida). */
    private static function huellaFoto(string $foto): ?string
    {
        if (!str_starts_with($foto, '/uploads/imagenes/')) {
            return null;
        }
        $ruta = Archivos::dirImagenes() . '/' . basename($foto);
        return is_file($ruta) ? hash_file('sha256', $ruta) : null;
    }

    /**
     * Reportes de un tipo con su parecido por texto con el nuevo, del más al menos parecido
     * (se descartan los de otra especie). $sinUsuario excluye los de esa persona.
     * @return array<int, array{texto:int, foto:string, huella:?string, fila:array}>
     */
    private static function candidatos(array $mio, string $tipo, ?string $especie, ?int $sinUsuario, ?int $dias = null): array
    {
        // Las alertas cerradas con «¡Ya apareció!» ya no buscan coincidencias ni cuentan como duplicado
        $sql = "SELECT r.*, u.nombre AS autor FROM reportes r JOIN usuarios u ON u.id = r.usuario_id WHERE r.tipo = ? AND r.estado = 'activo'";
        $parametros = [$tipo];
        if ($sinUsuario !== null) {
            $sql .= ' AND r.usuario_id <> ?';
            $parametros[] = $sinUsuario;
        }
        if ($dias !== null) {
            $sql .= " AND r.creado_en >= SYS_EXTRACT_UTC(SYSTIMESTAMP) - NUMTODSINTERVAL(?, 'DAY')";
            $parametros[] = $dias;
        }
        $candidatos = [];
        foreach (Base::todos("$sql ORDER BY r.id DESC FETCH FIRST 200 ROWS ONLY", $parametros) as $c) {
            if ($especie && $especie !== 'otro' && ($c['especie'] ?? '') !== '' && $c['especie'] !== 'otro' && $c['especie'] !== $especie) {
                continue;
            }
            $suAnalisis = ($c['analisis_ia'] ?? '') !== '' ? json_decode($c['analisis_ia'], true) : null;
            $suyo = ['descripcion' => self::textoComparable($c, is_array($suAnalisis) ? $suAnalisis : null), 'zona' => $c['zona']];
            $candidatos[(int) $c['id']] = [
                // Reportes de antes de guardar la huella: se calcula aquí con el archivo (es rápido)
                'texto' => Similitud::calcular($mio, $suyo), 'foto' => $c['foto'], 'huella' => $c['foto_huella'] ?? self::huellaFoto($c['foto']), 'fila' => $c,
            ];
        }
        uasort($candidatos, static fn ($a, $b) => $b['texto'] <=> $a['texto']);
        return $candidatos;
    }

    /**
     * Guarda las coincidencias con los reportes contrarios que superen el umbral.
     * Si los dos usan la MISMA fotografía, la foto no cuenta como prueba (pudo copiarse del muro):
     * solo pesa el texto y se marca misma_foto para avisar en la pantalla de coincidencias.
     * @return array{total:int, porIa:bool}
     */
    private static function guardarCoincidencias(int $id, string $tipo, array $contrarios, array $porIa, callable $esMismaFoto, ?array $miPunto = null): array
    {
        $total = 0;
        foreach ($contrarios as $otroId => $c) {
            $mismaFoto = $esMismaFoto($otroId, $c);
            $ia = $mismaFoto ? null : ($porIa[(string) $otroId] ?? null);
            // Con IA pesa más la foto (75 %); sin IA (o con la misma foto) queda el puntaje por texto
            $similitud = $ia === null ? $c['texto'] : min(99, (int) round(0.75 * $ia + 0.25 * $c['texto']));
            // Distancia real entre los dos puntos del mapa: cerca suma, lejos resta
            $suPunto = ($c['fila']['latitud'] ?? null) !== null ? [(float) $c['fila']['latitud'], (float) $c['fila']['longitud']] : null;
            $similitud = max(0, min(99, $similitud + self::ajustePorDistancia(self::distanciaKm($miPunto, $suPunto))));
            [$perdido, $encontrado] = $tipo === 'perdida' ? [$id, $otroId] : [$otroId, $id];
            // La IA llega después: si ya había coincidencia (por texto), se actualiza con lo que vio en las fotos
            $actualizada = Base::ejecutar(
                'UPDATE coincidencias SET similitud = ?, por_ia = ?, misma_foto = ? WHERE reporte_perdido_id = ? AND reporte_encontrado_id = ?',
                [$similitud, $ia === null ? 0 : 1, $mismaFoto ? 1 : 0, $perdido, $encontrado],
            );
            if ($actualizada > 0 || $similitud < Similitud::UMBRAL) {
                continue;
            }
            $nueva = Base::insertarSiNoExiste(
                'INSERT INTO coincidencias (reporte_perdido_id, reporte_encontrado_id, similitud, por_ia, misma_foto) VALUES (?, ?, ?, ?, ?)',
                [$perdido, $encontrado, $similitud, $ia === null ? 0 : 1, $mismaFoto ? 1 : 0],
            );
            $total += $nueva;
            if ($nueva > 0) { // HU-19: avisar a las dos personas
                $duenos = Base::todos('SELECT id, usuario_id, tipo, nombre FROM reportes WHERE id IN (?, ?)', [$perdido, $encontrado]);
                foreach ($duenos as $d) {
                    $quien = ($d['nombre'] ?? '') !== '' ? $d['nombre'] : 'tu reporte';
                    Avisos::crear((int) $d['usuario_id'], 'coincidencias', $d['tipo'] === 'perdida'
                        ? "🐾 Posible coincidencia para $quien ($similitud %)"
                        : "🐾 La mascota que encontraste podría tener familia ($similitud %)", 'Revísala en Coincidencias.');
                }
            }
        }
        return ['total' => $total, 'porIa' => $porIa !== []];
    }

    /** Lo que se muestra de un reporte que podría ser de la misma mascota (sin datos de contacto). */
    private static function resumenDuplicado(array $f): array
    {
        $partes = preg_split('/\s+/', trim((string) $f['autor'])) ?: [''];
        $autor = $partes[0] . (isset($partes[1]) ? ' ' . mb_substr($partes[1], 0, 1) . '.' : '');
        return [
            'id' => (string) $f['id'], 'tipo' => $f['tipo'], 'nombre' => $f['nombre'] ?? null, 'descripcion' => $f['descripcion'],
            'zona' => $f['zona'], 'foto' => $f['foto'], 'fecha' => Serializadores::fecha($f['creado_en']), 'autor' => $autor,
        ];
    }

    /** Publica la alerta en el foro: así aparece en el muro de la app y en el foro del sitio. */
    private static function publicarAlerta(int $reporteId, array $usuario, array $r): void
    {
        $perdida = $r['tipo'] === 'perdida';
        $quien = ($r['nombre'] ?? '') !== '' ? $r['nombre'] : match ($r['especie'] ?? null) { 'perro' => 'un perrito', 'gato' => 'un gatito', default => 'una mascota' };
        $titulo = $perdida ? "🔎 SE BUSCA: $quien" : "🏠 BUSCA A SU FAMILIA: $quien";
        $rasgos = implode(' · ', array_filter([$r['color'] ?? '', $r['tamano'] ?? '']));
        $cuando = ($r['fecha_evento'] ?? null)
            ? date_create_immutable(Serializadores::fecha($r['fecha_evento']))?->setTimezone(new \DateTimeZone('America/Mexico_City'))->format('d/m/Y H:i')
            : null;
        $lineas = [
            $titulo,
            "📍 Zona: {$r['zona']}",
            $cuando ? ($perdida ? "🕒 Se perdió: $cuando" : "🕒 La vieron: $cuando") : null,
            $rasgos !== '' ? "🎨 $rasgos" : null,
            ($r['collar'] ?? '') !== '' ? "🏷️ Collar o placa: {$r['collar']}" : null,
            !$perdida && ($r['situacion'] ?? null) ? '📌 ' . self::SITUACIONES[$r['situacion']] : null,
            $r['descripcion'],
            $perdida ? '¿La has visto? Escribe en los comentarios.' : '¿Es tu mascota? Escribe en los comentarios o revisa «Coincidencias».',
        ];
        $texto = implode("\n", array_filter($lineas, static fn ($l) => $l !== null && $l !== ''));
        try {
            Base::insertar(
                'INSERT INTO publicaciones_foro (usuario_id, texto, foto, foto_alt, reporte_id, creado_en) VALUES (?, ?, ?, ?, ?, ?)',
                [$usuario['id'], mb_substr($texto, 0, 600), $r['foto'], mb_substr("Foto de la alerta: $quien", 0, 160), $reporteId, Base::ahora()],
            );
        } catch (\Throwable $e) {
            error_log('No se pudo publicar la alerta en el foro: ' . $e->getMessage()); // el reporte ya quedó guardado
        }
    }

    /**
     * GET /api/coincidencias — Las coincidencias del usuario, de los dos lados:
     *  - lado "perdida":    yo perdí la mascota; otroReporte es el hallazgo de otra persona.
     *  - lado "encontrada": yo encontré una mascota; otroReporte es la pérdida de su posible dueño.
     * miReporte es siempre el reporte propio y otroReporte trae el contacto de la otra persona.
     * "hallazgo" se conserva igual que antes (el reporte de la mascota encontrada, con contacto)
     * para no romper clientes viejos; los nuevos deben usar lado + otroReporte.
     */
    public static function listar(Solicitud $s): array
    {
        $u = (int) $s->usuario['id'];
        self::despertarIa();
        $columnas = static fn (string $a): string => "$a.id AS {$a}_id, $a.usuario_id AS {$a}_usuario, $a.tipo AS {$a}_tipo,
                    $a.descripcion AS {$a}_descripcion, $a.zona AS {$a}_zona, $a.foto AS {$a}_foto, $a.foto_alt AS {$a}_alt,
                    $a.creado_en AS {$a}_fecha, $a.especie AS {$a}_especie, $a.nombre AS {$a}_nombre, $a.analisis_ia AS {$a}_analisis";
        $filas = Base::todos(
            'SELECT c.id, c.similitud, c.por_ia, c.misma_foto, c.creado_en, c.respuesta_sena, rp.sena_secreta,
                    rp.latitud AS rp_lat, rp.longitud AS rp_lng, re.latitud AS re_lat, re.longitud AS re_lng, ' . $columnas('rp') . ', ' . $columnas('re') . ',
                    up.nombre AS up_nombre, up.telefono AS up_telefono, up.correo AS up_correo,
                    ue.nombre AS ue_nombre, ue.telefono AS ue_telefono, ue.correo AS ue_correo
               ' . self::DESDE . '
               JOIN usuarios up ON up.id = rp.usuario_id
               JOIN usuarios ue ON ue.id = re.usuario_id
              WHERE ' . self::MIA . ' AND NOT ' . self::DESCARTADA . '
              ORDER BY c.similitud DESC, c.id',
            [$u, $u, $u],
        );

        // Un reporte (rp = pérdida, re = hallazgo) en el formato que ven la app y el sitio
        $reporte = static fn (array $f, string $a, string $alt): array => [
            'id' => (string) $f["{$a}_id"], 'tipo' => $f["{$a}_tipo"], 'descripcion' => $f["{$a}_descripcion"], 'zona' => $f["{$a}_zona"],
            'foto' => $f["{$a}_foto"], 'fotoAlt' => $f["{$a}_alt"] ?: $alt, 'fecha' => Serializadores::fecha($f["{$a}_fecha"]),
            'especie' => $f["{$a}_especie"] ?? null, 'nombre' => $f["{$a}_nombre"] ?? null,
            'analisisIA' => ($f["{$a}_analisis"] ?? '') !== '' ? json_decode($f["{$a}_analisis"], true) : null,
        ];
        // Dueño del reporte (up = quien perdió, ue = quien encontró). Sin teléfono se manda ''
        // (antes era el texto "No indicó teléfono", que el sitio mostraba como si fuera un número).
        $contacto = static fn (array $f, string $a): array => [
            'nombre' => $f["{$a}_nombre"], 'telefono' => (string) ($f["{$a}_telefono"] ?? ''), 'correo' => $f["{$a}_correo"],
        ];

        return ['coincidencias' => array_map(static function (array $f) use ($u, $reporte, $contacto): array {
            $perdi = (int) $f['rp_usuario'] === $u;
            $hallazgo = $reporte($f, 're', 'Mascota encontrada') + ['contacto' => $contacto($f, 'ue')];
            $mio = $reporte($f, $perdi ? 'rp' : 're', 'Tu reporte');
            $otro = $perdi ? $hallazgo : $reporte($f, 'rp', 'Mascota perdida') + ['contacto' => $contacto($f, 'up')];

            // Seña secreta: quien encontró NO ve el contacto del dueño hasta describir la seña.
            // El dueño ve la respuesta junto a su seña y decide (la seña nunca se le muestra a quien encontró).
            $hayResena = ($f['sena_secreta'] ?? '') !== '';
            $respuesta = ($f['respuesta_sena'] ?? '') !== '' ? $f['respuesta_sena'] : null;
            $verificacion = null;
            if ($hayResena && $perdi) {
                $verificacion = ['tuSena' => $f['sena_secreta'], 'respuesta' => $respuesta];
            } elseif ($hayResena) {
                $verificacion = ['requerida' => $respuesta === null, 'respuesta' => $respuesta];
                if ($respuesta === null) {
                    $otro['contacto'] = null;
                }
            }
            $distancia = self::distanciaKm(
                $f['rp_lat'] !== null ? [(float) $f['rp_lat'], (float) $f['rp_lng']] : null,
                $f['re_lat'] !== null ? [(float) $f['re_lat'], (float) $f['re_lng']] : null,
            );
            return [
                'id' => (string) $f['id'], 'similitud' => (int) $f['similitud'], 'porIA' => (int) ($f['por_ia'] ?? 0) === 1, 'mismaFoto' => (int) ($f['misma_foto'] ?? 0) === 1,
                'fecha' => Serializadores::fecha($f['creado_en']), 'reporteId' => $mio['id'],
                'distanciaKm' => $distancia !== null ? round($distancia, 1) : null,
                'verificacion' => $verificacion,
                'lado' => $perdi ? 'perdida' : 'encontrada',
                'miReporte' => $mio,
                'otroReporte' => $otro,
                'hallazgo' => $hallazgo,
            ];
        }, $filas)] + self::estadoIa($u);
    }

    /**
     * Lo que la persona debe saber de la IA de sus reportes:
     *  - analizando: cuántos de sus reportes siguen esperando a la IA (Gemini ocupado o reintentando)
     *  - duplicados: sus reportes que la IA cree que son la misma mascota que otra alerta ya publicada
     */
    private static function estadoIa(int $u): array
    {
        $analizando = (int) Base::valor(
            "SELECT COUNT(*) FROM reportes WHERE usuario_id = ? AND ia_estado IN ('pendiente', 'procesando')",
            [$u],
        );
        $duplicados = array_map(static fn (array $f): array => [
            'miReporte' => ['id' => (string) $f['id'], 'nombre' => $f['nombre'] ?? null, 'tipo' => $f['tipo']],
            'otro' => self::resumenDuplicado([
                'id' => $f['o_id'], 'tipo' => $f['o_tipo'], 'nombre' => $f['o_nombre'], 'descripcion' => $f['o_descripcion'],
                'zona' => $f['o_zona'], 'foto' => $f['o_foto'], 'creado_en' => $f['o_creado_en'], 'autor' => $f['o_autor'],
            ]),
        ], Base::todos(
            'SELECT r.id, r.nombre, r.tipo, o.id AS o_id, o.tipo AS o_tipo, o.nombre AS o_nombre, o.descripcion AS o_descripcion,
                    o.zona AS o_zona, o.foto AS o_foto, o.creado_en AS o_creado_en, u.nombre AS o_autor
               FROM reportes r JOIN reportes o ON o.id = r.duplicado_de JOIN usuarios u ON u.id = o.usuario_id
              WHERE r.usuario_id = ? ORDER BY r.id DESC FETCH FIRST 5 ROWS ONLY',
            [$u],
        ));
        return ['analizando' => $analizando, 'duplicados' => $duplicados];
    }

    public static function resumen(Solicitud $s): array
    {
        self::despertarIa();
        $u = $s->usuario['id'];
        $contar = static fn (bool $descartadas): int => (int) Base::valor(
            'SELECT COUNT(*) ' . self::DESDE . ' WHERE ' . self::MIA . ' AND ' . ($descartadas ? '' : 'NOT ') . self::DESCARTADA,
            [$u, $u, $u],
        );
        return ['pendientes' => $contar(false), 'descartadas' => $contar(true)] + self::estadoIa((int) $u);
    }

    public static function restaurar(Solicitud $s): array
    {
        Base::ejecutar('DELETE FROM coincidencias_descartadas WHERE usuario_id = ?', [$s->usuario['id']]);
        return ['ok' => true];
    }

    public static function descartar(Solicitud $s): array
    {
        $id = Validar::idDeRuta($s->parametro('id'));
        // Solo se puede declinar una coincidencia propia
        if (!Base::uno('SELECT c.id ' . self::DESDE . ' WHERE ' . self::MIA . ' AND c.id = ?', [$s->usuario['id'], $s->usuario['id'], $id])) {
            throw new ErrorHttp(404, 'Esa coincidencia no existe.');
        }
        Base::insertarSiNoExiste('INSERT INTO coincidencias_descartadas (usuario_id, coincidencia_id) VALUES (?, ?)', [$s->usuario['id'], $id]);
        return ['ok' => true];
    }
}
