/**
 * moderacion.js — HU-18: bandeja de moderación del administrador. Lista las publicaciones y los
 * comentarios del foro que se marcaron automáticamente (por palabras o con IA) para aprobarlos
 * (vuelven a verse) o quitarlos (se ocultan y se avisa a su autor). Todo el texto entra con textContent.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar, refrescarInsigniaModeracion } from "../../components/navbar.js";
import { listarModeracion, decidirModeracion } from "../../core/servicios-admin.js";
import { crearElemento, formatearFecha, mostrarAlerta, ocultarAlerta, resolverImagen } from "../../core/utils.js";

const FUENTES = { palabras: "Detectado por palabras", ia: "Detectado con IA", admin: "Decisión del administrador" };
const VACIO = { revision: "No hay nada pendiente de revisar.", quitado: "Todavía no se ha quitado nada." };

const sesion = requerirRol("admin");
const lista = document.getElementById("lista-moderacion");
const vacio = document.getElementById("sin-elementos");
const alerta = document.getElementById("alerta");
const anuncio = document.getElementById("anuncio");
let estado = "revision";
let elementos = [];

if (sesion) {
  montarNavbar({ sesion, activa: "moderacion" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  ocultarAlerta(alerta);
  try {
    elementos = await listarModeracion(estado);
  } catch (error) {
    mostrarAlerta(alerta, "error", error.message || "No pudimos cargar la bandeja.");
    return;
  }
  document.getElementById("sin-elementos-texto").textContent = VACIO[estado];
  vacio.hidden = elementos.length > 0;
  lista.replaceChildren(...elementos.map(crearItem));
}

function crearItem(e) {
  const acciones = estado === "revision"
    ? [
      crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: "Aprobar", atributos: { type: "button", "data-accion": "aprobar", "aria-label": `Aprobar ${e.tipo} de ${e.autor}` } }),
      crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Quitar", atributos: { type: "button", "data-accion": "quitar", "aria-label": `Quitar ${e.tipo} de ${e.autor}` } }),
    ]
    : [crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Restaurar", atributos: { type: "button", "data-accion": "aprobar", "aria-label": `Restaurar ${e.tipo} de ${e.autor}` } })];

  return crearElemento("li", {}, crearElemento("article", { clase: "moderacion__item tarjeta tarjeta--blanca", atributos: { "data-tipo": e.tipo, "data-id": e.id } }, [
    crearElemento("div", { clase: "moderacion__cabecera" }, [
      crearElemento("span", { clase: "insignia insignia--pendiente", texto: e.tipo === "publicacion" ? "Publicación" : "Comentario" }),
      crearElemento("strong", { texto: e.autor }),
      crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${e.autorCorreo} · ${formatearFecha(e.fecha)}` }),
    ]),
    crearElemento("p", { clase: "moderacion__motivo", texto: `⚠️ ${e.motivo || "Marcado para revisión"} · ${FUENTES[e.fuente] || ""}` }),
    ...(e.enPublicacion ? [crearElemento("p", { clase: "texto-suave texto-pequeno", texto: `En la publicación: «${e.enPublicacion}…»` })] : []),
    crearElemento("blockquote", { clase: "moderacion__texto", texto: e.texto }),
    ...(e.foto ? [crearElemento("img", { clase: "moderacion__foto", atributos: { src: resolverImagen(e.foto), alt: "Foto de la publicación", loading: "lazy" } })] : []),
    crearElemento("div", { clase: "moderacion__acciones" }, acciones),
  ]));
}

function enlazarEventos() {
  document.querySelector(".moderacion__pestanas").addEventListener("click", (e) => {
    const boton = e.target.closest("[data-estado]");
    if (!boton || boton.dataset.estado === estado) return;
    estado = boton.dataset.estado;
    document.querySelectorAll("[data-estado]").forEach((b) => {
      const activo = b.dataset.estado === estado;
      b.setAttribute("aria-selected", String(activo));
      b.className = `boton ${activo ? "boton--primario" : "boton--contorno"} boton--pequeno`;
    });
    cargar();
  });

  lista.addEventListener("click", async (e) => {
    const boton = e.target.closest("[data-accion]");
    if (!boton) return;
    const item = boton.closest("[data-id]");
    const { tipo, id } = item.dataset;
    item.querySelectorAll("button").forEach((b) => { b.disabled = true; });
    const r = await decidirModeracion(tipo, id, boton.dataset.accion);
    if (!r.ok) {
      item.querySelectorAll("button").forEach((b) => { b.disabled = false; });
      mostrarAlerta(alerta, "error", r.error);
      return;
    }
    anuncio.textContent = boton.dataset.accion === "aprobar" ? "Listo: vuelve a verse en el foro." : "Listo: se quitó del foro y se avisó a su autor.";
    item.closest("li").remove();
    vacio.hidden = lista.children.length > 0;
    refrescarInsigniaModeracion();
  });
}
