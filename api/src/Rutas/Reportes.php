<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, Enrutador, ErrorHttp, Gemini, Respuesta, Serializadores, Sesion, Similitud, Solicitud, Validar};

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
     * Cuerpo: { tipo: perdida|encontrada, descripcion, zona, foto, especie?: perro|gato|otro, nombre? }
     *
     *  1. Se guarda el reporte.
     *  2. Gemini mira la foto y saca especie, raza, color, tamaño y señas (si hay GEMINI_API_KEY).
     *  3. Se compara con los reportes contrarios de OTRAS personas: primero por texto y zona
     *     (Similitud.php) y, a los más parecidos, Gemini les compara las FOTOS.
     *  4. Se publica la alerta en el foro (muro) con la foto, para que toda la comunidad la vea.
     */
    public static function crear(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $tipo = Validar::enumerado($b['tipo'] ?? null, 'El tipo de reporte', ['perdida', 'encontrada']);
        $descripcion = Validar::texto($b['descripcion'] ?? null, 'La descripción', min: 15, max: 600);
        $zona = Validar::texto($b['zona'] ?? null, 'La zona', min: 2, max: 120);
        $especie = ($b['especie'] ?? '') === '' ? null : Validar::enumerado($b['especie'], 'La especie', ['perro', 'gato', 'otro']);
        $nombre = Validar::texto($b['nombre'] ?? '', 'El nombre', max: 60, opcional: true);
        $foto = Archivos::resolverFoto($b['foto'] ?? null, 'La foto');
        if ($foto === '') {
            throw new ErrorHttp(400, 'Toma una foto o sube un archivo.');
        }
        $usuario = $s->usuario;
        @set_time_limit(180); // la IA puede tardar (dos llamadas a Gemini con reintentos)

        // 2) La IA analiza la foto antes de guardar (si falla, se sigue sin IA)
        $analisis = Gemini::analizarMascota($foto, $descripcion);
        $especie ??= $analisis['especie'] ?? null;

        // 1) El reporte
        $id = Base::insertar(
            'INSERT INTO reportes (usuario_id, tipo, descripcion, zona, foto, foto_alt, especie, nombre, analisis_ia, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [$usuario['id'], $tipo, $descripcion, $zona, $foto, "Foto del reporte de {$usuario['nombre']}", $especie, $nombre ?: null,
                $analisis ? json_encode($analisis, JSON_UNESCAPED_UNICODE) : null, Base::ahora()],
        );

        // 3) Coincidencias
        $nuevas = self::buscarCoincidencias($id, $tipo, $descripcion, $zona, $foto, $especie, $analisis, (int) $usuario['id']);

        // 4) Alerta en el foro
        self::publicarAlerta($usuario, $tipo, $descripcion, $zona, $foto, $especie, $nombre, $analisis);

        $fila = Base::uno('SELECT * FROM reportes WHERE id = ?', [$id]);
        return Respuesta::json([
            'ok' => true, 'reporte' => Serializadores::reporte($fila), 'coincidenciasNuevas' => $nuevas['total'],
            'iaUsada' => $analisis !== null || $nuevas['porIa'], 'analisisIA' => $analisis,
        ], 201);
    }

    /** Texto con el que se compara un reporte: descripción + rasgos detectados por la IA. */
    private static function textoComparable(string $descripcion, ?array $analisis): string
    {
        if (!$analisis) {
            return $descripcion;
        }
        return "$descripcion {$analisis['raza']} {$analisis['color']} {$analisis['tamano']} {$analisis['senas']}";
    }

    /** @return array{total:int, porIa:bool} */
    private static function buscarCoincidencias(int $id, string $tipo, string $descripcion, string $zona, string $foto, ?string $especie, ?array $analisis, int $usuarioId): array
    {
        $contrario = $tipo === 'perdida' ? 'encontrada' : 'perdida';
        $mio = ['descripcion' => self::textoComparable($descripcion, $analisis), 'zona' => $zona];

        // Puntaje por texto de cada candidato (se descartan los de otra especie)
        $candidatos = [];
        foreach (Base::todos('SELECT * FROM reportes WHERE tipo = ? AND usuario_id <> ? ORDER BY id DESC FETCH FIRST 200 ROWS ONLY', [$contrario, $usuarioId]) as $c) {
            if ($especie && $especie !== 'otro' && ($c['especie'] ?? '') !== '' && $c['especie'] !== 'otro' && $c['especie'] !== $especie) {
                continue;
            }
            $suAnalisis = ($c['analisis_ia'] ?? '') !== '' ? json_decode($c['analisis_ia'], true) : null;
            $suyo = ['descripcion' => self::textoComparable($c['descripcion'], is_array($suAnalisis) ? $suAnalisis : null), 'zona' => $c['zona']];
            $candidatos[(int) $c['id']] = ['texto' => Similitud::calcular($mio, $suyo), 'foto' => $c['foto']];
        }
        uasort($candidatos, static fn ($a, $b) => $b['texto'] <=> $a['texto']);

        // La IA compara las fotos de los más parecidos por texto
        $porIa = Gemini::compararFotos(
            $foto,
            $descripcion,
            array_map(static fn ($c) => $c['foto'], array_slice($candidatos, 0, self::CANDIDATOS_IA, true)),
        ) ?? [];

        $total = 0;
        foreach ($candidatos as $otroId => $c) {
            $ia = $porIa[(string) $otroId] ?? null;
            // Con IA pesa más la foto (75 %); sin IA queda el puntaje por texto
            $similitud = $ia === null ? $c['texto'] : min(99, (int) round(0.75 * $ia + 0.25 * $c['texto']));
            if ($similitud < Similitud::UMBRAL) {
                continue;
            }
            [$perdido, $encontrado] = $tipo === 'perdida' ? [$id, $otroId] : [$otroId, $id];
            $total += Base::insertarSiNoExiste(
                'INSERT INTO coincidencias (reporte_perdido_id, reporte_encontrado_id, similitud, por_ia) VALUES (?, ?, ?, ?)',
                [$perdido, $encontrado, $similitud, $ia === null ? 0 : 1],
            );
        }
        return ['total' => $total, 'porIa' => $porIa !== []];
    }

    /** Publica la alerta en el foro: así aparece en el muro de la app y en el foro del sitio. */
    private static function publicarAlerta(array $usuario, string $tipo, string $descripcion, string $zona, string $foto, ?string $especie, string $nombre, ?array $analisis): void
    {
        $quien = $nombre !== '' ? $nombre : match ($especie) { 'perro' => 'un perrito', 'gato' => 'un gatito', default => 'una mascota' };
        $titulo = $tipo === 'perdida' ? "🔎 SE BUSCA: $quien" : "🐾 ENCONTRÉ A $quien";
        $rasgos = $analisis ? trim(implode(' · ', array_filter([$analisis['raza'], $analisis['color'], $analisis['tamano']], static fn ($v) => $v !== '' && $v !== 'No se distingue'))) : '';
        $texto = "$titulo\n📍 Zona: $zona\n" . ($rasgos !== '' ? "🤖 Rasgos (IA): $rasgos\n" : '') . $descripcion
            . "\n¿La has visto? Revisa «Coincidencias» o escribe en los comentarios.";
        try {
            Base::insertar(
                'INSERT INTO publicaciones_foro (usuario_id, texto, foto, foto_alt, creado_en) VALUES (?, ?, ?, ?, ?)',
                [$usuario['id'], mb_substr($texto, 0, 600), $foto, mb_substr("Foto de la alerta: $quien", 0, 160), Base::ahora()],
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
        $columnas = static fn (string $a): string => "$a.id AS {$a}_id, $a.usuario_id AS {$a}_usuario, $a.tipo AS {$a}_tipo,
                    $a.descripcion AS {$a}_descripcion, $a.zona AS {$a}_zona, $a.foto AS {$a}_foto, $a.foto_alt AS {$a}_alt,
                    $a.creado_en AS {$a}_fecha, $a.especie AS {$a}_especie, $a.nombre AS {$a}_nombre, $a.analisis_ia AS {$a}_analisis";
        $filas = Base::todos(
            'SELECT c.id, c.similitud, c.por_ia, c.creado_en, ' . $columnas('rp') . ', ' . $columnas('re') . ',
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
            return [
                'id' => (string) $f['id'], 'similitud' => (int) $f['similitud'], 'porIA' => (int) ($f['por_ia'] ?? 0) === 1,
                'fecha' => Serializadores::fecha($f['creado_en']), 'reporteId' => $mio['id'],
                'lado' => $perdi ? 'perdida' : 'encontrada',
                'miReporte' => $mio,
                'otroReporte' => $otro,
                'hallazgo' => $hallazgo,
            ];
        }, $filas)];
    }

    public static function resumen(Solicitud $s): array
    {
        $u = $s->usuario['id'];
        $contar = static fn (bool $descartadas): int => (int) Base::valor(
            'SELECT COUNT(*) ' . self::DESDE . ' WHERE ' . self::MIA . ' AND ' . ($descartadas ? '' : 'NOT ') . self::DESCARTADA,
            [$u, $u, $u],
        );
        return ['pendientes' => $contar(false), 'descartadas' => $contar(true)];
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
