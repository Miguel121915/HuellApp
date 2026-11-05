/**
 * servicios.js — Datos de la vista de usuario (foro, refugios, reportes, coincidencias).
 * Cada función llama a la API del servidor; los módulos de página no saben nada de HTTP.
 * Las acciones que escribe el usuario devuelven { ok, ... } o { ok:false, error }.
 */
import { get, post, put, del, intentar } from "./api.js";

/* ---------- Foro ---------- */

export async function obtenerPublicacionesForo() {
  return (await get("/foro")).publicaciones;
}

/** @param {{texto:string, foto?:string}} datos  `foto` es una imagen en data URL (opcional) */
export const crearPublicacionForo = ({ texto, foto = "" }) => intentar(async () => {
  const r = await post("/foro", { texto, foto });
  return { ok: true, publicacion: r.publicacion };
});

export const agregarComentario = (idPublicacion, { texto }) => intentar(async () => {
  const r = await post(`/foro/${idPublicacion}/comentarios`, { texto });
  return { ok: true, comentarios: r.comentarios };
});

/** Fija el "me gusta" de una publicación. Devuelve { ok, activo }. */
export const establecerLike = (idPublicacion, activo) => intentar(async () => {
  const r = await put(`/foro/${idPublicacion}/like`, { activo });
  return { ok: true, activo: r.activo };
});

/* ---------- Refugios y mascotas (solo los verificados son visibles) ---------- */

export async function obtenerRefugiosVerificados() {
  return (await get("/refugios")).refugios;
}

/** @returns {Promise<object|null>} null si no existe o no está verificado */
export async function obtenerRefugioVerificado(id) {
  try {
    return (await get(`/refugios/${encodeURIComponent(id)}`)).refugio;
  } catch (error) {
    if (error.estado === 404) return null;
    throw error;
  }
}

export async function obtenerMascotasDisponibles(refugioId) {
  return (await get(`/refugios/${encodeURIComponent(refugioId)}/mascotas`)).mascotas;
}

export async function obtenerPublicacionesRefugio(refugioId) {
  return (await get(`/refugios/${encodeURIComponent(refugioId)}/publicaciones`)).publicaciones;
}

/* ---------- Adopción ---------- */

/** Preguntas frecuentes activas de un refugio: [{ id, pregunta, respuesta, claves[] }] */
export async function obtenerPreguntasRefugio(refugioId) {
  return (await get(`/refugios/${encodeURIComponent(refugioId)}/preguntas`)).preguntas;
}

/** Solicitudes de adopción del usuario con su estado: [{ mascotaId, estado, notaRefugio, ... }] */
export async function obtenerMisSolicitudesAdopcion() {
  return (await get("/adopciones")).solicitudes;
}

/**
 * Envía una solicitud de adopción.
 * @param {object} datos  mascotaId, nombre, correo, telefono, direccion, ocupacion, tipoVivienda,
 *   viviendaPropia, otrasMascotas, motivo, aceptaTerminos y documentos [{ tipo, nombre, dataUrl }]
 */
export const enviarSolicitudAdopcion = (datos) => intentar(async () => {
  const r = await post("/adopciones", datos);
  return { ok: true, solicitud: r.solicitud };
});

/* ---------- Reportes y coincidencias ---------- */

/** @param {{tipo:"perdida"|"encontrada", descripcion:string, zona:string, foto:string}} datos */
export const crearReporte = ({ tipo, descripcion, zona, foto }) => intentar(async () => {
  const r = await post("/reportes", { tipo, descripcion, zona, foto });
  return { ok: true, reporte: r.reporte, coincidenciasNuevas: r.coincidenciasNuevas };
});

export async function obtenerCoincidencias() {
  return (await get("/coincidencias")).coincidencias;
}

/** { pendientes, descartadas } */
export async function obtenerResumenCoincidencias() {
  return get("/coincidencias/resumen");
}

export const descartarCoincidencia = (id) => intentar(async () => {
  await post(`/coincidencias/${id}/descartar`);
  return { ok: true };
});

export const restaurarCoincidencias = () => intentar(async () => {
  await post("/coincidencias/restaurar");
  return { ok: true };
});

/* ---------- HU-12 Favoritos ---------- */

/** Mis mascotas favoritas con su refugio: [{ ...mascota, refugioNombre, refugioMunicipio, guardado }] */
export async function obtenerFavoritos() {
  return (await get("/favoritos")).favoritos;
}

/** Guarda (activo = true) o quita (false) una mascota de favoritos. */
export const establecerFavorito = (mascotaId, activo) => intentar(async () => {
  if (activo) await post("/favoritos", { mascotaId });
  else await del(`/favoritos/${encodeURIComponent(mascotaId)}`);
  return { ok: true, activo };
});

/* ---------- HU-13 Contacto con el refugio ---------- */

export async function obtenerMisMensajes() {
  return (await get("/mensajes")).mensajes;
}

/** @param {{refugioId?:string, mascotaId?:string, mensaje:string, telefono?:string}} datos */
export const enviarMensajeRefugio = (datos) => intentar(async () => {
  const r = await post("/mensajes", datos);
  return { ok: true, mensaje: r.mensaje };
});

/* ---------- HU-16 Requisitos de adopción ---------- */

/** Requisitos de un refugio (también para visitantes): [{ id, texto, detalle, obligatorio }] */
export async function obtenerRequisitosRefugio(refugioId) {
  return (await get(`/refugios/${encodeURIComponent(refugioId)}/requisitos`)).requisitos;
}
