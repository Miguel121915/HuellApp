<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Avisos, Base, DocumentosMascota, Enrutador, ErrorHttp, Respuesta, Serializadores, Sesion, Solicitud, Validar};

/** Revisión de refugios por el administrador: solicitudes, documentos, aprobar / rechazar / suspender / reactivar. */
final class Admin
{
    private const ESTADOS = ['pendiente', 'aprobado', 'rechazado', 'suspendido'];
    private const SELECT_REFUGIO = 'SELECT r.*, u.correo FROM refugios r JOIN usuarios u ON u.id = r.usuario_id';

    public static function registrar(Enrutador $r): void
    {
        $r->grupo('/admin', [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('admin')], static function (Enrutador $r): void {
            $r->get('/resumen', [self::class, 'resumen']);
            $r->get('/estadisticas', [self::class, 'estadisticas']); // HU-20
            $r->get('/refugios', [self::class, 'listar']);
            $r->get('/refugios/{id}', [self::class, 'ver']);
            $r->post('/refugios/{id}/aprobar', [self::class, 'aprobar']);
            $r->post('/refugios/{id}/rechazar', [self::class, 'rechazar']);
            $r->post('/refugios/{id}/suspender', [self::class, 'suspender']);
            $r->post('/refugios/{id}/reactivar', [self::class, 'reactivar']);
            $r->patch('/documentos/{id}', [self::class, 'marcarDocumento']);
            $r->get('/documentos/{id}/archivo', [self::class, 'archivo']);

            // Mascotas de cada refugio y sus documentos especiales
            $r->get('/refugios/{id}/mascotas', [self::class, 'mascotasDeRefugio']);
            $r->get('/mascotas/{id}', [self::class, 'verMascota']);
            $r->patch('/documentos-mascota/{id}', [self::class, 'marcarDocumentoMascota']);
            $r->get('/documentos-mascota/{id}/archivo', [self::class, 'archivoMascota']);

            // HU-18: bandeja de moderación del foro
            $r->get('/moderacion', [self::class, 'bandejaModeracion']);
            $r->post('/moderacion/{tipo}/{id}', [self::class, 'decidirModeracion']);
        });
    }

    /* ---------- Moderación de contenido (HU-18) ---------- */

    // GET /api/admin/moderacion?estado=revision|quitado → publicaciones y comentarios marcados, los más recientes primero
    public static function bandejaModeracion(Solicitud $s): array
    {
        $estado = Validar::enumerado($s->query['estado'] ?? 'revision', 'El estado', ['revision', 'quitado']);
        $publicaciones = Base::todos(
            "SELECT 'publicacion' AS tipo, p.id, p.texto, p.foto, p.creado_en, p.moderacion_motivo, p.moderacion_fuente, p.moderacion_en,
                    u.nombre AS autor, u.correo AS autor_correo, NULL AS publicacion_texto
               FROM publicaciones_foro p JOIN usuarios u ON u.id = p.usuario_id WHERE p.moderacion = ?",
            [$estado],
        );
        $comentarios = Base::todos(
            "SELECT 'comentario' AS tipo, c.id, c.texto, NULL AS foto, c.creado_en, c.moderacion_motivo, c.moderacion_fuente, c.moderacion_en,
                    u.nombre AS autor, u.correo AS autor_correo, p.texto AS publicacion_texto
               FROM comentarios_foro c JOIN usuarios u ON u.id = c.usuario_id JOIN publicaciones_foro p ON p.id = c.publicacion_id
              WHERE c.moderacion = ?",
            [$estado],
        );
        $elementos = array_map(static fn (array $f): array => [
            'tipo' => $f['tipo'], 'id' => (string) $f['id'], 'texto' => $f['texto'], 'foto' => $f['foto'] ?: null,
            'autor' => $f['autor'], 'autorCorreo' => $f['autor_correo'],
            'enPublicacion' => $f['publicacion_texto'] !== null ? mb_substr((string) $f['publicacion_texto'], 0, 140) : null,
            'motivo' => $f['moderacion_motivo'], 'fuente' => $f['moderacion_fuente'],
            'fecha' => Serializadores::fecha($f['creado_en']), 'marcado' => Serializadores::fecha($f['moderacion_en']),
        ], [...$publicaciones, ...$comentarios]);
        usort($elementos, static fn ($a, $b) => strcmp((string) $b['marcado'], (string) $a['marcado']));
        return ['elementos' => $elementos];
    }

    // POST /api/admin/moderacion/{publicacion|comentario}/{id}  { accion: aprobar|quitar }
    public static function decidirModeracion(Solicitud $s): array
    {
        $tipo = Validar::enumerado($s->parametro('tipo'), 'El tipo', array_keys(\HuellApp\Moderacion::TABLAS));
        $tabla = \HuellApp\Moderacion::TABLAS[$tipo];
        $id = Validar::idDeRuta($s->parametro('id'));
        $accion = Validar::enumerado($s->cuerpo()['accion'] ?? null, 'La acción', ['aprobar', 'quitar']);
        $fila = Base::uno("SELECT usuario_id, texto, moderacion FROM $tabla WHERE id = ?", [$id]);
        if ($fila === null) {
            throw new ErrorHttp(404, 'Ya no existe.');
        }
        $nuevo = $accion === 'aprobar' ? 'visible' : 'quitado';
        Base::ejecutar("UPDATE $tabla SET moderacion = ?, moderacion_fuente = 'admin', moderacion_en = TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS.FF3') WHERE id = ?", [$nuevo, Base::ahora(), $id]);
        if ($accion === 'quitar' && $fila['moderacion'] !== 'quitado') {
            Avisos::crear((int) $fila['usuario_id'], 'foro', $tipo === 'publicacion' ? 'Retiramos una publicación tuya del foro' : 'Retiramos un comentario tuyo del foro',
                'No cumple las reglas de la comunidad de HuellApp: «' . mb_substr((string) $fila['texto'], 0, 80) . '…»');
        }
        return ['ok' => true, 'moderacion' => $nuevo];
    }

    private static function documentos(int $refugioId): array
    {
        return Base::todos('SELECT * FROM documentos_refugio WHERE refugio_id = ? ORDER BY id', [$refugioId]);
    }

    private static function refugioPorId(int|string $id): array
    {
        $fila = Base::uno(self::SELECT_REFUGIO . ' WHERE r.id = ?', [is_int($id) ? $id : Validar::idDeRuta($id)]);
        if ($fila === null) {
            throw new ErrorHttp(404, 'Ese refugio no existe.');
        }
        return $fila;
    }

    /** Cambia el estado solo si el refugio está en uno de los estados de origen permitidos. */
    private static function cambiarEstado(Solicitud $s, array $desde, string $hacia, string $mensajeError, string $motivo = ''): array
    {
        $refugio = self::refugioPorId($s->parametro('id'));
        if (!in_array($refugio['estado'], $desde, true)) {
            throw new ErrorHttp(409, $mensajeError);
        }
        Base::ejecutar('UPDATE refugios SET estado = ?, motivo_rechazo = ?, revisado_por = ?, revisado_en = ? WHERE id = ?', [$hacia, $motivo, $s->usuario['id'], Base::ahora(), $refugio['id']]);
        Avisos::crear((int) $refugio['usuario_id'], 'estado-refugio', match ($hacia) {
            'aprobado' => '¡Tu refugio fue aprobado! 🎉',
            'rechazado' => 'Tu solicitud de refugio no fue aprobada',
            'suspendido' => 'Tu refugio fue suspendido',
            default => 'El estado de tu refugio cambió',
        }, $hacia === 'aprobado' ? 'Ya puedes publicar tus mascotas en adopción.' : $motivo);
        $fila = self::refugioPorId((int) $refugio['id']);
        return ['ok' => true, 'refugio' => Serializadores::refugioCompleto($fila, self::documentos((int) $fila['id']))];
    }

    /**
     * GET /api/admin/estadisticas — Estadísticas de uso de la plataforma (HU-20).
     * Totales por estado y la actividad de las últimas 8 semanas (lunes a domingo, en UTC).
     */
    public static function estadisticas(): array
    {
        $porGrupo = static function (string $sql): array {
            $res = [];
            foreach (Base::todos($sql) as $f) {
                $res[(string) $f['clave']] = (int) $f['total'];
            }
            return $res;
        };
        $total = static fn (string $tabla): int => (int) Base::valor("SELECT COUNT(*) FROM $tabla");

        // Semanas: del lunes de hace 7 semanas al lunes de esta semana
        $lunes = (new \DateTimeImmutable('monday this week', new \DateTimeZone('UTC')))->setTime(0, 0);
        $semanas = [];
        for ($i = 7; $i >= 0; $i--) {
            $semanas[] = $lunes->modify("-$i weeks")->format('Y-m-d');
        }
        $desde = $semanas[0] . ' 00:00:00.000';
        $porSemana = static function (string $tabla) use ($desde, $semanas): array {
            $filas = Base::todos(
                "SELECT TO_CHAR(TRUNC(creado_en, 'IW'), 'YYYY-MM-DD') AS semana, COUNT(*) AS total
                   FROM $tabla WHERE creado_en >= TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS.FF3')
                  GROUP BY TRUNC(creado_en, 'IW')",
                [$desde],
            );
            $cuenta = array_column($filas, 'total', 'semana');
            return array_map(static fn ($s) => (int) ($cuenta[$s] ?? 0), $semanas);
        };

        $adopciones = $porGrupo('SELECT estado AS clave, COUNT(*) AS total FROM solicitudes_adopcion GROUP BY estado');
        $resueltas = ($adopciones['aprobada'] ?? 0) + ($adopciones['rechazada'] ?? 0);

        return [
            'generado' => Serializadores::fecha(Base::ahora()),
            'usuarios' => $porGrupo('SELECT rol AS clave, COUNT(*) AS total FROM usuarios GROUP BY rol'),
            'refugios' => $porGrupo('SELECT estado AS clave, COUNT(*) AS total FROM refugios GROUP BY estado'),
            'mascotas' => $porGrupo('SELECT estatus AS clave, COUNT(*) AS total FROM mascotas GROUP BY estatus'),
            'mascotasPorEspecie' => $porGrupo('SELECT especie AS clave, COUNT(*) AS total FROM mascotas GROUP BY especie'),
            'adopciones' => $adopciones,
            // De las solicitudes ya resueltas, qué porcentaje se aprobó
            'tasaAprobacion' => $resueltas > 0 ? (int) round(100 * ($adopciones['aprobada'] ?? 0) / $resueltas) : null,
            'reportes' => $porGrupo('SELECT tipo AS clave, COUNT(*) AS total FROM reportes GROUP BY tipo'),
            'coincidencias' => [
                'total' => $total('coincidencias'),
                'porIa' => (int) Base::valor('SELECT COUNT(*) FROM coincidencias WHERE por_ia = 1'),
            ],
            'comunidad' => [
                'publicaciones' => $total('publicaciones_foro'),
                'comentarios' => $total('comentarios_foro'),
                'mensajes' => $total('mensajes_refugio'),
                'favoritos' => $total('favoritos'),
            ],
            'topRefugios' => array_map(static fn ($f) => ['nombre' => $f['nombre'], 'adopciones' => (int) $f['total']], Base::todos(
                "SELECT r.nombre, COUNT(*) AS total FROM solicitudes_adopcion s JOIN refugios r ON r.id = s.refugio_id
                  WHERE s.estado = 'aprobada' GROUP BY r.nombre ORDER BY total DESC, r.nombre FETCH FIRST 5 ROWS ONLY",
            )),
            'semanas' => $semanas,
            'actividad' => [
                'usuarios' => $porSemana('usuarios'),
                'reportes' => $porSemana('reportes'),
                'solicitudes' => $porSemana('solicitudes_adopcion'),
                'publicaciones' => $porSemana('publicaciones_foro'),
            ],
        ];
    }

    public static function resumen(): array
    {
        $cuenta = static fn (string $estado): int => (int) Base::valor('SELECT COUNT(*) FROM refugios WHERE estado = ?', [$estado]);
        $enRevision = (int) Base::valor("SELECT (SELECT COUNT(*) FROM publicaciones_foro WHERE moderacion = 'revision') + (SELECT COUNT(*) FROM comentarios_foro WHERE moderacion = 'revision') FROM dual");
        return ['pendientes' => $cuenta('pendiente'), 'aprobados' => $cuenta('aprobado'), 'rechazados' => $cuenta('rechazado'), 'suspendidos' => $cuenta('suspendido'),
            'moderacion' => $enRevision]; // HU-18: número rojo de «Moderación»
    }

    // ?estado=pendiente|aprobado|rechazado|suspendido (sin filtro devuelve todos)
    public static function listar(Solicitud $s): array
    {
        $estado = isset($s->query['estado']) && $s->query['estado'] !== '' ? Validar::enumerado($s->query['estado'], 'El estado', self::ESTADOS) : null;
        $filas = Base::todos(self::SELECT_REFUGIO . ($estado ? ' WHERE r.estado = ?' : '') . ' ORDER BY r.creado_en DESC, r.id DESC', $estado ? [$estado] : []);
        return ['refugios' => array_map(static fn ($f) => Serializadores::refugioCompleto($f, self::documentos((int) $f['id'])), $filas)];
    }

    public static function ver(Solicitud $s): array
    {
        $fila = self::refugioPorId($s->parametro('id'));
        return ['refugio' => Serializadores::refugioCompleto($fila, self::documentos((int) $fila['id']))];
    }

    public static function aprobar(Solicitud $s): array
    {
        return self::cambiarEstado($s, ['pendiente'], 'aprobado', 'Esta solicitud ya fue revisada.');
    }

    public static function rechazar(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $motivo = Validar::texto($b['motivo'] ?? null, 'El motivo del rechazo', min: 10, max: 400); // obligatorio
        $refugio = self::refugioPorId($s->parametro('id'));

        // Documentos señalados como erróneos (opcional): el refugio tendrá que reemplazarlos para apelar
        $conError = $b['documentosConError'] ?? [];
        if (!is_array($conError)) {
            throw new ErrorHttp(400, 'La lista de documentos con error no es válida.');
        }
        $propios = array_column(self::documentos((int) $refugio['id']), 'id');
        $ids = array_values(array_unique(array_map(static fn ($id) => is_scalar($id) ? (string) $id : '', $conError)));
        if (array_diff($ids, array_map('strval', $propios))) {
            throw new ErrorHttp(400, 'Alguno de los documentos señalados no pertenece a esta solicitud.');
        }

        return Base::transaccion(static function () use ($s, $motivo, $refugio, $ids): array {
            Base::ejecutar('UPDATE documentos_refugio SET con_error = 0 WHERE refugio_id = ?', [$refugio['id']]);
            if ($ids) {
                Base::ejecutar(
                    'UPDATE documentos_refugio SET con_error = 1, verificado = 0 WHERE refugio_id = ? AND id IN (' . implode(',', array_fill(0, count($ids), '?')) . ')',
                    [$refugio['id'], ...array_map('intval', $ids)],
                );
            }
            return self::cambiarEstado($s, ['pendiente'], 'rechazado', 'Esta solicitud ya fue revisada.', $motivo);
        });
    }

    public static function suspender(Solicitud $s): array
    {
        $motivo = Validar::texto($s->cuerpo()['motivo'] ?? null, 'El motivo', max: 400, opcional: true);
        return self::cambiarEstado($s, ['aprobado'], 'suspendido', 'Solo se puede suspender un refugio aprobado.', $motivo);
    }

    public static function reactivar(Solicitud $s): array
    {
        return self::cambiarEstado($s, ['suspendido'], 'aprobado', 'Solo se puede reactivar un refugio suspendido.');
    }

    /* ---------- Documentos (privados) ---------- */

    private static function documentoPorId(Solicitud $s): array
    {
        $d = Base::uno('SELECT * FROM documentos_refugio WHERE id = ?', [Validar::idDeRuta($s->parametro('id'))]);
        if ($d === null) {
            throw new ErrorHttp(404, 'Ese documento no existe.');
        }
        return $d;
    }

    // Casilla del checklist de revisión
    public static function marcarDocumento(Solicitud $s): array
    {
        $d = self::documentoPorId($s);
        $verificado = Validar::booleano($s->cuerpo()['verificado'] ?? null, '«verificado»');
        Base::ejecutar('UPDATE documentos_refugio SET verificado = ? WHERE id = ?', [$verificado ? 1 : 0, $d['id']]);
        return ['ok' => true, 'documento' => Serializadores::documento([...$d, 'verificado' => $verificado ? 1 : 0])];
    }

    // El archivo solo se entrega al administrador con sesión válida (no es una carpeta pública)
    public static function archivo(Solicitud $s): Respuesta
    {
        $d = self::documentoPorId($s);
        $ruta = Archivos::rutaDocumento($d['archivo']);
        if (!is_file($ruta)) {
            throw new ErrorHttp(404, 'El archivo ya no está disponible.');
        }
        return Respuesta::archivo($ruta, [
            'Content-Type' => $d['mime'],
            'Content-Disposition' => "inline; filename*=UTF-8''" . rawurlencode($d['nombre']),
            'Content-Security-Policy' => 'sandbox',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    /* ---------- Mascotas de un refugio y sus documentos ---------- */

    // Todas las mascotas (cualquier estatus), con cuántos documentos tienen y cuántos están revisados
    public static function mascotasDeRefugio(Solicitud $s): array
    {
        $refugio = self::refugioPorId($s->parametro('id'));
        $filas = Base::todos('SELECT * FROM mascotas WHERE refugio_id = ? ORDER BY id DESC', [$refugio['id']]);
        return [
            'refugio' => Serializadores::refugioPublico($refugio),
            'mascotas' => DocumentosMascota::mascotasConConteo($filas),
        ];
    }

    public static function verMascota(Solicitud $s): array
    {
        $m = Base::uno('SELECT * FROM mascotas WHERE id = ?', [Validar::idDeRuta($s->parametro('id'))]);
        if ($m === null) {
            throw new ErrorHttp(404, 'Esa mascota no existe.');
        }
        return [
            'mascota' => Serializadores::mascota($m),
            'documentos' => array_map([Serializadores::class, 'documentoMascota'], DocumentosMascota::deMascota((int) $m['id'])),
        ];
    }

    private static function documentoMascotaPorId(Solicitud $s): array
    {
        $d = Base::uno('SELECT * FROM documentos_mascota WHERE id = ?', [Validar::idDeRuta($s->parametro('id'))]);
        if ($d === null) {
            throw new ErrorHttp(404, 'Ese documento no existe.');
        }
        return $d;
    }

    public static function marcarDocumentoMascota(Solicitud $s): array
    {
        $d = self::documentoMascotaPorId($s);
        $verificado = Validar::booleano($s->cuerpo()['verificado'] ?? null, '«verificado»');
        Base::ejecutar('UPDATE documentos_mascota SET verificado = ? WHERE id = ?', [$verificado ? 1 : 0, $d['id']]);
        return ['ok' => true, 'documento' => Serializadores::documentoMascota([...$d, 'verificado' => $verificado ? 1 : 0])];
    }

    public static function archivoMascota(Solicitud $s): Respuesta
    {
        return DocumentosMascota::servir(self::documentoMascotaPorId($s));
    }
}
