<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Totp — Códigos de 6 dígitos que cambian cada 30 segundos (RFC 6238), los mismos que muestran
 * Google Authenticator, Microsoft Authenticator o Authy. No usa internet ni servicios externos:
 * el teléfono y la API calculan el código con el mismo secreto y la hora.
 */
final class Totp
{
    private const ALFABETO = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; // Base32 (RFC 4648)
    private const PERIODO = 30;
    private const DIGITOS = 6;
    /** Se aceptan el código anterior y el siguiente por si el reloj del teléfono va un poco desfasado. */
    private const TOLERANCIA = 1;

    /** Secreto nuevo de 160 bits en Base32 (32 caracteres), como lo pide Google Authenticator. */
    public static function nuevoSecreto(): string
    {
        return self::base32(random_bytes(20));
    }

    /** Enlace otpauth:// que se convierte en QR (o se abre en el teléfono) para dar de alta la cuenta. */
    public static function enlace(string $secreto, string $cuenta, string $emisor = 'HuellApp'): string
    {
        return 'otpauth://totp/' . rawurlencode("$emisor:$cuenta") . '?' . http_build_query([
            'secret' => $secreto, 'issuer' => $emisor, 'algorithm' => 'SHA1', 'digits' => self::DIGITOS, 'period' => self::PERIODO,
        ], '', '&', PHP_QUERY_RFC3986);
    }

    /** Código para un paso de tiempo (paso = segundos Unix / 30). */
    public static function codigo(string $secreto, int $paso): string
    {
        $hash = hash_hmac('sha1', pack('J', $paso), self::base32Inverso($secreto), true);
        $desplazamiento = ord($hash[19]) & 0x0F;
        $numero = ((ord($hash[$desplazamiento]) & 0x7F) << 24) | (ord($hash[$desplazamiento + 1]) << 16)
            | (ord($hash[$desplazamiento + 2]) << 8) | ord($hash[$desplazamiento + 3]);
        return str_pad((string) ($numero % 10 ** self::DIGITOS), self::DIGITOS, '0', STR_PAD_LEFT);
    }

    public static function pasoActual(?int $ahora = null): int
    {
        return intdiv($ahora ?? time(), self::PERIODO);
    }

    /**
     * Revisa un código escrito por la persona. Devuelve el paso de tiempo que coincidió (para que el
     * mismo código no se pueda usar dos veces) o null si no es válido.
     * $ultimoPaso = último paso ya usado por esa cuenta: ese y los anteriores se rechazan.
     */
    public static function verificar(string $secreto, string $codigo, ?int $ultimoPaso = null, ?int $ahora = null): ?int
    {
        $codigo = preg_replace('/\s+/', '', $codigo) ?? '';
        if (!preg_match('/^\d{' . self::DIGITOS . '}$/', $codigo)) {
            return null;
        }
        $actual = self::pasoActual($ahora);
        for ($paso = $actual - self::TOLERANCIA; $paso <= $actual + self::TOLERANCIA; $paso++) {
            if ($ultimoPaso !== null && $paso <= $ultimoPaso) {
                continue;
            }
            if (hash_equals(self::codigo($secreto, $paso), $codigo)) { // comparación en tiempo constante
                return $paso;
            }
        }
        return null;
    }

    public static function base32(string $bytes): string
    {
        $bits = '';
        foreach (str_split($bytes) as $byte) {
            $bits .= str_pad(decbin(ord($byte)), 8, '0', STR_PAD_LEFT);
        }
        $texto = '';
        foreach (str_split($bits, 5) as $grupo) {
            $texto .= self::ALFABETO[bindec(str_pad($grupo, 5, '0'))];
        }
        return $texto;
    }

    public static function base32Inverso(string $texto): string
    {
        $texto = strtoupper(preg_replace('/[\s=-]+/', '', $texto) ?? '');
        $bits = '';
        foreach (str_split($texto) as $letra) {
            $valor = strpos(self::ALFABETO, $letra);
            if ($valor === false) {
                throw new \InvalidArgumentException('Secreto Base32 no válido.');
            }
            $bits .= str_pad(decbin($valor), 5, '0', STR_PAD_LEFT);
        }
        $bytes = '';
        foreach (str_split($bits, 8) as $octeto) {
            if (strlen($octeto) === 8) {
                $bytes .= chr(bindec($octeto));
            }
        }
        return $bytes;
    }
}
