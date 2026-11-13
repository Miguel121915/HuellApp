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
            // Huella SHA-256 del archivo de la foto: detecta la misma imagen subida dos veces
            'foto_huella' => 'VARCHAR2(64 CHAR)',
            // IA en segundo plano: pendiente | procesando | listo | fallo | sin_ia, reintentos y posible duplicado
            'ia_estado' => 'VARCHAR2(12 CHAR)', 'ia_intentos' => 'NUMBER(2) DEFAULT 0 NOT NULL',
            'ia_siguiente' => 'TIMESTAMP(3)', 'duplicado_de' => 'NUMBER(10)',
            // Formularios separados «Se me perdió» / «La encontré» y cierre con «¡Ya apareció!»
            'color' => 'VARCHAR2(40 CHAR)', 'tamano' => 'VARCHAR2(10 CHAR)', 'collar' => 'VARCHAR2(80 CHAR)',
            'fecha_evento' => 'TIMESTAMP(3)', 'situacion' => 'VARCHAR2(12 CHAR)',
            'estado' => "VARCHAR2(10 CHAR) DEFAULT 'activo' NOT NULL", 'reunido_en' => 'TIMESTAMP(3)',
            // Punto en el mapa (coincidencias por distancia real) y seña secreta del dueño (NUNCA se publica)
            'latitud' => 'NUMBER(9,6)', 'longitud' => 'NUMBER(9,6)', 'sena_secreta' => 'VARCHAR2(200 CHAR)',
        ],
        // Muro por pestañas: la publicación de una alerta queda ligada a su reporte
        'publicaciones_foro' => [
            'reporte_id' => 'NUMBER(10)',
            // HU-18: moderación (visible | revision | quitado), por qué se marcó y quién (palabras | ia)
            'moderacion' => "VARCHAR2(10 CHAR) DEFAULT 'visible' NOT NULL", 'moderacion_motivo' => 'VARCHAR2(300 CHAR)',
            'moderacion_fuente' => 'VARCHAR2(10 CHAR)', 'moderacion_en' => 'TIMESTAMP(3)',
        ],
        // Coincidencias (HU-8): 1 si la IA comparó las fotos; 1 si las dos usan la MISMA fotografía
        'coincidencias' => [
            'por_ia' => 'NUMBER(1) DEFAULT 0 NOT NULL', 'misma_foto' => 'NUMBER(1) DEFAULT 0 NOT NULL',
            // Quien encontró describe la seña secreta antes de ver el contacto del dueño
            'respuesta_sena' => 'VARCHAR2(300 CHAR)', 'respondida_en' => 'TIMESTAMP(3)',
        ],
        'refugios' => [
            'latitud' => 'NUMBER(9,6)', 'longitud' => 'NUMBER(9,6)', 'municipio' => 'VARCHAR2(100 CHAR)',
            'codigo_postal' => 'VARCHAR2(5 CHAR)', 'rfc' => 'VARCHAR2(13 CHAR)', 'tipo_organizacion' => 'VARCHAR2(60 CHAR)',
            'anio_fundacion' => 'NUMBER(4)', 'whatsapp' => 'VARCHAR2(25 CHAR)', 'redes' => 'VARCHAR2(1000 CHAR)',
            'necesidades' => 'VARCHAR2(1000 CHAR)', 'tiene_perros' => 'NUMBER(1) DEFAULT 1 NOT NULL',
            'tiene_gatos' => 'NUMBER(1) DEFAULT 1 NOT NULL',
        ],
        // HU-22: resumen con IA de cada solicitud (JSON), guardado para no gastar cuota cada vez que se abre
        'solicitudes_adopcion' => [
            'resumen_ia' => 'VARCHAR2(2000 CHAR)', 'resumen_ia_en' => 'TIMESTAMP(3)',
            // HU-23: consejos de cuidado con IA para quien adoptó (JSON), guardados igual
            'guia_ia' => 'VARCHAR2(1500 CHAR)',
        ],
        // HU-18: moderación (visible | revision | quitado), por qué se marcó y quién la marcó (palabras | ia)
        'comentarios_foro' => [
            'moderacion' => "VARCHAR2(10 CHAR) DEFAULT 'visible' NOT NULL", 'moderacion_motivo' => 'VARCHAR2(300 CHAR)',
            'moderacion_fuente' => 'VARCHAR2(10 CHAR)', 'moderacion_en' => 'TIMESTAMP(3)',
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
        self::ligarAlertasViejas();
    }

    /**
     * Alertas publicadas antes de existir publicaciones_foro.reporte_id: se ligan a su reporte por la
     * foto (la alerta usa la misma foto que el reporte). Es seguro repetirlo: solo toca las que faltan.
     */
    private static function ligarAlertasViejas(): void
    {
        Base::ejecutar(
            "UPDATE publicaciones_foro p
                SET reporte_id = (SELECT MIN(r.id) FROM reportes r WHERE r.foto = p.foto AND r.usuario_id = p.usuario_id)
              WHERE p.reporte_id IS NULL AND p.foto IS NOT NULL
                AND (p.texto LIKE '🔎 SE BUSCA%' OR p.texto LIKE '🐾 ENCONTRÉ%')",
        );
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
