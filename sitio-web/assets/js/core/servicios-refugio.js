/**
 * servicios-refugio.js — Datos del panel de refugio (inventario, publicaciones, perfil, resumen).
 * El servidor sabe de qué refugio se trata por la sesión: aquí nunca se envía un id de refugio.
 */
import { get, post, put, patch, del, descargar, intentar } from "./api.js";

/* ---------- Resumen ---------- */
export const obtenerResumen = () => get("/refugio/resumen");

/* ---------- Inventario (CRUD) ---------- */

export async function listarMascotas() {
  return (await get("/refugio/mascotas")).mascotas;
}

/**
 * Crea (sin `id`) o edita (con `id`) una mascota.
 * @param {object} datos  nombre, especie, raza, edadMeses, sexo, tamano, salud, descripcion, foto, estatus
 */
export const guardarMascota = (datos, id = null) => intentar(async () => {
  const r = id ? await put(`/refugio/mascotas/${id}`, datos) : await post("/refugio/mascotas", datos);
  return { ok: true, mascota: r.mascota };
});

export const cambiarEstatus = (id, estatus) => intentar(async () => {
  const r = await patch(`/refugio/mascotas/${id}/estatus`, { estatus });
  return { ok: true, mascota: r.mascota };
});

/** Cantidad de publicaciones que se borrarían junto con la mascota. */
export async function contarPublicacionesDeMascota(id) {
  return (await get(`/refugio/mascotas/${id}/publicaciones/conteo`)).total;
}

/** Elimina la mascota y también las publicaciones que la mostraban. */
export const eliminarMascota = (id) => intentar(async () => {
  const r = await del(`/refugio/mascotas/${id}`);
  return { ok: true, publicacionesEliminadas: r.publicacionesEliminadas };
});

/* ---------- Documentos de una mascota (vacunas, esterilización, pedigree...) ---------- */

export async function listarDocumentosMascota(mascotaId) {
  return (await get(`/refugio/mascotas/${mascotaId}/documentos`)).documentos;
}

/** @param {{tipo:string, nombre:string, dataUrl:string}} documento  PDF, JPG o PNG de máx. 5 MB */
export const subirDocumentoMascota = (mascotaId, documento) => intentar(async () => {
  const r = await post(`/refugio/mascotas/${mascotaId}/documentos`, documento);
  return { ok: true, documento: r.documento };
});

export const eliminarDocumentoMascota = (mascotaId, documentoId) => intentar(async () => {
  await del(`/refugio/mascotas/${mascotaId}/documentos/${documentoId}`);
  return { ok: true };
});

/** Contenido del documento como Blob (los documentos son privados: se descargan con la sesión). */
export const descargarDocumentoMascota = (mascotaId, documentoId) => descargar(`/refugio/mascotas/${mascotaId}/documentos/${documentoId}/archivo`);

/* ---------- Publicaciones ---------- */

/** Publicaciones del refugio con el nombre y estatus de la mascota asociada. */
export async function listarPublicaciones() {
  return (await get("/refugio/publicaciones")).publicaciones;
}

/**
 * @param {{mascotaId:string, texto:string, foto?:string, republicarCadaDias?:number|null}} datos
 *   Sin `foto` se usa la de la mascota. `republicarCadaDias` (1–90) activa la republicación automática.
 */
export const crearPublicacionRefugio = ({ mascotaId, texto, foto = "", republicarCadaDias = null }) => intentar(async () => {
  const r = await post("/refugio/publicaciones", { mascotaId, texto, foto, republicarCadaDias });
  return { ok: true, publicacion: r.publicacion };
});

/** Edita texto, foto (vacía = se conserva la actual) y republicación. La mascota no cambia. */
export const editarPublicacionRefugio = (id, { texto, foto = "", republicarCadaDias = null }) => intentar(async () => {
  const r = await put(`/refugio/publicaciones/${id}`, { texto, foto, republicarCadaDias });
  return { ok: true, publicacion: r.publicacion };
});

export const eliminarPublicacionRefugio = (id) => intentar(async () => {
  await del(`/refugio/publicaciones/${id}`);
  return { ok: true };
});

/* ---------- Preguntas frecuentes (las usa el asistente del formulario de adopción) ---------- */

export async function listarPreguntas() {
  return (await get("/refugio/preguntas")).preguntas;
}

/** Crea (sin `id`) o edita (con `id`). @param {{pregunta, respuesta, claves:string[], activa:boolean}} datos */
export const guardarPregunta = (datos, id = null) => intentar(async () => {
  const r = id ? await put(`/refugio/preguntas/${id}`, datos) : await post("/refugio/preguntas", datos);
  return { ok: true, pregunta: r.pregunta };
});

export const eliminarPregunta = (id) => intentar(async () => {
  await del(`/refugio/preguntas/${id}`);
  return { ok: true };
});

/* ---------- Solicitudes de adopción recibidas ---------- */

export async function listarSolicitudesAdopcion() {
  return (await get("/refugio/adopciones")).solicitudes;
}

/** @param {"pendiente"|"en revision"|"aprobada"|"rechazada"} estado  Rechazar exige `nota`. */
/** HU-17: borrador de descripción con IA a partir de los datos del formulario → { ok, descripcion, iaUsada } */
export const sugerirDescripcionMascota = (datos) => intentar(async () => {
  const r = await post("/refugio/mascotas/borrador", datos);
  return { ok: true, descripcion: r.descripcion, iaUsada: r.iaUsada };
});

/** HU-22: resumen con IA de una solicitud. Se guarda en la API; `regenerar` pide uno nuevo. */
export const resumirSolicitudAdopcion = (id, regenerar = false) => intentar(async () => {
  const r = await post(`/refugio/adopciones/${id}/resumen`, { regenerar });
  return { ok: true, resumen: r.resumen };
});

export const cambiarEstadoAdopcion =(id, estado, nota = "") => intentar(async () => {
  const r = await patch(`/refugio/adopciones/${id}`, { estado, nota });
  return { ok: true, solicitud: r.solicitud };
});

export const descargarDocumentoAdopcion = (solicitudId, documentoId) => descargar(`/refugio/adopciones/${solicitudId}/documentos/${documentoId}/archivo`);

/* ---------- Perfil ---------- */

/** Solo se pueden editar: telefono, direccion, horario y descripcion. */
export const actualizarPerfil = (cambios) => intentar(async () => {
  const r = await put("/refugio/perfil", cambios);
  return { ok: true, refugio: r.refugio };
});

/* ---------- HU-16 Requisitos de adopción ---------- */

export async function listarRequisitos() {
  return (await get("/refugio/requisitos")).requisitos;
}

/** Crea (sin `id`) o edita (con `id`). @param {{texto, detalle, obligatorio:boolean}} datos */
export const guardarRequisito = (datos, id = null) => intentar(async () => {
  const r = id ? await put(`/refugio/requisitos/${id}`, datos) : await post("/refugio/requisitos", datos);
  return { ok: true, requisito: r.requisito };
});

export const eliminarRequisito = (id) => intentar(async () => {
  await del(`/refugio/requisitos/${id}`);
  return { ok: true };
});

/* ---------- HU-13 Mensajes de los usuarios ---------- */

export async function listarMensajes() {
  return (await get("/refugio/mensajes")).mensajes;
}

/** Sin respuesta = marcar como leído; con respuesta = responder. */
export const responderMensaje = (id, respuesta = null) => intentar(async () => {
  const r = await patch(`/refugio/mensajes/${id}`, respuesta === null ? {} : { respuesta });
  return { ok: true, mensaje: r.mensaje };
});
