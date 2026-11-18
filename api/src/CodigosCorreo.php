<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * CodigosCorreo — Códigos de 6 dígitos que se envían por correo.
 *
 * Propósitos: 'verificar' (confirmar el correo al registrarse) y 'recuperar' (cambiar la contraseña).
 * - En la base solo se guarda la huella HMAC-SHA256 del código (con JWT_SECRET), nunca el código.
 * - Cada código vence en 15 minutos y admite 5 intentos; después hay que pedir otro.
 * - Pedir uno nuevo invalida el anterior, y no se puede pedir otro antes de 60 segundos.
 */
final class CodigosCorreo
{
    public const VIGENCIA_SEGUNDOS = 900;
    public const ESPERA_REENVIO_SEGUNDOS = 60;
    private const MAX_INTENTOS = 5;

    private static function huella(int $usuarioId, string $proposito, string $codigo): string
    {
        return hash_hmac('sha256', "$usuarioId|$proposito|$codigo", Config::obtener('JWT_SECRET'));
    }

    /** Segundos que faltan para poder pedir otro código (0 = ya se puede). */
    public static function esperaParaReenviar(int $usuarioId, string $proposito): int
    {
        $creado = Base::valor(
            'SELECT MAX(creado_en) FROM codigos_correo WHERE usuario_id = ? AND proposito = ?',
            [$usuarioId, $proposito],
        );
        if (!$creado) {
            return 0;
        }
        $pasados = time() - (new \DateTimeImmutable((string) $creado, new \DateTimeZone('UTC')))->getTimestamp();
        return max(0, self::ESPERA_REENVIO_SEGUNDOS - $pasados);
    }

    /** Crea un código nuevo (borra los anteriores del mismo propósito) y lo devuelve para enviarlo. */
    public static function crear(int $usuarioId, string $proposito): string
    {
        $codigo = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $expira = (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))
            ->modify('+' . self::VIGENCIA_SEGUNDOS . ' seconds')->format('Y-m-d H:i:s.v');
        Base::ejecutar('DELETE FROM codigos_correo WHERE usuario_id = ? AND proposito = ?', [$usuarioId, $proposito]);
        Base::ejecutar(
            'INSERT INTO codigos_correo (usuario_id, proposito, codigo_hash, expira_en, creado_en) VALUES (?, ?, ?, ?, ?)',
            [$usuarioId, $proposito, self::huella($usuarioId, $proposito, $codigo), $expira, Base::ahora()],
        );
        return $codigo;
    }

    /**
     * Revisa el código. Si es correcto lo borra (solo sirve una vez). Si no, suma un intento.
     * Lanza ErrorHttp con un mensaje claro para cada caso.
     */
    public static function comprobar(int $usuarioId, string $proposito, mixed $codigo): void
    {
        $codigo = is_string($codigo) || is_int($codigo) ? preg_replace('/\D/', '', (string) $codigo) : '';
        if (strlen((string) $codigo) !== 6) {
            throw new ErrorHttp(400, 'Escribe el código de 6 dígitos que te llegó por correo.');
        }
        $fila = Base::uno(
            'SELECT id, codigo_hash, intentos, expira_en FROM codigos_correo WHERE usuario_id = ? AND proposito = ?',
            [$usuarioId, $proposito],
        );
        $sinCodigo = new ErrorHttp(400, 'El código ya no es válido. Pide uno nuevo.', ['codigo' => 'codigo-vencido']);
        if ($fila === null) {
            throw $sinCodigo;
        }
        $vencido = (new \DateTimeImmutable((string) $fila['expira_en'], new \DateTimeZone('UTC')))->getTimestamp() < time();
        if ($vencido || (int) $fila['intentos'] >= self::MAX_INTENTOS) {
            Base::ejecutar('DELETE FROM codigos_correo WHERE id = ?', [$fila['id']]);
            throw $sinCodigo;
        }
        if (!hash_equals((string) $fila['codigo_hash'], self::huella($usuarioId, $proposito, (string) $codigo))) {
            Base::ejecutar('UPDATE codigos_correo SET intentos = intentos + 1 WHERE id = ?', [$fila['id']]);
            $quedan = self::MAX_INTENTOS - (int) $fila['intentos'] - 1;
            throw new ErrorHttp(400, $quedan > 0
                ? "El código no coincide. Te quedan $quedan intento" . ($quedan === 1 ? '' : 's') . '.'
                : 'El código no coincide. Pide uno nuevo.', ['codigo' => $quedan > 0 ? 'codigo-incorrecto' : 'codigo-vencido']);
        }
        Base::ejecutar('DELETE FROM codigos_correo WHERE id = ?', [$fila['id']]);
    }

    /**
     * Crea y envía un código. Respeta la espera de 60 s entre envíos (si aún no pasa, no hace nada).
     * Devuelve el código solo si CORREO_CODIGO_EN_RESPUESTA=1 (pruebas automáticas); si no, null.
     */
    public static function enviar(array $usuario, string $proposito): ?string
    {
        $id = (int) $usuario['id'];
        if (self::esperaParaReenviar($id, $proposito) > 0) {
            return null;
        }
        $codigo = self::crear($id, $proposito);
        Correo::enviarCodigo((string) $usuario['correo'], (string) $usuario['nombre'], $codigo, $proposito);
        return Config::obtener('CORREO_CODIGO_EN_RESPUESTA') === '1' ? $codigo : null;
    }
}
