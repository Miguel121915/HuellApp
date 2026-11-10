<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Google — Comprueba el "ID token" que entrega el botón «Continuar con Google» (sitio web y app).
 *
 * El token lo firma Google; aquí se le pregunta a Google si es auténtico (endpoint tokeninfo) y se
 * revisa que sea para NUESTRO Client ID, que no haya vencido y que el correo esté verificado.
 * Configuración en api/.env:  GOOGLE_CLIENT_ID=<id web>.apps.googleusercontent.com
 * (si hay varios Client ID, por ejemplo web y Android, sepáralos con comas; el primero es el web).
 */
final class Google
{
    private const TOKENINFO = 'https://oauth2.googleapis.com/tokeninfo?id_token=';
    private const EMISORES = ['accounts.google.com', 'https://accounts.google.com'];

    /** @return list<string> */
    public static function clientIds(): array
    {
        return array_values(array_filter(array_map('trim', explode(',', Config::obtener('GOOGLE_CLIENT_ID')))));
    }

    /** Client ID web: lo usan el botón del sitio y la app (serverClientId en Android). Vacío = desactivado. */
    public static function clientIdWeb(): string
    {
        return self::clientIds()[0] ?? '';
    }

    /**
     * Valida el ID token y devuelve los datos de la cuenta de Google.
     * @return array{sub:string, correo:string, nombre:string}
     */
    public static function verificar(string $idToken): array
    {
        $ids = self::clientIds();
        if ($ids === []) {
            throw new ErrorHttp(503, 'El inicio de sesión con Google no está configurado. Agrega GOOGLE_CLIENT_ID en api/.env.');
        }
        if (!preg_match('/^[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$/', $idToken) || strlen($idToken) > 4096) {
            throw new ErrorHttp(400, 'La respuesta de Google no es válida. Inténtalo de nuevo.');
        }
        [$estado, $cuerpo] = self::pedir(self::TOKENINFO . rawurlencode($idToken));
        if ($estado === 0) {
            throw new ErrorHttp(503, 'No se pudo contactar a Google para confirmar tu cuenta. Revisa la conexión a internet.');
        }
        $datos = json_decode($cuerpo, true);
        if ($estado !== 200 || !is_array($datos)) {
            throw new ErrorHttp(401, 'Google no confirmó tu inicio de sesión. Inténtalo de nuevo.');
        }
        $valido = in_array($datos['aud'] ?? '', $ids, true)
            && in_array($datos['iss'] ?? '', self::EMISORES, true)
            && (int) ($datos['exp'] ?? 0) > time()
            && is_string($datos['sub'] ?? null) && $datos['sub'] !== ''
            && is_string($datos['email'] ?? null)
            && in_array($datos['email_verified'] ?? false, [true, 'true'], true);
        if (!$valido) {
            throw new ErrorHttp(401, 'Google no confirmó tu inicio de sesión (o tu correo de Google no está verificado).');
        }
        $correo = strtolower(trim($datos['email']));
        $nombre = trim((string) ($datos['name'] ?? '')) ?: strstr($correo, '@', true);
        return ['sub' => $datos['sub'], 'correo' => $correo, 'nombre' => mb_substr($nombre, 0, 80)];
    }

    /** GET simple. Devuelve [código HTTP, cuerpo]; código 0 = sin conexión. */
    private static function pedir(string $url): array
    {
        if (function_exists('curl_init')) {
            $c = curl_init($url);
            curl_setopt_array($c, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10, CURLOPT_CONNECTTIMEOUT => 5]);
            $cuerpo = curl_exec($c);
            $estado = $cuerpo === false ? 0 : (int) curl_getinfo($c, CURLINFO_RESPONSE_CODE);
            curl_close($c);
            return [$estado, (string) $cuerpo];
        }
        $contexto = stream_context_create(['http' => ['timeout' => 10, 'ignore_errors' => true]]);
        $cuerpo = @file_get_contents($url, false, $contexto);
        if ($cuerpo === false) {
            return [0, ''];
        }
        $estado = preg_match('#^HTTP/\S+ (\d{3})#', $http_response_header[0] ?? '', $m) ? (int) $m[1] : 0;
        return [$estado, $cuerpo];
    }
}
