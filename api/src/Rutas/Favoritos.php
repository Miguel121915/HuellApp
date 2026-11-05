<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Respuesta, Serializadores, Sesion, Solicitud, Validar};

/**
 * HU-12 Mascotas favoritas: el usuario guarda mascotas para compararlas después.
 * Se guardan en la base (no se pierden al cerrar la app) y son las mismas en la app y en la web.
 */
final class Favoritos
{
    private const MAX_FAVORITOS = 50;

    public static function registrar(Enrutador $r): void
    {
        $r->grupo('/favoritos', [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('usuario')], static function (Enrutador $r): void {
            $r->get('', [self::class, 'listar']);
            $r->post('', [self::class, 'agregar']);
            $r->delete('/{id}', [self::class, 'quitar']); // {id} = id de la MASCOTA
        });
    }

    /** Mis favoritos con los datos de la mascota y su refugio (para la vista y la comparación). */
    public static function listar(Solicitud $s): array
    {
        $filas = Base::todos(
            "SELECT m.*, r.nombre AS refugio_nombre, r.municipio AS refugio_municipio, f.creado_en AS guardado_en
               FROM favoritos f
               JOIN mascotas m ON m.id = f.mascota_id
               JOIN refugios r ON r.id = m.refugio_id
              WHERE f.usuario_id = ? AND r.estado = 'aprobado'
              ORDER BY f.creado_en DESC, f.id DESC",
            [$s->usuario['id']],
        );
        return ['favoritos' => array_map(static fn ($f) => Serializadores::mascota($f) + [
            'refugioNombre' => $f['refugio_nombre'],
            'refugioMunicipio' => $f['refugio_municipio'] ?? '',
            'guardado' => Serializadores::fecha($f['guardado_en']),
        ], $filas)];
    }

    public static function agregar(Solicitud $s): Respuesta
    {
        $id = $s->cuerpo()['mascotaId'] ?? null;
        $mascota = is_scalar($id) && ctype_digit((string) $id)
            ? Base::uno("SELECT m.id, m.nombre FROM mascotas m JOIN refugios r ON r.id = m.refugio_id WHERE m.id = ? AND r.estado = 'aprobado'", [(int) $id])
            : null;
        if ($mascota === null) {
            throw new ErrorHttp(404, 'Esa mascota ya no está disponible.');
        }
        if ((int) Base::valor('SELECT COUNT(*) FROM favoritos WHERE usuario_id = ?', [$s->usuario['id']]) >= self::MAX_FAVORITOS) {
            throw new ErrorHttp(400, 'Llegaste al máximo de ' . self::MAX_FAVORITOS . ' favoritos. Quita alguno para guardar otro.');
        }
        // Si ya estaba en favoritos no pasa nada (se puede tocar el corazón dos veces)
        Base::insertarSiNoExiste('INSERT INTO favoritos (usuario_id, mascota_id, creado_en) VALUES (?, ?, ?)', [$s->usuario['id'], $mascota['id'], Base::ahora()]);
        return Respuesta::json(['ok' => true, 'mascotaId' => (string) $mascota['id']], 201);
    }

    public static function quitar(Solicitud $s): array
    {
        Base::ejecutar('DELETE FROM favoritos WHERE usuario_id = ? AND mascota_id = ?', [$s->usuario['id'], Validar::idDeRuta($s->parametro('id'))]);
        return ['ok' => true];
    }
}
