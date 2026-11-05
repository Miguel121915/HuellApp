/**
 * publicaciones.js — El refugio publica mascotas del inventario en su página pública.
 * Formulario (mascota + texto + foto opcional + republicación automática) que también sirve para
 * editar, y lista de publicaciones con opción de editar o eliminar.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearTarjetaPublicacion } from "../../components/tarjeta-publicacion.js";
import { listarMascotas, listarPublicaciones, crearPublicacionRefugio, editarPublicacionRefugio, eliminarPublicacionRefugio } from "../../core/servicios-refugio.js";
import { crearElemento, formatearFecha, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta, redimensionarImagen, resolverImagen, validarImagen, ESTATUS_MASCOTA } from "../../core/utils.js";

const PERIODOS_FIJOS = ["7", "14", "30"]; // opciones del selector; cualquier otro número es "personalizada"

const sesion = requerirRol("refugio");

const formulario = document.getElementById("formulario-publicacion");
const tituloFormulario = document.getElementById("titulo-formulario");
const selector = document.getElementById("pub-mascota");
const entradaTexto = document.getElementById("pub-texto");
const entradaFoto = document.getElementById("pub-foto");
const contador = document.getElementById("pub-contador");
const vista = document.getElementById("pub-vista");
const vistaImg = vista.querySelector("img");
const botonUsarOriginal = document.getElementById("pub-foto-original");
const selectorRepublicar = document.getElementById("pub-republicar");
const zonaDias = document.getElementById("pub-dias-zona");
const entradaDias = document.getElementById("pub-dias");
const campoRepublicar = document.getElementById("campo-republicar");
const alerta = document.getElementById("alerta-publicacion");
const botonPublicar = document.getElementById("boton-publicar");
const botonCancelarEdicion = document.getElementById("cancelar-edicion");
const avisoSinMascotas = document.getElementById("sin-mascotas");
const lista = document.getElementById("lista-publicaciones");
const vacio = document.getElementById("sin-publicaciones");
const anuncio = document.getElementById("anuncio");
const modalBorrar = document.getElementById("modal-borrar");

let mascotas = [];
let publicaciones = [];
let fotoPersonalizada = ""; // data URL si el refugio sube otra foto distinta a la de la mascota
let editando = null;        // publicación que se está editando (null = creando una nueva)
let borrandoId = null;

if (sesion) {
  montarNavbar({ sesion, activa: "publicaciones" });
  iniciar();
}

async function iniciar() {
  // Solo se publican mascotas que siguen buscando hogar
  mascotas = (await listarMascotas()).filter((m) => m.estatus !== "adoptado");
  const opciones = mascotas.map((m) => crearElemento("option", { texto: `${m.nombre} · ${m.especie === "perro" ? "Perro" : "Gato"} · ${ESTATUS_MASCOTA[m.estatus].etiqueta}`, atributos: { value: m.id } }));
  selector.append(...opciones);

  if (mascotas.length === 0) {
    avisoSinMascotas.hidden = false;
    formulario.querySelectorAll("input, select, textarea, button").forEach((c) => { c.disabled = true; });
  }
  enlazarEventos();
  await renderLista();
}

/* ---------- Vista previa de la foto ---------- */

function actualizarVista() {
  const mascota = mascotas.find((m) => m.id === selector.value);
  const origen = fotoPersonalizada || editando?.foto || mascota?.foto || "";
  vista.hidden = !origen;
  if (origen) vistaImg.src = resolverImagen(origen);
  botonUsarOriginal.hidden = !fotoPersonalizada;
}

/* ---------- Republicación automática ---------- */

function mostrarPeriodicidad(dias) {
  const valor = dias ? String(dias) : "";
  const fijo = !valor || PERIODOS_FIJOS.includes(valor);
  selectorRepublicar.value = fijo ? valor : "personalizada";
  if (!fijo) entradaDias.value = valor;
  zonaDias.hidden = fijo;
}

/** Días elegidos (null = no republicar), o undefined si el número personalizado no es válido. */
function leerPeriodicidad() {
  if (!selectorRepublicar.value) return null;
  if (selectorRepublicar.value !== "personalizada") return Number(selectorRepublicar.value);
  const dias = Number(entradaDias.value);
  return Number.isInteger(dias) && dias >= 1 && dias <= 90 ? dias : undefined;
}

function textoPeriodicidad(dias) {
  if (dias === 7) return "cada semana";
  if (dias === 14) return "cada 2 semanas";
  if (dias === 30) return "cada mes";
  return dias === 1 ? "cada día" : `cada ${dias} días`;
}

/* ---------- Modo edición ---------- */

function salirDeEdicion() {
  editando = null;
  selector.querySelectorAll("[data-temporal]").forEach((o) => o.remove());
  formulario.reset();
  fotoPersonalizada = "";
  selector.disabled = mascotas.length === 0;
  mostrarPeriodicidad(null);
  contador.textContent = "0/500";
  tituloFormulario.textContent = "Nueva publicación";
  botonPublicar.textContent = "Publicar";
  botonCancelarEdicion.hidden = true;
  formulario.classList.remove("tarjeta--editando");
  formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
  actualizarVista();
}

function entrarEnEdicion(publicacion) {
  salirDeEdicion();
  editando = publicacion;
  ocultarAlerta(alerta);
  // La mascota no se puede cambiar; si ya no está en la lista (p. ej. adoptada) se agrega solo para mostrarla
  if (![...selector.options].some((o) => o.value === publicacion.mascotaId)) {
    selector.append(crearElemento("option", { texto: publicacion.mascotaNombre, atributos: { value: publicacion.mascotaId, "data-temporal": true } }));
  }
  selector.value = publicacion.mascotaId;
  selector.disabled = true;
  entradaTexto.value = publicacion.texto;
  contador.textContent = `${publicacion.texto.length}/500`;
  mostrarPeriodicidad(publicacion.republicarCadaDias);
  tituloFormulario.textContent = `Editar publicación de ${publicacion.mascotaNombre}`;
  botonPublicar.textContent = "Guardar cambios";
  botonCancelarEdicion.hidden = false;
  formulario.classList.add("tarjeta--editando");
  actualizarVista();
  formulario.scrollIntoView({ behavior: "smooth", block: "start" });
  entradaTexto.focus({ preventScroll: true });
}

/* ---------- Lista de publicaciones ---------- */

function crearInsigniaRepublicacion(p) {
  if (!p.republicarCadaDias) return [];
  if (p.mascotaEstatus === "adoptado") {
    return [crearElemento("span", { clase: "insignia insignia--adoptado", texto: "Republicación detenida (adoptada)" })];
  }
  const proxima = p.proximaRepublicacion ? ` · próxima: ${formatearFecha(p.proximaRepublicacion)}` : "";
  return [crearElemento("span", { clase: "insignia insignia--republica", texto: `Se republica ${textoPeriodicidad(p.republicarCadaDias)}${proxima}` })];
}

async function renderLista() {
  publicaciones = await listarPublicaciones();
  vacio.hidden = publicaciones.length > 0;
  const fragmento = document.createDocumentFragment();
  publicaciones.forEach((p) => {
    const estatus = ESTATUS_MASCOTA[p.mascotaEstatus];
    const tarjeta = crearTarjetaPublicacion({ ...p, likes: 0, comentarios: [], etiqueta: `Mascota: ${p.mascotaNombre}` }, { conLikes: false, conComentarios: false });
    fragmento.append(crearElemento("li", { clase: "publicacion-item", atributos: { "data-id": p.id } }, [
      tarjeta,
      crearElemento("div", { clase: "publicacion-item__acciones" }, [
        crearElemento("span", { clase: `insignia insignia--${estatus ? estatus.clase : "rechazado"}`, texto: estatus ? estatus.etiqueta : "Sin mascota" }),
        ...crearInsigniaRepublicacion(p),
        ...(p.republicadaVeces > 0 ? [crearElemento("span", { clase: "texto-pequeno texto-suave", texto: `Republicada ${p.republicadaVeces === 1 ? "1 vez" : `${p.republicadaVeces} veces`} · creada el ${formatearFecha(p.creadoEn)}` })] : []),
        ...(p.mascotaEstatus === "adoptado" ? [crearElemento("span", { clase: "texto-pequeno texto-suave", texto: "No se muestra a los usuarios porque ya fue adoptada." })] : []),
        crearElemento("button", { clase: "boton boton--secundario boton--pequeno", texto: "Editar", atributos: { type: "button", "data-accion": "editar", "aria-label": `Editar publicación de ${p.mascotaNombre}` } }),
        crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Eliminar", atributos: { type: "button", "data-accion": "eliminar", "aria-label": `Eliminar publicación de ${p.mascotaNombre}` } }),
      ]),
    ]));
  });
  lista.replaceChildren(fragmento);
}

/* ---------- Eventos ---------- */

function enlazarEventos() {
  limpiarErroresAlEscribir(formulario);
  selector.addEventListener("change", () => { marcarError(selector.closest(".campo"), ""); actualizarVista(); });
  entradaTexto.addEventListener("input", () => { contador.textContent = `${entradaTexto.value.length}/500`; });
  selectorRepublicar.addEventListener("change", () => {
    zonaDias.hidden = selectorRepublicar.value !== "personalizada";
    if (!zonaDias.hidden) entradaDias.focus();
  });

  entradaFoto.addEventListener("change", async () => {
    const archivo = entradaFoto.files[0];
    const zona = entradaFoto.closest(".campo");
    if (!archivo) return;
    const error = validarImagen(archivo);
    if (error) { marcarError(zona, error); entradaFoto.value = ""; return; }
    try {
      fotoPersonalizada = await redimensionarImagen(archivo);
      marcarError(zona, "");
      actualizarVista();
    } catch {
      marcarError(zona, "No pudimos leer esa imagen. Prueba con otra.");
    }
  });
  botonUsarOriginal.addEventListener("click", () => { fotoPersonalizada = ""; entradaFoto.value = ""; actualizarVista(); });
  botonCancelarEdicion.addEventListener("click", () => { salirDeEdicion(); ocultarAlerta(alerta); });

  formulario.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    ocultarAlerta(alerta);
    const texto = entradaTexto.value.trim();
    const republicarCadaDias = leerPeriodicidad();
    const errorMascota = selector.value ? "" : "Elige una mascota de tu inventario.";
    const errorTexto = texto.length < 10 ? "Escribe al menos 10 caracteres." : "";
    const errorPeriodo = republicarCadaDias === undefined ? "Escribe un número de días entre 1 y 90." : "";
    marcarError(selector.closest(".campo"), errorMascota);
    marcarError(entradaTexto.closest(".campo"), errorTexto);
    marcarError(campoRepublicar, errorPeriodo);
    if (errorMascota || errorTexto || errorPeriodo) { (errorMascota ? selector : errorTexto ? entradaTexto : entradaDias).focus(); return; }

    botonPublicar.disabled = true;
    const resultado = editando
      ? await editarPublicacionRefugio(editando.id, { texto, foto: fotoPersonalizada, republicarCadaDias })
      : await crearPublicacionRefugio({ mascotaId: selector.value, texto, foto: fotoPersonalizada, republicarCadaDias });
    botonPublicar.disabled = false;

    if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error); return; }
    const mensaje = editando
      ? "Cambios guardados."
      : `¡Publicación creada! Ya aparece en la página pública de tu refugio${republicarCadaDias ? ` y se republicará ${textoPeriodicidad(republicarCadaDias)}` : ""}.`;
    salirDeEdicion();
    mostrarAlerta(alerta, "exito", mensaje);
    await renderLista();
  });

  lista.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton) return;
    const id = boton.closest("li").dataset.id;
    if (boton.dataset.accion === "editar") {
      const publicacion = publicaciones.find((p) => p.id === id);
      if (publicacion) entrarEnEdicion(publicacion);
      return;
    }
    borrandoId = id;
    modalBorrar.showModal();
  });
  document.getElementById("cancelar-borrar").addEventListener("click", () => modalBorrar.close());
  document.getElementById("confirmar-borrar").addEventListener("click", async () => {
    modalBorrar.close();
    const resultado = await eliminarPublicacionRefugio(borrandoId);
    if (editando?.id === borrandoId) salirDeEdicion();
    anuncio.textContent = resultado.ok ? "Publicación eliminada." : resultado.error;
    await renderLista();
  });
}
