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

    /** Guardia: exige un token válido y carga al usuario desde la BD (un usuario borrado pierde el acceso). */
    public static function requiereSesion(Solicitud $s): void
    {
        if (!preg_match('/^Bearer (.+)$/', $s->cabecera('authorization') ?? '', $m)) {
            throw new ErrorHttp(401, 'Inicia sesión para continuar.');
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
