/**
 * auth.js — Sesión, inicio de sesión y registros, contra la API del servidor.
 *
 * La sesión (datos básicos + token) se guarda en localStorage para recordar al usuario entre
 * páginas; la validez REAL del token la comprueba el servidor en cada petición.
 */
import { leer, guardar, borrar, CLAVES } from "./storage.js";
import { get, post, intentar } from "./api.js";

/* ---------- Sesión ---------- */

/** @returns {{id,nombre,correo,rol,refugioId,refugioEstado,token}|null} */
export function obtenerSesion() {
  return leer(CLAVES.SESION, null);
}

export function cerrarSesion() {
  borrar(CLAVES.SESION);
}

/**
 * Inicia sesión validando correo, contraseña y rol elegido.
 * @returns {Promise<{ok:boolean, sesion?:object, error?:string}>}
 */
export const iniciarSesion = ({ rol, correo, password }) => intentar(async () => {
  const r = await post("/auth/login", { rol, correo: correo.trim(), password });
  const sesion = { ...r.sesion, token: r.token };
  guardar(CLAVES.SESION, sesion);
  return { ok: true, sesion };
});

/**
 * Vuelve a pedir al servidor los datos de la sesión (el estado de un refugio puede haber
 * cambiado desde que inició sesión). Actualiza lo guardado y devuelve { sesion, refugio }.
 */
export async function refrescarSesion() {
  const r = await get("/auth/yo");
  guardar(CLAVES.SESION, { ...r.sesion, token: obtenerSesion()?.token });
  return r;
}

/* ---------- Registros ---------- */

export const registrarUsuario = (datos) => intentar(async () => {
  await post("/auth/registro-usuario", datos);
  return { ok: true };
});

/**
 * Alta de refugio: el servidor crea la cuenta del responsable y la solicitud "pendiente".
 * `datos.documentos` es una lista de { tipo, nombre, dataUrl }.
 */
export const registrarRefugio = (datos) => intentar(async () => {
  await post("/auth/registro-refugio", datos);
  return { ok: true };
});

/* ---------- Apelación de un refugio rechazado ---------- */

/**
 * Datos y documentos actuales del refugio rechazado, para precargar el formulario.
 * @returns {Promise<object|null>} null si la solicitud ya no está rechazada (no hay nada que apelar)
 */
export async function obtenerApelacion() {
  try {
    return (await get("/auth/apelacion")).refugio;
  } catch (error) {
    if (error.estado === 409) return null;
    throw error;
  }
}

/**
 * Reenvía la solicitud corregida. `datos.documentos` lleva SOLO los archivos nuevos
 * ({ tipo, nombre, dataUrl }); cada uno reemplaza al anterior de su tipo.
 * El servidor deja la solicitud otra vez en "pendiente".
 */
export const enviarApelacion = (datos) => intentar(async () => {
  const r = await post("/auth/apelacion", datos);
  return { ok: true, refugio: r.refugio };
});

/** Datos completos del refugio de la sesión (con correo y documentos). */
export async function obtenerMiRefugio() {
  return (await get("/refugio/yo")).refugio;
}
