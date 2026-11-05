<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Republicacion — Vuelve a poner "como nuevas" las publicaciones del refugio que tienen
 * republicación automática (cada N días).
 *
 * No necesita un cron: se aplica justo antes de listar publicaciones. Como la fecha y el orden
 * solo importan cuando alguien las mira, el resultado es el mismo que con una tarea programada.
 * También se puede forzar con:  php artisan publicaciones:republicar
 *
 * Si pasaron varios periodos sin que nadie mirara, se republica una sola vez (no se "acumulan").
 * Las publicaciones de mascotas adoptadas no se republican.
 */
final class Republicacion
{
    public const MIN_DIAS = 1;
    public const MAX_DIAS = 90;

    /** @return int cuántas publicaciones se republicaron */
    public static function aplicar(?int $refugioId = null): int
    {
        $ahora = Base::ahora();
        return Base::ejecutar(
            "UPDATE publicaciones_refugio p
               JOIN mascotas m ON m.id = p.mascota_id
                SET p.publicado_en = ?, p.republicada_veces = p.republicada_veces + 1
              WHERE p.republicar_cada_dias IS NOT NULL
                AND m.estatus <> 'adoptado'
                AND p.publicado_en <= DATE_SUB(?, INTERVAL p.republicar_cada_dias DAY)"
                . ($refugioId !== null ? ' AND p.refugio_id = ?' : ''),
            $refugioId !== null ? [$ahora, $ahora, $refugioId] : [$ahora, $ahora],
        );
    }

    /** Lee la periodicidad enviada por el cliente: null/"" = desactivada; si no, entero de 1 a 90 días. */
    public static function leerPeriodicidad(mixed $valor): ?int
    {
        if ($valor === null || $valor === '' || $valor === 0 || $valor === '0') {
            return null;
        }
        return Validar::entero($valor, 'La republicación (días)', self::MIN_DIAS, self::MAX_DIAS);
    }

    /** Fecha ISO de la próxima republicación, o null si no tiene. */
    public static function proxima(array $fila): ?string
    {
        if (($fila['republicar_cada_dias'] ?? null) === null || ($fila['mascota_estatus'] ?? '') === 'adoptado') {
            return null;
        }
        $fecha = new \DateTimeImmutable($fila['publicado_en'], new \DateTimeZone('UTC'));
        return Serializadores::fecha($fecha->modify('+' . (int) $fila['republicar_cada_dias'] . ' days')->format('Y-m-d H:i:s.v'));
    }
}
