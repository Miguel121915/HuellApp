<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Republicacion, Serializadores, Sesion, Solicitud, Validar};

/**
 * Parte PÚBLICA de los refugios: lo que ven los usuarios al explorar.
 * Solo existen para los visitantes los refugios APROBADOS.
 */
final class Refugios
{
    public static function registrar(Enrutador $r): void
    {
        // Públicas: un visitante sin cuenta también puede ver refugios aprobados y sus mascotas
        $r->grupo('/refugios', [], static function (Enrutador $r): void {
            $r->get('', [self::class, 'listar']);
            $r->get('/{id}', [self::class, 'ver']);
            $r->get('/{id}/mascotas', [self::class, 'mascotas']);
            $r->get('/{id}/publicaciones', [self::class, 'publicaciones']);
        });
    }

    private static function aprobado(Solicitud $s): array
    {
        $refugio = Base::uno("SELECT * FROM refugios WHERE id = ? AND estado = 'aprobado'", [Validar::idDeRuta($s->parametro('id'))]);
        if ($refugio === null) {
            throw new ErrorHttp(404, 'Ese refugio no está disponible.');
        }
        return $refugio;
    }

    /**
     * Refugios aprobados. Con ?mascotas=1 cada refugio trae también sus mascotas disponibles:
     * así la app y la web cargan el catálogo con UNA petición y 2 consultas, en vez de una por refugio.
     */
    public static function listar(Solicitud $s): array
    {
        $refugios = array_map([Serializadores::class, 'refugioPublico'], Base::todos("SELECT * FROM refugios WHERE estado = 'aprobado' ORDER BY id"));
        if (($s->query['mascotas'] ?? '') !== '1') {
            return ['refugios' => $refugios];
        }
        $porRefugio = [];
        $filas = Base::todos(
            "SELECT m.* FROM mascotas m JOIN refugios r ON r.id = m.refugio_id
              WHERE r.estado = 'aprobado' AND m.estatus = 'disponible' ORDER BY m.refugio_id, m.id",
        );
        foreach ($filas as $f) {
            $porRefugio[(string) $f['refugio_id']][] = Serializadores::mascota($f);
        }
        return ['refugios' => array_map(static fn (array $r): array => $r + ['mascotas' => $porRefugio[(string) $r['id']] ?? []], $refugios)];
    }

    public static function ver(Solicitud $s): array
    {
        return ['refugio' => Serializadores::refugioPublico(self::aprobado($s))];
    }

    // Los usuarios solo ven mascotas DISPONIBLES
    public static function mascotas(Solicitud $s): array
    {
        $refugio = self::aprobado($s);
        return ['mascotas' => array_map([Serializadores::class, 'mascota'], Base::todos("SELECT * FROM mascotas WHERE refugio_id = ? AND estatus = 'disponible' ORDER BY id", [$refugio['id']]))];
    }

    // Publicaciones del refugio; se ocultan las de mascotas ya adoptadas
    public static function publicaciones(Solicitud $s): array
    {
        $refugio = self::aprobado($s);
        Republicacion::aplicar((int) $refugio['id']); // las que tocan republicarse vuelven a salir arriba
        $filas = Base::todos(
            "SELECT p.*, r.nombre AS refugio_nombre, m.nombre AS mascota_nombre
               FROM publicaciones_refugio p
               JOIN refugios r ON r.id = p.refugio_id
               JOIN mascotas m ON m.id = p.mascota_id
              WHERE p.refugio_id = ? AND m.estatus <> 'adoptado'
              ORDER BY p.publicado_en DESC, p.id DESC",
            [$refugio['id']],
        );
        return ['publicaciones' => array_map(
            static fn ($f) => Serializadores::publicacionRefugio($f) + ['etiqueta' => "Mascota: {$f['mascota_nombre']}"],
            $filas,
        )];
    }
}
