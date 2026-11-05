<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * DocumentosMascota — Documentos especiales de cada mascota (certificado de vacunación,
 * esterilización, pedigree...). Los sube el refugio dueño y los revisa el administrador.
 * Los archivos van a la carpeta PRIVADA de documentos (igual que los del registro del refugio).
 */
final class DocumentosMascota
{
    public const TIPOS = ['vacunacion', 'esterilizacion', 'desparasitacion', 'pedigree', 'medico', 'otro'];
    public const MAX_POR_MASCOTA = 10;

    /** @return list<array> filas de la tabla, en orden de subida */
    public static function deMascota(int $mascotaId): array
    {
        return Base::todos('SELECT * FROM documentos_mascota WHERE mascota_id = ? ORDER BY id', [$mascotaId]);
    }

    /**
     * Conteo de documentos por mascota, para mostrarlo en listas.
     * @param list<int|string> $mascotaIds
     * @return array<int, array{total:int, verificados:int}>
     */
    public static function conteos(array $mascotaIds): array
    {
        if (!$mascotaIds) {
            return [];
        }
        $filas = Base::todos(
            'SELECT mascota_id, COUNT(*) AS total, SUM(verificado) AS verificados FROM documentos_mascota
              WHERE mascota_id IN (' . implode(',', array_fill(0, count($mascotaIds), '?')) . ') GROUP BY mascota_id',
            array_map('intval', $mascotaIds),
        );
        $conteos = [];
        foreach ($filas as $f) {
            $conteos[(int) $f['mascota_id']] = ['total' => (int) $f['total'], 'verificados' => (int) $f['verificados']];
        }
        return $conteos;
    }

    /** Serializa mascotas agregando `documentos: {total, verificados}`. */
    public static function mascotasConConteo(array $filas): array
    {
        $conteos = self::conteos(array_column($filas, 'id'));
        return array_map(
            static fn ($m) => Serializadores::mascota($m) + ['documentos' => $conteos[(int) $m['id']] ?? ['total' => 0, 'verificados' => 0]],
            $filas,
        );
    }

    /** Valida y guarda un documento nuevo. Devuelve la fila creada. */
    public static function subir(array $mascota, array $cuerpo): array
    {
        if ((int) Base::valor('SELECT COUNT(*) FROM documentos_mascota WHERE mascota_id = ?', [$mascota['id']]) >= self::MAX_POR_MASCOTA) {
            throw new ErrorHttp(400, 'Esta mascota ya tiene ' . self::MAX_POR_MASCOTA . ' documentos. Elimina alguno para subir otro.');
        }
        $tipo = Validar::enumerado($cuerpo['tipo'] ?? null, 'El tipo de documento', self::TIPOS);
        $nombre = Validar::texto($cuerpo['nombre'] ?? null, 'El nombre del documento', max: 120);
        $archivo = Archivos::guardarDocumento($cuerpo['dataUrl'] ?? null, "El documento «{$nombre}»");
        $id = Base::insertar(
            'INSERT INTO documentos_mascota (mascota_id, refugio_id, tipo, nombre, archivo, mime, tamano, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [$mascota['id'], $mascota['refugio_id'], $tipo, $nombre, $archivo['archivo'], $archivo['mime'], $archivo['tamano'], Base::ahora()],
        );
        return Base::uno('SELECT * FROM documentos_mascota WHERE id = ?', [$id]);
    }

    /** Entrega el archivo con las mismas cabeceras seguras que los documentos del refugio. */
    public static function servir(array $documento): Respuesta
    {
        $ruta = Archivos::rutaDocumento($documento['archivo']);
        if (!is_file($ruta)) {
            throw new ErrorHttp(404, 'El archivo ya no está disponible.');
        }
        return Respuesta::archivo($ruta, [
            'Content-Type' => $documento['mime'],
            'Content-Disposition' => "inline; filename*=UTF-8''" . rawurlencode($documento['nombre']),
            'Content-Security-Policy' => 'sandbox',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    /** Borra del disco los archivos de todos los documentos de una mascota (antes de eliminarla). */
    public static function borrarArchivosDeMascota(int $mascotaId): void
    {
        Archivos::borrarDocumentos(array_column(self::deMascota($mascotaId), 'archivo'));
    }
}
