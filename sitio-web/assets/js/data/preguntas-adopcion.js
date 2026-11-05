/**
 * preguntas-adopcion.js — Respuestas GENERALES de HuellApp sobre la solicitud de adopción.
 * El asistente del formulario usa primero las preguntas que da de alta cada refugio; estas solo
 * se muestran si ninguna del refugio responde la duda (y se indican como respuesta general).
 */
export const PREGUNTAS_GENERALES = [
  { pregunta: "¿Qué documentos debo adjuntar?", claves: ["requisitos", "papeles", "adjuntar", "subir"],
    respuesta: "El formulario pide tres cosas: una identificación oficial (INE, pasaporte o cédula), un comprobante de domicilio y de 1 a 3 fotos del espacio donde vivirá la mascota. Puedes agregar un documento extra si el refugio te lo pidió." },
  { pregunta: "¿En qué formato subo los archivos?", claves: ["formato", "pdf", "jpg", "png", "tamaño", "pesa", "megas"],
    respuesta: "La identificación y el comprobante pueden ser PDF, JPG o PNG de hasta 5 MB cada uno. Las fotos del espacio deben ser imágenes (JPG o PNG); se reducen automáticamente antes de enviarse." },
  { pregunta: "¿Qué identificación sirve?", claves: ["ine", "credencial", "pasaporte", "cedula", "licencia", "identificacion"],
    respuesta: "Cualquier identificación oficial vigente con foto: credencial para votar (INE), pasaporte o cédula profesional. Asegúrate de que se lea bien tu nombre." },
  { pregunta: "¿Qué comprobante de domicilio puedo usar?", claves: ["comprobante", "recibo", "luz", "agua", "telefono", "predial"],
    respuesta: "Normalmente se acepta un recibo de luz, agua, teléfono, internet o predial reciente (de los últimos 3 meses). Cada refugio puede tener reglas propias: si tienes dudas, llámale." },
  { pregunta: "¿Qué fotos del espacio debo tomar?", claves: ["fotos", "espacio", "patio", "casa", "departamento"],
    respuesta: "Toma fotos claras y con buena luz de donde estará la mascota: patio, jardín, azotea o las habitaciones. Si vives en un piso alto, incluye ventanas o balcones con protección." },
  { pregunta: "¿Qué pasa después de enviar la solicitud?", claves: ["despues", "enviar", "respuesta", "revision", "estado", "cuando"],
    respuesta: "El refugio revisará tus datos y documentos y te contactará por teléfono o correo. Mientras tanto, el botón de la mascota mostrará «Solicitud enviada»." },
  { pregunta: "¿Mis datos están protegidos?", claves: ["privacidad", "datos", "seguro", "quien ve", "protegidos"],
    respuesta: "Tus documentos solo los puede ver el refugio que recibe la solicitud. No se publican ni se comparten con otros usuarios." },
];

export const SALUDO_ASISTENTE = (refugio) =>
  `¡Hola! Soy KIRO 🐾. Te ayudo con tus dudas sobre la adopción y los documentos que pide ${refugio}. Escribe tu pregunta o elige una de abajo.`;

export const SIN_RESPUESTA = "Mmm, no encontré una respuesta para eso. Prueba con otras palabras, elige una de las preguntas sugeridas o llama directamente al refugio.";
