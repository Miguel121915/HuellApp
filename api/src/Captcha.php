<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * CAPTCHA del sitio web con Cloudflare Turnstile («no soy un robot» casi siempre de un solo clic).
 *
 * Se pide en el REGISTRO de usuarios y en el INICIO DE SESIÓN después de varios intentos fallidos,
 * solo para peticiones que vienen del sitio web (la página la sirve esta misma API). La app móvil no
 * lo muestra: se protege con el límite de intentos por IP que ya tiene la API.
 *
 * Configuración en api/.env (vacías = sin CAPTCHA):
 *   TURNSTILE_SITE_KEY=...     (pública, la usa la página)
 *   TURNSTILE_SECRET_KEY=...   (privada, solo aquí)
 * Claves de PRUEBA de Cloudflare (siempre pasan, sirven para desarrollo):
 *   TURNSTILE_SITE_KEY=1x00000000000000000000AA
 *   TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA
 */
final class Captcha
{
    private const URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

    public static function activo(): bool
    {
        return Config::obtener('TURNSTILE_SITE_KEY') !== '' && Config::obtener('TURNSTILE_SECRET_KEY') !== '';
    }

    /** Clave pública para la página ('' = sin CAPTCHA). */
    public static function claveSitio(): string
    {
        return self::activo() ? Config::obtener('TURNSTILE_SITE_KEY') : '';
    }

    /** ¿La petición viene del sitio web que sirve esta API? (el navegador manda Origin = este host) */
    public static function desdeSitioWeb(Solicitud $s): bool
    {
        $origen = $s->cabecera('Origin');
        $host = $s->cabecera('Host');
        if ($origen === null || $host === null) {
            return false;
        }
        $partes = parse_url($origen);
        $origenHost = ($partes['host'] ?? '') . (isset($partes['port']) ? ':' . $partes['port'] : '');
        return strcasecmp($origenHost, $host) === 0;
    }

    /**
     * Exige un CAPTCHA válido en el campo "captcha" del cuerpo (si está activo y la petición viene del sitio).
     * Lanza 400 con codigo "requiere-captcha" para que la página lo muestre.
     */
    public static function exigir(Solicitud $s): void
    {
        if (!self::activo() || !self::desdeSitioWeb($s)) {
            return;
        }
        $token = $s->cuerpo()['captcha'] ?? null;
        if (!is_string($token) || $token === '') {
            throw new ErrorHttp(400, 'Confirma que no eres un robot.', ['codigo' => 'requiere-captcha']);
        }
        if (!self::verificar($token, $s->ip())) {
            throw new ErrorHttp(400, 'No pudimos confirmar que no eres un robot. Inténtalo de nuevo.', ['codigo' => 'requiere-captcha']);
        }
    }

    private static function verificar(string $token, string $ip): bool
    {
        $datos = http_build_query(['secret' => Config::obtener('TURNSTILE_SECRET_KEY'), 'response' => $token, 'remoteip' => $ip]);
        if (function_exists('curl_init')) {
            $c = curl_init(self::URL);
            curl_setopt_array($c, [
                CURLOPT_POST => true, CURLOPT_POSTFIELDS => $datos, CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT => 10, CURLOPT_CONNECTTIMEOUT => 5,
            ]);
            $cuerpo = curl_exec($c);
            curl_close($c);
        } else {
            $contexto = stream_context_create(['http' => [
                'method' => 'POST', 'header' => 'Content-Type: application/x-www-form-urlencoded', 'content' => $datos, 'timeout' => 10,
            ]]);
            $cuerpo = @file_get_contents(self::URL, false, $contexto);
        }
        $r = is_string($cuerpo) ? json_decode($cuerpo, true) : null;
        if (!is_array($r)) {
            error_log('Turnstile: sin respuesta de Cloudflare');
            return false;
        }
        return ($r['success'] ?? false) === true;
    }
}
