-- Base de Datos HuellApp en MySQL / MariaDB (XAMPP)

-- 1. Tabla de Usuarios (Soporta registros locales y autenticación con Google)
CREATE TABLE IF NOT EXISTS usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_usuario VARCHAR(100) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NULL, -- Nulo si accede por Google Sign-In
    google_id VARCHAR(100) UNIQUE NULL, -- Para identificar cuentas de Google
    tipo_usuario VARCHAR(30) DEFAULT 'CIUDADANO', -- 'CIUDADANO', 'REFUGIO', 'ADMIN'
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla de Refugios (Datos capturados desde RegisterShelterScreen)
CREATE TABLE IF NOT EXISTS refugios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT,
    nombre_refugio VARCHAR(150) NOT NULL,
    tipo_organizacion VARCHAR(100),
    rfc VARCHAR(20),
    anio_fundacion INT,
    descripcion VARCHAR(1000),
    direccion VARCHAR(250),
    municipio VARCHAR(100),
    codigo_postal VARCHAR(10),
    horario VARCHAR(150),
    telefono VARCHAR(30),
    latitud DECIMAL(10, 6) NOT NULL,  -- Crucial para el mapa y proximidad
    longitud DECIMAL(10, 6) NOT NULL, -- Crucial para el mapa y proximidad
    documento_aval_url VARCHAR(400),
    verificado TINYINT(1) DEFAULT 0, -- 0: Pendiente, 1: Aprobado
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- 3. Tabla de Mascotas en Refugios (Vinculadas a los modales de adopción)
CREATE TABLE IF NOT EXISTS mascotas_refugio (
    id INT AUTO_INCREMENT PRIMARY KEY,
    refugio_id INT,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(50), -- 'Perro', 'Gato', 'Otro'
    edad VARCHAR(50),
    genero VARCHAR(20),
    descripcion VARCHAR(500),
    imagen_principal VARCHAR(400),
    salud_json VARCHAR(1000), -- Almacena lista de vacunas/cuidados
    estado_adopcion VARCHAR(30) DEFAULT 'DISPONIBLE',
    FOREIGN KEY (refugio_id) REFERENCES refugios(id) ON DELETE CASCADE
);

-- 4. Tabla de Reportes (Mascotas extraviadas o avistamientos con IA)
CREATE TABLE IF NOT EXISTS reportes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT,
    tipo_reporte VARCHAR(30) NOT NULL, -- 'Extraviada' o 'Avistamiento'
    tipo_mascota VARCHAR(50),          -- 'Perro', 'Gato', 'Otro'
    nombre_mascota VARCHAR(100),
    raza VARCHAR(100),
    descripcion VARCHAR(1000),
    zona_ubicacion VARCHAR(200),
    latitud DECIMAL(10, 6),
    longitud DECIMAL(10, 6),
    imagen_url VARCHAR(400) NOT NULL,  -- Foto procesada por el backend de IA
    fecha_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- 5. Tabla del Foro Comunitario
CREATE TABLE IF NOT EXISTS foro_posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT,
    titulo VARCHAR(150) NOT NULL,
    contenido VARCHAR(1000) NOT NULL,
    imagen_url VARCHAR(400),
    fecha_post TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- 6. Tabla de Coincidencias (El puente inteligente entre Reportes y Foro)
CREATE TABLE IF NOT EXISTS coincidencias (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reporte_id INT,
    post_id INT,
    porcentaje_similitud DECIMAL(5, 2) NOT NULL, -- Ej: 92.50
    estado VARCHAR(30) DEFAULT 'PENDIENTE',    -- 'PENDIENTE', 'CONTACTADO', 'DESCARTADO'
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reporte_id) REFERENCES reportes(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES foro_posts(id) ON DELETE CASCADE
);