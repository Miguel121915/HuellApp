/**
 * camara.js — Acceso a la cámara con navigator.mediaDevices.getUserMedia.
 * Funciona en https:// y en http://localhost / 127.0.0.1 (contextos seguros).
 */

/** Error con un `codigo` para que la pantalla muestre el mensaje adecuado. */
export class ErrorCamara extends Error {
  constructor(codigo, mensaje) {
    super(mensaje);
    this.codigo = codigo; // "no-soportada" | "denegada" | "sin-camara" | "ocupada" | "desconocido"
  }
}

const MENSAJES = {
  "no-soportada": "Tu navegador no permite usar la cámara en esta página.",
  denegada: "No diste permiso para usar la cámara. Puedes activarlo en el candado de la barra de direcciones o subir una foto desde tu equipo.",
  "sin-camara": "No encontramos ninguna cámara conectada. Puedes subir una foto desde tu equipo.",
  ocupada: "La cámara está siendo usada por otra aplicación. Ciérrala e inténtalo de nuevo, o sube una foto.",
  desconocido: "No pudimos iniciar la cámara. Puedes volver a intentarlo o subir una foto.",
};

/** Enciende la cámara y la conecta al <video>. Lanza ErrorCamara si falla. */
export async function iniciarCamara(video) {
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new ErrorCamara("no-soportada", MENSAJES["no-soportada"]);
  }
  let flujo;
  try {
    flujo = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } },
      audio: false,
    });
  } catch (error) {
    const codigo = {
      NotAllowedError: "denegada", SecurityError: "denegada",
      NotFoundError: "sin-camara", OverconstrainedError: "sin-camara",
      NotReadableError: "ocupada", AbortError: "ocupada",
    }[error.name] || "desconocido";
    throw new ErrorCamara(codigo, MENSAJES[codigo]);
  }
  video.srcObject = flujo;
  await video.play();
  return flujo;
}

/** Apaga la cámara (la luz del equipo se apaga) y desconecta el <video>. */
export function detenerCamara(video) {
  const flujo = video.srcObject;
  if (flujo) flujo.getTracks().forEach((pista) => pista.stop());
  video.srcObject = null;
}

/**
 * Dibuja el fotograma actual en un <canvas> y devuelve la imagen como data URL (JPEG).
 * Se reduce a `anchoMax` px para no guardar fotos enormes.
 */
export function capturarFoto(video, canvas, anchoMax = 1024) {
  const escala = Math.min(1, anchoMax / video.videoWidth);
  canvas.width = Math.round(video.videoWidth * escala);
  canvas.height = Math.round(video.videoHeight * escala);
  canvas.getContext("2d").drawImage(video, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.85);
}
