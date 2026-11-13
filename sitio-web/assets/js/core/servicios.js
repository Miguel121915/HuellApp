/**
 * servicios.js — Datos de la vista de usuario (foro, refugios, reportes, coincidencias).
 * Cada función llama a la API del servidor; los módulos de página no saben nada de HTTP.
 * Las acciones que escribe el usuario devuelven { ok, ... } o { ok:false, error }.
 */
import { get, post, put, del, intentar } from "./api.js";

/* ---------- Foro ---------- */

/** Publicaciones del muro. `categoria`: busca | familia | reunidos | comunidad (sin ella, todas). */
export async function obtenerPublicacionesForo(categoria = "") {
  return (await get(`/foro${categoria ? `?categoria=${encodeURIComponent(categoria)}` : ""}`)).publicaciones;
}

/** «¡Ya apareció!»: quien publicó la alerta la cierra y pasa a «Reunidos». */
export const marcarReunido = (reporteId) => intentar(async () => {
  await post(`/reportes/${encodeURIComponent(reporteId)}/reunido`, {});
  return { ok: true };
});

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

/** Refugios con sus mascotas disponibles en UNA petición: [{ ...refugio, mascotas: [...] }] */
export async function obtenerRefugiosConMascotas() {
  return (await get("/refugios?mascotas=1")).refugios;
}

/**
 * Mascotas disponibles de un refugio. Los filtros (HU-3) los aplica la API:
 * { q?: nombre o raza, especie?: perro|gato, tamano?: pequeño|mediano|grande, edad?: cachorro|joven|adulto|senior }
 */
export async function obtenerMascotasDisponibles(refugioId, filtros = {}) {
  const consulta = new URLSearchParams(Object.entries(filtros).filter(([, valor]) => valor)).toString();
  return (await get(`/refugios/${encodeURIComponent(refugioId)}/mascotas${consulta ? `?${consulta}` : ""}`)).mascotas;
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

/** HU-23: guía de cuidado de una adopción aprobada → { ok, guia: { titulo, etapa, secciones, consejos|null } } */
export const obtenerGuiaCuidados = (solicitudId) => intentar(async () =>
  ({ ok: true, guia: (await get(`/adopciones/${encodeURIComponent(solicitudId)}/cuidados`)).guia }));

/** HU-23: consejos con IA para esa mascota (la API los guarda) → { ok, consejos: [...]|null } */
export const personalizarGuiaCuidados = (solicitudId) => intentar(async () =>
  ({ ok: true, consejos: (await post(`/adopciones/${encodeURIComponent(solicitudId)}/cuidados`, {})).consejos }));

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
/**
 * Si la API cree que esa mascota ya fue reportada responde { ok:false, codigo:"posible-duplicado",
 * datos:{ foto, duplicados } }; para publicar de todos modos se reenvía con confirmarDuplicado y esa foto.
 */
export const crearReporte = ({ confirmarDuplicado = false, ...datos }) => intentar(async () => {
  // datos: { tipo, descripcion, zona, foto, especie?, nombre?, color?, tamano?, collar?, fecha?, situacion? }
  // La API publica la alerta al instante; la IA revisa la foto después (en segundo plano)
  const r = await post("/reportes", { ...datos, ...(confirmarDuplicado ? { confirmarDuplicado: true } : {}) });
  return { ok: true, reporte: r.reporte, coincidenciasNuevas: r.coincidenciasNuevas, analisisIA: r.analisisIA || null, iaUsada: Boolean(r.iaUsada), iaPendiente: Boolean(r.iaPendiente) };
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

/** Quien encontró la mascota describe la seña secreta que pidió el dueño (después ve su contacto). */
export const responderSena = (id, respuesta) => intentar(async () => {
  await post(`/coincidencias/${id}/sena`, { respuesta });
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
