<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Sesion — Autenticación y permisos. Esta es la seguridad REAL: las guardias de ruta del sitio
 * solo mejoran la experiencia; aquí se decide quién puede hacer qué.
 *
 * El token es un JWT (HS256) firmado con JWT_SECRET: no se puede falsificar ni modificar.
 */
final class Sesion
{
    private const DURACION = 7 * 24 * 3600; // 7 días

    private static function b64(string $datos): string
    {
        return rtrim(strtr(base64_encode($datos), '+/', '-_'), '=');
    }

    private static function b64Inverso(string $texto): string|false
    {
        return base64_decode(strtr($texto, '-_', '+/'), true);
    }

    public static function crearToken(array $usuario): string
    {
        $cabecera = self::b64(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
        $carga = self::b64(json_encode(['sub' => (string) $usuario['id'], 'rol' => $usuario['rol'], 'exp' => time() + self::DURACION]));
        $firma = self::b64(hash_hmac('sha256', "$cabecera.$carga", Config::obtener('JWT_SECRET'), true));
        return "$cabecera.$carga.$firma";
    }

    /** Devuelve la carga del token si es válido y no venció; si no, null. */
    private static function verificar(string $token): ?array
    {
        $partes = explode('.', $token);
        if (count($partes) !== 3) {
            return null;
        }
        [$cabecera, $carga, $firma] = $partes;
        $esperada = self::b64(hash_hmac('sha256', "$cabecera.$carga", Config::obtener('JWT_SECRET'), true));
        if (!hash_equals($esperada, $firma)) { // comparación en tiempo constante
            return null;
        }
        $datos = json_decode((string) self::b64Inverso($carga), true);
        $encabezado = json_decode((string) self::b64Inverso($cabecera), true);
        if (!is_array($datos) || ($encabezado['alg'] ?? '') !== 'HS256' || ($datos['exp'] ?? 0) < time()) {
            return null;
        }
        return $datos;
    }

    /** Guardia: si viene un token válido carga al usuario; si no, sigue como visitante ($s->usuario = null). */
    public static function sesionOpcional(Solicitud $s): void
    {
        if (!preg_match('/^Bearer (.+)$/', $s->cabecera('authorization') ?? '', $m)) {
            return;
        }
        $carga = self::verificar($m[1]);
        if ($carga !== null) {
            $s->usuario = Base::uno('SELECT id, nombre, correo, telefono, rol FROM usuarios WHERE id = ?', [(int) $carga['sub']]);
        }
    }

    /* ---------- Verificación en dos pasos ----------
     * Si la cuenta tiene activado Google Authenticator, la contraseña (o Google) correcta NO da la
     * sesión: da un "desafío" de 5 minutos que solo sirve para POST /auth/2fa/verificar junto con el
     * código de 6 dígitos. Se firma con otra etiqueta, así que nunca vale como token de sesión.
     */
    private const VIGENCIA_DESAFIO = 300;

    public static function crearDesafio(int $usuarioId): string
    {
        $carga = self::b64(json_encode(['sub' => (string) $usuarioId, 'exp' => time() + self::VIGENCIA_DESAFIO]));
        return "$carga." . self::b64(hash_hmac('sha256', "desafio-2fa|$carga", Config::obtener('JWT_SECRET'), true));
    }

    /** Id del usuario del desafío, o null si es falso o ya venció. */
    public static function verificarDesafio(string $desafio): ?int
    {
        $partes = explode('.', $desafio);
        if (count($partes) !== 2) {
            return null;
        }
        [$carga, $firma] = $partes;
        $esperada = self::b64(hash_hmac('sha256', "desafio-2fa|$carga", Config::obtener('JWT_SECRET'), true));
        if (!hash_equals($esperada, $firma)) {
            return null;
        }
        $datos = json_decode((string) self::b64Inverso($carga), true);
        return is_array($datos) && ($datos['exp'] ?? 0) >= time() ? (int) ($datos['sub'] ?? 0) : null;
    }

    /** El secreto de Google Authenticator se guarda cifrado (AES-256-GCM con una clave derivada de JWT_SECRET). */
    private static function claveSecretos(): string
    {
        return hash_hmac('sha256', 'secretos-2fa', Config::obtener('JWT_SECRET'), true);
    }

    public static function cifrar(string $texto): string
    {
        $iv = random_bytes(12);
        $cifrado = openssl_encrypt($texto, 'aes-256-gcm', self::claveSecretos(), OPENSSL_RAW_DATA, $iv, $etiqueta);
        return 'v1:' . base64_encode($iv . $etiqueta . $cifrado);
    }

    public static function descifrar(string $guardado): ?string
    {
        if (!str_starts_with($guardado, 'v1:')) {
            return null;
        }
        $bin = base64_decode(substr($guardado, 3), true);
        if ($bin === false || strlen($bin) < 29) {
            return null;
        }
        $texto = openssl_decrypt(substr($bin, 28), 'aes-256-gcm', self::claveSecretos(), OPENSSL_RAW_DATA, substr($bin, 0, 12), substr($bin, 12, 16));
        return $texto === false ? null : $texto;
    }

    /* ---------- Enlaces firmados para abrir documentos privados ----------
     * Un navegador o visor externo no puede mandar la cabecera Authorization. Para que la app
     * abra un documento privado, la API firma un enlace de 5 minutos SOLO para esa ruta GET de
     * archivo y ese usuario. Al usarlo se aplican los mismos permisos de siempre (rol, dueño).
     */
    private const VIGENCIA_ENLACE = 300;
    public const PATRON_ARCHIVO = '#^/(refugio/adopciones/\d+/documentos/\d+|refugio/mascotas/\d+/documentos/\d+)/archivo$#';

    private static function firma(string $ruta, int $usuarioId, int $expira): string
    {
        return self::b64(hash_hmac('sha256', "enlace|$ruta|$usuarioId|$expira", Config::obtener('JWT_SECRET'), true));
    }

    /** Parámetros de consulta (u, exp, firma) que habilitan $ruta para el usuario por 5 minutos. */
    public static function firmarEnlace(string $ruta, int $usuarioId): string
    {
        $expira = time() + self::VIGENCIA_ENLACE;
        return http_build_query(['u' => $usuarioId, 'exp' => $expira, 'firma' => self::firma($ruta, $usuarioId, $expira)]);
    }

    /** Usuario de un enlace firmado válido para esta ruta, o null. */
    private static function usuarioDeEnlace(Solicitud $s): ?int
    {
        $q = $s->query;
        if ($s->metodo !== 'GET' || !preg_match(self::PATRON_ARCHIVO, $s->ruta) || !isset($q['u'], $q['exp'], $q['firma'])) {
            return null;
        }
        $usuarioId = (int) $q['u'];
        $expira = (int) $q['exp'];
        if ($expira < time() || !is_string($q['firma']) || !hash_equals(self::firma($s->ruta, $usuarioId, $expira), $q['firma'])) {
            return null;
        }
        return $usuarioId;
    }

    /** Guardia: exige un token válido y carga al usuario desde la BD (un usuario borrado pierde el acceso). */
    public static function requiereSesion(Solicitud $s): void
    {
        if (!preg_match('/^Bearer (.+)$/', $s->cabecera('authorization') ?? '', $m)) {
            $porEnlace = self::usuarioDeEnlace($s);
            if ($porEnlace === null) {
                throw new ErrorHttp(401, 'Inicia sesión para continuar.');
            }
            $s->usuario = Base::uno('SELECT id, nombre, correo, telefono, rol FROM usuarios WHERE id = ?', [$porEnlace]);
            if ($s->usuario === null) {
                throw new ErrorHttp(401, 'Tu cuenta ya no existe. Inicia sesión de nuevo.');
            }
            return;
        }
        $carga = self::verificar($m[1]);
        if ($carga === null) {
            throw new ErrorHttp(401, 'Tu sesión expiró. Inicia sesión de nuevo.');
        }
        $usuario = Base::uno('SELECT id, nombre, correo, telefono, rol FROM usuarios WHERE id = ?', [(int) $carga['sub']]);
        if ($usuario === null) {
            throw new ErrorHttp(401, 'Tu cuenta ya no existe. Inicia sesión de nuevo.');
        }
        $s->usuario = $usuario;
    }

    /** Guardia: limita la ruta a uno o varios roles (usar después de requiereSesion). */
    public static function requiereRol(string ...$roles): \Closure
    {
        return static function (Solicitud $s) use ($roles): void {
            if (!in_array($s->usuario['rol'], $roles, true)) {
                throw new ErrorHttp(403, 'No tienes permiso para hacer esto.');
            }
        };
    }

    /** Guardia del panel de refugio: solo refugios APROBADOS. Deja el refugio en $s->refugio. */
    public static function requiereRefugioAprobado(Solicitud $s): void
    {
        $refugio = Base::uno(
            'SELECT r.*, u.correo FROM refugios r JOIN usuarios u ON u.id = r.usuario_id WHERE r.usuario_id = ?',
            [$s->usuario['id']],
        );
        if ($refugio === null || $refugio['estado'] !== 'aprobado') {
            throw new ErrorHttp(403, 'Tu refugio aún no está verificado.', ['codigo' => 'refugio-no-aprobado', 'estado' => $refugio['estado'] ?? null]);
        }
        $s->refugio = $refugio;
    }
}
