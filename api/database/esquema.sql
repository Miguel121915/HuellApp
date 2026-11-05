-- ============================================================
-- Esquema de la base de datos de HuellApp (Oracle Database 19c o superior)
-- Se ejecuta con:  php artisan migrate
-- Es seguro repetirlo: lo que ya existe se salta (ORA-00955).
-- Fechas: TIMESTAMP(3) en UTC.
--
-- Diferencias con la versión anterior en MySQL:
--  * Los id salen de una secuencia <tabla>_seq (DEFAULT <tabla>_seq.NEXTVAL).
--  * ENUM -> VARCHAR2 + CHECK; TINYINT(1) -> NUMBER(1).
--  * Oracle guarda '' como NULL: las columnas de texto opcional ("DEFAULT ''" en MySQL)
--    aceptan NULL y la API las devuelve como '' (ver Base::normalizar).
-- Cada sentencia termina en ";" (sin bloques PL/SQL).
-- ============================================================

-- Cuentas de acceso de los tres roles ------------------------------------
CREATE SEQUENCE usuarios_seq;
CREATE TABLE usuarios (
  id            NUMBER(10) DEFAULT usuarios_seq.NEXTVAL NOT NULL,
  nombre        VARCHAR2(100 CHAR) NOT NULL,
  correo        VARCHAR2(120 CHAR) NOT NULL,
  telefono      VARCHAR2(25 CHAR),
  password_hash VARCHAR2(255 CHAR) NOT NULL,
  rol           VARCHAR2(10 CHAR) NOT NULL,
  creado_en     TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_usuarios PRIMARY KEY (id),
  CONSTRAINT uq_usuarios_correo UNIQUE (correo),
  CONSTRAINT ck_usuarios_rol CHECK (rol IN ('usuario', 'refugio', 'admin'))
);

-- Refugios: cada uno pertenece a la cuenta de su responsable ---------------
CREATE SEQUENCE refugios_seq;
CREATE TABLE refugios (
  id              NUMBER(10) DEFAULT refugios_seq.NEXTVAL NOT NULL,
  usuario_id      NUMBER(10) NOT NULL,
  nombre          VARCHAR2(100 CHAR) NOT NULL,
  responsable     VARCHAR2(100 CHAR) NOT NULL,
  telefono        VARCHAR2(25 CHAR) NOT NULL,
  direccion       VARCHAR2(160 CHAR) NOT NULL,
  horario         VARCHAR2(20 CHAR) NOT NULL,
  descripcion     VARCHAR2(400 CHAR),
  estado          VARCHAR2(12 CHAR) DEFAULT 'pendiente' NOT NULL,
  motivo_rechazo  VARCHAR2(400 CHAR),
  revisado_por    NUMBER(10),
  revisado_en     TIMESTAMP(3),
  creado_en       TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  -- Apelaciones: cuántas veces reenvió la solicitud tras un rechazo, y el motivo del último rechazo
  apelaciones     NUMBER(5) DEFAULT 0 NOT NULL,
  motivo_anterior VARCHAR2(400 CHAR),
  apelado_en      TIMESTAMP(3),
  CONSTRAINT pk_refugios PRIMARY KEY (id),
  CONSTRAINT uq_refugios_usuario UNIQUE (usuario_id),
  CONSTRAINT ck_refugios_estado CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'suspendido')),
  CONSTRAINT fk_refugios_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_refugios_revisor FOREIGN KEY (revisado_por) REFERENCES usuarios (id) ON DELETE SET NULL
);
CREATE INDEX idx_refugios_estado ON refugios (estado);

-- Documentos que sube el refugio al registrarse (los revisa el administrador) --
CREATE SEQUENCE documentos_refugio_seq;
CREATE TABLE documentos_refugio (
  id          NUMBER(10) DEFAULT documentos_refugio_seq.NEXTVAL NOT NULL,
  refugio_id  NUMBER(10) NOT NULL,
  tipo        VARCHAR2(15 CHAR) NOT NULL,
  nombre      VARCHAR2(120 CHAR) NOT NULL,
  archivo     VARCHAR2(120 CHAR) NOT NULL,
  mime        VARCHAR2(60 CHAR) NOT NULL,
  tamano      NUMBER(10) NOT NULL,
  verificado  NUMBER(1) DEFAULT 0 NOT NULL,
  con_error   NUMBER(1) DEFAULT 0 NOT NULL,
  creado_en   TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_documentos_refugio PRIMARY KEY (id),
  CONSTRAINT ck_documentos_refugio_tipo CHECK (tipo IN ('acta', 'domicilio', 'identificacion', 'permiso')),
  CONSTRAINT fk_documentos_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
);
CREATE INDEX idx_documentos_refugio ON documentos_refugio (refugio_id);

-- Inventario de mascotas del refugio ---------------------------------------
CREATE SEQUENCE mascotas_seq;
CREATE TABLE mascotas (
  id             NUMBER(10) DEFAULT mascotas_seq.NEXTVAL NOT NULL,
  refugio_id     NUMBER(10) NOT NULL,
  nombre         VARCHAR2(40 CHAR) NOT NULL,
  especie        VARCHAR2(10 CHAR) NOT NULL,
  raza           VARCHAR2(60 CHAR) NOT NULL,
  edad_meses     NUMBER(5) NOT NULL,
  sexo           VARCHAR2(10 CHAR) NOT NULL,
  tamano         VARCHAR2(10 CHAR) NOT NULL,
  salud          VARCHAR2(120 CHAR) NOT NULL,
  descripcion    VARCHAR2(400 CHAR) NOT NULL,
  foto           VARCHAR2(200 CHAR) NOT NULL,
  estatus        VARCHAR2(12 CHAR) DEFAULT 'disponible' NOT NULL,
  creado_en      TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  actualizado_en TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_mascotas PRIMARY KEY (id),
  CONSTRAINT ck_mascotas_especie CHECK (especie IN ('perro', 'gato')),
  CONSTRAINT ck_mascotas_sexo CHECK (sexo IN ('macho', 'hembra')),
  CONSTRAINT ck_mascotas_tamano CHECK (tamano IN ('pequeño', 'mediano', 'grande')),
  CONSTRAINT ck_mascotas_estatus CHECK (estatus IN ('disponible', 'en proceso', 'adoptado')),
  CONSTRAINT fk_mascotas_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
);
CREATE INDEX idx_mascotas_refugio ON mascotas (refugio_id, estatus);

-- Documentos especiales de cada mascota (vacunas, esterilización, pedigree...) -----
-- Los sube el refugio y los revisa el administrador. Archivos privados en storage/uploads/documentos.
CREATE SEQUENCE documentos_mascota_seq;
CREATE TABLE documentos_mascota (
  id          NUMBER(10) DEFAULT documentos_mascota_seq.NEXTVAL NOT NULL,
  mascota_id  NUMBER(10) NOT NULL,
  refugio_id  NUMBER(10) NOT NULL,
  tipo        VARCHAR2(15 CHAR) NOT NULL,
  nombre      VARCHAR2(120 CHAR) NOT NULL,
  archivo     VARCHAR2(120 CHAR) NOT NULL,
  mime        VARCHAR2(60 CHAR) NOT NULL,
  tamano      NUMBER(10) NOT NULL,
  verificado  NUMBER(1) DEFAULT 0 NOT NULL,
  creado_en   TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_documentos_mascota PRIMARY KEY (id),
  CONSTRAINT ck_docmascota_tipo CHECK (tipo IN ('vacunacion', 'esterilizacion', 'desparasitacion', 'pedigree', 'medico', 'otro')),
  CONSTRAINT fk_docmascota_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE,
  CONSTRAINT fk_docmascota_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
);
CREATE INDEX idx_docmascota_mascota ON documentos_mascota (mascota_id);

-- Publicaciones del refugio (si se borra la mascota, se borran también) -------
CREATE SEQUENCE publicaciones_refugio_seq;
CREATE TABLE publicaciones_refugio (
  id                   NUMBER(10) DEFAULT publicaciones_refugio_seq.NEXTVAL NOT NULL,
  refugio_id           NUMBER(10) NOT NULL,
  mascota_id           NUMBER(10) NOT NULL,
  texto                VARCHAR2(500 CHAR) NOT NULL,
  foto                 VARCHAR2(200 CHAR),
  foto_alt             VARCHAR2(160 CHAR),
  creado_en            TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  republicar_cada_dias NUMBER(5),
  publicado_en         TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  republicada_veces    NUMBER(10) DEFAULT 0 NOT NULL,
  CONSTRAINT pk_publicaciones_refugio PRIMARY KEY (id),
  CONSTRAINT fk_pubref_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE,
  CONSTRAINT fk_pubref_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE
);
CREATE INDEX idx_pub_refugio ON publicaciones_refugio (refugio_id, creado_en);
CREATE INDEX idx_pub_publicado ON publicaciones_refugio (refugio_id, publicado_en);

-- Foro de la comunidad -----------------------------------------------------
CREATE SEQUENCE publicaciones_foro_seq;
CREATE TABLE publicaciones_foro (
  id          NUMBER(10) DEFAULT publicaciones_foro_seq.NEXTVAL NOT NULL,
  usuario_id  NUMBER(10) NOT NULL,
  texto       VARCHAR2(600 CHAR) NOT NULL,
  foto        VARCHAR2(200 CHAR),
  foto_alt    VARCHAR2(160 CHAR),
  creado_en   TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_publicaciones_foro PRIMARY KEY (id),
  CONSTRAINT fk_foro_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);
CREATE INDEX idx_foro_fecha ON publicaciones_foro (creado_en);

CREATE SEQUENCE comentarios_foro_seq;
CREATE TABLE comentarios_foro (
  id             NUMBER(10) DEFAULT comentarios_foro_seq.NEXTVAL NOT NULL,
  publicacion_id NUMBER(10) NOT NULL,
  usuario_id     NUMBER(10) NOT NULL,
  texto          VARCHAR2(300 CHAR) NOT NULL,
  creado_en      TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_comentarios_foro PRIMARY KEY (id),
  CONSTRAINT fk_coment_pub FOREIGN KEY (publicacion_id) REFERENCES publicaciones_foro (id) ON DELETE CASCADE,
  CONSTRAINT fk_coment_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);
CREATE INDEX idx_comentarios_pub ON comentarios_foro (publicacion_id);

-- "Me gusta" en forma de huella: un usuario solo puede darlo una vez por publicación
CREATE TABLE likes_foro (
  publicacion_id NUMBER(10) NOT NULL,
  usuario_id     NUMBER(10) NOT NULL,
  CONSTRAINT pk_likes_foro PRIMARY KEY (publicacion_id, usuario_id),
  CONSTRAINT fk_likes_pub FOREIGN KEY (publicacion_id) REFERENCES publicaciones_foro (id) ON DELETE CASCADE,
  CONSTRAINT fk_likes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);

-- Reportes de mascotas perdidas / encontradas --------------------------------
CREATE SEQUENCE reportes_seq;
CREATE TABLE reportes (
  id          NUMBER(10) DEFAULT reportes_seq.NEXTVAL NOT NULL,
  usuario_id  NUMBER(10) NOT NULL,
  tipo        VARCHAR2(10 CHAR) NOT NULL,
  descripcion VARCHAR2(600 CHAR) NOT NULL,
  zona        VARCHAR2(120 CHAR) NOT NULL,
  foto        VARCHAR2(200 CHAR) NOT NULL,
  foto_alt    VARCHAR2(160 CHAR),
  creado_en   TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_reportes PRIMARY KEY (id),
  CONSTRAINT ck_reportes_tipo CHECK (tipo IN ('perdida', 'encontrada')),
  CONSTRAINT fk_reportes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);
CREATE INDEX idx_reportes_tipo ON reportes (tipo, creado_en);

-- Posibles coincidencias: pareja (reporte de pérdida, reporte de hallazgo) + similitud
CREATE SEQUENCE coincidencias_seq;
CREATE TABLE coincidencias (
  id                    NUMBER(10) DEFAULT coincidencias_seq.NEXTVAL NOT NULL,
  reporte_perdido_id    NUMBER(10) NOT NULL,
  reporte_encontrado_id NUMBER(10) NOT NULL,
  similitud             NUMBER(3) NOT NULL,
  creado_en             TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_coincidencias PRIMARY KEY (id),
  CONSTRAINT uq_coincidencia UNIQUE (reporte_perdido_id, reporte_encontrado_id),
  CONSTRAINT fk_coin_perdido FOREIGN KEY (reporte_perdido_id) REFERENCES reportes (id) ON DELETE CASCADE,
  CONSTRAINT fk_coin_encontrado FOREIGN KEY (reporte_encontrado_id) REFERENCES reportes (id) ON DELETE CASCADE
);

-- Coincidencias que el dueño del reporte decidió declinar
CREATE TABLE coincidencias_descartadas (
  usuario_id      NUMBER(10) NOT NULL,
  coincidencia_id NUMBER(10) NOT NULL,
  CONSTRAINT pk_coincidencias_descartadas PRIMARY KEY (usuario_id, coincidencia_id),
  CONSTRAINT fk_desc_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_desc_coin FOREIGN KEY (coincidencia_id) REFERENCES coincidencias (id) ON DELETE CASCADE
);

-- Intentos fallidos de inicio de sesión (para bloquear a quien adivine contraseñas)
CREATE TABLE intentos_login (
  clave  VARCHAR2(190 CHAR) NOT NULL,
  cuenta NUMBER(10) DEFAULT 1 NOT NULL,
  desde  TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_intentos_login PRIMARY KEY (clave)
);

-- Preguntas frecuentes de cada refugio (las usa el asistente del formulario de adopción) ------
-- `claves`: palabras extra, separadas por comas, que ayudan al asistente a encontrar la respuesta
CREATE SEQUENCE preguntas_refugio_seq;
CREATE TABLE preguntas_refugio (
  id             NUMBER(10) DEFAULT preguntas_refugio_seq.NEXTVAL NOT NULL,
  refugio_id     NUMBER(10) NOT NULL,
  pregunta       VARCHAR2(200 CHAR) NOT NULL,
  respuesta      VARCHAR2(1000 CHAR) NOT NULL,
  claves         VARCHAR2(300 CHAR),
  activa         NUMBER(1) DEFAULT 1 NOT NULL,
  creado_en      TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  actualizado_en TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_preguntas_refugio PRIMARY KEY (id),
  CONSTRAINT fk_preguntas_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE
);
CREATE INDEX idx_preguntas_refugio ON preguntas_refugio (refugio_id, activa);

-- Solicitudes de adopción que hacen los usuarios a un refugio -------------------------
CREATE SEQUENCE solicitudes_adopcion_seq;
CREATE TABLE solicitudes_adopcion (
  id              NUMBER(10) DEFAULT solicitudes_adopcion_seq.NEXTVAL NOT NULL,
  mascota_id      NUMBER(10) NOT NULL,
  refugio_id      NUMBER(10) NOT NULL,
  usuario_id      NUMBER(10) NOT NULL,
  nombre          VARCHAR2(100 CHAR) NOT NULL,
  correo          VARCHAR2(120 CHAR) NOT NULL,
  telefono        VARCHAR2(25 CHAR) NOT NULL,
  direccion       VARCHAR2(200 CHAR) NOT NULL,
  ocupacion       VARCHAR2(100 CHAR),
  tipo_vivienda   VARCHAR2(15 CHAR) NOT NULL,
  vivienda_propia VARCHAR2(10 CHAR) NOT NULL,
  otras_mascotas  VARCHAR2(200 CHAR),
  motivo          VARCHAR2(800 CHAR) NOT NULL,
  estado          VARCHAR2(12 CHAR) DEFAULT 'pendiente' NOT NULL,
  nota_refugio    VARCHAR2(400 CHAR),
  creado_en       TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  actualizado_en  TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_solicitudes_adopcion PRIMARY KEY (id),
  CONSTRAINT ck_adopcion_vivienda CHECK (tipo_vivienda IN ('casa', 'departamento', 'otro')),
  CONSTRAINT ck_adopcion_propia CHECK (vivienda_propia IN ('propia', 'rentada', 'familiar')),
  CONSTRAINT ck_adopcion_estado CHECK (estado IN ('pendiente', 'en revision', 'aprobada', 'rechazada')),
  CONSTRAINT fk_adopcion_mascota FOREIGN KEY (mascota_id) REFERENCES mascotas (id) ON DELETE CASCADE,
  CONSTRAINT fk_adopcion_refugio FOREIGN KEY (refugio_id) REFERENCES refugios (id) ON DELETE CASCADE,
  CONSTRAINT fk_adopcion_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
);
CREATE INDEX idx_adopcion_refugio ON solicitudes_adopcion (refugio_id, estado);
CREATE INDEX idx_adopcion_usuario ON solicitudes_adopcion (usuario_id);

-- Documentos de una solicitud de adopción (privados: solo los ve el refugio que la recibe)
CREATE SEQUENCE documentos_adopcion_seq;
CREATE TABLE documentos_adopcion (
  id           NUMBER(10) DEFAULT documentos_adopcion_seq.NEXTVAL NOT NULL,
  solicitud_id NUMBER(10) NOT NULL,
  tipo         VARCHAR2(15 CHAR) NOT NULL,
  nombre       VARCHAR2(120 CHAR) NOT NULL,
  archivo      VARCHAR2(120 CHAR) NOT NULL,
  mime         VARCHAR2(60 CHAR) NOT NULL,
  tamano       NUMBER(10) NOT NULL,
  creado_en    TIMESTAMP(3) DEFAULT SYS_EXTRACT_UTC(SYSTIMESTAMP) NOT NULL,
  CONSTRAINT pk_documentos_adopcion PRIMARY KEY (id),
  CONSTRAINT ck_docadopcion_tipo CHECK (tipo IN ('identificacion', 'domicilio', 'vivienda', 'otro')),
  CONSTRAINT fk_docadopcion_solicitud FOREIGN KEY (solicitud_id) REFERENCES solicitudes_adopcion (id) ON DELETE CASCADE
);
CREATE INDEX idx_docadopcion_solicitud ON documentos_adopcion (solicitud_id);
