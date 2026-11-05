-- ============================================================
-- Esquema de la base de datos de HuellApp (MySQL / MariaDB)
-- Se ejecuta con:  php artisan migrate
-- Es seguro repetirlo: usa CREATE TABLE IF NOT EXISTS.
-- Fechas: DATETIME(3) en UTC.
-- ============================================================

-- Cuentas de acceso de los tres roles ------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(100) NOT NULL,
  correo        VARCHAR(120) NOT NULL,
  telefono      VARCHAR(25) NULL,
  password_hash VARCHAR(255) NOT NULL,
  rol           ENUM('usuario', 'refugio', 'admin') NOT NULL,
  creado_en     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuarios_correo (correo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Refugios: cada uno pertenece a la cuenta de su responsable ---------------
CREATE TABLE IF NOT EXISTS refugios (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id     INT UNSIGNED NOT NULL,
  nombre         VARCHAR(100) NOT NULL,
  responsable    VARCHAR(100) NOT NULL,
  telefono       VARCHAR(25) NOT NULL,
  direccion      VARCHAR(160) NOT NULL,
  horario        VARCHAR(20) NOT NULL,
  descripcion    VARCHAR(400) NOT NULL DEFAULT '',
  estado         ENUM('pendiente', 'aprobado', 'rechazado', 'suspendido') NOT NULL DEFAULT 'pendiente',
  motivo_rechazo VARCHAR(400) NOT NULL DEFAULT '',
  revisado_por   INT UNSIGNED NULL,
  revisado_en    DATETIME(3) NULL,
  creado_en      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- Apelaciones: cuántas veces reenvió la solicitud tras un rechazo, y el motivo del último rechazo
  apelaciones     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  motivo_anterior VARCHAR(400) NOT NULL DEFAULT '',
  apelado_en      DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refugios_usuario (usuario_id),
  KEY idx_refugios_estado (estado),
  CONSTRAINT fk_refugios_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_refugios_revisor FOREIGN KEY (revisado_por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Documentos que sube el refugio al registrarse (los revisa el administrador) --
CREATE TABLE IF NOT EXISTS documentos_refugio (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  refugio_id  INT UNSIGNED NOT NULL,
  tipo        ENUM('acta', 'domicilio', 'identificacion', 'permiso') NOT NULL,
  nombre      VARCHAR(120) NOT NULL,
  archivo     VARCHAR(120) NOT NULL,
  mime        VARCHAR(60) NOT NULL,
  tamano      INT UNSIGNED NOT NULL,
  verificado  TINYINT(1) NOT NULL DEFAULT 0,
  -- El administrador lo señaló como erróneo al rechazar: el refugio debe reemplazarlo para apelar
  con_error   TINYINT(1) NOT NULL DEFAULT 0,
  creado_en   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_documentos_refugio (refugio_id),
  CONSTRAINT fk_documentos_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inventario de mascotas del refugio ---------------------------------------
CREATE TABLE IF NOT EXISTS mascotas (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  refugio_id     INT UNSIGNED NOT NULL,
  nombre         VARCHAR(40) NOT NULL,
  especie        ENUM('perro', 'gato') NOT NULL,
  raza           VARCHAR(60) NOT NULL,
  edad_meses     SMALLINT UNSIGNED NOT NULL,
  sexo           ENUM('macho', 'hembra') NOT NULL,
  tamano         ENUM('pequeño', 'mediano', 'grande') NOT NULL,
  salud          VARCHAR(120) NOT NULL,
  descripcion    VARCHAR(400) NOT NULL,
  foto           VARCHAR(200) NOT NULL,
  estatus        ENUM('disponible', 'en proceso', 'adoptado') NOT NULL DEFAULT 'disponible',
  creado_en      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  actualizado_en DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_mascotas_refugio (refugio_id, estatus),
  CONSTRAINT fk_mascotas_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Documentos especiales de cada mascota (vacunas, esterilización, pedigree...) -----
-- Los sube el refugio y los revisa el administrador. Archivos privados en storage/uploads/documentos.
CREATE TABLE IF NOT EXISTS documentos_mascota (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  mascota_id  INT UNSIGNED NOT NULL,
  refugio_id  INT UNSIGNED NOT NULL,
  tipo        ENUM('vacunacion', 'esterilizacion', 'desparasitacion', 'pedigree', 'medico', 'otro') NOT NULL,
  nombre      VARCHAR(120) NOT NULL,
  archivo     VARCHAR(120) NOT NULL,
  mime        VARCHAR(60) NOT NULL,
  tamano      INT UNSIGNED NOT NULL,
  verificado  TINYINT(1) NOT NULL DEFAULT 0,
  creado_en   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_docmascota_mascota (mascota_id),
  CONSTRAINT fk_docmascota_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE,
  CONSTRAINT fk_docmascota_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Publicaciones del refugio (si se borra la mascota, se borran también) -------
CREATE TABLE IF NOT EXISTS publicaciones_refugio (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  refugio_id  INT UNSIGNED NOT NULL,
  mascota_id  INT UNSIGNED NOT NULL,
  texto       VARCHAR(500) NOT NULL,
  foto        VARCHAR(200) NOT NULL,
  foto_alt    VARCHAR(160) NOT NULL DEFAULT '',
  creado_en   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- Republicación automática: cada N días vuelve a mostrarse como nueva (NULL = desactivada).
  -- En bases creadas antes de esta versión, Migraciones.php agrega estas columnas solas.
  republicar_cada_dias SMALLINT UNSIGNED NULL,
  publicado_en         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  republicada_veces    INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_pub_refugio (refugio_id, creado_en),
  KEY idx_pub_publicado (refugio_id, publicado_en),
  CONSTRAINT fk_pubref_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE,
  CONSTRAINT fk_pubref_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Foro de la comunidad -----------------------------------------------------
CREATE TABLE IF NOT EXISTS publicaciones_foro (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id  INT UNSIGNED NOT NULL,
  texto       VARCHAR(600) NOT NULL,
  foto        VARCHAR(200) NOT NULL DEFAULT '',
  foto_alt    VARCHAR(160) NOT NULL DEFAULT '',
  creado_en   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_foro_fecha (creado_en),
  CONSTRAINT fk_foro_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS comentarios_foro (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  publicacion_id INT UNSIGNED NOT NULL,
  usuario_id     INT UNSIGNED NOT NULL,
  texto          VARCHAR(300) NOT NULL,
  creado_en      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_comentarios_pub (publicacion_id),
  CONSTRAINT fk_coment_pub FOREIGN KEY (publicacion_id) REFERENCES publicaciones_foro (id) ON DELETE CASCADE,
  CONSTRAINT fk_coment_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- "Me gusta" en forma de huella: un usuario solo puede darlo una vez por publicación
CREATE TABLE IF NOT EXISTS likes_foro (
  publicacion_id INT UNSIGNED NOT NULL,
  usuario_id     INT UNSIGNED NOT NULL,
  PRIMARY KEY (publicacion_id, usuario_id),
  CONSTRAINT fk_likes_pub FOREIGN KEY (publicacion_id) REFERENCES publicaciones_foro (id) ON DELETE CASCADE,
  CONSTRAINT fk_likes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reportes de mascotas perdidas / encontradas --------------------------------
CREATE TABLE IF NOT EXISTS reportes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id  INT UNSIGNED NOT NULL,
  tipo        ENUM('perdida', 'encontrada') NOT NULL,
  descripcion VARCHAR(600) NOT NULL,
  zona        VARCHAR(120) NOT NULL,
  foto        VARCHAR(200) NOT NULL,
  foto_alt    VARCHAR(160) NOT NULL DEFAULT '',
  creado_en   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_reportes_tipo (tipo, creado_en),
  CONSTRAINT fk_reportes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Posibles coincidencias: pareja (reporte de pérdida, reporte de hallazgo) + similitud
CREATE TABLE IF NOT EXISTS coincidencias (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  reporte_perdido_id    INT UNSIGNED NOT NULL,
  reporte_encontrado_id INT UNSIGNED NOT NULL,
  similitud             TINYINT UNSIGNED NOT NULL,
  creado_en             DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_coincidencia (reporte_perdido_id, reporte_encontrado_id),
  CONSTRAINT fk_coin_perdido FOREIGN KEY (reporte_perdido_id) REFERENCES reportes (id) ON DELETE CASCADE,
  CONSTRAINT fk_coin_encontrado FOREIGN KEY (reporte_encontrado_id) REFERENCES reportes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Coincidencias que el dueño del reporte decidió declinar
CREATE TABLE IF NOT EXISTS coincidencias_descartadas (
  usuario_id      INT UNSIGNED NOT NULL,
  coincidencia_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (usuario_id, coincidencia_id),
  CONSTRAINT fk_desc_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_desc_coin FOREIGN KEY (coincidencia_id) REFERENCES coincidencias (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Intentos fallidos de inicio de sesión (para bloquear a quien adivine contraseñas)
CREATE TABLE IF NOT EXISTS intentos_login (
  clave  VARCHAR(190) NOT NULL,
  cuenta INT UNSIGNED NOT NULL DEFAULT 1,
  desde  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Preguntas frecuentes de cada refugio (las usa el asistente del formulario de adopción) ------
-- `claves`: palabras extra, separadas por comas, que ayudan al asistente a encontrar la respuesta
CREATE TABLE IF NOT EXISTS preguntas_refugio (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  refugio_id     INT UNSIGNED NOT NULL,
  pregunta       VARCHAR(200) NOT NULL,
  respuesta      VARCHAR(1000) NOT NULL,
  claves         VARCHAR(300) NOT NULL DEFAULT '',
  activa         TINYINT(1) NOT NULL DEFAULT 1,
  creado_en      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  actualizado_en DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_preguntas_refugio (refugio_id, activa),
  CONSTRAINT fk_preguntas_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Solicitudes de adopción que hacen los usuarios a un refugio -------------------------
CREATE TABLE IF NOT EXISTS solicitudes_adopcion (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  mascota_id      INT UNSIGNED NOT NULL,
  refugio_id      INT UNSIGNED NOT NULL,
  usuario_id      INT UNSIGNED NOT NULL,
  nombre          VARCHAR(100) NOT NULL,
  correo          VARCHAR(120) NOT NULL,
  telefono        VARCHAR(25) NOT NULL,
  direccion       VARCHAR(200) NOT NULL,
  ocupacion       VARCHAR(100) NOT NULL DEFAULT '',
  tipo_vivienda   ENUM('casa', 'departamento', 'otro') NOT NULL,
  vivienda_propia ENUM('propia', 'rentada', 'familiar') NOT NULL,
  otras_mascotas  VARCHAR(200) NOT NULL DEFAULT '',
  motivo          VARCHAR(800) NOT NULL,
  estado          ENUM('pendiente', 'en revision', 'aprobada', 'rechazada') NOT NULL DEFAULT 'pendiente',
  nota_refugio    VARCHAR(400) NOT NULL DEFAULT '',
  creado_en       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  actualizado_en  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_adopcion_refugio (refugio_id, estado),
  KEY idx_adopcion_usuario (usuario_id),
  CONSTRAINT fk_adopcion_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE,
  CONSTRAINT fk_adopcion_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE,
  CONSTRAINT fk_adopcion_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Documentos de una solicitud de adopción (privados: solo los ve el refugio que la recibe)
CREATE TABLE IF NOT EXISTS documentos_adopcion (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  solicitud_id INT UNSIGNED NOT NULL,
  tipo         ENUM('identificacion', 'domicilio', 'vivienda', 'otro') NOT NULL,
  nombre       VARCHAR(120) NOT NULL,
  archivo      VARCHAR(120) NOT NULL,
  mime         VARCHAR(60) NOT NULL,
  tamano       INT UNSIGNED NOT NULL,
  creado_en    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_docadopcion_solicitud (solicitud_id),
  CONSTRAINT fk_docadopcion_solicitud FOREIGN KEY (solicitud_id) REFERENCES solicitudes_adopcion (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
