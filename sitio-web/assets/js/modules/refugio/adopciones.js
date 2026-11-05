/**
 * adopciones.js — Solicitudes de adopción que recibe el refugio: lista con filtros, detalle con
 * datos del solicitante, visor de sus documentos (privados) y la respuesta del refugio.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearVisor } from "../../components/visor-documento.js";
import { listarSolicitudesAdopcion, cambiarEstadoAdopcion, descargarDocumentoAdopcion } from "../../core/servicios-refugio.js";
import {
  crearElemento, debounce, formatearFecha, formatearTamano, limpiarErroresAlEscribir, marcarError, mostrarAlerta, normalizarTexto,
  ocultarAlerta, resolverImagen, tiempoRelativo,
} from "../../core/utils.js";

/** Estado de una solicitud: etiqueta visible y variante de color de la insignia. */
const ESTADOS = {
  pendiente: { etiqueta: "Nueva", clase: "pendiente" },
  "en revision": { etiqueta: "En revisión", clase: "pendiente" },
  aprobada: { etiqueta: "Aprobada", clase: "aprobado" },
  rechazada: { etiqueta: "Rechazada", clase: "rechazado" },
};
const DOCUMENTOS = { identificacion: "Identificación oficial", domicilio: "Comprobante de domicilio", vivienda: "Foto del espacio", otro: "Otro documento" };
const VIVIENDA = { casa: "Casa", departamento: "Departamento", otro: "Otro" };
const PROPIEDAD = { propia: "propia", rentada: "rentada", familiar: "de un familiar" };

const sesion = requerirRol("refugio");

const lista = document.getElementById("lista-solicitudes");
const vacio = document.getElementById("sin-solicitudes");
const conteo = document.getElementById("conteo");
const anuncio = document.getElementById("anuncio");
const entradaTexto = document.getElementById("filtro-texto");
const filtroEstado = document.getElementById("filtro-estado");
const modal = document.getElementById("modal-solicitud");
const formulario = document.getElementById("formulario-estado");
const alerta = document.getElementById("alerta-estado");
const listaDocs = document.getElementById("sd-documentos");
const zonaVisor = document.getElementById("sd-visor-zona");
const visor = crearVisor({
  area: document.getElementById("sd-visor"),
  titulo: document.getElementById("sd-visor-titulo"),
  abrir: document.getElementById("sd-visor-abrir"),
});

let solicitudes = [];
let abierta = null;

if (sesion) {
  montarNavbar({ sesion, activa: "adopciones" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  solicitudes = await listarSolicitudesAdopcion();
  document.querySelectorAll("[data-resumen]").forEach((n) => {
    n.textContent = String(solicitudes.filter((s) => s.estado === n.dataset.resumen).length);
  });
  aplicarFiltros();
}

/* ---------- Lista ---------- */

function aplicarFiltros() {
  const texto = normalizarTexto(entradaTexto.value);
  const estado = filtroEstado.value;
  const visibles = solicitudes.filter((s) =>
    (!estado || (estado === "abiertas" ? ["pendiente", "en revision"].includes(s.estado) : s.estado === estado)) &&
    (!texto || normalizarTexto(`${s.mascotaNombre} ${s.nombre} ${s.correo}`).includes(texto)));
  // Por atender: las más antiguas primero; en lo demás, las más recientes
  if (estado === "abiertas") visibles.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

  conteo.textContent = visibles.length === 1 ? "1 solicitud" : `${visibles.length} solicitudes`;
  vacio.hidden = visibles.length > 0;
  lista.replaceChildren(...visibles.map(crearItem));
}

function crearItem(s) {
  const estado = ESTADOS[s.estado];
  const fotos = s.documentos.filter((d) => d.tipo === "vivienda").length;
  return crearElemento("li", {}, crearElemento("article", { clase: "solicitud-adopcion tarjeta tarjeta--blanca", atributos: { "data-id": s.id } }, [
    crearElemento("img", { clase: "tabla__foto", atributos: { src: resolverImagen(s.mascotaFoto), alt: "", width: 56, height: 56, loading: "lazy" } }),
    crearElemento("div", { clase: "solicitud-adopcion__info" }, [
      crearElemento("strong", { texto: `${s.nombre} quiere adoptar a ${s.mascotaNombre}` }),
      crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${formatearFecha(s.fecha)} (${tiempoRelativo(s.fecha)}) · ${s.documentos.length} documentos, ${fotos} ${fotos === 1 ? "foto" : "fotos"} del espacio` }),
    ]),
    crearElemento("span", { clase: `insignia insignia--${estado.clase}`, texto: estado.etiqueta }),
    crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: "Revisar", atributos: { type: "button", "data-revisar": s.id, "aria-label": `Revisar la solicitud de ${s.nombre} para ${s.mascotaNombre}` } }),
  ]));
}

/* ---------- Detalle ---------- */

const poner = (id, texto) => { document.getElementById(id).textContent = texto; };

function actualizarNotaObligatoria() {
  const obligatoria = formulario.elements.estado.value === "rechazada";
  poner("sd-nota-req", obligatoria ? "(obligatoria al rechazar)" : "(opcional)");
}

function abrir(id) {
  abierta = solicitudes.find((s) => s.id === id);
  if (!abierta) return;
  const s = abierta;
  const estado = ESTADOS[s.estado];
  const foto = document.getElementById("sd-foto");
  foto.src = resolverImagen(s.mascotaFoto);
  foto.alt = `Foto de ${s.mascotaNombre}`;
  poner("solicitud-titulo", `${s.nombre} → ${s.mascotaNombre}`);
  poner("sd-fecha", `Recibida el ${formatearFecha(s.fecha)}${s.actualizado !== s.fecha ? ` · última respuesta el ${formatearFecha(s.actualizado)}` : ""}`);
  const insignia = document.getElementById("sd-estado");
  insignia.textContent = estado.etiqueta;
  insignia.className = `insignia insignia--${estado.clase}`;

  poner("sd-nombre", s.nombre);
  const correo = document.getElementById("sd-correo");
  correo.textContent = s.correo;
  correo.href = `mailto:${s.correo}`;
  const tel = document.getElementById("sd-telefono");
  tel.textContent = s.telefono;
  tel.href = `tel:${s.telefono.replace(/\D/g, "")}`;
  poner("sd-ocupacion", s.ocupacion || "No indicó");
  poner("sd-direccion", s.direccion);
  poner("sd-vivienda", `${VIVIENDA[s.tipoVivienda]} ${PROPIEDAD[s.viviendaPropia]}`);
  poner("sd-otras", s.otrasMascotas || "Ninguna");
  poner("sd-motivo", s.motivo);

  listaDocs.replaceChildren(...s.documentos.map((d, i) => {
    const numero = d.tipo === "vivienda" ? ` ${s.documentos.slice(0, i + 1).filter((x) => x.tipo === "vivienda").length}` : "";
    return crearElemento("li", { clase: "doc-mascota", atributos: { "data-id": d.id } }, [
      crearElemento("div", { clase: "doc-mascota__info" }, [
        crearElemento("strong", { texto: `${DOCUMENTOS[d.tipo]}${numero}` }),
        crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${d.nombre} · ${formatearTamano(d.tamano)}` }),
      ]),
      crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Ver", atributos: { type: "button", "data-ver": d.id, "aria-label": `Ver ${DOCUMENTOS[d.tipo]}${numero}` } }),
    ]);
  }));
  zonaVisor.hidden = true;
  visor.reiniciar();

  formulario.reset();
  formulario.elements.estado.value = s.estado;
  formulario.elements.nota.value = s.notaRefugio;
  formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
  ocultarAlerta(alerta);
  actualizarNotaObligatoria();
  modal.showModal();
}

/* ---------- Eventos ---------- */

function enlazarEventos() {
  entradaTexto.addEventListener("input", debounce(aplicarFiltros, 250));
  filtroEstado.addEventListener("change", aplicarFiltros);
  document.querySelector(".herramientas").addEventListener("submit", (e) => e.preventDefault());
  lista.addEventListener("click", (e) => {
    const boton = e.target.closest("[data-revisar]");
    if (boton) abrir(boton.dataset.revisar);
  });

  listaDocs.addEventListener("click", (e) => {
    const boton = e.target.closest("[data-ver]");
    if (!boton) return;
    const d = abierta.documentos.find((x) => x.id === boton.dataset.ver);
    zonaVisor.hidden = false;
    listaDocs.querySelectorAll(".doc-mascota").forEach((li) => li.classList.toggle("doc-mascota--activo", li.dataset.id === d.id));
    visor.mostrar(() => descargarDocumentoAdopcion(abierta.id, d.id), `${DOCUMENTOS[d.tipo]} — ${d.nombre}`);
  });

  document.getElementById("cerrar-solicitud").addEventListener("click", () => modal.close());
  modal.addEventListener("close", () => visor.reiniciar());
  limpiarErroresAlEscribir(formulario);
  formulario.elements.estado.addEventListener("change", actualizarNotaObligatoria);

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const estado = formulario.elements.estado.value;
    const nota = formulario.elements.nota.value.trim();
    if (estado === "rechazada" && !nota) {
      marcarError(formulario.querySelector('[data-campo="nota"]'), "Explica brevemente el motivo: el solicitante lo verá.");
      formulario.elements.nota.focus();
      return;
    }
    const boton = document.getElementById("guardar-estado");
    boton.disabled = true;
    const r = await cambiarEstadoAdopcion(abierta.id, estado, nota);
    boton.disabled = false;
    if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
    modal.close();
    anuncio.textContent = `Solicitud de ${abierta.nombre}: ${ESTADOS[estado].etiqueta}.`;
    await cargar();
  });
}
