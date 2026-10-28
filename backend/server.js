// =========================================================================
// 1. IMPORTACIÓN DE LIBRERÍAS Y MÓDULOS NECESARIOS
// =========================================================================
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

require('dotenv').config({ path: path.join(__dirname, '.env') });

const { GoogleGenAI } = require('@google/genai');

// =========================================================================
// 2. CONFIGURACIÓN DEL SERVIDOR Y MIDDLEWARES
// =========================================================================
const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Carpeta donde se guardan las fotos y se sirven como URL (/uploads/archivo.jpg)
const CARPETA_UPLOADS = path.join(__dirname, 'uploads');
fs.mkdirSync(CARPETA_UPLOADS, { recursive: true });
app.use('/uploads', express.static(CARPETA_UPLOADS));

// =========================================================================
// 3. INICIALIZACIÓN DE SERVICIOS (GEMINI Y MYSQL)
// =========================================================================
if (!process.env.GEMINI_API_KEY) {
    console.error('❌ Falta GEMINI_API_KEY en el archivo .env');
    process.exit(1);
}
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const MODELO = process.env.GEMINI_MODEL || 'gemini-3.8-flash';
console.log(`🤖 Modelo de IA en uso: ${MODELO}`);

const db = mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'huellapp',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

(async () => {
    try {
        const connection = await db.getConnection();
        console.log('✅ Conexión exitosa a MySQL (Base de datos: huellapp)');
        connection.release();
    } catch (err) {
        console.error('❌ Error al conectar a MySQL:', err.message);
    }
})();

// -------------------------------------------------------------------------
// Utilidades
// -------------------------------------------------------------------------
const esperar = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Llamar a Gemini con reintentos automáticos en errores temporales
async function generarConReintentos(params, intentos = 3) {
    for (let i = 1; i <= intentos; i++) {
        try {
            return await ai.models.generateContent(params);
        } catch (error) {
            const temporal =
                [429, 500, 503].includes(error.status) ||
                /UNAVAILABLE|high demand/i.test(error.message || '');

            if (!temporal || i === intentos) throw error;

            const espera = 1500 * 2 ** (i - 1);
            console.log(`⏳ Gemini ocupado (intento ${i}/${intentos}). Reintentando en ${espera / 1000} s...`);
            await esperar(espera);
        }
    }
}

// Convierte una ruta guardada (/uploads/x.jpg) en URL completa (http://IP:3000/uploads/x.jpg)
function urlAbsoluta(req, ruta) {
    if (!ruta) return null;
    if (/^https?:\/\//i.test(ruta)) return ruta;
    if (!ruta.startsWith('/')) return null; // valores viejos como 'foto_almacenada_base64'
    return `${req.protocol}://${req.get('host')}${ruta}`;
}

// Guarda la foto en disco y devuelve la ruta relativa (/uploads/archivo.jpg)
function guardarFoto(imagenBase64, mimeType) {
    const base64Limpia = (imagenBase64.includes(',') ? imagenBase64.split(',')[1] : imagenBase64)
        .replace(/[\r\n]/g, '');
    const extension = mimeType === 'image/png' ? 'png' : mimeType === 'image/webp' ? 'webp' : 'jpg';
    const nombreArchivo = `reporte_${Date.now()}.${extension}`;
    fs.writeFileSync(path.join(CARPETA_UPLOADS, nombreArchivo), Buffer.from(base64Limpia, 'base64'));
    return `/uploads/${nombreArchivo}`;
}

// =========================================================================
// 4. RUTAS Y ENDPOINTS DE HUELLAPP
// =========================================================================

// --- Ruta 1: Verificación de estado ---
app.get('/', (req, res) => {
    res.json({ status: 'OK', mensaje: 'Backend HuellApp activo y listo.' });
});

// --- Ruta 2: Análisis, guardado, coincidencias y publicación en el foro ---
app.post('/api/analizar-mascota', async (req, res) => {
    console.log('📥 Petición recibida en /api/analizar-mascota');

    try {
        const {
            usuarioId, tipoReporte, tipoMascota, nombreMascota, promptTexto,
            imagenBase64, mimeType, latitud, longitud, zonaUbicacion
        } = req.body;

        if (!imagenBase64 && !promptTexto) {
            return res.status(400).json({ exito: false, error: 'Se requiere una imagen o descripción.' });
        }

        // ---------- 1) Análisis de la mascota con Gemini ----------
        const promptEstructurado = `
Eres el asistente de visión por computadora de HuellApp.
Analiza la foto y/o descripción adjunta de la mascota.
Devuelve ÚNICAMENTE un objeto JSON con el siguiente formato exacto:

{
  "razaEstimada": "string",
  "colorPrincipal": "string",
  "tamano": "Pequeño / Mediano / Grande",
  "senasParticulares": "string",
  "resumenAlerta": "string"
}

Descripción: "${promptTexto || 'Analizar foto adjunta.'}"
`;

        const parts = [];
        if (imagenBase64) {
            const base64Limpia = (imagenBase64.includes(',') ? imagenBase64.split(',')[1] : imagenBase64)
                .replace(/[\r\n]/g, '');
            parts.push({
                inlineData: { data: base64Limpia, mimeType: mimeType || 'image/jpeg' }
            });
        }
        parts.push({ text: promptEstructurado });

        const response = await generarConReintentos({
            model: MODELO,
            contents: [{ role: 'user', parts }],
            config: { responseMimeType: 'application/json' }
        });

        let datosIA;
        try {
            datosIA = JSON.parse(response.text);
        } catch (e) {
            datosIA = { analisisTexto: response.text };
        }

        // ---------- 2) Guardar la foto y el reporte ----------
        const rutaFoto = imagenBase64 ? guardarFoto(imagenBase64, mimeType) : null;

        const raza = datosIA.razaEstimada || 'Por determinar';
        const descripcionCompleta = `${promptTexto || ''} | Rasgos: ${datosIA.colorPrincipal || ''}, ${datosIA.senasParticulares || ''}`;

        const [resultadoReporte] = await db.execute(
            `INSERT INTO reportes
             (usuario_id, tipo_reporte, tipo_mascota, nombre_mascota, raza, descripcion, zona_ubicacion, latitud, longitud, imagen_url)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                usuarioId || null,
                tipoReporte || 'Extraviada',
                tipoMascota || 'Otro',
                nombreMascota || 'Sin nombre',
                raza,
                descripcionCompleta,
                zonaUbicacion || 'No especificada',
                latitud || null,
                longitud || null,
                rutaFoto || 'sin_imagen'
            ]
        );

        const reporteId = resultadoReporte.insertId;
        console.log(`💾 Reporte insertado con ID: ${reporteId}`);

        // ---------- 3) Buscar coincidencias contra el foro ----------
        const [postsForo] = await db.execute(
            'SELECT id, titulo, contenido, imagen_url FROM foro_posts ORDER BY id DESC LIMIT 10'
        );

        let coincidenciasEncontradas = [];

        if (postsForo.length > 0) {
            // Al modelo solo le mandamos id, título y contenido (sin las URLs de fotos)
            const postsParaIA = postsForo.map(({ id, titulo, contenido }) => ({ id, titulo, contenido }));

            const promptCoincidencia = `
Compara las siguientes características de una mascota recién reportada contra esta lista de publicaciones del foro comunitario.

Mascota Reportada:
- Raza: ${datosIA.razaEstimada}
- Color: ${datosIA.colorPrincipal}
- Tamaño: ${datosIA.tamano}
- Señas: ${datosIA.senasParticulares}
- Resumen: ${promptTexto || ''}

Publicaciones del Foro:
${JSON.stringify(postsParaIA)}

Analiza si alguna publicación del foro describe al mismo animal.
Devuelve ÚNICAMENTE un arreglo JSON con el id del post y el porcentaje de similitud estimado de 0 a 100:
[
  { "post_id": 1, "porcentaje_similitud": 85.5 }
]
Si no hay similitud relevante (>50%), devuelve un arreglo vacío: []
`;

            try {
                const responseCoincidencias = await generarConReintentos({
                    model: MODELO,
                    contents: [{ role: 'user', parts: [{ text: promptCoincidencia }] }],
                    config: { responseMimeType: 'application/json' }
                });

                const listaCoincidencias = JSON.parse(responseCoincidencias.text);

                for (const match of listaCoincidencias) {
                    if (match.porcentaje_similitud >= 50) {
                        const post = postsForo.find((p) => p.id === match.post_id);
                        if (!post) continue; // el modelo devolvió un id que no existe

                        const [ins] = await db.execute(
                            'INSERT INTO coincidencias (reporte_id, post_id, porcentaje_similitud, estado) VALUES (?, ?, ?, ?)',
                            [reporteId, post.id, match.porcentaje_similitud, 'PENDIENTE']
                        );

                        // Datos completos para pintar la tarjeta en Flutter
                        coincidenciasEncontradas.push({
                            id: ins.insertId,
                            post_id: post.id,
                            titulo: post.titulo,
                            contenido: post.contenido,
                            imagen_url: urlAbsoluta(req, post.imagen_url),
                            porcentaje_similitud: match.porcentaje_similitud
                        });
                    }
                }
                console.log(`🔗 Se registraron ${coincidenciasEncontradas.length} coincidencia(s) en la BD.`);
            } catch (errMatch) {
                console.error('⚠️ Error al calcular coincidencias con Gemini:', errMatch.message);
            }
        }

        // ---------- 4) Publicar el reporte en el foro ----------
        // Se hace DESPUÉS de buscar coincidencias para que no se compare contra sí mismo
        try {
            const etiqueta = (tipoReporte || 'Extraviada') === 'Extraviada' ? '🔎 Se busca' : '🐾 Fue encontrada';
            const titulo = `${etiqueta}: ${nombreMascota || raza}`.slice(0, 150);
            const contenido = [
                `Raza: ${raza}`,
                `Color: ${datosIA.colorPrincipal || 'No especificado'}`,
                `Tamaño: ${datosIA.tamano || 'No especificado'}`,
                `Señas: ${datosIA.senasParticulares || 'Sin señas'}`,
                `Zona: ${zonaUbicacion || 'No especificada'}`
            ].join('\n').slice(0, 1000);

            await db.execute(
                'INSERT INTO foro_posts (usuario_id, titulo, contenido, imagen_url) VALUES (?, ?, ?, ?)',
                [usuarioId || null, titulo, contenido, rutaFoto]
            );
            console.log('📰 Reporte publicado en el foro.');
        } catch (errForo) {
            console.error('⚠️ No se pudo publicar en el foro:', errForo.message);
        }

        res.json({
            exito: true,
            reporteId,
            analisisIA: datosIA,
            coincidencias: coincidenciasEncontradas
        });

    } catch (error) {
        console.error('❌ Error detallado en el servidor:', error);
        res.status(500).json({
            exito: false,
            error: error.message || 'Error interno en el servidor.'
        });
    }
});

// --- Ruta 3: Coincidencias registradas de un reporte ---
app.get('/api/coincidencias/:reporteId', async (req, res) => {
    try {
        const { reporteId } = req.params;
        const [rows] = await db.execute(`
            SELECT c.id, c.post_id, c.porcentaje_similitud AS porcentaje_similitud, c.estado,
                   f.titulo, f.contenido, f.imagen_url
            FROM coincidencias c
            JOIN foro_posts f ON c.post_id = f.id
            WHERE c.reporte_id = ?
            ORDER BY c.porcentaje_similitud DESC
        `, [reporteId]);

        res.json({
            exito: true,
            coincidencias: rows.map((r) => ({ ...r, imagen_url: urlAbsoluta(req, r.imagen_url) }))
        });
    } catch (error) {
        res.status(500).json({ exito: false, error: error.message });
    }
});

// --- Ruta 4: Listar las publicaciones del foro ---
app.get('/api/foro', async (req, res) => {
    try {
        const [rows] = await db.execute(`
            SELECT f.id, f.titulo, f.contenido, f.imagen_url, f.fecha_post,
                   u.nombre_usuario
            FROM foro_posts f
            LEFT JOIN usuarios u ON u.id = f.usuario_id
            ORDER BY f.id DESC
            LIMIT 50
        `);

        res.json({
            exito: true,
            posts: rows.map((r) => ({ ...r, imagen_url: urlAbsoluta(req, r.imagen_url) }))
        });
    } catch (error) {
        res.status(500).json({ exito: false, error: error.message });
    }
});

// =========================================================================
// 5. ARRANCAR EL SERVIDOR HTTP
// =========================================================================
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor backend escuchando en http://localhost:${PORT}`);
});