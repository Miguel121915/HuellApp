<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Serializadores — Convierten filas de la BD en el JSON que espera el cliente.
 * Los ids salen como TEXTO ("12") para poder compararlos con los de atributos HTML (data-id).
 */
final class Serializadores
{
    /** "2026-10-15 14:30:00.123" (UTC) → "2026-10-15T14:30:00.123Z" */
    public static function fecha(?string $valor): ?string
    {
        return $valor === null ? null : str_replace(' ', 'T', $valor) . 'Z';
    }

    public static function mascota(array $r): array
    {
        return [
            'id' => (string) $r['id'], 'refugioId' => (string) $r['refugio_id'], 'nombre' => $r['nombre'], 'especie' => $r['especie'],
            'raza' => $r['raza'], 'edadMeses' => (int) $r['edad_meses'], 'sexo' => $r['sexo'], 'tamano' => $r['tamano'],
            'salud' => $r['salud'], 'descripcion' => $r['descripcion'], 'foto' => $r['foto'], 'estatus' => $r['estatus'],
        ];
    }

    public static function documento(array $r): array
    {
        return ['id' => (string) $r['id'], 'tipo' => $r['tipo'], 'nombre' => $r['nombre'], 'tamano' => (int) $r['tamano'],
            'mime' => $r['mime'], 'verificado' => (bool) $r['verificado']]
            // Solo los documentos del refugio: el administrador los señala como erróneos al rechazar
            + (array_key_exists('con_error', $r) ? ['conError' => (bool) $r['con_error'], 'fecha' => self::fecha($r['creado_en'])] : []);
    }

    /** Datos públicos de un refugio (sin correo ni documentos). */
    public static function refugioPublico(array $r): array
    {
        return ['id' => (string) $r['id'], 'nombre' => $r['nombre'], 'responsable' => $r['responsable'], 'telefono' => $r['telefono'],
            'direccion' => $r['direccion'], 'horario' => $r['horario'], 'descripcion' => $r['descripcion'], 'estado' => $r['estado']];
    }

    /** Datos completos para el propio refugio y para el administrador. */
    public static function refugioCompleto(array $r, array $documentos = []): array
    {
        return self::refugioPublico($r) + [
            'correo' => $r['correo'], 'motivoRechazo' => $r['motivo_rechazo'], 'fechaSolicitud' => self::fecha($r['creado_en']),
            'revisadoEn' => self::fecha($r['revisado_en']), 'documentos' => array_map([self::class, 'documento'], $documentos),
            'apelaciones' => (int) ($r['apelaciones'] ?? 0), 'motivoAnterior' => $r['motivo_anterior'] ?? '',
            'apeladoEn' => self::fecha($r['apelado_en'] ?? null),
        ];
    }

    /** Documento especial de una mascota (vacunas, esterilización, pedigree...). */
    public static function documentoMascota(array $r): array
    {
        return self::documento($r) + ['mascotaId' => (string) $r['mascota_id'], 'fecha' => self::fecha($r['creado_en'])];
    }

    /** `fecha` es la de la última (re)publicación: es la que ven los usuarios y la que ordena la lista. */
    public static function publicacionRefugio(array $r): array
    {
        return ['id' => (string) $r['id'], 'refugioId' => (string) $r['refugio_id'], 'mascotaId' => (string) $r['mascota_id'],
            'autor' => $r['refugio_nombre'], 'fecha' => self::fecha($r['publicado_en'] ?? $r['creado_en']), 'creadoEn' => self::fecha($r['creado_en']),
            'texto' => $r['texto'], 'foto' => $r['foto'], 'fotoAlt' => $r['foto_alt']];
    }

    /** Datos de republicación (solo para el propio refugio). */
    public static function republicacion(array $r): array
    {
        return [
            'republicarCadaDias' => $r['republicar_cada_dias'] === null ? null : (int) $r['republicar_cada_dias'],
            'republicadaVeces' => (int) $r['republicada_veces'],
            'proximaRepublicacion' => Republicacion::proxima($r),
        ];
    }

    public static function reporte(array $r): array
    {
        return ['id' => (string) $r['id'], 'tipo' => $r['tipo'], 'descripcion' => $r['descripcion'], 'zona' => $r['zona'],
            'foto' => $r['foto'], 'fotoAlt' => $r['foto_alt'] ?: 'Foto del reporte', 'fecha' => self::fecha($r['creado_en'])];
    }
}
