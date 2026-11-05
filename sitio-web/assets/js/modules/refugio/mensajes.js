/**
 * mensajes.js — HU-13: el refugio lee y responde los mensajes que le escriben los usuarios.
 * Al abrir un mensaje nuevo se marca como leído; la respuesta se puede corregir después.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar, refrescarInsigniaMensajes } from "../../components/navbar.js";
import { listarMensajes, responderMensaje } from "../../core/servicios-refugio.js";
import { crearElemento, formatearFecha, mostrarAlerta, resolverImagen } from "../../core/utils.js";

const ESTADOS = {
  nuevo: { texto: "Nuevo", clase: "rechazado" },
  leido: { texto: "Leído", clase: "pendiente" },
  respondido: { texto: "Respondido", clase: "aprobado" },
};

const sesion = requerirRol("refugio");
const lista = document.getElementById("lista-mensajes");
const vacio = document.getElementById("sin-mensajes");
const alerta = document.getElementById("alerta");
const anuncio = document.getElementById("anuncio");

let mensajes = [];
let filtro = "pendientes";

if (sesion) {
  montarNavbar({ sesion, activa: "mensajes" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  try {
    mensajes = await listarMensajes();
  } catch (error) {
    mostrarAlerta(alerta, "error", error.message);
    return;
  }
  dibujar();
}

function dibujar() {
  const visibles = filtro === "todos" ? mensajes : mensajes.filter((m) => m.estado !== "respondido");
  vacio.hidden = visibles.length > 0;
  vacio.textContent = filtro === "todos" ? "Aún no te han escrito." : "No tienes mensajes por responder. 🎉";
  lista.replaceChildren(...visibles.map(crearMensaje));
}

function crearMensaje(m) {
  const estado = ESTADOS[m.estado] || ESTADOS.nuevo;
  const contacto = [m.usuarioCorreo, m.telefono].filter(Boolean).join(" · ");
  const respuesta = crearElemento("textarea", { clase: "campo__control", atributos: { name: "respuesta", maxlength: 1000, rows: 3, "aria-label": `Respuesta para ${m.usuarioNombre}` } });
  respuesta.value = m.respuesta;
  return crearElemento("li", { clase: `mensaje tarjeta tarjeta--blanca${m.estado === "nuevo" ? " mensaje--nuevo" : ""}`, atributos: { "data-id": m.id } }, [
    crearElemento("div", { clase: "mensaje__cabecera" }, [
      ...(m.mascotaFoto ? [crearElemento("img", { clase: "mensaje__foto", atributos: { src: resolverImagen(m.mascotaFoto), alt: "", width: 48, height: 48, loading: "lazy" } })] : []),
      crearElemento("div", { clase: "mensaje__titulo" }, [
        crearElemento("strong", { texto: m.usuarioNombre }),
        crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${m.mascotaNombre ? `Sobre ${m.mascotaNombre} · ` : ""}${formatearFecha(m.fecha)}` }),
        crearElemento("span", { clase: "texto-pequeno", texto: contacto }),
      ]),
      crearElemento("span", { clase: `insignia insignia--${estado.clase}`, texto: estado.texto }),
    ]),
    crearElemento("p", { clase: "mensaje__texto", texto: m.mensaje }),
    crearElemento("form", { clase: "mensaje__responder", atributos: { novalidate: true } }, [
      respuesta,
      crearElemento("div", { clase: "mensaje__acciones" }, [
        ...(m.estado === "nuevo" ? [crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Marcar como leído", atributos: { type: "button", "data-accion": "leido" } })] : []),
        crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: m.respuesta ? "Actualizar respuesta" : "Responder", atributos: { type: "submit" } }),
      ]),
    ]),
  ]);
}

async function actualizar(id, respuesta = null) {
  const r = await responderMensaje(id, respuesta);
  if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
  mensajes = mensajes.map((m) => (m.id === id ? r.mensaje : m));
  anuncio.textContent = respuesta === null ? "Mensaje marcado como leído." : `Respuesta enviada a ${r.mensaje.usuarioNombre}.`;
  dibujar();
  refrescarInsigniaMensajes();
}

function enlazarEventos() {
  document.querySelector(".filtro-mensajes").addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-filtro]");
    if (!boton) return;
    filtro = boton.dataset.filtro;
    document.querySelectorAll("[data-filtro]").forEach((b) => {
      const activo = b === boton;
      b.setAttribute("aria-pressed", String(activo));
      b.classList.toggle("boton--secundario", activo);
      b.classList.toggle("boton--contorno", !activo);
    });
    dibujar();
  });

  lista.addEventListener("click", (evento) => {
    const boton = evento.target.closest('[data-accion="leido"]');
    if (boton) actualizar(boton.closest("li").dataset.id);
  });

  lista.addEventListener("submit", (evento) => {
    evento.preventDefault();
    const texto = evento.target.elements.respuesta.value.trim();
    if (texto.length < 2) { mostrarAlerta(alerta, "error", "Escribe tu respuesta antes de enviarla."); return; }
    actualizar(evento.target.closest("li").dataset.id, texto);
  });
}
