/**
 * refugios.js — Listado de refugios verificados y, al entrar a uno (?id=ref-1),
 * sus mascotas disponibles con filtros (nombre, especie, edad, tamaño) y paginación por lotes.
 * También: favoritos (HU-12), escribirle al refugio (HU-13) y sus requisitos de adopción (HU-16).
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearTarjetaMascota, marcarFavorito } from "../../components/tarjeta-mascota.js";
import { crearTarjetaPublicacion } from "../../components/tarjeta-publicacion.js";
import {
  obtenerRefugiosVerificados, obtenerRefugioVerificado, obtenerMascotasDisponibles, obtenerPublicacionesRefugio,
  obtenerPreguntasRefugio, obtenerMisSolicitudesAdopcion, obtenerFavoritos, obtenerRefugiosConMascotas, establecerFavorito,
  obtenerRequisitosRefugio, enviarMensajeRefugio,
} from "../../core/servicios.js";
import { crearElemento, debounce, normalizarTexto, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";
import { montarFormularioAdopcion } from "./adopcion.js";
import { pedirCuenta } from "../../components/aviso-cuenta.js";
import { dibujarMapaRefugios, ubicarPersona, distanciaKm } from "../../components/mapa-refugios.js";

const LOTE = 6;

/* Rangos de edad en meses */
const RANGOS_EDAD = {
  cachorro: (m) => m < 12,
  joven: (m) => m >= 12 && m < 36,
  adulto: (m) => m >= 36 && m < 96,
  senior: (m) => m >= 96,
};

const vistaLista = document.getElementById("vista-lista");
const vistaDetalle = document.getElementById("vista-detalle");
const alerta = document.getElementById("alerta");
const listaRefugios = document.getElementById("lista-refugios");
const rejilla = document.getElementById("lista-mascotas");
const conteo = document.getElementById("conteo");
const vacio = document.getElementById("sin-resultados");
const botonMas = document.getElementById("boton-mas-mascotas");
const entradaTexto = document.getElementById("filtro-texto");
const filtroEspecie = document.getElementById("filtro-especie");
const filtroEdad = document.getElementById("filtro-edad");
const filtroTamano = document.getElementById("filtro-tamano");

let mascotasBase = [];   // mascotas del refugio abierto
let coincidentes = [];   // resultado de aplicar los filtros
let mostradas = 0;
let refugioActual = null;
const preguntasPorRefugio = new Map();  // caché de preguntas frecuentes (para el asistente)
const solicitudesPorMascota = new Map(); // mascotaId → estado de la solicitud abierta o aprobada del usuario
const favoritos = new Set();             // ids de mis mascotas favoritas
let requisitosActuales = [];             // requisitos de adopción del refugio abierto

const sesion = requerirRol("usuario", { permitirInvitado: true });
const esVisitante = sesion?.rol === "invitado";
let formularioAdopcion = null;
// El arranque está AL FINAL del archivo: enlazarEventos() usa constantes declaradas más abajo
// (formularioContacto, miUbicacion…) y usarlas antes de su declaración rompía la página.

/* ---------- Adopción ---------- */

/** Las rechazadas no cuentan: el usuario puede volver a intentarlo. */
async function cargarMisSolicitudes() {
  if (esVisitante) return; // un visitante no tiene solicitudes
  try {
    (await obtenerMisSolicitudesAdopcion())
      .filter((s) => s.estado !== "rechazada")
      .forEach((s) => { if (!solicitudesPorMascota.has(s.mascotaId)) solicitudesPorMascota.set(s.mascotaId, s.estado); });
  } catch { /* sin conexión: la franja de aviso ya lo explica; los botones siguen activos */ }
}

async function cargarFavoritos() {
  if (esVisitante) return;
  try { (await obtenerFavoritos()).forEach((m) => favoritos.add(m.id)); } catch { /* sin conexión */ }
}

async function alternarFavorito(boton) {
  if (esVisitante) { pedirCuenta("guardar mascotas en favoritos"); return; }
  const id = boton.dataset.favorito;
  const mascota = mascotasBase.find((m) => m.id === id);
  const activo = !favoritos.has(id);
  boton.disabled = true;
  const r = await establecerFavorito(id, activo);
  boton.disabled = false;
  if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
  if (activo) favoritos.add(id); else favoritos.delete(id);
  marcarFavorito(boton, activo, mascota?.nombre || "la mascota");
  document.getElementById("anuncio-favorito").textContent = activo
    ? `${mascota?.nombre || "La mascota"} se guardó en tus favoritos.`
    : `${mascota?.nombre || "La mascota"} se quitó de tus favoritos.`;
}

/* ---------- Contacto con el refugio (HU-13) ---------- */

const modalContacto = document.getElementById("modal-contacto");
const formularioContacto = document.getElementById("formulario-contacto");
const alertaContacto = document.getElementById("alerta-contacto");
let contactoMascota = null;

function abrirContacto(mascota = null) {
  if (esVisitante) { pedirCuenta("escribirle al refugio"); return; }
  if (!refugioActual) return;
  contactoMascota = mascota;
  formularioContacto.reset();
  ocultarAlerta(alertaContacto);
  document.getElementById("contacto-destino").textContent = mascota
    ? `Para ${refugioActual.nombre} · sobre ${mascota.nombre}`
    : `Para ${refugioActual.nombre}`;
  formularioContacto.elements.mensaje.placeholder = mascota
    ? `Ej. Hola, me interesa ${mascota.nombre}. ¿Cuándo puedo visitarlo y qué necesito llevar?`
    : "Ej. Hola, ¿qué días puedo visitar el refugio para conocer a las mascotas?";
  document.getElementById("contacto-contador").textContent = "0/1000";
  modalContacto.showModal();
  formularioContacto.elements.mensaje.focus();
}

async function enviarContacto(evento) {
  evento.preventDefault();
  ocultarAlerta(alertaContacto);
  const mensaje = formularioContacto.elements.mensaje.value.trim();
  const telefono = formularioContacto.elements.telefono.value.trim();
  if (mensaje.length < 10) { mostrarAlerta(alertaContacto, "error", "Escribe tu mensaje (al menos 10 caracteres)."); return; }
  if (telefono && !/^[\d\s+()-]{8,}$/.test(telefono)) { mostrarAlerta(alertaContacto, "error", "El teléfono debe tener al menos 8 dígitos."); return; }
  const boton = document.getElementById("enviar-contacto");
  boton.disabled = true;
  const r = await enviarMensajeRefugio({
    ...(contactoMascota ? { mascotaId: contactoMascota.id } : { refugioId: refugioActual.id }),
    mensaje, telefono,
  });
  boton.disabled = false;
  if (!r.ok) { mostrarAlerta(alertaContacto, "error", r.error); return; }
  modalContacto.close();
  mostrarAlerta(alerta, "exito", `Mensaje enviado a ${refugioActual.nombre}. Verás su respuesta en «Mensajes».`);
  alerta.scrollIntoView({ behavior: "smooth", block: "center" });
}

/* ---------- Requisitos de adopción (HU-16) ---------- */

/** Lista de requisitos (obligatorios y recomendables) para el perfil del refugio y el formulario. */
function crearListaRequisitos(requisitos) {
  if (!requisitos.length) {
    return [crearElemento("p", { clase: "texto-suave texto-pequeno", texto: "Este refugio aún no publica requisitos. Puedes escribirle para preguntar." })];
  }
  return [crearElemento("ul", { clase: "requisitos-lista" }, requisitos.map((q) => crearElemento("li", { clase: `requisito${q.obligatorio ? "" : " requisito--opcional"}` }, [
    crearElemento("span", { clase: "requisito__marca", texto: q.obligatorio ? "✓" : "○", atributos: { "aria-hidden": "true" } }),
    crearElemento("div", {}, [
      crearElemento("strong", { texto: q.texto }),
      crearElemento("span", { clase: "requisito__tipo", texto: q.obligatorio ? " · Obligatorio" : " · Recomendable" }),
      ...(q.detalle ? [crearElemento("p", { clase: "texto-pequeno", texto: q.detalle })] : []),
    ]),
  ])))];
}

async function mostrarRequisitos(refugioId) {
  try { requisitosActuales = await obtenerRequisitosRefugio(refugioId); } catch { requisitosActuales = []; }
  document.getElementById("lista-requisitos").replaceChildren(...crearListaRequisitos(requisitosActuales));
}

async function abrirAdopcion(mascotaId) {
  if (esVisitante) { pedirCuenta("solicitar una adopción"); return; }
  const mascota = mascotasBase.find((m) => m.id === mascotaId);
  if (!mascota || !refugioActual) return;
  if (!preguntasPorRefugio.has(refugioActual.id)) {
    let preguntas = [];
    try { preguntas = await obtenerPreguntasRefugio(refugioActual.id); } catch { /* el asistente usa las respuestas generales */ }
    preguntasPorRefugio.set(refugioActual.id, preguntas);
  }
  // Antes de llenar la solicitud, el usuario repasa los requisitos del refugio (HU-16)
  const cajaRequisitos = document.getElementById("adopcion-requisitos");
  cajaRequisitos.hidden = requisitosActuales.length === 0;
  document.getElementById("adopcion-lista-requisitos").replaceChildren(...crearListaRequisitos(requisitosActuales));
  formularioAdopcion.abrir(mascota, refugioActual, preguntasPorRefugio.get(refugioActual.id));
}

function solicitudEnviada(solicitud) {
  solicitudesPorMascota.set(solicitud.mascotaId, solicitud.estado);
  // Se redibuja solo la tarjeta de esa mascota: su botón pasa a "Solicitud enviada"
  const tarjeta = rejilla.querySelector(`.mascota[data-id="${CSS.escape(solicitud.mascotaId)}"]`);
  const mascota = mascotasBase.find((m) => m.id === solicitud.mascotaId);
  if (tarjeta && mascota) tarjeta.replaceWith(crearTarjeta(mascota));
  mostrarAlerta(alerta, "exito", `¡Listo! Enviamos tu solicitud para adoptar a ${solicitud.mascotaNombre}. ${refugioActual?.nombre || "El refugio"} revisará tus datos y te contactará.`);
  alerta.scrollIntoView({ behavior: "smooth", block: "center" });
}

const crearTarjeta = (m) => crearTarjetaMascota(m, {
  conAdopcion: true, estadoSolicitud: solicitudesPorMascota.get(m.id),
  conFavorito: true, esFavorito: favoritos.has(m.id), conContacto: true,
});

/* ---------- Navegación dentro de la página (sin recargar) ---------- */

function mostrarSegunUrl() {
  const id = new URLSearchParams(window.location.search).get("id");
  return id ? mostrarDetalle(id) : mostrarLista();
}

function irARefugio(id) {
  const url = id ? `?id=${encodeURIComponent(id)}` : window.location.pathname;
  history.pushState({}, "", url);
  mostrarSegunUrl();
  window.scrollTo({ top: 0 });
}

function enlazarEventos() {
  window.addEventListener("popstate", mostrarSegunUrl);

  listaRefugios.addEventListener("click", (evento) => {
    const enlace = evento.target.closest("[data-refugio]");
    if (!enlace) return;
    evento.preventDefault();
    irARefugio(enlace.dataset.refugio);
  });
  document.getElementById("volver").addEventListener("click", (evento) => { evento.preventDefault(); irARefugio(null); });
  document.getElementById("boton-cerca").addEventListener("click", buscarCercaDeMi);

  // Botón "Adoptar" de cada tarjeta (delegación: las tarjetas se crean y recrean por lotes)
  rejilla.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-adoptar]");
    if (boton) { abrirAdopcion(boton.dataset.adoptar); return; }
    const corazon = evento.target.closest("[data-favorito]");
    if (corazon) { alternarFavorito(corazon); return; }
    const contactar = evento.target.closest("[data-contactar]");
    if (contactar) abrirContacto(mascotasBase.find((m) => m.id === contactar.dataset.contactar) || null);
  });

  document.getElementById("boton-contactar").addEventListener("click", () => abrirContacto(null));
  formularioContacto.addEventListener("submit", enviarContacto);
  document.getElementById("cancelar-contacto").addEventListener("click", () => modalContacto.close());
  formularioContacto.elements.mensaje.addEventListener("input", () => {
    document.getElementById("contacto-contador").textContent = `${formularioContacto.elements.mensaje.value.length}/1000`;
  });

  // Filtros: el texto lleva debounce; los selects aplican de inmediato
  document.querySelector(".filtros").addEventListener("submit", (evento) => evento.preventDefault());
  entradaTexto.addEventListener("input", debounce(aplicarFiltros, 250));
  [filtroEspecie, filtroEdad, filtroTamano].forEach((s) => s.addEventListener("change", aplicarFiltros));
  document.getElementById("limpiar-filtros").addEventListener("click", () => {
    entradaTexto.value = ""; filtroEspecie.value = ""; filtroEdad.value = ""; filtroTamano.value = "";
    aplicarFiltros();
  });
  botonMas.addEventListener("click", mostrarMas);
}

/* ---------- Vista: lista de refugios ---------- */

async function mostrarLista() {
  ocultarAlerta(alerta);
  vistaDetalle.hidden = true;
  vistaLista.hidden = false;
  document.title = "Refugios · HuellApp";

  // Búsqueda desde Inicio (?q=texto): refugios cuyo nombre, dirección o municipio coincida,
  // o que tengan una mascota disponible con ese nombre o raza (todo llega en una sola petición)
  const qTexto = (new URLSearchParams(window.location.search).get("q") || "").trim();
  const q = normalizarTexto(qTexto);
  let refugios = q ? await obtenerRefugiosConMascotas() : await obtenerRefugiosVerificados();
  if (q) {
    refugios = refugios.filter((r) =>
      normalizarTexto(`${r.nombre} ${r.direccion} ${r.municipio || ""}`).includes(q)
      || (r.mascotas || []).some((m) => normalizarTexto(`${m.nombre} ${m.raza}`).includes(q)));
    mostrarAlerta(alerta, refugios.length ? "exito" : "aviso", refugios.length
      ? `Resultados para «${qTexto}»: ${refugios.length} refugio(s).`
      : `No encontramos refugios ni mascotas para «${qTexto}».`);
  }

  // «Cerca de mí»: distancia a cada refugio con ubicación y los más cercanos primero
  if (miUbicacion) {
    refugios = refugios
      .map((r) => ({ ...r, distanciaKm: r.latitud != null && r.longitud != null && r.latitud !== "" ? distanciaKm(miUbicacion, [Number(r.latitud), Number(r.longitud)]) : null }))
      .sort((a, b) => (a.distanciaKm ?? Infinity) - (b.distanciaKm ?? Infinity));
  }

  const fragmento = document.createDocumentFragment();
  refugios.forEach((r) => {
    fragmento.append(crearElemento("li", {}, crearElemento("a", {
      clase: "refugio-tarjeta",
      atributos: { href: `?id=${encodeURIComponent(r.id)}`, "data-refugio": r.id },
    }, [
      crearElemento("span", { clase: "refugio-tarjeta__nombre", texto: r.nombre }),
      crearElemento("span", { clase: "refugio-tarjeta__dato", texto: r.direccion }),
      crearElemento("span", { clase: "refugio-tarjeta__dato", texto: `Horario: ${r.horario}` }),
      r.distanciaKm != null ? crearElemento("span", { clase: "refugio-tarjeta__dato", texto: `📍 A ${r.distanciaKm.toFixed(1)} km` }) : null,
      crearElemento("span", { clase: "refugio-tarjeta__accion", texto: "Ver mascotas →" }),
    ].filter(Boolean))));
  });
  listaRefugios.replaceChildren(fragmento);

  // Mapa (HU-11)
  dibujarMapaRefugios(document.getElementById("mapa"), refugios, { alElegir: irARefugio, aviso: document.getElementById("mapa-aviso") });
}

let miUbicacion = null; // [lat, lon] después de «Cerca de mí»

async function buscarCercaDeMi() {
  const boton = document.getElementById("boton-cerca");
  const aviso = document.getElementById("mapa-aviso");
  boton.disabled = true;
  aviso.textContent = "Buscando tu ubicación…";
  try {
    miUbicacion = await ubicarPersona();
    await mostrarLista();
  } catch (error) {
    aviso.textContent = error.message;
  } finally {
    boton.disabled = false;
  }
}

/* ---------- Vista: detalle de un refugio ---------- */

async function mostrarDetalle(id) {
  ocultarAlerta(alerta);
  const refugio = await obtenerRefugioVerificado(id);

  if (!refugio) { // id inválido o refugio no verificado
    await mostrarLista();
    mostrarAlerta(alerta, "aviso", "Ese refugio no está disponible. Elige uno de la lista.");
    return;
  }

  refugioActual = refugio;
  vistaLista.hidden = true;
  vistaDetalle.hidden = false;
  document.title = `${refugio.nombre} · HuellApp`;
  document.getElementById("refugio-nombre").textContent = refugio.nombre;
  document.getElementById("refugio-direccion").textContent = refugio.direccion;
  document.getElementById("refugio-horario").textContent = refugio.horario;
  document.getElementById("refugio-responsable").textContent = refugio.responsable;
  const descripcion = document.getElementById("refugio-descripcion");
  descripcion.textContent = refugio.descripcion || "";
  descripcion.hidden = !refugio.descripcion;
  const tel = document.getElementById("refugio-telefono");
  tel.textContent = refugio.telefono;
  tel.href = `tel:${refugio.telefono.replace(/\D/g, "")}`;
  mostrarContactoExtra(refugio);

  mascotasBase = await obtenerMascotasDisponibles(refugio.id);
  entradaTexto.value = ""; filtroEspecie.value = ""; filtroEdad.value = ""; filtroTamano.value = "";
  aplicarFiltros();
  mostrarRequisitos(refugio.id);
  mostrarPublicaciones(refugio.id);
}

/** WhatsApp, redes, necesidades y "Cómo llegar" (datos que también captura la app móvil). */
function mostrarContactoExtra(refugio) {
  const ponerFila = (id, visible) => { document.getElementById(id).hidden = !visible; };

  const whatsapp = (refugio.whatsapp || "").replace(/\D/g, "");
  ponerFila("fila-whatsapp", !!whatsapp);
  if (whatsapp) {
    const enlace = document.getElementById("refugio-whatsapp");
    enlace.textContent = refugio.whatsapp;
    enlace.href = `https://wa.me/${whatsapp.length === 10 ? "52" + whatsapp : whatsapp}`;
  }

  const redes = refugio.redes || [];
  ponerFila("fila-redes", redes.length > 0);
  document.getElementById("refugio-redes").textContent = redes.join(" · ");

  const necesidades = refugio.necesidades || [];
  ponerFila("fila-necesidades", necesidades.length > 0);
  document.getElementById("refugio-necesidades").textContent = necesidades.join(", ");

  const hayUbicacion = refugio.latitud !== null && refugio.latitud !== undefined && refugio.longitud !== null && refugio.longitud !== undefined;
  const llegar = document.getElementById("refugio-como-llegar");
  llegar.hidden = !hayUbicacion;
  if (hayUbicacion) llegar.href = `https://www.google.com/maps/dir/?api=1&destination=${refugio.latitud},${refugio.longitud}`;
}

let consultaFiltros = 0; // descarta respuestas viejas si la persona cambia los filtros rápido

/** Filtros del catálogo (HU-3): se envían a la API; si la API falla, se filtra aquí con lo ya cargado. */
async function aplicarFiltros() {
  const filtros = { q: entradaTexto.value.trim(), especie: filtroEspecie.value, edad: filtroEdad.value, tamano: filtroTamano.value };
  const hayFiltros = Object.values(filtros).some(Boolean);
  const consulta = ++consultaFiltros;
  const refugioId = refugioActual?.id;

  let resultado;
  if (!hayFiltros || !refugioId) {
    resultado = mascotasBase;
  } else {
    try {
      resultado = await obtenerMascotasDisponibles(refugioId, filtros);
    } catch {
      resultado = filtrarLocal(filtros);
    }
  }
  if (consulta !== consultaFiltros) return; // llegó otra búsqueda más nueva

  coincidentes = resultado;
  rejilla.replaceChildren();
  mostradas = 0;
  mostrarMas();
}

function filtrarLocal({ q, especie, edad, tamano }) {
  const texto = normalizarTexto(q);
  return mascotasBase.filter((m) =>
    (!texto || normalizarTexto(`${m.nombre} ${m.raza}`).includes(texto)) &&
    (!especie || m.especie === especie) &&
    (!edad || RANGOS_EDAD[edad](m.edadMeses)) &&
    (!tamano || m.tamano === tamano));
}

/** Añade el siguiente lote de tarjetas (DocumentFragment: un solo reflow). */
function mostrarMas() {
  const lote = coincidentes.slice(mostradas, mostradas + LOTE);
  const fragmento = document.createDocumentFragment();
  lote.forEach((m) => fragmento.append(crearTarjeta(m)));
  rejilla.append(fragmento);
  mostradas += lote.length;

  const total = coincidentes.length;
  conteo.textContent = total === 1 ? "1 mascota disponible" : `${total} mascotas disponibles`;
  vacio.hidden = total > 0;
  botonMas.hidden = mostradas >= total;
}

async function mostrarPublicaciones(refugioId) {
  const seccion = document.getElementById("publicaciones-refugio");
  const lista = document.getElementById("lista-publicaciones");
  const publicaciones = await obtenerPublicacionesRefugio(refugioId);
  seccion.hidden = publicaciones.length === 0;
  const fragmento = document.createDocumentFragment();
  publicaciones.forEach((p) => fragmento.append(crearTarjetaPublicacion({ ...p, likes: 0, comentarios: [] }, { conLikes: false, conComentarios: false })));
  lista.replaceChildren(fragmento);
}

/* ---------- Arranque ---------- */
if (sesion) {
  montarNavbar({ sesion, activa: "refugios" });
  formularioAdopcion = montarFormularioAdopcion({ sesion, alEnviar: solicitudEnviada });
  enlazarEventos();
  Promise.all([cargarMisSolicitudes(), cargarFavoritos()]).then(mostrarSegunUrl);
}
