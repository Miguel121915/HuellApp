<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Avisos — Notificaciones dentro de la app y el sitio (HU-19).
 *
 * Cuando pasa algo que le importa a una cuenta (le respondieron, cambió su solicitud, hay una
 * coincidencia nueva…) se guarda un aviso para esa cuenta. La app y el sitio los consultan cada
 * 30 segundos (GET /api/avisos) y muestran la campana con el número de no leídos; el sitio además
 * puede mostrar una notificación del navegador si la persona lo permite.
 *
 * `seccion` dice a dónde lleva el aviso; cada cliente la traduce a su pantalla:
 *   coincidencias · solicitudes · mensajes · foro · refugio-mensajes · refugio-adopciones · estado-refugio
 */
final class Avisos
{
    public const SECCIONES = ['coincidencias', 'solicitudes', 'mensajes', 'foro', 'refugio-mensajes', 'refugio-adopciones', 'estado-refugio'];
    private const MAX_LISTA = 30;

    /**
     * Guarda un aviso. Nunca lanza errores: un aviso que falla no debe romper la acción principal
     * (enviar un mensaje, cambiar una solicitud…), así que solo se registra en la terminal.
     */
    public static function crear(int $usuarioId, string $seccion, string $titulo, string $texto = ''): void
    {
        if ($usuarioId <= 0) {
            return;
        }
        try {
            Base::insertar(
                'INSERT INTO avisos (usuario_id, seccion, titulo, texto, creado_en) VALUES (?, ?, ?, ?, ?)',
                [$usuarioId, in_array($seccion, self::SECCIONES, true) ? $seccion : 'foro', mb_substr($titulo, 0, 120), mb_substr($texto, 0, 300) ?: null, Base::ahora()],
            );
        } catch (\Throwable $e) {
            error_log('No se pudo guardar el aviso: ' . $e->getMessage());
        }
    }

    /** Aviso para la cuenta responsable de un refugio. */
    public static function aRefugio(int $refugioId, string $seccion, string $titulo, string $texto = ''): void
    {
        try {
            $usuarioId = (int) Base::valor('SELECT usuario_id FROM refugios WHERE id = ?', [$refugioId]);
        } catch (\Throwable $e) {
            return;
        }
        self::crear($usuarioId, $seccion, $titulo, $texto);
    }

    /* ---------- Rutas ---------- */

    public static function registrar(Enrutador $r): void
    {
        $sesion = [[Sesion::class, 'requiereSesion']];
        $r->get('/avisos', [self::class, 'listar'], $sesion);
        $r->post('/avisos/leidos', [self::class, 'marcarLeidos'], $sesion);
    }

    // GET /api/avisos — los más recientes y cuántos no se han leído
    public static function listar(Solicitud $s): array
    {
        $u = (int) $s->usuario['id'];
        $filas = Base::todos(
            'SELECT * FROM avisos WHERE usuario_id = ? ORDER BY creado_en DESC, id DESC FETCH FIRST ' . self::MAX_LISTA . ' ROWS ONLY',
            [$u],
        );
        return [
            'noLeidos' => (int) Base::valor('SELECT COUNT(*) FROM avisos WHERE usuario_id = ? AND leido = 0', [$u]),
            'avisos' => array_map(static fn (array $a): array => [
                'id' => (string) $a['id'], 'seccion' => $a['seccion'], 'titulo' => $a['titulo'], 'texto' => $a['texto'] ?? '',
                'leido' => (int) $a['leido'] === 1, 'fecha' => Serializadores::fecha($a['creado_en']),
            ], $filas),
        ];
    }

    // POST /api/avisos/leidos — { ids?: [..] }; sin ids marca todos
    public static function marcarLeidos(Solicitud $s): array
    {
        $ids = array_values(array_filter(
            array_map(static fn ($v) => is_scalar($v) && ctype_digit((string) $v) ? (int) $v : 0, is_array($s->cuerpo()['ids'] ?? null) ? $s->cuerpo()['ids'] : []),
        ));
        if ($ids === []) {
            Base::ejecutar('UPDATE avisos SET leido = 1 WHERE usuario_id = ? AND leido = 0', [$s->usuario['id']]);
        } else {
            $ids = array_slice($ids, 0, 100);
            Base::ejecutar(
                'UPDATE avisos SET leido = 1 WHERE usuario_id = ? AND id IN (' . implode(',', array_fill(0, count($ids), '?')) . ')',
                [$s->usuario['id'], ...$ids],
            );
        }
        return ['ok' => true];
    }
}
