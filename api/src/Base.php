<?php
declare(strict_types=1);

namespace HuellApp;

use PDO;
use PDOException;

/**
 * Base — Conexión a MySQL/MariaDB (la de XAMPP) con PDO y consultas preparadas.
 * Todas las consultas usan parámetros (?) para evitar inyección SQL.
 */
final class Base
{
    private static ?PDO $pdo = null;

    private static function opciones(): array
    {
        return [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ];
    }

    public static function nombreBase(): string
    {
        $nombre = Config::obtener('DB_NAME');
        if (!preg_match('/^[A-Za-z0-9_]+$/', $nombre)) {
            throw new \RuntimeException('DB_NAME solo puede tener letras, números y guion bajo.');
        }
        return $nombre;
    }

    /** Conexión al servidor MySQL sin elegir base (para crear la base de datos). */
    public static function sinBase(): PDO
    {
        return self::conectar(null);
    }

    public static function pdo(): PDO
    {
        return self::$pdo ??= self::conectar(self::nombreBase());
    }

    private static function conectar(?string $base): PDO
    {
        $dsn = sprintf('mysql:host=%s;port=%s;%scharset=utf8mb4', Config::obtener('DB_HOST'), Config::obtener('DB_PORT'), $base ? "dbname=$base;" : '');
        try {
            $pdo = new PDO($dsn, Config::obtener('DB_USER'), Config::obtener('DB_PASS'), self::opciones());
        } catch (PDOException $e) {
            throw self::traducir($e);
        }
        $pdo->exec("SET time_zone = '+00:00'"); // todas las fechas se guardan en UTC
        return $pdo;
    }

    /** Convierte errores comunes de MySQL en mensajes que expliquen qué hacer. */
    public static function traducir(PDOException $e): \Throwable
    {
        $codigo = (int) ($e->errorInfo[1] ?? $e->getCode());
        $base = Config::obtener('DB_NAME');
        return match (true) {
            $codigo === 2002 || str_contains($e->getMessage(), 'Connection refused') =>
                new ErrorHttp(503, 'No se pudo conectar con MySQL. Abre el panel de XAMPP y enciende MySQL (botón Start).'),
            $codigo === 1045 =>
                new ErrorHttp(503, 'MySQL rechazó el usuario o la contraseña. Revisa DB_USER y DB_PASS en el archivo .env.'),
            $codigo === 1049 =>
                new ErrorHttp(503, "La base de datos «$base» no existe. Ejecuta:  php artisan migrate --seed"),
            $codigo === 1146 =>
                new ErrorHttp(503, 'Faltan las tablas de la base de datos. Ejecuta:  php artisan migrate --seed'),
            default => $e,
        };
    }

    /** @param array<int,mixed> $parametros */
    private static function preparar(string $sql, array $parametros): \PDOStatement
    {
        try {
            $sentencia = self::pdo()->prepare($sql);
            $sentencia->execute($parametros);
            return $sentencia;
        } catch (PDOException $e) {
            throw self::traducir($e);
        }
    }

    /** Una sola fila, o null si no hay. */
    public static function uno(string $sql, array $parametros = []): ?array
    {
        $fila = self::preparar($sql, $parametros)->fetch();
        return $fila === false ? null : $fila;
    }

    /** Todas las filas. */
    public static function todos(string $sql, array $parametros = []): array
    {
        return self::preparar($sql, $parametros)->fetchAll();
    }

    /** Ejecuta un INSERT/UPDATE/DELETE y devuelve cuántas filas cambió. */
    public static function ejecutar(string $sql, array $parametros = []): int
    {
        return self::preparar($sql, $parametros)->rowCount();
    }

    /** Ejecuta un INSERT y devuelve el id nuevo. */
    public static function insertar(string $sql, array $parametros = []): int
    {
        self::preparar($sql, $parametros);
        return (int) self::pdo()->lastInsertId();
    }

    /** Valor de una sola columna de la primera fila (ej. un COUNT). */
    public static function valor(string $sql, array $parametros = []): mixed
    {
        $fila = self::preparar($sql, $parametros)->fetch(PDO::FETCH_NUM);
        return $fila === false ? null : $fila[0];
    }

    /** O se guarda todo lo que hace $fn, o no se guarda nada. */
    public static function transaccion(callable $fn): mixed
    {
        $pdo = self::pdo();
        $pdo->beginTransaction();
        try {
            $resultado = $fn();
            $pdo->commit();
            return $resultado;
        } catch (\Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e instanceof PDOException ? self::traducir($e) : $e;
        }
    }

    /** Fecha y hora actual en UTC con el formato de MySQL (DATETIME(3)). */
    public static function ahora(?int $segundosAtras = null): string
    {
        $fecha = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        if ($segundosAtras) {
            $fecha = $fecha->modify("-{$segundosAtras} seconds");
        }
        return $fecha->format('Y-m-d H:i:s.v');
    }
}
