/**
 * router-guard.js — Guardias de ruta del lado del cliente.
 * IMPORTANTE: esto solo mejora la experiencia; la seguridad real la aplica el servidor
 * en cada petición (rol, estado del refugio, dueño de los datos).
 */
import { obtenerSesion } from "./auth.js";
import { irA } from "./utils.js";

export const RUTA_LOGIN = "pages/login.html";
export const RUTA_ESTADO_REFUGIO = "pages/estado-refugio.html";

/** Pantalla principal de cada rol. */
export const RUTA_INICIO_POR_ROL = Object.freeze({
  usuario: "pages/usuario/inicio.html",
  refugio: "pages/refugio/panel.html",
  admin: "pages/admin/solicitudes.html",
});

/** A dónde mandar a una sesión recién iniciada (o ya existente). */
export function destinoDeSesion(sesion) {
  if (sesion.rol === "refugio" && sesion.refugioEstado !== "aprobado") return RUTA_ESTADO_REFUGIO;
  return RUTA_INICIO_POR_ROL[sesion.rol] || RUTA_LOGIN;
}

/**
 * Protege una página para un rol. Llamar al inicio del módulo de cada vista.
 * @param {"usuario"|"refugio"|"admin"} rol
 * @param {{permitirRefugioNoVerificado?: boolean}} opciones
 * @returns {object|null} la sesión si hay acceso; null si redirigió.
 */
export function requerirRol(rol, { permitirRefugioNoVerificado = false } = {}) {
  const sesion = obtenerSesion();

  if (!sesion) { irA(RUTA_LOGIN); return null; }

  if (sesion.rol !== rol) { irA(RUTA_INICIO_POR_ROL[sesion.rol] || RUTA_LOGIN); return null; }

  if (rol === "refugio" && !permitirRefugioNoVerificado && sesion.refugioEstado !== "aprobado") {
    irA(RUTA_ESTADO_REFUGIO);
    return null;
  }

  document.body.removeAttribute("data-protegida"); // muestra la página
  return sesion;
}

/** Para login/registro: si ya hay sesión, enviar al panel correspondiente. */
export function redirigirSiHaySesion() {
  const sesion = obtenerSesion();
  if (sesion) { irA(destinoDeSesion(sesion)); return true; }
  return false;
}
