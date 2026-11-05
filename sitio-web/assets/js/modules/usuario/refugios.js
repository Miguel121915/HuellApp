/**
 * refugios.js — Listado de refugios verificados y, al entrar a uno (?id=ref-1),
 * sus mascotas disponibles con filtros (nombre, especie, edad, tamaño) y paginación por lotes.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearTarjetaMascota } from "../../components/tarjeta-mascota.js";
import { crearTarjetaPublicacion } from "../../components/tarjeta-publicacion.js";
import {
  obtenerRefugiosVerificados, obtenerRefugioVerificado, obtenerMascotasDisponibles, obtenerPublicacionesRefugio,
  obtenerPreguntasRefugio, obtenerMisSolicitudesAdopcion,
} from "../../core/servicios.js";
import { crearElemento, debounce, normalizarTexto, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";
import { montarFormularioAdopcion } from "./adopcion.js";

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

const sesion = requerirRol("usuario");
let formularioAdopcion = null;

if (sesion) {
  montarNavbar({ sesion, activa: "refugios" });
  formularioAdopcion = montarFormularioAdopcion({ sesion, alEnviar: solicitudEnviada });
  enlazarEventos();
  cargarMisSolicitudes().then(mostrarSegunUrl);
}

/* ---------- Adopción ---------- */

/** Las rechazadas no cuentan: el usuario puede volver a intentarlo. */
async function cargarMisSolicitudes() {
  try {
    (await obtenerMisSolicitudesAdopcion())
      .filter((s) => s.estado !== "rechazada")
      .forEach((s) => { if (!solicitudesPorMascota.has(s.mascotaId)) solicitudesPorMascota.set(s.mascotaId, s.estado); });
  } catch { /* sin conexión: la franja de aviso ya lo explica; los botones siguen activos */ }
}

async function abrirAdopcion(mascotaId) {
  const mascota = mascotasBase.find((m) => m.id === mascotaId);
  if (!mascota || !refugioActual) return;
  if (!preguntasPorRefugio.has(refugioActual.id)) {
    let preguntas = [];
    try { preguntas = await obtenerPreguntasRefugio(refugioActual.id); } catch { /* el asistente usa las respuestas generales */ }
    preguntasPorRefugio.set(refugioActual.id, preguntas);
  }
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

const crearTarjeta = (m) => crearTarjetaMascota(m, { conAdopcion: true, estadoSolicitud: solicitudesPorMascota.get(m.id) });

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

  // Botón "Adoptar" de cada tarjeta (delegación: las tarjetas se crean y recrean por lotes)
  rejilla.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-adoptar]");
    if (boton) abrirAdopcion(boton.dataset.adoptar);
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

  const refugios = await obtenerRefugiosVerificados();
  const fragmento = document.createDocumentFragment();
  refugios.forEach((r) => {
    fragmento.append(crearElemento("li", {}, crearElemento("a", {
      clase: "refugio-tarjeta",
      atributos: { href: `?id=${encodeURIComponent(r.id)}`, "data-refugio": r.id },
    }, [
      crearElemento("span", { clase: "refugio-tarjeta__nombre", texto: r.nombre }),
      crearElemento("span", { clase: "refugio-tarjeta__dato", texto: r.direccion }),
      crearElemento("span", { clase: "refugio-tarjeta__dato", texto: `Horario: ${r.horario}` }),
      crearElemento("span", { clase: "refugio-tarjeta__accion", texto: "Ver mascotas →" }),
    ])));
  });
  listaRefugios.replaceChildren(fragmento);
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

  mascotasBase = await obtenerMascotasDisponibles(refugio.id);
  entradaTexto.value = ""; filtroEspecie.value = ""; filtroEdad.value = ""; filtroTamano.value = "";
  aplicarFiltros();
  mostrarPublicaciones(refugio.id);
}

function aplicarFiltros() {
  const texto = normalizarTexto(entradaTexto.value);
  coincidentes = mascotasBase.filter((m) =>
    (!texto || normalizarTexto(`${m.nombre} ${m.raza}`).includes(texto)) &&
    (!filtroEspecie.value || m.especie === filtroEspecie.value) &&
    (!filtroEdad.value || RANGOS_EDAD[filtroEdad.value](m.edadMeses)) &&
    (!filtroTamano.value || m.tamano === filtroTamano.value));

  rejilla.replaceChildren();
  mostradas = 0;
  mostrarMas();
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
