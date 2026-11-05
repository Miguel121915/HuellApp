/**
 * requisitos.js — HU-16: el refugio define, edita y elimina sus requisitos de adopción.
 * Los usuarios los ven en la página del refugio y antes de enviar una solicitud.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { listarRequisitos, guardarRequisito, eliminarRequisito } from "../../core/servicios-refugio.js";
import { crearElemento, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";

/** Punto de partida para un refugio sin requisitos (los adapta después). */
const SUGERIDOS = [
  { texto: "Ser mayor de edad", detalle: "Presenta tu identificación oficial (INE, pasaporte o cédula) el día de la visita.", obligatorio: true },
  { texto: "Comprobante de domicilio reciente", detalle: "Recibo de luz, agua o teléfono de los últimos 3 meses.", obligatorio: true },
  { texto: "Visita al refugio para conocer a la mascota", detalle: "Agenda tu visita antes de que se apruebe la adopción.", obligatorio: true },
  { texto: "Permiso del arrendador si rentas", detalle: "Una carta o mensaje del dueño de la vivienda que autorice tener mascotas.", obligatorio: false },
  { texto: "Compromiso de esterilización y vacunas", detalle: "Si la mascota aún no está esterilizada o vacunada, te pedimos completarlo.", obligatorio: true },
];

const sesion = requerirRol("refugio");

const formulario = document.getElementById("formulario-requisito");
const f = formulario.elements;
const alerta = document.getElementById("alerta-formulario");
const botonGuardar = document.getElementById("boton-guardar");
const botonCancelar = document.getElementById("cancelar-edicion");
const lista = document.getElementById("lista-requisitos");
const vacio = document.getElementById("sin-requisitos");
const anuncio = document.getElementById("anuncio");
const modalBorrar = document.getElementById("modal-borrar");
const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

let requisitos = [];
let editando = null;
let borrando = null;

if (sesion) {
  montarNavbar({ sesion, activa: "requisitos" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  requisitos = await listarRequisitos();
  dibujar();
}

function dibujar() {
  vacio.hidden = requisitos.length > 0;
  const obligatorios = requisitos.filter((q) => q.obligatorio).length;
  document.getElementById("conteo").textContent = requisitos.length ? `(${obligatorios} obligatorios de ${requisitos.length})` : "";
  lista.replaceChildren(...requisitos.map((q) => crearElemento("li", { clase: "pregunta-item tarjeta tarjeta--blanca", atributos: { "data-id": q.id } }, [
    crearElemento("div", { clase: "pregunta-item__cabecera" }, [
      crearElemento("h3", { clase: "pregunta-item__pregunta", texto: q.texto }),
      crearElemento("span", { clase: `insignia insignia--${q.obligatorio ? "aprobado" : "pendiente"}`, texto: q.obligatorio ? "Obligatorio" : "Recomendable" }),
    ]),
    ...(q.detalle ? [crearElemento("p", { clase: "pregunta-item__respuesta", texto: q.detalle })] : []),
    crearElemento("div", { clase: "pregunta-item__acciones" }, [
      crearElemento("button", { clase: "boton boton--secundario boton--pequeno", texto: "Editar", atributos: { type: "button", "data-accion": "editar" } }),
      crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Eliminar", atributos: { type: "button", "data-accion": "eliminar" } }),
    ]),
  ])));
}

function salirDeEdicion() {
  editando = null;
  formulario.reset();
  f.obligatorio.checked = true;
  document.getElementById("q-contador").textContent = "0/500";
  document.getElementById("titulo-formulario").textContent = "Nuevo requisito";
  botonGuardar.textContent = "Agregar requisito";
  botonCancelar.hidden = true;
  formulario.classList.remove("tarjeta--editando");
  formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
}

function entrarEnEdicion(q) {
  salirDeEdicion();
  editando = q;
  f.texto.value = q.texto;
  f.detalle.value = q.detalle;
  f.obligatorio.checked = q.obligatorio;
  document.getElementById("q-contador").textContent = `${q.detalle.length}/500`;
  document.getElementById("titulo-formulario").textContent = "Editar requisito";
  botonGuardar.textContent = "Guardar cambios";
  botonCancelar.hidden = false;
  formulario.classList.add("tarjeta--editando");
  formulario.scrollIntoView({ behavior: "smooth", block: "start" });
  f.texto.focus({ preventScroll: true });
}

async function guardar(evento) {
  evento.preventDefault();
  ocultarAlerta(alerta);
  const datos = { texto: f.texto.value.trim(), detalle: f.detalle.value.trim(), obligatorio: f.obligatorio.checked };
  const error = datos.texto.length < 3 ? "Escribe el requisito (al menos 3 caracteres)." : "";
  marcarError(campo("texto"), error);
  if (error) { f.texto.focus(); return; }

  botonGuardar.disabled = true;
  const r = await guardarRequisito(datos, editando?.id);
  botonGuardar.disabled = false;
  if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
  const mensaje = editando ? "Cambios guardados." : "Requisito agregado. Los usuarios ya lo ven.";
  salirDeEdicion();
  mostrarAlerta(alerta, "exito", mensaje);
  setTimeout(() => ocultarAlerta(alerta), 3500);
  await cargar();
}

function enlazarEventos() {
  limpiarErroresAlEscribir(formulario);
  formulario.addEventListener("submit", guardar);
  botonCancelar.addEventListener("click", () => { salirDeEdicion(); ocultarAlerta(alerta); });
  f.detalle.addEventListener("input", () => { document.getElementById("q-contador").textContent = `${f.detalle.value.length}/500`; });

  lista.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton) return;
    const q = requisitos.find((x) => x.id === boton.closest("li").dataset.id);
    if (!q) return;
    if (boton.dataset.accion === "editar") { entrarEnEdicion(q); return; }
    borrando = q;
    document.getElementById("borrar-texto").textContent = `¿Eliminar «${q.texto}»? Los usuarios dejarán de verlo.`;
    modalBorrar.showModal();
  });

  document.getElementById("cancelar-borrar").addEventListener("click", () => modalBorrar.close());
  document.getElementById("confirmar-borrar").addEventListener("click", async () => {
    modalBorrar.close();
    const r = await eliminarRequisito(borrando.id);
    if (editando?.id === borrando.id) salirDeEdicion();
    anuncio.textContent = r.ok ? "Requisito eliminado." : r.error;
    await cargar();
  });

  const botonSugeridos = document.getElementById("usar-sugeridos");
  botonSugeridos.addEventListener("click", async () => {
    botonSugeridos.disabled = true;
    for (const q of SUGERIDOS) await guardarRequisito(q);
    anuncio.textContent = "Se agregaron los requisitos sugeridos. Revísalos y adáptalos a tu refugio.";
    botonSugeridos.disabled = false;
    await cargar();
  });
}
