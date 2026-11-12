<?php
declare(strict_types=1);

namespace HuellApp;

use PDO;
use PDOException;
use PDOStatement;

/**
 * Base — Conexión a Oracle (Autonomous Database en OCI) con PDO_OCI y consultas preparadas.
 * Todas las consultas usan parámetros (?) para evitar inyección SQL.
 *
 * Para que el resto de la API no note el cambio de MySQL a Oracle, aquí se resuelve:
 *  - Nombres de columna en minúsculas (Oracle los devuelve en MAYÚSCULAS).
 *  - Números como int/float (PDO_OCI los entrega como texto).
 *  - Texto opcional NULL -> '' (Oracle guarda '' como NULL).
 *  - Fechas con el mismo formato que MySQL: "2026-11-04 21:38:00.000", en UTC.
 *  - El id de un INSERT se lee de la secuencia <tabla>_seq (PDO_OCI no tiene lastInsertId).
 */
final class Base
{
    private static ?PDO $pdo = null;

    /** Columnas de texto opcional que en MySQL eran NOT NULL DEFAULT '' (ver database/esquema.sql). */
    private const TEXTO_OPCIONAL = [
        'descripcion', 'motivo_rechazo', 'motivo_anterior', 'foto', 'foto_alt',
        'claves', 'ocupacion', 'otras_mascotas', 'nota_refugio', 'detalle', 'respuesta',
    ];

    /** Columnas numéricas por nombre, por si el driver no informa el tipo de la columna. */
    private const NUMERICAS = [
        'id', 'cuenta', 'tamano', 'edad_meses', 'apelaciones', 'verificado', 'con_error', 'activa',
        'similitud', 'republicar_cada_dias', 'republicada_veces', 'total', 'verificados', 'total_likes', 'ya_dio', 'obligatorio', 'mensajes_nuevos', 'totp_activo', 'totp_ultimo_paso', 'por_ia', 'leido',
    ];

    private static function opciones(): array
    {
        return [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_CASE => PDO::CASE_LOWER,
            PDO::ATTR_ORACLE_NULLS => PDO::NULL_NATURAL,
            // Conexión persistente: se reutiliza entre peticiones del mismo proceso de PHP en lugar de
            // abrir cada vez una conexión cifrada nueva con Oracle en la nube (lo más lento: 1–3 s).
            // Si causara problemas se apaga con DB_PERSISTENTE=0 en el .env.
            PDO::ATTR_PERSISTENT => Config::obtener('DB_PERSISTENTE') !== '0',
        ];
    }

    /** Nombre del usuario/esquema de Oracle (para mensajes). */
    public static function nombreBase(): string
    {
        return strtoupper(Config::obtener('DB_USER'));
    }

    public static function pdo(): PDO
    {
        return self::$pdo ??= self::conectar();
    }

    /** Cierra la conexión (la siguiente consulta abre una nueva con la configuración actual). */
    public static function reiniciarConexion(): void
    {
        self::$pdo = null;
    }

    private static function conectar(): PDO
    {
        if (!extension_loaded('pdo_oci')) {
            throw new ErrorHttp(503, 'Falta la extensión pdo_oci de PHP. En XAMPP: en php.ini agrega la línea  extension=pdo_oci  (ver la guía de Oracle).');
        }
        $tnsAdmin = Config::obtener('TNS_ADMIN');
        if ($tnsAdmin !== '') {
            putenv("TNS_ADMIN=$tnsAdmin"); // carpeta del wallet
        }
        $dsn = 'oci:dbname=' . Config::obtener('DB_TNS') . ';charset=AL32UTF8';
        try {
            $pdo = new PDO($dsn, Config::obtener('DB_USER'), Config::obtener('DB_PASS'), self::opciones());
            // Mismo formato de fechas y números que usaba MySQL; todas las fechas en UTC.
            // Los 4 ajustes van en UN solo viaje a la nube (antes eran 4).
            $pdo->exec("BEGIN
                EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_TIMESTAMP_FORMAT = ''YYYY-MM-DD HH24:MI:SS.FF3''';
                EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT = ''YYYY-MM-DD HH24:MI:SS''';
                EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
                EXECUTE IMMEDIATE 'ALTER SESSION SET TIME_ZONE = ''+00:00''';
            END;");
        } catch (PDOException $e) {
            throw self::traducir($e);
        }
        return $pdo;
    }

    /** Código ORA-xxxxx de un error de Oracle (0 si no se reconoce). */
    public static function codigoOracle(\Throwable $e): int
    {
        return preg_match('/ORA-(\d{5})/', $e->getMessage(), $m) ? (int) $m[1] : 0;
    }

    /** Convierte errores comunes de Oracle en mensajes que expliquen qué hacer. */
    public static function traducir(PDOException $e): \Throwable
    {
        $usuario = self::nombreBase();
        $tns = Config::obtener('DB_TNS');
        return match (self::codigoOracle($e)) {
            12154, 12162, 12262 =>
                new ErrorHttp(503, "Oracle no encontró el servicio «$tns». Revisa DB_TNS en el .env y que TNS_ADMIN apunte a la carpeta del wallet."),
            1017 =>
                new ErrorHttp(503, "Oracle rechazó el usuario o la contraseña de $usuario. Revisa DB_USER y DB_PASS en el archivo .env."),
            28759, 29024, 29106 =>
                new ErrorHttp(503, 'No se pudo abrir el wallet de Oracle. Revisa la ruta DIRECTORY en el sqlnet.ora del wallet.'),
            12506, 12514, 12541, 12170, 12545 =>
                new ErrorHttp(503, 'No se pudo conectar con Oracle en OCI. Revisa tu internet y que la base esté encendida (Available) en la consola de OCI.'),
            942 =>
                new ErrorHttp(503, 'Faltan las tablas de la base de datos. Ejecuta:  php artisan migrate --seed'),
            1950 =>
                new ErrorHttp(503, "El usuario $usuario no tiene espacio en la base. Como ADMIN ejecuta:  ALTER USER $usuario QUOTA UNLIMITED ON DATA;"),
            default => $e,
        };
    }

    /**
     * Errores de "esa conexión ya no sirve" (la nube la cerró por inactividad, se cortó la red…).
     * Con conexiones persistentes pueden salir al reutilizar una vieja: se reconecta y se reintenta.
     */
    private const CONEXION_PERDIDA = [28, 1012, 2396, 3113, 3114, 3135, 12537, 12543, 25408];

    /** @param array<int,mixed> $parametros */
    private static function preparar(string $sql, array $parametros, bool $reintento = false): PDOStatement
    {
        try {
            $sentencia = self::pdo()->prepare($sql);
            $sentencia->execute(array_map(static fn ($v) => is_bool($v) ? (int) $v : $v, $parametros));
            return $sentencia;
        } catch (PDOException $e) {
            // Fuera de una transacción es seguro reintentar una vez con una conexión nueva
            $enTransaccion = self::$pdo?->inTransaction() ?? false;
            if (!$reintento && !$enTransaccion && in_array(self::codigoOracle($e), self::CONEXION_PERDIDA, true)) {
                self::$pdo = null;
                return self::preparar($sql, $parametros, true);
            }
            throw self::traducir($e);
        }
    }

    /**
     * Ajusta una fila para que se vea igual que con MySQL (ver el comentario de la clase).
     * @param array<string,mixed> $fila
     * @param array<string,bool> $numericas columnas que el driver reporta como NUMBER
     */
    private static function normalizar(array $fila, array $numericas): array
    {
        foreach ($fila as $columna => $valor) {
            if (is_resource($valor)) { // CLOB
                $valor = stream_get_contents($valor);
            }
            if ($valor === null) {
                if (in_array($columna, self::TEXTO_OPCIONAL, true) || str_ends_with($columna, '_alt')) {
                    $valor = '';
                }
            } elseif (is_string($valor) && ($numericas[$columna] ?? false) && is_numeric($valor)) {
                $valor = preg_match('/^-?\d+$/', $valor) ? (int) $valor : (float) $valor;
            }
            $fila[$columna] = $valor;
        }
        return $fila;
    }

    /** @return array<string,bool> columnas NUMBER del resultado */
    private static function columnasNumericas(PDOStatement $sentencia): array
    {
        $numericas = [];
        for ($i = 0, $n = $sentencia->columnCount(); $i < $n; $i++) {
            $meta = @$sentencia->getColumnMeta($i);
            if (!is_array($meta) || !isset($meta['name'])) {
                continue;
            }
            $nombre = strtolower((string) $meta['name']);
            $tipo = strtoupper((string) ($meta['native_type'] ?? ''));
            $numericas[$nombre] = $tipo !== ''
                ? in_array($tipo, ['NUMBER', 'BINARY_FLOAT', 'BINARY_DOUBLE', 'FLOAT', 'INTEGER'], true)
                : (in_array($nombre, self::NUMERICAS, true) || str_ends_with($nombre, '_id'));
        }
        return $numericas;
    }

    /** Una sola fila, o null si no hay. */
    public static function uno(string $sql, array $parametros = []): ?array
    {
        $sentencia = self::preparar($sql, $parametros);
        $fila = $sentencia->fetch();
        return $fila === false ? null : self::normalizar($fila, self::columnasNumericas($sentencia));
    }

    /** Todas las filas. */
    public static function todos(string $sql, array $parametros = []): array
    {
        $sentencia = self::preparar($sql, $parametros);
        $filas = $sentencia->fetchAll();
        if (!$filas) {
            return [];
        }
        $numericas = self::columnasNumericas($sentencia);
        return array_map(static fn (array $f): array => self::normalizar($f, $numericas), $filas);
    }

    /** Ejecuta un INSERT/UPDATE/DELETE/MERGE y devuelve cuántas filas cambió. */
    public static function ejecutar(string $sql, array $parametros = []): int
    {
        return self::preparar($sql, $parametros)->rowCount();
    }

    /**
     * Ejecuta un INSERT y si viola una clave única/primaria no hace nada (equivale a INSERT IGNORE de MySQL).
     * Devuelve cuántas filas insertó (0 o 1).
     */
    public static function insertarSiNoExiste(string $sql, array $parametros = []): int
    {
        try {
            return self::ejecutar($sql, $parametros);
        } catch (PDOException $e) {
            if (self::codigoOracle($e) === 1) { // ORA-00001: restricción única violada
                return 0;
            }
            throw $e;
        }
    }

    /** Ejecuta un INSERT y devuelve el id nuevo (de la secuencia <tabla>_seq). */
    public static function insertar(string $sql, array $parametros = []): int
    {
        if (!preg_match('/^\s*INSERT\s+INTO\s+([a-z_]+)/i', $sql, $m)) {
            throw new \LogicException('Base::insertar solo acepta sentencias INSERT INTO <tabla>.');
        }
        self::preparar($sql, $parametros);
        return (int) self::valor('SELECT ' . strtolower($m[1]) . '_seq.CURRVAL FROM dual');
    }

    /** Valor de una sola columna de la primera fila (ej. un COUNT). */
    public static function valor(string $sql, array $parametros = []): mixed
    {
        $fila = self::uno($sql, $parametros);
        return $fila === null ? null : reset($fila);
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

    /** Fecha y hora actual en UTC con el formato "Y-m-d H:i:s.v" (TIMESTAMP(3)). */
    public static function ahora(?int $segundosAtras = null): string
    {
        $fecha = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        if ($segundosAtras) {
            $fecha = $fecha->modify("-{$segundosAtras} seconds");
        }
        return $fecha->format('Y-m-d H:i:s.v');
    }
}
