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

/** Sesión de visitante: puede ver refugios y mascotas sin cuenta (no tiene token). */
export function entrarComoInvitado() {
  const sesion = { id: null, nombre: "Visitante", correo: "", rol: "invitado", refugioId: null, refugioEstado: null, token: null };
  guardar(CLAVES.SESION, sesion);
  return sesion;
}

export const esInvitado = (sesion) => sesion?.rol === "invitado";

/** Guarda la sesión que devolvió el servidor, o avisa que falta el código de dos pasos. */
function recibirLogin(r) {
  if (r.requiere2fa) return { ok: true, requiere2fa: true, desafio: r.desafio };
  const sesion = { ...r.sesion, token: r.token };
  guardar(CLAVES.SESION, sesion);
  return { ok: true, sesion };
}

/**
 * Inicia sesión validando correo, contraseña y rol elegido.
 * Si la cuenta tiene verificación en dos pasos devuelve { ok, requiere2fa, desafio }:
 * falta llamar a verificarCodigo2fa con el código de Google Authenticator.
 * @returns {Promise<{ok:boolean, sesion?:object, requiere2fa?:boolean, desafio?:string, error?:string}>}
 */
export const iniciarSesion = ({ rol, correo, password }) => intentar(async () =>
  recibirLogin(await post("/auth/login", { rol, correo: correo.trim(), password })));

/** «Continuar con Google»: `idToken` es la credencial que entrega el botón de Google. */
export const iniciarSesionGoogle = ({ rol, idToken }) => intentar(async () =>
  recibirLogin(await post("/auth/google", { rol, idToken })));

/** Segundo paso: el código de 6 dígitos de Google Authenticator. */
export const verificarCodigo2fa = ({ desafio, codigo }) => intentar(async () =>
  recibirLogin(await post("/auth/2fa/verificar", { desafio, codigo: codigo.replace(/\s+/g, "") })));

/** Configuración pública del login (por ahora, el Client ID de Google; "" = sin botón de Google). */
export async function obtenerConfigAuth() {
  try {
    return await get("/auth/config");
  } catch {
    return { googleClientId: "" };
  }
}

/* ---------- Verificación en dos pasos de la cuenta (con sesión) ---------- */

export const estado2fa = async () => (await get("/auth/2fa")).activo;
/** Genera un secreto nuevo: { secreto, enlace } (el enlace otpauth:// va en el código QR). */
export const preparar2fa = () => post("/auth/2fa/preparar");
export const activar2fa = (codigo) => intentar(async () => ({ ok: true, ...(await post("/auth/2fa/activar", { codigo })) }));
export const desactivar2fa = (codigo) => intentar(async () => ({ ok: true, ...(await post("/auth/2fa/desactivar", { codigo })) }));

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
