/**
 * refugios.js (administrador) — Todos los refugios con filtro por estado y búsqueda.
 * Desde aquí se puede suspender un refugio verificado o reactivar uno suspendido.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar, refrescarInsigniaSolicitudes } from "../../components/navbar.js";
import { listarRefugios, obtenerResumenAdmin, suspenderRefugio, reactivarRefugio } from "../../core/servicios-admin.js";
import { crearElemento, debounce, ESTADOS_REFUGIO, formatearFecha, mostrarAlerta, ocultarAlerta, normalizarTexto } from "../../core/utils.js";

const sesion = requerirRol("admin");

const cuerpo = document.getElementById("cuerpo-tabla");
const contenedorTabla = document.getElementById("contenedor-tabla");
const conteo = document.getElementById("conteo");
const anuncio = document.getElementById("anuncio");
const vacio = document.getElementById("sin-resultados");
const entradaTexto = document.getElementById("filtro-texto");
const filtroEstado = document.getElementById("filtro-estado");
const modal = document.getElementById("modal-accion");
const campoMotivo = document.getElementById("campo-motivo-suspension");
const alertaModal = document.getElementById("alerta-modal");

let refugios = [];
let accionPendiente = null; // { tipo: "suspender" | "reactivar", refugio }

if (sesion) {
  montarNavbar({ sesion, activa: "refugios" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  const [resumen, lista] = await Promise.all([obtenerResumenAdmin(), listarRefugios()]);
  refugios = lista;
  document.querySelectorAll("[data-resumen]").forEach((nodo) => { nodo.textContent = String(resumen[nodo.dataset.resumen]); });
  aplicarFiltros();
}

function aplicarFiltros() {
  const texto = normalizarTexto(entradaTexto.value);
  const visibles = refugios.filter((r) =>
    (!filtroEstado.value || r.estado === filtroEstado.value) &&
    (!texto || normalizarTexto(`${r.nombre} ${r.responsable} ${r.correo}`).includes(texto)));

  conteo.textContent = visibles.length === 1 ? "1 refugio" : `${visibles.length} refugios`;
  vacio.hidden = visibles.length > 0;
  contenedorTabla.hidden = visibles.length === 0;
  const fragmento = document.createDocumentFragment();
  visibles.forEach((r) => fragmento.append(crearFila(r)));
  cuerpo.replaceChildren(fragmento);
}

function crearFila(r) {
  const estado = ESTADOS_REFUGIO[r.estado];
  const acciones = [crearElemento("a", {
    clase: "boton boton--contorno boton--pequeno", texto: r.estado === "pendiente" ? "Revisar" : "Ver detalle",
    atributos: { href: `detalle-solicitud.html?id=${encodeURIComponent(r.id)}`, "aria-label": `Ver los datos y documentos de ${r.nombre}` },
  })];
  if (r.estado === "aprobado" || r.estado === "suspendido") {
    acciones.push(crearElemento("a", {
      clase: "boton boton--secundario boton--pequeno", texto: "Mascotas",
      atributos: { href: `mascotas-refugio.html?id=${encodeURIComponent(r.id)}`, "aria-label": `Ver las mascotas y documentos de ${r.nombre}` },
    }));
  }
  if (r.estado === "aprobado") {
    acciones.push(crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Suspender", atributos: { type: "button", "data-accion": "suspender", "aria-label": `Suspender a ${r.nombre}` } }));
  }
  if (r.estado === "suspendido") {
    acciones.push(crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: "Reactivar", atributos: { type: "button", "data-accion": "reactivar", "aria-label": `Reactivar a ${r.nombre}` } }));
  }
  return crearElemento("tr", { atributos: { "data-id": r.id } }, [
    crearElemento("th", { texto: r.nombre, atributos: { scope: "row" } }),
    crearElemento("td", { texto: r.responsable }),
    crearElemento("td", { texto: r.correo }),
    crearElemento("td", { texto: r.telefono }),
    crearElemento("td", { texto: formatearFecha(r.fechaSolicitud) }),
    crearElemento("td", {}, crearElemento("span", { clase: `insignia insignia--${estado.clase}`, texto: estado.etiqueta })),
    crearElemento("td", {}, crearElemento("div", { clase: "tabla__acciones" }, acciones)),
  ]);
}

/* ---------- Suspender / reactivar (con confirmación) ---------- */

function abrirConfirmacion(tipo, refugio) {
  accionPendiente = { tipo, refugio };
  const suspender = tipo === "suspender";
  ocultarAlerta(alertaModal);
  document.getElementById("modal-titulo").textContent = suspender ? "Suspender refugio" : "Reactivar refugio";
  document.getElementById("modal-texto").textContent = suspender
    ? `«${refugio.nombre}» dejará de ser visible para los usuarios y no podrá usar su panel hasta que lo reactives.`
    : `«${refugio.nombre}» volverá a ser visible para los usuarios y podrá usar su panel.`;
  campoMotivo.hidden = !suspender;
  document.getElementById("motivo-suspension").value = "";
  const confirmar = document.getElementById("confirmar-accion");
  confirmar.textContent = suspender ? "Sí, suspender" : "Sí, reactivar";
  confirmar.className = `boton ${suspender ? "boton--peligro" : "boton--primario"}`;
  modal.showModal();
}

async function confirmarAccion() {
  const { tipo, refugio } = accionPendiente;
  const resultado = tipo === "suspender"
    ? await suspenderRefugio(refugio.id, document.getElementById("motivo-suspension").value.trim())
    : await reactivarRefugio(refugio.id);
  if (!resultado.ok) { mostrarAlerta(alertaModal, "error", resultado.error); return; }
  modal.close();
  anuncio.textContent = tipo === "suspender" ? `«${refugio.nombre}» fue suspendido.` : `«${refugio.nombre}» fue reactivado.`;
  await cargar();
  refrescarInsigniaSolicitudes();
}

function enlazarEventos() {
  entradaTexto.addEventListener("input", debounce(aplicarFiltros, 250));
  filtroEstado.addEventListener("change", aplicarFiltros);
  document.querySelector(".herramientas").addEventListener("submit", (e) => e.preventDefault());

  // Delegación: un solo listener para todos los botones de la tabla
  cuerpo.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton) return;
    const refugio = refugios.find((r) => r.id === boton.closest("tr").dataset.id);
    if (refugio) abrirConfirmacion(boton.dataset.accion, refugio);
  });
  document.getElementById("cancelar-accion").addEventListener("click", () => modal.close());
  document.getElementById("confirmar-accion").addEventListener("click", confirmarAccion);
}
