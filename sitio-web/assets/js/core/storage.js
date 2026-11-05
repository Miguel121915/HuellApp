/**
 * storage.js — Capa única de acceso a localStorage.
 * Hoy solo guarda la sesión: los datos de la aplicación viven en la base de datos del servidor.
 */
const PREFIJO = "huellapp:";

/** Claves usadas por la aplicación. */
export const CLAVES = Object.freeze({
  SESION: "sesion", // datos básicos + token del usuario autenticado
});

/** Lee y parsea un valor; devuelve `valorPorDefecto` si no existe o está corrupto. */
export function leer(clave, valorPorDefecto = null) {
  try {
    const crudo = localStorage.getItem(PREFIJO + clave);
    return crudo === null ? valorPorDefecto : JSON.parse(crudo);
  } catch {
    return valorPorDefecto;
  }
}

/** Guarda un valor serializado. Devuelve false si el navegador lo bloquea. */
export function guardar(clave, valor) {
  try {
    localStorage.setItem(PREFIJO + clave, JSON.stringify(valor));
    return true;
  } catch {
    return false;
  }
}

export function borrar(clave) {
  try { localStorage.removeItem(PREFIJO + clave); } catch { /* sin acceso */ }
}
