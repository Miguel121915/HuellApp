<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Migraciones — Crea la base de datos y las tablas (database/esquema.sql).
 * Equivale a "php artisan migrate" y "migrate:fresh" de Laravel.
 */
final class Migraciones
{
    /** Crea la base de datos si no existe y todas las tablas que falten. */
    public static function migrar(): void
    {
        $nombre = Base::nombreBase();
        Base::sinBase()->exec("CREATE DATABASE IF NOT EXISTS `$nombre` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

        $sql = (string) file_get_contents(RAIZ . '/database/esquema.sql');
        $sql = preg_replace('/^\s*--.*$/m', '', $sql); // quita comentarios
        foreach (array_filter(array_map('trim', explode(';', (string) $sql))) as $sentencia) {
            Base::pdo()->exec($sentencia);
        }
        self::actualizar();
    }

    /**
     * Cambios para bases creadas con una versión anterior del esquema (CREATE TABLE IF NOT EXISTS
     * no agrega columnas a tablas que ya existen). Es seguro repetirlo: solo agrega lo que falta.
     */
    private static function actualizar(): void
    {
        // Republicación automática de publicaciones del refugio
        $nuevaFecha = !self::columnaExiste('publicaciones_refugio', 'publicado_en');
        self::asegurarColumna('publicaciones_refugio', 'republicar_cada_dias', 'SMALLINT UNSIGNED NULL AFTER creado_en');
        self::asegurarColumna('publicaciones_refugio', 'publicado_en', 'DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) AFTER republicar_cada_dias');
        self::asegurarColumna('publicaciones_refugio', 'republicada_veces', 'INT UNSIGNED NOT NULL DEFAULT 0 AFTER publicado_en');
        if ($nuevaFecha) {
            Base::ejecutar('UPDATE publicaciones_refugio SET publicado_en = creado_en'); // conservan su fecha original
        }
        self::asegurarIndice('publicaciones_refugio', 'idx_pub_publicado', '(refugio_id, publicado_en)');

        // Apelación de refugios rechazados
        self::asegurarColumna('refugios', 'apelaciones', 'SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER creado_en');
        self::asegurarColumna('refugios', 'motivo_anterior', "VARCHAR(400) NOT NULL DEFAULT '' AFTER apelaciones");
        self::asegurarColumna('refugios', 'apelado_en', 'DATETIME(3) NULL AFTER motivo_anterior');
        self::asegurarColumna('documentos_refugio', 'con_error', 'TINYINT(1) NOT NULL DEFAULT 0 AFTER verificado');
    }

    private static function columnaExiste(string $tabla, string $columna): bool
    {
        return (int) Base::valor(
            'SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?',
            [Base::nombreBase(), $tabla, $columna],
        ) > 0;
    }

    private static function asegurarColumna(string $tabla, string $columna, string $definicion): void
    {
        if (!self::columnaExiste($tabla, $columna)) {
            Base::pdo()->exec("ALTER TABLE `$tabla` ADD COLUMN `$columna` $definicion");
        }
    }

    private static function asegurarIndice(string $tabla, string $indice, string $columnas): void
    {
        $existe = (int) Base::valor(
            'SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = ? AND table_name = ? AND index_name = ?',
            [Base::nombreBase(), $tabla, $indice],
        ) > 0;
        if (!$existe) {
            Base::pdo()->exec("ALTER TABLE `$tabla` ADD INDEX `$indice` $columnas");
        }
    }

    /** Borra TODAS las tablas y las vuelve a crear. */
    public static function reiniciar(): void
    {
        $nombre = Base::nombreBase();
        Base::sinBase()->exec("CREATE DATABASE IF NOT EXISTS `$nombre` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
        $pdo = Base::pdo();
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
        foreach (Base::todos('SELECT table_name AS t FROM information_schema.tables WHERE table_schema = ?', [$nombre]) as $fila) {
            $pdo->exec('DROP TABLE IF EXISTS `' . str_replace('`', '', $fila['t']) . '`');
        }
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');
        self::migrar();
    }

    public static function tablasExisten(): bool
    {
        return (int) Base::valor(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
            [Base::nombreBase(), 'usuarios'],
        ) > 0;
    }

    public static function baseVacia(): bool
    {
        return (int) Base::valor('SELECT COUNT(*) FROM usuarios') === 0;
    }
}
