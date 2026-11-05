/**
 * coincidencias.js — Posibles coincidencias entre reportes (simuladas) con porcentaje de
 * similitud. El usuario puede contactar a quien encontró la mascota o declinar la coincidencia.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar, refrescarInsigniaCoincidencias } from "../../components/navbar.js";
import { obtenerCoincidencias, descartarCoincidencia, restaurarCoincidencias, obtenerResumenCoincidencias } from "../../core/servicios.js";
import { crearElemento, resolverImagen, tiempoRelativo } from "../../core/utils.js";

const sesion = requerirRol("usuario");

const lista = document.getElementById("lista-coincidencias");
const vacio = document.getElementById("sin-coincidencias");
const resumen = document.getElementById("resumen");
const anuncio = document.getElementById("anuncio");
const botonRestaurar = document.getElementById("boton-restaurar");
const modal = document.getElementById("modal-contacto");

let coincidencias = [];
let descartadas = 0;

if (sesion) {
  montarNavbar({ sesion, activa: "coincidencias" });
  iniciar();
}

async function cargar() {
  [coincidencias, { descartadas }] = await Promise.all([obtenerCoincidencias(), obtenerResumenCoincidencias()]);
  render();
}

async function iniciar() {
  await cargar();

  // Delegación: un solo listener para todos los botones de las tarjetas
  lista.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton) return;
    const id = boton.closest(".coincidencia").dataset.id;
    if (boton.dataset.accion === "contactar") abrirContacto(id);
    if (boton.dataset.accion === "declinar") await declinar(id);
  });

  botonRestaurar.addEventListener("click", async () => {
    await restaurarCoincidencias();
    await cargar();
    refrescarInsigniaCoincidencias();
    anuncio.textContent = "Coincidencias restauradas.";
  });
  document.getElementById("cerrar-modal").addEventListener("click", () => modal.close());
}

function render() {
  const fragmento = document.createDocumentFragment();
  coincidencias.forEach((c) => fragmento.append(crearTarjeta(c)));
  lista.replaceChildren(fragmento);

  vacio.hidden = coincidencias.length > 0;
  resumen.textContent = coincidencias.length === 1 ? "1 posible coincidencia" : `${coincidencias.length} posibles coincidencias`;
  botonRestaurar.hidden = descartadas === 0;
  botonRestaurar.textContent = `Restaurar descartadas (${descartadas})`;
}

function crearTarjeta(c) {
  const { miReporte: mio, hallazgo } = c;
  const imagen = (src, alt) => crearElemento("img", { atributos: { src: resolverImagen(src), alt, width: 400, height: 300, loading: "lazy", decoding: "async" } });

  return crearElemento("article", { clase: "coincidencia", atributos: { "data-id": c.id } }, [
    crearElemento("p", { clase: "coincidencia__aviso", texto: "Se ha encontrado una coincidencia" }),
    crearElemento("div", { clase: "coincidencia__cuerpo" }, [
      // Lo que reportó el usuario
      crearElemento("section", { clase: "coincidencia__lado coincidencia__lado--mio" }, [
        crearElemento("h2", { clase: "coincidencia__subtitulo", texto: "Tu reporte" }),
        crearElemento("figure", { clase: "coincidencia__foto" }, imagen(mio.foto, mio.fotoAlt || "Tu mascota")),
        crearElemento("p", { clase: "coincidencia__texto", texto: mio.descripcion }),
        crearElemento("p", { clase: "texto-pequeno", texto: `Zona: ${mio.zona}` }),
      ]),
      // Lo que se encontró
      crearElemento("section", { clase: "coincidencia__lado coincidencia__lado--hallazgo" }, [
        crearElemento("div", { clase: "coincidencia__cabecera" }, [
          crearElemento("h2", { clase: "coincidencia__subtitulo", texto: "Posible coincidencia" }),
          crearElemento("span", { clase: "similitud", texto: `${c.similitud}% de similitud`, atributos: { "aria-label": `${c.similitud} por ciento de similitud` } }),
        ]),
        crearElemento("figure", { clase: "coincidencia__foto" }, imagen(hallazgo.foto, hallazgo.fotoAlt || "Mascota encontrada")),
        crearElemento("p", { clase: "coincidencia__texto", texto: hallazgo.descripcion }),
        crearElemento("p", { clase: "texto-pequeno", texto: `Zona: ${hallazgo.zona} · Reportado ${tiempoRelativo(c.fecha)}` }),
        crearElemento("div", { clase: "coincidencia__acciones" }, [
          crearElemento("button", { clase: "boton boton--primario", texto: "Contactar", atributos: { type: "button", "data-accion": "contactar" } }),
          crearElemento("button", { clase: "boton boton--peligro", texto: "Declinar", atributos: { type: "button", "data-accion": "declinar" } }),
        ]),
      ]),
    ]),
  ]);
}

function abrirContacto(id) {
  const c = coincidencias.find((x) => x.id === id);
  if (!c) return;
  const { contacto } = c.hallazgo;
  document.getElementById("contacto-nombre").textContent = contacto.nombre;
  const tel = document.getElementById("contacto-telefono");
  tel.textContent = contacto.telefono;
  tel.href = `tel:${contacto.telefono.replace(/\D/g, "")}`;
  const correo = document.getElementById("contacto-correo");
  correo.textContent = contacto.correo;
  correo.href = `mailto:${contacto.correo}`;
  modal.showModal();
}

async function declinar(id) {
  const resultado = await descartarCoincidencia(id);
  if (!resultado.ok) { anuncio.textContent = resultado.error; return; }
  coincidencias = coincidencias.filter((c) => c.id !== id);
  descartadas += 1;
  render();
  refrescarInsigniaCoincidencias();
  anuncio.textContent = "Coincidencia declinada.";
}
