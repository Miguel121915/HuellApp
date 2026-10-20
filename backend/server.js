const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const path = require('path');

// Cargar variables de entorno desde el archivo .env de la carpeta backend
require('dotenv').config({ path: path.join(__dirname, '.env') });

const { GoogleGenAI } = require('@google/genai');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// =========================================================================
// PON TU API KEY AQUÍ PARA EVITAR CUALQUIER FALLO DE INYECCIÓN EN WINDOWS:
// =========================================================================
const API_KEY_MANUAL = ''; 

const apiKey = process.env.GEMINI_API_KEY || API_KEY_MANUAL;

// Inicializar el cliente de Gemini usando el SDK oficial
const ai = new GoogleGenAI({ apiKey: apiKey });

// Configuración de la conexión a MySQL (XAMPP - Puerto 3307)
const db = mysql.createConnection({
    host: 'localhost',
    port: 3307,
    user: 'root',
    password: '',
    database: 'huellapp'
});

db.connect((err) => {
    if (err) {
        console.error('❌ Error al conectar a la base de datos:', err);
        return;
    }
    console.log('✅ Conectado exitosamente a la base de datos MySQL (huellapp)');
});

// Ruta de prueba del servidor
app.get('/', (req, res) => {
    res.json({ mensaje: '¡El backend de HuellApp con IA está funcionando al 100%!' });
});

// Endpoint para analizar una mascota usando Gemini
app.post('/api/analizar-mascota', async (req, res) => {
    try {
        const { promptTexto } = req.body;
        
        if (!promptTexto) {
            return res.status(400).json({ error: 'Falta el texto o la descripción de la mascota para analizar.' });
        }

        // Prompt avanzado para garantizar respuesta limpia y estructurada
        const promptEstructurado = `
Eres un asistente experto en rescate animal para HuellApp.
Analiza la siguiente descripción de una mascota y genera una respuesta exclusivamente en formato JSON con la siguiente estructura exacta (sin texto ni Markdown adicional antes o después del JSON):

{
  "razaEstimada": "string",
  "colorPrincipal": "string",
  "tamano": "Pequeño / Mediano / Grande",
  "senasParticulares": "string",
  "resumenAlerta": "string con un resumen breve para el foro/alerta"
}

Descripción recibida:
"${promptTexto}"
`;

        // Llamada al modelo Gemini 2.5 Flash en el SDK oficial
        const response = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: [
                {
                    role: 'user',
                    parts: [
                        { text: promptEstructurado }
                    ]
                }
            ]
        });

        // Limpiar posible formato Markdown de la respuesta (```json ... ```)
        let textoLimpio = response.text.trim();
        if (textoLimpio.startsWith('```json')) {
            textoLimpio = textoLimpio.replace(/^```json\s*/, '').replace(/\s*```$/, '');
        } else if (textoLimpio.startsWith('```')) {
            textoLimpio = textoLimpio.replace(/^```\s*/, '').replace(/\s*```$/, '');
        }

        // Parsear a JSON para devolver un objeto listo para Flutter
        let datosIA;
        try {
            datosIA = JSON.parse(textoLimpio);
        } catch (e) {
            datosIA = { analisisTexto: response.text };
        }

        res.json({
            exito: true,
            analisisIA: datosIA
        });

    } catch (error) {
        console.error('❌ Error al conectar con Gemini:', error);
        res.status(500).json({ 
            exito: false, 
            error: 'Error interno al procesar la Inteligencia Artificial.' 
        });
    }
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});