/**
 * api.js — Cliente HTTP de la API de HuellApp. Todo el sitio habla con el servidor por aquí:
 * agrega el token de sesión, interpreta los errores y reacciona a sesiones vencidas.
 */
import { API_URL } from "./config.js";
import { leer, borrar, CLAVES } from "./storage.js";
import { irA } from "./utils.js";

/** Error de la API con el mensaje listo para mostrar al usuario. */
export class ErrorApi extends Error {
  constructor(mensaje, estado = 0, datos = {}) {
    super(mensaje);
    this.estado = estado;   // código HTTP (0 = sin conexión)
    this.datos = datos;     // cuerpo completo de la respuesta de error
  }
}

const MENSAJE_SIN_SERVIDOR = "No hay conexión con el servidor de HuellApp. Revisa que esté encendido (en la carpeta backend ejecuta: php artisan serve) y que MySQL esté encendido en XAMPP; luego recarga la página.";

/** Franja de aviso visible (servidor apagado u otro error que ninguna pantalla muestra por sí sola). */
function avisar(mensaje) {
  let banner = document.getElementById("banner-servidor");
  if (!banner) {
    banner = document.createElement("div");
    banner.id = "banner-servidor";
    banner.className = "banner-servidor";
    banner.setAttribute("role", "alert");
    document.body.prepend(banner);
  }
  banner.textContent = mensaje;
}

// Si una pantalla no atrapa un error de la API, se avisa al usuario en vez de dejar la página muda.
// (401 y "refugio no aprobado" ya redirigen; la falta de conexión ya mostró su aviso.)
window.addEventListener("unhandledrejection", (evento) => {
  const error = evento.reason;
  if (!(error instanceof ErrorApi)) return;
  evento.preventDefault(); // es un error esperado y ya se atiende: no ensuciar la consola
  const yaAtendido = error.estado === 0 || error.estado === 401 || (error.estado === 403 && error.datos.codigo === "refugio-no-aprobado");
  if (!yaAtendido) avisar(error.message);
});

/**
 * @param {"GET"|"POST"|"PUT"|"PATCH"|"DELETE"} metodo
 * @param {string} ruta  Relativa a /api, ej. "/foro"
 * @param {object} [cuerpo]
 */
export async function api(metodo, ruta, cuerpo, { blob = false } = {}) {
  const sesion = leer(CLAVES.SESION, null);
  let respuesta;
  try {
    respuesta = await fetch(API_URL + ruta, {
      method: metodo,
      headers: {
        ...(cuerpo !== undefined ? { "Content-Type": "application/json" } : {}),
        ...(sesion?.token ? { Authorization: `Bearer ${sesion.token}` } : {}),
      },
      body: cuerpo !== undefined ? JSON.stringify(cuerpo) : undefined,
    });
  } catch {
    avisar(MENSAJE_SIN_SERVIDOR);
    throw new ErrorApi(MENSAJE_SIN_SERVIDOR, 0);
  }

  if (respuesta.ok && blob) return respuesta.blob(); // archivos (documentos): se devuelven tal cual

  let datos = {};
  try { datos = await respuesta.json(); } catch { /* respuesta sin cuerpo JSON */ }
  if (respuesta.ok) return datos;

  // Sesión vencida o inválida: se limpia y se manda al login (excepto al intentar iniciar sesión)
  if (respuesta.status === 401 && !ruta.startsWith("/auth/login")) {
    borrar(CLAVES.SESION);
    irA("pages/login.html");
  }
  // Un refugio que dejó de estar aprobado (p. ej. lo suspendieron) vuelve a su pantalla de estado
  if (respuesta.status === 403 && datos.codigo === "refugio-no-aprobado") irA("pages/estado-refugio.html");

  throw new ErrorApi(datos.error || "Ocurrió un error. Inténtalo de nuevo.", respuesta.status, datos);
}

export const get = (ruta) => api("GET", ruta);
export const post = (ruta, cuerpo = {}) => api("POST", ruta, cuerpo);
export const put = (ruta, cuerpo = {}) => api("PUT", ruta, cuerpo);
export const patch = (ruta, cuerpo = {}) => api("PATCH", ruta, cuerpo);
export const del = (ruta) => api("DELETE", ruta);

/** Descarga un archivo protegido (necesita sesión) y lo devuelve como Blob. */
export const descargar = (ruta) => api("GET", ruta, undefined, { blob: true });

/**
 * Para las acciones de formularios: convierte un ErrorApi en { ok:false, error } para mostrarlo
 * en pantalla, y deja pasar cualquier otro error (los bugs no se esconden).
 */
export async function intentar(accion) {
  try {
    return await accion();
  } catch (error) {
    if (error instanceof ErrorApi) return { ok: false, error: error.message };
    throw error;
  }
}
