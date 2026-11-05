/**
 * mock-kiro.js — Preguntas frecuentes del asistente KIRO.
 * `claves` son raíces de palabras (sin acentos y en minúsculas): "adopt" coincide con
 * adoptar, adopción, adoptado... El chatbot real se conectaría a un backend más adelante.
 */
export const SALUDO_KIRO = "Hola, me llamo KIRO y te asistiré en lo que pueda";
export const RESPUESTA_VACIA = "Escribe tu duda arriba y con gusto te ayudo. Por ejemplo: «¿Cómo adopto una mascota?»";
export const RESPUESTA_DESCONOCIDA = "Mmm, todavía no sé responder eso. Prueba con otras palabras o elige una de las preguntas frecuentes de abajo.";

export const preguntasKiro = [
  { id: "reportar", pregunta: "¿Cómo reporto una mascota perdida?", claves: ["report", "perdi", "extravi", "se fue", "desaparec"],
    respuesta: "Ve a «Reportar», toma una foto con tu cámara (o sube una), indica si está perdida o encontrada, describe a tu mascota y la zona. Después revisaré si hay coincidencias.",
    enlace: { texto: "Ir a Reportar", ruta: "pages/usuario/reportar.html" } },
  { id: "encontre", pregunta: "Encontré una mascota, ¿qué hago?", claves: ["encontre", "encontrada", "encontrado", "hallé", "halle", "calle"],
    respuesta: "¡Gracias por ayudar! Resguárdala en un lugar seguro, revisa si trae collar o placa, y crea un reporte de mascota «encontrada» con foto y zona. Si hay coincidencia, el dueño podrá contactarte.",
    enlace: { texto: "Crear reporte", ruta: "pages/usuario/reportar.html" } },
  { id: "adoptar", pregunta: "¿Cómo adopto una mascota?", claves: ["adopt", "adopci", "quiero un perro", "quiero un gato", "familia"],
    respuesta: "Entra a «Refugios», elige un centro de adopción verificado y filtra por especie, edad y tamaño. Cuando encuentres a tu compañero ideal, contacta al refugio con los datos de su ficha.",
    enlace: { texto: "Ver refugios", ruta: "pages/usuario/refugios.html" } },
  { id: "requisitos", pregunta: "¿Qué requisitos piden para adoptar?", claves: ["requisit", "document", "necesito para", "que piden"],
    respuesta: "Cada refugio define los suyos, pero normalmente piden una identificación, comprobante de domicilio y una entrevista breve. Confirma los detalles llamando al refugio que te interese." },
  { id: "coincidencias", pregunta: "¿Qué son las coincidencias?", claves: ["coincid", "similitud", "porcentaje", "match"],
    respuesta: "Son reportes de mascotas encontradas que se parecen a la tuya. Cada una muestra un porcentaje de similitud; si la reconoces puedes contactar a quien la encontró, y si no, declinarla.",
    enlace: { texto: "Ver coincidencias", ruta: "pages/usuario/coincidencias.html" } },
  { id: "foro", pregunta: "¿Cómo funciona el foro?", claves: ["foro", "publicar", "publicacion", "me gusta", "huella", "like", "comentar"],
    respuesta: "El foro es el muro de la comunidad: comparte texto y fotos, comenta y da «me gusta» tocando la huellita 🐾. Úsalo para recomendar veterinarias, contar historias de adopción o pedir ayuda.",
    enlace: { texto: "Ir al foro", ruta: "pages/usuario/foro.html" } },
  { id: "contacto", pregunta: "¿Cómo contacto a un refugio?", claves: ["contact", "telefono", "direccion", "horario", "donde esta", "ubicacion"],
    respuesta: "En «Refugios» abre el centro que quieras: ahí verás su dirección, horario y teléfono." },
  { id: "registrar", pregunta: "Tengo un refugio, ¿cómo me registro?", claves: ["registrar", "mi refugio", "verific", "soy refugio", "dar de alta"],
    respuesta: "Cierra sesión y elige «Regístrate» en la pestaña de Refugio. Deberás subir tus documentos y un administrador los revisará antes de activar tu panel." },
  { id: "cuidados", pregunta: "¿Qué cuidados básicos necesita una mascota?", claves: ["cuidad", "vacuna", "esteril", "veterinari", "comida", "alimento", "salud"],
    respuesta: "Lo básico: vacunas y desparasitación al día, alimentación adecuada, agua limpia, paseos o juego diario, esterilización y una visita anual al veterinario. Ante cualquier síntoma raro, consulta a un profesional." },
  { id: "kiro", pregunta: "¿Quién eres, KIRO?", claves: ["kiro", "quien eres", "como te llamas", "que eres", "robot"],
    respuesta: "Soy KIRO, un gato-robot asistente de HuellApp. Respondo dudas frecuentes sobre reportes, adopción y el uso de la plataforma." },
  { id: "saludo", pregunta: "Hola", claves: ["hola", "buenas", "buenos dias", "buenas tardes", "que tal"], oculta: true,
    respuesta: "¡Hola! 🐾 ¿En qué te puedo ayudar hoy? Pregúntame sobre reportes, adopción o el foro." },
];
