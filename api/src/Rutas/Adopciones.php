<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, DocumentosMascota, Enrutador, ErrorHttp, Respuesta, Serializadores, Sesion, Solicitud, Validar};

/**
 * Flujo de adopción:
 *  - Usuarios: envían una solicitud de adopción (datos + documentos) por una mascota disponible
 *    y consultan el estado de las suyas.
 *  - Refugios: dan de alta sus preguntas frecuentes (las usa el asistente del formulario) y
 *    revisan las solicitudes que reciben.
 * Los documentos son privados: solo el refugio que recibe la solicitud puede descargarlos.
 */
final class Adopciones
{
    private const TIPOS_DOCUMENTO = ['identificacion', 'domicilio', 'vivienda', 'otro'];
    private const MAX_FOTOS_VIVIENDA = 3;
    private const MAX_DOCUMENTOS = 6;
    private const ESTADOS = ['pendiente', 'en revision', 'aprobada', 'rechazada'];
    private const MAX_PREGUNTAS = 50;

    private const SELECT_SOLICITUD = 'SELECT s.*, m.nombre AS mascota_nombre, m.foto AS mascota_foto, m.especie AS mascota_especie, r.nombre AS refugio_nombre
        FROM solicitudes_adopcion s JOIN mascotas m ON m.id = s.mascota_id JOIN refugios r ON r.id = s.refugio_id';

    public static function registrar(Enrutador $r): void
    {
        $sesion = [Sesion::class, 'requiereSesion'];

        // Preguntas frecuentes públicas de un refugio aprobado (para el asistente)
        $r->get('/refugios/{id}/preguntas', [self::class, 'preguntasPublicas'], [$sesion]);

        $r->grupo('/adopciones', [$sesion, Sesion::requiereRol('usuario')], static function (Enrutador $r): void {
            $r->get('', [self::class, 'misSolicitudes']);
            $r->post('', [self::class, 'solicitar']);
        });

        $r->grupo('/refugio', [$sesion, Sesion::requiereRol('refugio'), [Sesion::class, 'requiereRefugioAprobado']], static function (Enrutador $r): void {
            $r->get('/preguntas', [self::class, 'listarPreguntas']);
            $r->post('/preguntas', [self::class, 'crearPregunta']);
            $r->put('/preguntas/{id}', [self::class, 'editarPregunta']);
            $r->delete('/preguntas/{id}', [self::class, 'eliminarPregunta']);

            $r->get('/adopciones', [self::class, 'recibidas']);
            $r->patch('/adopciones/{id}', [self::class, 'cambiarEstado']);
            $r->get('/adopciones/{id}/documentos/{doc}/archivo', [self::class, 'archivo']);
        });
    }

    /* ---------- Serialización ---------- */

    private static function pregunta(array $f): array
    {
        return ['id' => (string) $f['id'], 'pregunta' => $f['pregunta'], 'respuesta' => $f['respuesta'],
            'claves' => $f['claves'] === '' ? [] : array_map('trim', explode(',', $f['claves'])), 'activa' => (bool) $f['activa']];
    }

    private static function documento(array $d): array
    {
        return ['id' => (string) $d['id'], 'tipo' => $d['tipo'], 'nombre' => $d['nombre'], 'mime' => $d['mime'], 'tamano' => (int) $d['tamano']];
    }

    /** @param bool $completa  true = con datos personales y documentos (para el refugio) */
    private static function solicitud(array $s, bool $completa): array
    {
        $base = [
            'id' => (string) $s['id'], 'mascotaId' => (string) $s['mascota_id'], 'mascotaNombre' => $s['mascota_nombre'],
            'mascotaFoto' => $s['mascota_foto'], 'mascotaEspecie' => $s['mascota_especie'],
            'refugioId' => (string) $s['refugio_id'], 'refugioNombre' => $s['refugio_nombre'],
            'estado' => $s['estado'], 'notaRefugio' => $s['nota_refugio'],
            'fecha' => Serializadores::fecha($s['creado_en']), 'actualizado' => Serializadores::fecha($s['actualizado_en']),
        ];
        if (!$completa) {
            return $base;
        }
        $docs = Base::todos('SELECT * FROM documentos_adopcion WHERE solicitud_id = ? ORDER BY id', [$s['id']]);
        return $base + [
            'nombre' => $s['nombre'], 'correo' => $s['correo'], 'telefono' => $s['telefono'], 'direccion' => $s['direccion'],
            'ocupacion' => $s['ocupacion'], 'tipoVivienda' => $s['tipo_vivienda'], 'viviendaPropia' => $s['vivienda_propia'],
            'otrasMascotas' => $s['otras_mascotas'], 'motivo' => $s['motivo'],
            'documentos' => array_map([self::class, 'documento'], $docs),
        ];
    }

    /* ---------- Preguntas frecuentes ---------- */

    public static function preguntasPublicas(Solicitud $s): array
    {
        $refugio = Base::uno("SELECT id FROM refugios WHERE id = ? AND estado = 'aprobado'", [Validar::idDeRuta($s->parametro('id'))]);
        if ($refugio === null) {
            throw new ErrorHttp(404, 'Ese refugio no está disponible.');
        }
        $filas = Base::todos('SELECT * FROM preguntas_refugio WHERE refugio_id = ? AND activa = 1 ORDER BY id', [$refugio['id']]);
        return ['preguntas' => array_map(static fn ($f) => array_diff_key(self::pregunta($f), ['activa' => 1]), $filas)];
    }

    public static function listarPreguntas(Solicitud $s): array
    {
        return ['preguntas' => array_map([self::class, 'pregunta'], Base::todos('SELECT * FROM preguntas_refugio WHERE refugio_id = ? ORDER BY id', [$s->refugio['id']]))];
    }

    private static function leerPregunta(array $b): array
    {
        $claves = $b['claves'] ?? [];
        if (is_string($claves)) {
            $claves = explode(',', $claves);
        }
        if (!is_array($claves)) {
            throw new ErrorHttp(400, 'Las palabras clave no son válidas.');
        }
        $claves = array_values(array_unique(array_filter(array_map(static fn ($c) => is_string($c) ? trim(str_replace(',', ' ', $c)) : '', $claves))));
        $unidas = implode(', ', $claves);
        if (Validar::largo($unidas) > 300) {
            throw new ErrorHttp(400, 'Las palabras clave no pueden pasar de 300 caracteres en total.');
        }
        return [
            'pregunta' => Validar::texto($b['pregunta'] ?? null, 'La pregunta', min: 5, max: 200),
            'respuesta' => Validar::texto($b['respuesta'] ?? null, 'La respuesta', min: 10, max: 1000),
            'claves' => $unidas,
            'activa' => array_key_exists('activa', $b) ? Validar::booleano($b['activa'], '«activa»') : true,
        ];
    }

    private static function preguntaPropia(Solicitud $s): array
    {
        $p = Base::uno('SELECT * FROM preguntas_refugio WHERE id = ? AND refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($p === null) {
            throw new ErrorHttp(404, 'Esa pregunta ya no existe.');
        }
        return $p;
    }

    public static function crearPregunta(Solicitud $s): Respuesta
    {
        if ((int) Base::valor('SELECT COUNT(*) FROM preguntas_refugio WHERE refugio_id = ?', [$s->refugio['id']]) >= self::MAX_PREGUNTAS) {
            throw new ErrorHttp(400, 'Llegaste al máximo de ' . self::MAX_PREGUNTAS . ' preguntas. Elimina alguna para agregar otra.');
        }
        $p = self::leerPregunta($s->cuerpo());
        $id = Base::insertar(
            'INSERT INTO preguntas_refugio (refugio_id, pregunta, respuesta, claves, activa, creado_en, actualizado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [$s->refugio['id'], $p['pregunta'], $p['respuesta'], $p['claves'], $p['activa'] ? 1 : 0, Base::ahora(), Base::ahora()],
        );
        return Respuesta::json(['ok' => true, 'pregunta' => self::pregunta(Base::uno('SELECT * FROM preguntas_refugio WHERE id = ?', [$id]))], 201);
    }

    public static function editarPregunta(Solicitud $s): array
    {
        $actual = self::preguntaPropia($s);
        $p = self::leerPregunta($s->cuerpo());
        Base::ejecutar(
            'UPDATE preguntas_refugio SET pregunta = ?, respuesta = ?, claves = ?, activa = ?, actualizado_en = ? WHERE id = ?',
            [$p['pregunta'], $p['respuesta'], $p['claves'], $p['activa'] ? 1 : 0, Base::ahora(), $actual['id']],
        );
        return ['ok' => true, 'pregunta' => self::pregunta(Base::uno('SELECT * FROM preguntas_refugio WHERE id = ?', [$actual['id']]))];
    }

    public static function eliminarPregunta(Solicitud $s): array
    {
        $p = self::preguntaPropia($s);
        Base::ejecutar('DELETE FROM preguntas_refugio WHERE id = ?', [$p['id']]);
        return ['ok' => true];
    }

    /* ---------- Solicitudes del usuario ---------- */

    public static function misSolicitudes(Solicitud $s): array
    {
        $filas = Base::todos(self::SELECT_SOLICITUD . ' WHERE s.usuario_id = ? ORDER BY s.creado_en DESC, s.id DESC', [$s->usuario['id']]);
        return ['solicitudes' => array_map(static fn ($f) => self::solicitud($f, false), $filas)];
    }

    public static function solicitar(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $mascotaId = $b['mascotaId'] ?? null;
        $mascota = is_scalar($mascotaId) && ctype_digit((string) $mascotaId)
            ? Base::uno("SELECT m.* FROM mascotas m JOIN refugios r ON r.id = m.refugio_id WHERE m.id = ? AND r.estado = 'aprobado'", [(int) $mascotaId])
            : null;
        if ($mascota === null) {
            throw new ErrorHttp(404, 'Esa mascota ya no está disponible.');
        }
        if ($mascota['estatus'] !== 'disponible') {
            throw new ErrorHttp(409, "{$mascota['nombre']} ya no está disponible para adopción.");
        }
        $abierta = Base::uno(
            "SELECT 1 FROM solicitudes_adopcion WHERE usuario_id = ? AND mascota_id = ? AND estado IN ('pendiente', 'en revision')",
            [$s->usuario['id'], $mascota['id']],
        );
        if ($abierta) {
            throw new ErrorHttp(409, "Ya enviaste una solicitud para adoptar a {$mascota['nombre']}. El refugio la está revisando.");
        }

        $datos = [
            'nombre' => Validar::texto($b['nombre'] ?? null, 'Tu nombre', min: 3, max: 100),
            'correo' => Validar::correo($b['correo'] ?? null),
            'telefono' => Validar::telefono($b['telefono'] ?? null),
            'direccion' => Validar::texto($b['direccion'] ?? null, 'La dirección', min: 8, max: 200),
            'ocupacion' => Validar::texto($b['ocupacion'] ?? null, 'La ocupación', max: 100, opcional: true),
            'tipo_vivienda' => Validar::enumerado($b['tipoVivienda'] ?? null, 'El tipo de vivienda', ['casa', 'departamento', 'otro']),
            'vivienda_propia' => Validar::enumerado($b['viviendaPropia'] ?? null, 'Si la vivienda es propia o rentada', ['propia', 'rentada', 'familiar']),
            'otras_mascotas' => Validar::texto($b['otrasMascotas'] ?? null, 'Las otras mascotas', max: 200, opcional: true),
            'motivo' => Validar::texto($b['motivo'] ?? null, 'El motivo', min: 20, max: 800),
        ];
        if (($b['aceptaTerminos'] ?? null) !== true) {
            throw new ErrorHttp(400, 'Debes aceptar que el refugio revise tus datos y documentos.');
        }

        // Documentos: identificación y comprobante obligatorios; 1 a 3 fotos del espacio (solo imágenes)
        $documentos = is_array($b['documentos'] ?? null) ? array_values($b['documentos']) : [];
        if (count($documentos) > self::MAX_DOCUMENTOS) {
            throw new ErrorHttp(400, 'Enviaste demasiados documentos (máximo ' . self::MAX_DOCUMENTOS . ').');
        }
        $tipos = array_map(static fn ($d) => is_array($d) ? ($d['tipo'] ?? null) : null, $documentos);
        if (array_diff($tipos, self::TIPOS_DOCUMENTO)) {
            throw new ErrorHttp(400, 'Los documentos enviados no son válidos.');
        }
        $cuenta = array_count_values(array_filter($tipos, 'is_string'));
        if (($cuenta['identificacion'] ?? 0) !== 1 || ($cuenta['domicilio'] ?? 0) !== 1) {
            throw new ErrorHttp(400, 'Adjunta una identificación oficial y un comprobante de domicilio.');
        }
        if (($cuenta['vivienda'] ?? 0) < 1 || ($cuenta['vivienda'] ?? 0) > self::MAX_FOTOS_VIVIENDA) {
            throw new ErrorHttp(400, 'Adjunta de 1 a ' . self::MAX_FOTOS_VIVIENDA . ' fotos del espacio donde vivirá la mascota.');
        }

        $guardados = [];
        try {
            foreach ($documentos as $d) {
                $nombre = Validar::texto($d['nombre'] ?? null, 'El nombre del documento', max: 120);
                $archivo = Archivos::guardarDocumento($d['dataUrl'] ?? null, "El documento «{$nombre}»");
                $guardados[] = ['tipo' => $d['tipo'], 'nombre' => $nombre] + $archivo;
                if ($d['tipo'] === 'vivienda' && !str_starts_with($archivo['mime'], 'image/')) {
                    throw new ErrorHttp(400, "«{$nombre}»: las fotos del espacio deben ser imágenes JPG o PNG.");
                }
            }
            $id = Base::transaccion(static function () use ($s, $mascota, $datos, $guardados): int {
                $ahora = Base::ahora();
                $id = Base::insertar(
                    'INSERT INTO solicitudes_adopcion (mascota_id, refugio_id, usuario_id, nombre, correo, telefono, direccion, ocupacion,
                        tipo_vivienda, vivienda_propia, otras_mascotas, motivo, creado_en, actualizado_en)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    [$mascota['id'], $mascota['refugio_id'], $s->usuario['id'], ...array_values($datos), $ahora, $ahora],
                );
                foreach ($guardados as $g) {
                    Base::insertar(
                        'INSERT INTO documentos_adopcion (solicitud_id, tipo, nombre, archivo, mime, tamano, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
                        [$id, $g['tipo'], $g['nombre'], $g['archivo'], $g['mime'], $g['tamano'], $ahora],
                    );
                }
                return $id;
            });
        } catch (\Throwable $e) {
            Archivos::borrarDocumentos(array_column($guardados, 'archivo'));
            throw $e;
        }
        return Respuesta::json(['ok' => true, 'solicitud' => self::solicitud(Base::uno(self::SELECT_SOLICITUD . ' WHERE s.id = ?', [$id]), false)], 201);
    }

    /* ---------- Solicitudes que recibe el refugio ---------- */

    public static function recibidas(Solicitud $s): array
    {
        $filas = Base::todos(self::SELECT_SOLICITUD . ' WHERE s.refugio_id = ? ORDER BY s.creado_en DESC, s.id DESC', [$s->refugio['id']]);
        return ['solicitudes' => array_map(static fn ($f) => self::solicitud($f, true), $filas)];
    }

    private static function recibidaPorId(Solicitud $s): array
    {
        $f = Base::uno(self::SELECT_SOLICITUD . ' WHERE s.id = ? AND s.refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($f === null) {
            throw new ErrorHttp(404, 'Esa solicitud ya no existe.');
        }
        return $f;
    }

    public static function cambiarEstado(Solicitud $s): array
    {
        $actual = self::recibidaPorId($s);
        $b = $s->cuerpo();
        $estado = Validar::enumerado($b['estado'] ?? null, 'El estado', self::ESTADOS);
        $nota = Validar::texto($b['nota'] ?? null, 'La nota', max: 400, opcional: true);
        if ($estado === 'rechazada' && $nota === '') {
            throw new ErrorHttp(400, 'Escribe una nota para explicar al solicitante por qué se rechaza.');
        }
        Base::ejecutar('UPDATE solicitudes_adopcion SET estado = ?, nota_refugio = ?, actualizado_en = ? WHERE id = ?', [$estado, $nota, Base::ahora(), $actual['id']]);
        return ['ok' => true, 'solicitud' => self::solicitud(Base::uno(self::SELECT_SOLICITUD . ' WHERE s.id = ?', [$actual['id']]), true)];
    }

    public static function archivo(Solicitud $s): Respuesta
    {
        $solicitud = self::recibidaPorId($s);
        $d = Base::uno('SELECT * FROM documentos_adopcion WHERE id = ? AND solicitud_id = ?', [Validar::idDeRuta($s->parametro('doc')), $solicitud['id']]);
        if ($d === null) {
            throw new ErrorHttp(404, 'Ese documento ya no existe.');
        }
        return DocumentosMascota::servir($d); // mismas cabeceras seguras que los demás documentos privados
    }

    /** Archivos de las solicitudes de una mascota (para borrarlos del disco junto con ella). */
    public static function archivosDeMascota(int $mascotaId): array
    {
        return array_column(Base::todos(
            'SELECT d.archivo FROM documentos_adopcion d JOIN solicitudes_adopcion s ON s.id = d.solicitud_id WHERE s.mascota_id = ?',
            [$mascotaId],
        ), 'archivo');
    }
}
