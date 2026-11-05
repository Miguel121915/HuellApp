<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Respuesta, Serializadores, Sesion, Solicitud, Validar};

/**
 * HU-13 Contacto con el refugio:
 *  - El usuario escribe al refugio responsable de una mascota (o al refugio en general) y ve las respuestas.
 *  - El refugio ve los mensajes que recibe, los marca como leídos y los responde.
 * El refugio destino sale de la mascota cuando hay mascota, así el usuario no puede escribirle a otro.
 */
final class Mensajes
{
    private const MAX_POR_HORA = 10;

    private const SELECT = 'SELECT c.*, r.nombre AS refugio_nombre, m.nombre AS mascota_nombre, m.foto AS mascota_foto,
               u.nombre AS usuario_nombre, u.correo AS usuario_correo
          FROM mensajes_refugio c
          JOIN refugios r ON r.id = c.refugio_id
          JOIN usuarios u ON u.id = c.usuario_id
          LEFT JOIN mascotas m ON m.id = c.mascota_id';

    public static function registrar(Enrutador $r): void
    {
        $sesion = [Sesion::class, 'requiereSesion'];
        $r->grupo('/mensajes', [$sesion, Sesion::requiereRol('usuario')], static function (Enrutador $r): void {
            $r->get('', [self::class, 'misMensajes']);
            $r->post('', [self::class, 'enviar']);
        });
        $r->grupo('/refugio', [$sesion, Sesion::requiereRol('refugio'), [Sesion::class, 'requiereRefugioAprobado']], static function (Enrutador $r): void {
            $r->get('/mensajes', [self::class, 'recibidos']);
            $r->patch('/mensajes/{id}', [self::class, 'responder']);
        });
    }

    /** @param bool $paraRefugio  true = con nombre y correo de quien escribe */
    private static function mensaje(array $f, bool $paraRefugio): array
    {
        $base = [
            'id' => (string) $f['id'], 'refugioId' => (string) $f['refugio_id'], 'refugioNombre' => $f['refugio_nombre'],
            'mascotaId' => $f['mascota_id'] === null ? null : (string) $f['mascota_id'],
            'mascotaNombre' => $f['mascota_nombre'] ?? '', 'mascotaFoto' => $f['mascota_foto'] ?? '',
            'mensaje' => $f['mensaje'], 'respuesta' => $f['respuesta'] ?? '', 'estado' => $f['estado'],
            'fecha' => Serializadores::fecha($f['creado_en']), 'respondido' => Serializadores::fecha($f['respondido_en']),
        ];
        return $paraRefugio
            ? $base + ['usuarioNombre' => $f['usuario_nombre'], 'usuarioCorreo' => $f['usuario_correo'], 'telefono' => $f['telefono'] ?? '']
            : $base;
    }

    /* ---------- Usuario ---------- */

    public static function misMensajes(Solicitud $s): array
    {
        $filas = Base::todos(self::SELECT . ' WHERE c.usuario_id = ? ORDER BY c.creado_en DESC, c.id DESC', [$s->usuario['id']]);
        return ['mensajes' => array_map(static fn ($f) => self::mensaje($f, false), $filas)];
    }

    public static function enviar(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $mascotaId = null;
        if (isset($b['mascotaId']) && $b['mascotaId'] !== '') {
            $m = is_scalar($b['mascotaId']) && ctype_digit((string) $b['mascotaId'])
                ? Base::uno('SELECT id, refugio_id FROM mascotas WHERE id = ?', [(int) $b['mascotaId']])
                : null;
            if ($m === null) {
                throw new ErrorHttp(404, 'Esa mascota ya no está disponible.');
            }
            $mascotaId = (int) $m['id'];
            $refugioId = (int) $m['refugio_id']; // el refugio responsable de la mascota
        } else {
            $refugioId = is_scalar($b['refugioId'] ?? null) && ctype_digit((string) $b['refugioId']) ? (int) $b['refugioId'] : 0;
        }
        if (Base::uno("SELECT id FROM refugios WHERE id = ? AND estado = 'aprobado'", [$refugioId]) === null) {
            throw new ErrorHttp(404, 'Ese refugio no está disponible.');
        }
        $recientes = (int) Base::valor('SELECT COUNT(*) FROM mensajes_refugio WHERE usuario_id = ? AND creado_en > ?', [$s->usuario['id'], Base::ahora(3600)]);
        if ($recientes >= self::MAX_POR_HORA) {
            throw new ErrorHttp(429, 'Enviaste muchos mensajes en poco tiempo. Espera un rato y vuelve a intentarlo.');
        }
        $texto = Validar::texto($b['mensaje'] ?? null, 'El mensaje', min: 10, max: 1000);
        $telefono = Validar::telefono($b['telefono'] ?? null, opcional: true);
        $id = Base::insertar(
            'INSERT INTO mensajes_refugio (usuario_id, refugio_id, mascota_id, mensaje, telefono, estado, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [$s->usuario['id'], $refugioId, $mascotaId, $texto, $telefono, 'nuevo', Base::ahora()],
        );
        return Respuesta::json(['ok' => true, 'mensaje' => self::mensaje(Base::uno(self::SELECT . ' WHERE c.id = ?', [$id]), false)], 201);
    }

    /* ---------- Refugio ---------- */

    public static function recibidos(Solicitud $s): array
    {
        $filas = Base::todos(
            self::SELECT . " WHERE c.refugio_id = ? ORDER BY CASE c.estado WHEN 'nuevo' THEN 0 WHEN 'leido' THEN 1 ELSE 2 END, c.creado_en DESC, c.id DESC",
            [$s->refugio['id']],
        );
        return ['mensajes' => array_map(static fn ($f) => self::mensaje($f, true), $filas)];
    }

    /** Sin «respuesta» solo lo marca como leído; con «respuesta» lo responde (y se puede corregir después). */
    public static function responder(Solicitud $s): array
    {
        $actual = Base::uno('SELECT * FROM mensajes_refugio WHERE id = ? AND refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($actual === null) {
            throw new ErrorHttp(404, 'Ese mensaje ya no existe.');
        }
        $b = $s->cuerpo();
        if (array_key_exists('respuesta', $b)) {
            $respuesta = Validar::texto($b['respuesta'], 'La respuesta', min: 2, max: 1000);
            Base::ejecutar("UPDATE mensajes_refugio SET respuesta = ?, estado = 'respondido', respondido_en = ? WHERE id = ?", [$respuesta, Base::ahora(), $actual['id']]);
        } elseif ($actual['estado'] === 'nuevo') {
            Base::ejecutar("UPDATE mensajes_refugio SET estado = 'leido' WHERE id = ?", [$actual['id']]);
        }
        return ['ok' => true, 'mensaje' => self::mensaje(Base::uno(self::SELECT . ' WHERE c.id = ?', [$actual['id']]), true)];
    }
}
