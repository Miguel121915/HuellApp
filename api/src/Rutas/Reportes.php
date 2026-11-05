<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, Enrutador, ErrorHttp, Respuesta, Serializadores, Sesion, Similitud, Solicitud, Validar};

/**
 * Reportes de mascotas perdidas/encontradas y sus coincidencias.
 * Al crear un reporte se compara con los reportes contrarios de otras personas (simulación por
 * palabras, ver Similitud.php) y se guardan las coincidencias que superen el umbral.
 */
final class Reportes
{
    // Coincidencias donde el REPORTE DE PÉRDIDA es del usuario que consulta
    private const BASE = 'FROM coincidencias c JOIN reportes rp ON rp.id = c.reporte_perdido_id AND rp.usuario_id = ?';
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

    public static function crear(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $tipo = Validar::enumerado($b['tipo'] ?? null, 'El tipo de reporte', ['perdida', 'encontrada']);
        $descripcion = Validar::texto($b['descripcion'] ?? null, 'La descripción', min: 15, max: 600);
        $zona = Validar::texto($b['zona'] ?? null, 'La zona', min: 2, max: 120);
        $foto = Archivos::resolverFoto($b['foto'] ?? null, 'La foto');
        if ($foto === '') {
            throw new ErrorHttp(400, 'Toma una foto o sube un archivo.');
        }
        $usuario = $s->usuario;

        $resultado = Base::transaccion(static function () use ($usuario, $tipo, $descripcion, $zona, $foto): array {
            $id = Base::insertar(
                'INSERT INTO reportes (usuario_id, tipo, descripcion, zona, foto, foto_alt, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
                [$usuario['id'], $tipo, $descripcion, $zona, $foto, "Foto del reporte de {$usuario['nombre']}", Base::ahora()],
            );
            // Se compara con los reportes contrarios de OTRAS personas
            $contrario = $tipo === 'perdida' ? 'encontrada' : 'perdida';
            $nuevas = 0;
            foreach (Base::todos('SELECT * FROM reportes WHERE tipo = ? AND usuario_id <> ? ORDER BY id DESC LIMIT 200', [$contrario, $usuario['id']]) as $c) {
                $similitud = Similitud::calcular(['descripcion' => $descripcion, 'zona' => $zona], $c);
                if ($similitud < Similitud::UMBRAL) {
                    continue;
                }
                [$perdido, $encontrado] = $tipo === 'perdida' ? [$id, (int) $c['id']] : [(int) $c['id'], $id];
                $nuevas += Base::ejecutar('INSERT IGNORE INTO coincidencias (reporte_perdido_id, reporte_encontrado_id, similitud) VALUES (?, ?, ?)', [$perdido, $encontrado, $similitud]);
            }
            return ['id' => $id, 'nuevas' => $nuevas];
        });

        $fila = Base::uno('SELECT * FROM reportes WHERE id = ?', [$resultado['id']]);
        return Respuesta::json(['ok' => true, 'reporte' => Serializadores::reporte($fila), 'coincidenciasNuevas' => $resultado['nuevas']], 201);
    }

    public static function listar(Solicitud $s): array
    {
        $u = $s->usuario['id'];
        $filas = Base::todos(
            'SELECT c.id, c.similitud, c.creado_en, rp.id AS rp_id, rp.tipo AS rp_tipo, rp.descripcion AS rp_descripcion, rp.zona AS rp_zona,
                    rp.foto AS rp_foto, rp.foto_alt AS rp_alt, rp.creado_en AS rp_fecha,
                    re.descripcion AS re_descripcion, re.zona AS re_zona, re.foto AS re_foto, re.foto_alt AS re_alt,
                    ue.nombre AS ue_nombre, ue.telefono AS ue_telefono, ue.correo AS ue_correo
               ' . self::BASE . '
               JOIN reportes re ON re.id = c.reporte_encontrado_id
               JOIN usuarios ue ON ue.id = re.usuario_id
              WHERE NOT ' . self::DESCARTADA . '
              ORDER BY c.similitud DESC, c.id',
            [$u, $u],
        );
        return ['coincidencias' => array_map(static fn (array $f): array => [
            'id' => (string) $f['id'], 'similitud' => (int) $f['similitud'], 'fecha' => Serializadores::fecha($f['creado_en']), 'reporteId' => (string) $f['rp_id'],
            'miReporte' => [
                'id' => (string) $f['rp_id'], 'tipo' => $f['rp_tipo'], 'descripcion' => $f['rp_descripcion'], 'zona' => $f['rp_zona'],
                'foto' => $f['rp_foto'], 'fotoAlt' => $f['rp_alt'] ?: 'Tu reporte', 'fecha' => Serializadores::fecha($f['rp_fecha']),
            ],
            'hallazgo' => [
                'descripcion' => $f['re_descripcion'], 'zona' => $f['re_zona'], 'foto' => $f['re_foto'], 'fotoAlt' => $f['re_alt'] ?: 'Mascota encontrada',
                'contacto' => ['nombre' => $f['ue_nombre'], 'telefono' => $f['ue_telefono'] ?: 'No indicó teléfono', 'correo' => $f['ue_correo']],
            ],
        ], $filas)];
    }

    public static function resumen(Solicitud $s): array
    {
        $u = $s->usuario['id'];
        $contar = static fn (bool $descartadas): int => (int) Base::valor(
            'SELECT COUNT(*) ' . self::BASE . ' WHERE ' . ($descartadas ? '' : 'NOT ') . self::DESCARTADA,
            [$u, $u],
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
        if (!Base::uno('SELECT c.id ' . self::BASE . ' WHERE c.id = ?', [$s->usuario['id'], $id])) {
            throw new ErrorHttp(404, 'Esa coincidencia no existe.');
        }
        Base::ejecutar('INSERT IGNORE INTO coincidencias_descartadas (usuario_id, coincidencia_id) VALUES (?, ?)', [$s->usuario['id'], $id]);
        return ['ok' => true];
    }
}
