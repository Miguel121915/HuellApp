<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Validar — Revisa lo que llega del cliente. NUNCA se confía en el navegador:
 * aunque el formulario ya valide, el servidor vuelve a revisar todo.
 */
final class Validar
{
    private static function falla(string $mensaje): never
    {
        throw new ErrorHttp(400, $mensaje);
    }

    public static function largo(string $texto): int
    {
        return function_exists('mb_strlen') ? mb_strlen($texto, 'UTF-8') : strlen($texto);
    }

    public static function texto(mixed $valor, string $nombre, int $min = 1, int $max = 200, bool $opcional = false): string
    {
        if ($valor === null || $valor === '') {
            if ($opcional) {
                return '';
            }
            self::falla("$nombre es obligatorio.");
        }
        if (!is_string($valor)) {
            self::falla("$nombre no es válido.");
        }
        $limpio = trim($valor);
        $largo = self::largo($limpio);
        if ($largo < $min) {
            self::falla("$nombre debe tener al menos $min caracteres.");
        }
        if ($largo > $max) {
            self::falla("$nombre no puede pasar de $max caracteres.");
        }
        return $limpio;
    }

    /** @param list<string> $permitidos */
    public static function enumerado(mixed $valor, string $nombre, array $permitidos): string
    {
        if (!is_string($valor) || !in_array($valor, $permitidos, true)) {
            self::falla("$nombre no es válido.");
        }
        return $valor;
    }

    public static function entero(mixed $valor, string $nombre, int $min, int $max): int
    {
        if (is_string($valor) && preg_match('/^-?\d+$/', $valor)) {
            $valor = (int) $valor;
        }
        if (!is_int($valor) || $valor < $min || $valor > $max) {
            self::falla("$nombre debe ser un número entero entre $min y $max.");
        }
        return $valor;
    }

    public static function correo(mixed $valor): string
    {
        $limpio = strtolower(self::texto($valor, 'El correo', max: 120));
        if (!preg_match('/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/', $limpio)) {
            self::falla('Escribe un correo válido, por ejemplo nombre@correo.com.');
        }
        return $limpio;
    }

    public static function telefono(mixed $valor, bool $opcional = false): string
    {
        $limpio = self::texto($valor, 'El teléfono', max: 25, opcional: $opcional);
        if ($limpio !== '' && !preg_match('/^[\d\s+()\-]{8,}$/', $limpio)) {
            self::falla('El teléfono debe tener al menos 8 dígitos (solo números, espacios, + - y paréntesis).');
        }
        return $limpio;
    }

    public static function password(mixed $valor): string
    {
        if (!is_string($valor) || strlen($valor) < 8) {
            self::falla('La contraseña debe tener al menos 8 caracteres.');
        }
        if (strlen($valor) > 100) {
            self::falla('La contraseña es demasiado larga.');
        }
        return $valor;
    }

    public static function horario(mixed $valor): string
    {
        $limpio = self::texto($valor, 'El horario', max: 20);
        if (!preg_match('/^(\d{2}:\d{2}) - (\d{2}:\d{2})$/', $limpio, $m) || $m[2] <= $m[1]) {
            self::falla('El horario debe ser como «09:00 - 18:00» y la hora de cierre posterior a la de apertura.');
        }
        return $limpio;
    }

    public static function booleano(mixed $valor, string $nombre): bool
    {
        if (!is_bool($valor)) {
            self::falla("$nombre debe ser verdadero o falso.");
        }
        return $valor;
    }

    /** Convierte el parámetro de la URL en un id numérico o responde 404. */
    public static function idDeRuta(string $valor): int
    {
        if (!ctype_digit($valor) || (int) $valor < 1) {
            throw new ErrorHttp(404, 'No se encontró lo que buscas.');
        }
        return (int) $valor;
    }
}
