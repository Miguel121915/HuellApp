/**
 * mascotas-refugio.js (administrador) — Inventario completo de un refugio y los documentos
 * especiales de cada mascota (vacunas, esterilización, pedigree...), con checklist y visor.
 * Los documentos los sube el refugio desde su inventario; aquí el administrador los revisa.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearVisor } from "../../components/visor-documento.js";
import { listarMascotasRefugio, obtenerMascotaAdmin, marcarDocumentoMascota, descargarDocumentoMascota } from "../../core/servicios-admin.js";
import {
  crearElemento, debounce, ESTADOS_REFUGIO, ESTATUS_MASCOTA, ETIQUETAS_DOCUMENTO_MASCOTA, formatearEdad, formatearFecha,
  formatearTamano, mostrarAlerta, ocultarAlerta, normalizarTexto, resolverImagen,
} from "../../core/utils.js";

const sesion = requerirRol("admin");

const alerta = document.getElementById("alerta");
const lista = document.getElementById("lista-mascotas");
const conteo = document.getElementById("conteo");
const sinResultados = document.getElementById("sin-resultados");
const sinMascotas = document.getElementById("sin-mascotas");
const entradaTexto = document.getElementById("filtro-texto");
const filtroEspecie = document.getElementById("filtro-especie");
const filtroEstatus = document.getElementById("filtro-estatus");
const filtroDocumentos = document.getElementById("filtro-documentos");
const detalle = document.getElementById("detalle");
const listaDocumentos = document.getElementById("lista-documentos");
const sinDocumentos = document.getElementById("sin-documentos");
const progreso = document.getElementById("progreso");
const visor = crearVisor({
  area: document.getElementById("visor"),
  titulo: document.getElementById("visor-titulo"),
  abrir: document.getElementById("visor-abrir"),
});

const parametros = new URLSearchParams(window.location.search);
const refugioId = parametros.get("id");
let mascotas = [];
let seleccion = null; // { mascota, documentos }

if (sesion) {
  montarNavbar({ sesion, activa: "refugios" });
  iniciar();
}

async function iniciar() {
  const datos = refugioId ? await listarMascotasRefugio(refugioId) : null;
  if (!datos) {
    document.getElementById("cabecera").hidden = true;
    document.getElementById("contenido-mascotas").hidden = true;
    mostrarAlerta(alerta, "aviso", "Ese refugio no existe. Vuelve a la lista de refugios para elegir otro.");
    return;
  }
  const { refugio } = datos;
  mascotas = datos.mascotas;
  document.title = `Mascotas de ${refugio.nombre} · HuellApp`;
  document.getElementById("refugio-nombre").textContent = `Mascotas de ${refugio.nombre}`;
  const estado = ESTADOS_REFUGIO[refugio.estado];
  const insignia = document.getElementById("estado-insignia");
  insignia.textContent = estado.etiqueta;
  insignia.className = `insignia insignia--${estado.clase}`;
  document.getElementById("ver-solicitud").href = `detalle-solicitud.html?id=${encodeURIComponent(refugio.id)}`;

  enlazarEventos();
  aplicarFiltros();
  const inicial = parametros.get("mascota");
  if (inicial && mascotas.some((m) => m.id === inicial)) seleccionar(inicial, { desplazar: false });
}

/* ---------- Lista de mascotas ---------- */

function textoDocumentos({ total, verificados }) {
  if (total === 0) return "Sin documentos";
  return `${verificados}/${total} ${total === 1 ? "documento revisado" : "documentos revisados"}`;
}

function aplicarFiltros() {
  const texto = normalizarTexto(entradaTexto.value);
  const docs = filtroDocumentos.value;
  const visibles = mascotas.filter((m) =>
    (!texto || normalizarTexto(`${m.nombre} ${m.raza}`).includes(texto)) &&
    (!filtroEspecie.value || m.especie === filtroEspecie.value) &&
    (!filtroEstatus.value || m.estatus === filtroEstatus.value) &&
    (!docs || (docs === "sin" ? m.documentos.total === 0
      : docs === "con" ? m.documentos.total > 0
        : m.documentos.verificados < m.documentos.total)));

  sinMascotas.hidden = mascotas.length > 0;
  sinResultados.hidden = mascotas.length === 0 || visibles.length > 0;
  conteo.textContent = mascotas.length === 0 ? "" : `${visibles.length} de ${mascotas.length} ${mascotas.length === 1 ? "mascota" : "mascotas"}`;
  const fragmento = document.createDocumentFragment();
  visibles.forEach((m) => fragmento.append(crearItem(m)));
  lista.replaceChildren(fragmento);
}

function crearItem(m) {
  const estatus = ESTATUS_MASCOTA[m.estatus];
  const pendientes = m.documentos.total - m.documentos.verificados;
  const activa = seleccion?.mascota.id === m.id;
  return crearElemento("li", {}, crearElemento("button", {
    clase: `mascota-admin${activa ? " mascota-admin--activa" : ""}`,
    atributos: { type: "button", "data-id": m.id, "aria-pressed": String(activa), "aria-label": `${m.nombre}: ${estatus.etiqueta}, ${textoDocumentos(m.documentos)}` },
  }, [
    crearElemento("img", { clase: "tabla__foto", atributos: { src: resolverImagen(m.foto), alt: "", width: 56, height: 56, loading: "lazy" } }),
    crearElemento("span", { clase: "mascota-admin__info" }, [
      crearElemento("strong", { texto: m.nombre }),
      crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${m.especie === "perro" ? "Perro" : "Gato"} · ${m.raza}` }),
      crearElemento("span", { clase: `insignia insignia--${estatus.clase}`, texto: estatus.etiqueta }),
    ]),
    crearElemento("span", {
      clase: `mascota-admin__docs${pendientes > 0 ? " mascota-admin__docs--pendiente" : ""}`,
      texto: textoDocumentos(m.documentos),
    }),
  ]));
}

/* ---------- Detalle: documentos de la mascota ---------- */

async function seleccionar(id, { desplazar = true } = {}) {
  ocultarAlerta(alerta);
  const datos = await obtenerMascotaAdmin(id);
  seleccion = datos;
  const url = new URL(window.location.href);
  url.searchParams.set("mascota", id);
  history.replaceState(null, "", url);

  const m = datos.mascota;
  const estatus = ESTATUS_MASCOTA[m.estatus];
  const foto = document.getElementById("detalle-foto");
  foto.src = resolverImagen(m.foto);
  foto.alt = `Foto de ${m.nombre}`;
  document.getElementById("detalle-nombre").textContent = m.nombre;
  document.getElementById("detalle-resumen").textContent =
    `${m.especie === "perro" ? "Perro" : "Gato"} · ${m.raza} · ${formatearEdad(m.edadMeses)} · ${m.sexo} · tamaño ${m.tamano}`;
  document.getElementById("detalle-salud").textContent = `Salud declarada por el refugio: ${m.salud}`;
  const insignia = document.getElementById("detalle-estatus");
  insignia.textContent = estatus.etiqueta;
  insignia.className = `insignia insignia--${estatus.clase}`;

  visor.reiniciar();
  renderDocumentos();
  detalle.hidden = false;
  lista.querySelectorAll(".mascota-admin").forEach((b) => {
    const activa = b.dataset.id === id;
    b.classList.toggle("mascota-admin--activa", activa);
    b.setAttribute("aria-pressed", String(activa));
  });
  if (desplazar) detalle.scrollIntoView({ behavior: "smooth", block: "start" });
}

function renderDocumentos() {
  const { documentos } = seleccion;
  sinDocumentos.hidden = documentos.length > 0;
  const fragmento = document.createDocumentFragment();
  documentos.forEach((d) => {
    const etiqueta = ETIQUETAS_DOCUMENTO_MASCOTA[d.tipo] || d.tipo;
    fragmento.append(crearElemento("li", { clase: "documento-item", atributos: { "data-id": d.id } }, [
      crearElemento("label", { clase: "documento-item__check" }, [
        crearElemento("input", { atributos: { type: "checkbox", checked: d.verificado, "data-doc": d.id, "aria-label": `${etiqueta}: marcar como revisado` } }),
        crearElemento("span", { texto: "Revisado" }),
      ]),
      crearElemento("div", { clase: "documento-item__info" }, [
        crearElemento("strong", { texto: etiqueta }),
        crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${d.nombre} · ${formatearTamano(d.tamano)} · subido el ${formatearFecha(d.fecha)}` }),
      ]),
      crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Ver", atributos: { type: "button", "data-ver": d.id, "aria-label": `Ver ${etiqueta}` } }),
    ]));
  });
  listaDocumentos.replaceChildren(fragmento);
  actualizarProgreso();
}

function actualizarProgreso() {
  const { documentos, mascota } = seleccion;
  const revisados = documentos.filter((d) => d.verificado).length;
  progreso.textContent = documentos.length ? `${revisados} de ${documentos.length} documentos revisados` : "";
  // Mantiene al día el contador de la lista sin volver a pedirla al servidor
  const enLista = mascotas.find((m) => m.id === mascota.id);
  if (enLista) {
    enLista.documentos = { total: documentos.length, verificados: revisados };
    const boton = lista.querySelector(`.mascota-admin[data-id="${CSS.escape(mascota.id)}"]`);
    if (boton) boton.closest("li").replaceWith(crearItem(enLista));
  }
}

/* ---------- Eventos ---------- */

function enlazarEventos() {
  const filtrar = debounce(aplicarFiltros, 250);
  entradaTexto.addEventListener("input", filtrar);
  [filtroEspecie, filtroEstatus, filtroDocumentos].forEach((s) => s.addEventListener("change", aplicarFiltros));
  document.querySelector(".herramientas").addEventListener("submit", (e) => e.preventDefault());

  lista.addEventListener("click", (evento) => {
    const boton = evento.target.closest(".mascota-admin");
    if (boton) seleccionar(boton.dataset.id);
  });

  listaDocumentos.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-ver]");
    if (!boton) return;
    const documento = seleccion.documentos.find((d) => d.id === boton.dataset.ver);
    listaDocumentos.querySelectorAll(".documento-item").forEach((li) => li.classList.toggle("documento-item--activo", li.dataset.id === documento.id));
    visor.mostrar(() => descargarDocumentoMascota(documento.id), `${ETIQUETAS_DOCUMENTO_MASCOTA[documento.tipo] || documento.tipo} — ${documento.nombre}`);
  });

  listaDocumentos.addEventListener("change", async (evento) => {
    const casilla = evento.target.closest("[data-doc]");
    if (!casilla) return;
    ocultarAlerta(alerta);
    const documento = seleccion.documentos.find((d) => d.id === casilla.dataset.doc);
    const resultado = await marcarDocumentoMascota(documento.id, casilla.checked);
    if (resultado.ok) {
      documento.verificado = resultado.documento.verificado;
    } else {
      casilla.checked = documento.verificado; // se revierte si no se pudo guardar
      mostrarAlerta(alerta, "error", resultado.error);
    }
    actualizarProgreso();
  });
}
