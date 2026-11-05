/**
 * preguntas.js — El refugio da de alta, edita, oculta y elimina sus preguntas frecuentes.
 * Las usa KIRO, el asistente del formulario de adopción. Incluye un probador que muestra qué
 * respondería el asistente a una duda escrita libremente.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearBuscador } from "../../core/buscador-faq.js";
import { listarPreguntas, guardarPregunta, eliminarPregunta } from "../../core/servicios-refugio.js";
import { crearElemento, debounce, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";
import { PREGUNTAS_GENERALES } from "../../data/preguntas-adopcion.js";

const sesion = requerirRol("refugio");

const formulario = document.getElementById("formulario-pregunta");
const f = formulario.elements;
const alerta = document.getElementById("alerta-formulario");
const botonGuardar = document.getElementById("boton-guardar");
const botonCancelar = document.getElementById("cancelar-edicion");
const lista = document.getElementById("lista-preguntas");
const vacio = document.getElementById("sin-preguntas");
const anuncio = document.getElementById("anuncio");
const modalBorrar = document.getElementById("modal-borrar");
const probarTexto = document.getElementById("probar-texto");
const probarResultado = document.getElementById("probar-resultado");
const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

let preguntas = [];
let editando = null;
let borrando = null;

if (sesion) {
  montarNavbar({ sesion, activa: "preguntas" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  preguntas = await listarPreguntas();
  dibujar();
  probar();
}

/* ---------- Lista ---------- */

function dibujar() {
  vacio.hidden = preguntas.length > 0;
  const activas = preguntas.filter((p) => p.activa).length;
  document.getElementById("conteo").textContent = preguntas.length ? `(${activas} visibles de ${preguntas.length})` : "";
  lista.replaceChildren(...preguntas.map((p) => crearElemento("li", { clase: `pregunta-item tarjeta tarjeta--blanca${p.activa ? "" : " pregunta-item--oculta"}`, atributos: { "data-id": p.id } }, [
    crearElemento("div", { clase: "pregunta-item__cabecera" }, [
      crearElemento("h3", { clase: "pregunta-item__pregunta", texto: p.pregunta }),
      crearElemento("span", { clase: `insignia insignia--${p.activa ? "aprobado" : "adoptado"}`, texto: p.activa ? "Visible" : "Oculta" }),
    ]),
    crearElemento("p", { clase: "pregunta-item__respuesta", texto: p.respuesta }),
    ...(p.claves.length ? [crearElemento("ul", { clase: "pregunta-item__claves", atributos: { "aria-label": "Palabras clave" } },
      p.claves.map((c) => crearElemento("li", { texto: c })))] : []),
    crearElemento("div", { clase: "pregunta-item__acciones" }, [
      crearElemento("button", { clase: "boton boton--secundario boton--pequeno", texto: "Editar", atributos: { type: "button", "data-accion": "editar" } }),
      crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: p.activa ? "Ocultar" : "Mostrar", atributos: { type: "button", "data-accion": "alternar" } }),
      crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Eliminar", atributos: { type: "button", "data-accion": "eliminar" } }),
    ]),
  ])));
}

/* ---------- Formulario (crear / editar) ---------- */

function leerClaves(texto) {
  return texto.split(",").map((c) => c.trim()).filter(Boolean);
}

function salirDeEdicion() {
  editando = null;
  formulario.reset();
  f.activa.checked = true;
  document.getElementById("p-contador").textContent = "0/1000";
  document.getElementById("titulo-formulario").textContent = "Nueva pregunta";
  botonGuardar.textContent = "Agregar pregunta";
  botonCancelar.hidden = true;
  formulario.classList.remove("tarjeta--editando");
  formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
}

function entrarEnEdicion(p) {
  salirDeEdicion();
  editando = p;
  f.pregunta.value = p.pregunta;
  f.respuesta.value = p.respuesta;
  f.claves.value = p.claves.join(", ");
  f.activa.checked = p.activa;
  document.getElementById("p-contador").textContent = `${p.respuesta.length}/1000`;
  document.getElementById("titulo-formulario").textContent = "Editar pregunta";
  botonGuardar.textContent = "Guardar cambios";
  botonCancelar.hidden = false;
  formulario.classList.add("tarjeta--editando");
  formulario.scrollIntoView({ behavior: "smooth", block: "start" });
  f.pregunta.focus({ preventScroll: true });
}

async function guardar(evento) {
  evento.preventDefault();
  ocultarAlerta(alerta);
  const datos = { pregunta: f.pregunta.value.trim(), respuesta: f.respuesta.value.trim(), claves: leerClaves(f.claves.value), activa: f.activa.checked };
  const errores = {
    pregunta: datos.pregunta.length < 5 ? "Escribe la pregunta (al menos 5 caracteres)." : "",
    respuesta: datos.respuesta.length < 10 ? "Escribe la respuesta (al menos 10 caracteres)." : "",
    claves: datos.claves.join(", ").length > 300 ? "Las palabras clave no pueden pasar de 300 caracteres." : "",
  };
  Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(campo(nombre), mensaje));
  if (Object.values(errores).some(Boolean)) { formulario.querySelector(".campo--error .campo__control")?.focus(); return; }

  botonGuardar.disabled = true;
  const r = await guardarPregunta(datos, editando?.id);
  botonGuardar.disabled = false;
  if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
  const mensaje = editando ? "Cambios guardados." : "Pregunta agregada. KIRO ya puede usarla.";
  salirDeEdicion();
  mostrarAlerta(alerta, "exito", mensaje);
  setTimeout(() => ocultarAlerta(alerta), 3500);
  await cargar();
}

/* ---------- Probador del asistente ---------- */

function probar() {
  const texto = probarTexto.value;
  if (texto.trim().length < 3) {
    probarResultado.replaceChildren(crearElemento("p", { clase: "texto-suave texto-pequeno", texto: "Aquí aparecerá la respuesta." }));
    return;
  }
  const [mejor] = crearBuscador(preguntas.filter((p) => p.activa)).buscar(texto);
  probarResultado.replaceChildren(...(mejor
    ? [crearElemento("strong", { texto: mejor.item.pregunta }), crearElemento("p", { texto: mejor.item.respuesta })]
    : [crearElemento("p", { clase: "texto-pequeno", texto: "Ninguna de tus preguntas visibles responde esto: KIRO usaría una respuesta general de HuellApp. Agrega una pregunta o palabras clave para cubrirla." })]));
}

/* ---------- Eventos ---------- */

function enlazarEventos() {
  limpiarErroresAlEscribir(formulario);
  formulario.addEventListener("submit", guardar);
  botonCancelar.addEventListener("click", () => { salirDeEdicion(); ocultarAlerta(alerta); });
  f.respuesta.addEventListener("input", () => { document.getElementById("p-contador").textContent = `${f.respuesta.value.length}/1000`; });
  probarTexto.addEventListener("input", debounce(probar, 200));

  lista.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton) return;
    const p = preguntas.find((x) => x.id === boton.closest("li").dataset.id);
    if (!p) return;
    if (boton.dataset.accion === "editar") { entrarEnEdicion(p); return; }
    if (boton.dataset.accion === "alternar") {
      const r = await guardarPregunta({ ...p, activa: !p.activa }, p.id);
      anuncio.textContent = r.ok ? `«${p.pregunta}» ahora está ${p.activa ? "oculta" : "visible"}.` : r.error;
      await cargar();
      return;
    }
    borrando = p;
    document.getElementById("borrar-texto").textContent = `¿Eliminar «${p.pregunta}»? KIRO dejará de usar esta respuesta.`;
    modalBorrar.showModal();
  });

  document.getElementById("cancelar-borrar").addEventListener("click", () => modalBorrar.close());
  document.getElementById("confirmar-borrar").addEventListener("click", async () => {
    modalBorrar.close();
    const r = await eliminarPregunta(borrando.id);
    if (editando?.id === borrando.id) salirDeEdicion();
    anuncio.textContent = r.ok ? "Pregunta eliminada." : r.error;
    await cargar();
  });

  // Punto de partida para refugios sin preguntas: copia las sugeridas para que las adapten
  const botonSugeridas = document.getElementById("usar-sugeridas");
  botonSugeridas.addEventListener("click", async () => {
    botonSugeridas.disabled = true;
    for (const p of PREGUNTAS_GENERALES) await guardarPregunta({ pregunta: p.pregunta, respuesta: p.respuesta, claves: p.claves, activa: true });
    anuncio.textContent = "Se agregaron las preguntas sugeridas. Revísalas y adáptalas a tu refugio.";
    botonSugeridas.disabled = false;
    await cargar();
  });
}
