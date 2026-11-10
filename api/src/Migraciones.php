<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Migraciones — Crea las tablas en Oracle (database/esquema.sql).
 * Equivale a "php artisan migrate" y "migrate:fresh" de Laravel.
 *
 * En Oracle no se crea "la base de datos": el usuario (DB_USER, por ejemplo HUELLAPP_DEV)
 * ya es el esquema donde viven las tablas. Lo crea el administrador en OCI (ver la guía).
 */
final class Migraciones
{
    /** Errores que significan "eso ya existe", así migrar se puede repetir sin problema. */
    private const YA_EXISTE = [
        955,  // ORA-00955: el nombre ya lo usa otro objeto (tabla, secuencia, índice)
        1408, // ORA-01408: esa lista de columnas ya tiene índice
        2260, // ORA-02260: la tabla ya tiene llave primaria
        2261, // ORA-02261: ya existe esa llave única
        2275, // ORA-02275: ya existe esa llave foránea
    ];

    /**
     * Columnas agregadas después de la primera versión del esquema en Oracle. CREATE TABLE no las
     * agrega a una tabla que ya existe; aquí se agregan las que falten (es seguro repetirlo).
     */
    private const COLUMNAS_NUEVAS = [
        // Verificación en dos pasos (Google Authenticator) y cuenta de Google vinculada
        'usuarios' => [
            'totp_secreto' => 'VARCHAR2(200 CHAR)', 'totp_activo' => 'NUMBER(1) DEFAULT 0 NOT NULL',
            'totp_ultimo_paso' => 'NUMBER(12)', 'google_sub' => 'VARCHAR2(64 CHAR)',
        ],
        // Reportes (HU-5): especie y nombre opcionales, y lo que detectó la IA (JSON)
        'reportes' => [
            'especie' => 'VARCHAR2(10 CHAR)', 'nombre' => 'VARCHAR2(60 CHAR)', 'analisis_ia' => 'VARCHAR2(1000 CHAR)',
        ],
        // Coincidencias (HU-8): 1 si la IA comparó las fotos
        'coincidencias' => ['por_ia' => 'NUMBER(1) DEFAULT 0 NOT NULL'],
        'refugios' => [
            'latitud' => 'NUMBER(9,6)', 'longitud' => 'NUMBER(9,6)', 'municipio' => 'VARCHAR2(100 CHAR)',
            'codigo_postal' => 'VARCHAR2(5 CHAR)', 'rfc' => 'VARCHAR2(13 CHAR)', 'tipo_organizacion' => 'VARCHAR2(60 CHAR)',
            'anio_fundacion' => 'NUMBER(4)', 'whatsapp' => 'VARCHAR2(25 CHAR)', 'redes' => 'VARCHAR2(1000 CHAR)',
            'necesidades' => 'VARCHAR2(1000 CHAR)', 'tiene_perros' => 'NUMBER(1) DEFAULT 1 NOT NULL',
            'tiene_gatos' => 'NUMBER(1) DEFAULT 1 NOT NULL',
        ],
    ];

    /** Crea todas las tablas, secuencias e índices que falten, y las columnas nuevas. */
    public static function migrar(): void
    {
        $pdo = Base::pdo();
        foreach (self::sentencias() as $sentencia) {
            try {
                $pdo->exec($sentencia);
            } catch (\PDOException $e) {
                if (!in_array(Base::codigoOracle($e), self::YA_EXISTE, true)) {
                    throw Base::traducir($e);
                }
            }
        }
        self::actualizar();
    }

    private static function actualizar(): void
    {
        foreach (self::COLUMNAS_NUEVAS as $tabla => $columnas) {
            foreach ($columnas as $columna => $definicion) {
                $existe = (int) Base::valor(
                    'SELECT COUNT(*) FROM user_tab_columns WHERE table_name = ? AND column_name = ?',
                    [strtoupper($tabla), strtoupper($columna)],
                ) > 0;
                if (!$existe) {
                    Base::pdo()->exec("ALTER TABLE $tabla ADD ($columna $definicion)");
                }
            }
        }
    }

    /** @return list<string> sentencias de database/esquema.sql, sin comentarios */
    private static function sentencias(): array
    {
        $sql = (string) file_get_contents(RAIZ . '/database/esquema.sql');
        $sql = (string) preg_replace('/^\s*--.*$/m', '', $sql); // quita comentarios
        return array_values(array_filter(array_map('trim', explode(';', $sql))));
    }

    /** Borra TODAS las tablas y secuencias del esquema y las vuelve a crear. */
    public static function reiniciar(): void
    {
        $pdo = Base::pdo();
        foreach (Base::todos('SELECT table_name AS t FROM user_tables') as $fila) {
            $pdo->exec('DROP TABLE "' . str_replace('"', '', $fila['t']) . '" CASCADE CONSTRAINTS PURGE');
        }
        foreach (Base::todos('SELECT sequence_name AS s FROM user_sequences') as $fila) {
            $pdo->exec('DROP SEQUENCE "' . str_replace('"', '', $fila['s']) . '"');
        }
        self::migrar();
    }

    public static function tablasExisten(): bool
    {
        return (int) Base::valor("SELECT COUNT(*) FROM user_tables WHERE table_name = 'USUARIOS'") > 0;
    }

    public static function baseVacia(): bool
    {
        return (int) Base::valor('SELECT COUNT(*) FROM usuarios') === 0;
    }
}
