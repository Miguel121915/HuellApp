<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Similitud — Comparación SIMULADA entre un reporte de pérdida y uno de hallazgo.
 *
 * No es reconocimiento de imágenes: compara las palabras de las descripciones y de la zona.
 * Sirve para que la pantalla «Coincidencias» funcione con datos reales mientras no exista un
 * servicio de comparación de fotos.
 */
final class Similitud
{
    public const UMBRAL = 40;

    private const PALABRAS_VACIAS = ('de la el los las un una unos unas que con sin por para del al lo se su sus mi mis es son esta este '
        . 'estan estar fue muy mas pero como cuando donde hay tiene tienen tengo hace hacia desde sobre entre cerca hola gracias algun alguien '
        . 'cualquier dato informacion favor ayuda ayudar');

    private const ACENTOS = [
        'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n',
        'Á' => 'a', 'É' => 'e', 'Í' => 'i', 'Ó' => 'o', 'Ú' => 'u', 'Ü' => 'u', 'Ñ' => 'n',
    ];

    /** @return array<string,true> conjunto de palabras significativas */
    public static function palabras(string $texto): array
    {
        $vacias = array_flip(explode(' ', self::PALABRAS_VACIAS));
        $limpio = strtolower(strtr($texto, self::ACENTOS));
        $conjunto = [];
        foreach (preg_split('/[^a-z0-9]+/', $limpio, -1, PREG_SPLIT_NO_EMPTY) ?: [] as $palabra) {
            if (strlen($palabra) >= 3 && !isset($vacias[$palabra])) {
                $conjunto[$palabra] = true;
            }
        }
        return $conjunto;
    }

    /** Proporción de palabras compartidas respecto al texto más corto (0 a 1). */
    private static function cobertura(array $a, array $b): float
    {
        if (!$a || !$b) {
            return 0.0;
        }
        return count(array_intersect_key($a, $b)) / min(count($a), count($b));
    }

    /** Porcentaje 0-99: 70 % descripción + 30 % zona. */
    public static function calcular(array $a, array $b): int
    {
        $puntaje = 0.7 * self::cobertura(self::palabras($a['descripcion']), self::palabras($b['descripcion']))
            + 0.3 * self::cobertura(self::palabras($a['zona']), self::palabras($b['zona']));
        return min(99, (int) round($puntaje * 100));
    }
}
