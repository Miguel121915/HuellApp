/**
 * coincidencias.js — Posibles coincidencias entre reportes con porcentaje de similitud.
 * Las ven las dos personas: quien perdió la mascota (lado "perdida") y quien la encontró
 * (lado "encontrada"). Cada una puede contactar a la otra o declinar la coincidencia.
 */
import { requerirRol } from "../../core/router-guard.js";
import { pedirCuenta } from "../../components/aviso-cuenta.js";
import { montarNavbar, refrescarInsigniaCoincidencias } from "../../components/navbar.js";
import { obtenerCoincidencias, descartarCoincidencia, restaurarCoincidencias, obtenerResumenCoincidencias, responderSena } from "../../core/servicios.js";
import { crearElemento, resolverImagen, tiempoRelativo } from "../../core/utils.js";

const sesion = requerirRol("usuario", { permitirInvitado: true });

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
  if (sesion.rol === "invitado") mostrarParaVisitante();
  else iniciar();
}

/** El visitante no tiene reportes: se explica la sección y se le invita a crear cuenta. */
function mostrarParaVisitante() {
  resumen.textContent = "Aquí verás las mascotas que se parecen a las que reportaste como perdidas o encontradas.";
  const boton = crearElemento("button", { clase: "boton boton--primario", texto: "Iniciar sesión para ver mis coincidencias", atributos: { type: "button" } });
  boton.addEventListener("click", () => pedirCuenta("ver tus coincidencias"));
  lista.replaceChildren(crearElemento("section", { clase: "vacio tarjeta tarjeta--blanca" }, [
    crearElemento("p", { texto: "Cuando reportes una mascota perdida o encontrada, HuellApp la compara con los reportes de otras personas y te muestra las posibles coincidencias." }),
    boton,
  ]));
}

let estadoIa = { analizando: 0, duplicados: [] };
let recarga = null;

async function cargar() {
  let resumenApi;
  [coincidencias, resumenApi] = await Promise.all([obtenerCoincidencias(), obtenerResumenCoincidencias()]);
  descartadas = resumenApi.descartadas;
  estadoIa = { analizando: resumenApi.analizando || 0, duplicados: resumenApi.duplicados || [] };
  render();
  // Mientras la IA revisa fotos (en segundo plano), la página se actualiza sola
  clearTimeout(recarga);
  if (estadoIa.analizando > 0) {
    recarga = setTimeout(async () => { await cargar(); refrescarInsigniaCoincidencias(); }, 15000);
  }
}

/** Avisos de la IA: reportes que aún revisa y alertas que parecen de la misma mascota. */
function avisosIa() {
  const avisos = [];
  if (estadoIa.analizando > 0) {
    avisos.push(crearElemento("p", { clase: "aviso-ia", atributos: { role: "status" }, texto:
      `🤖 La IA está revisando la foto de ${estadoIa.analizando === 1 ? "tu reporte" : `${estadoIa.analizando} de tus reportes`} y comparándola con otros. Esta página se actualiza sola.` }));
  }
  for (const d of estadoIa.duplicados) {
    const nombre = d.miReporte.nombre ? `de ${d.miReporte.nombre} ` : "";
    avisos.push(crearElemento("article", { clase: "aviso-ia aviso-ia--duplicado" }, [
      d.otro.foto ? crearElemento("img", { atributos: { src: resolverImagen(d.otro.foto), alt: `Foto de la alerta de ${d.otro.autor}`, width: 96, height: 72 } }) : null,
      crearElemento("div", {}, [
        crearElemento("strong", { texto: `Tu alerta ${nombre}parece ser de la misma mascota que otra ya publicada` }),
        crearElemento("p", { clase: "texto-pequeno", texto: `${d.otro.autor} la publicó ${tiempoRelativo(d.otro.fecha)} (zona: ${d.otro.zona}). Si es la misma, pónganse de acuerdo en los comentarios de esa alerta en el foro.` }),
      ]),
    ]));
  }
  return avisos;
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
  fragmento.append(...avisosIa());
  coincidencias.forEach((c) => fragmento.append(crearTarjeta(c)));
  lista.replaceChildren(fragmento);

  vacio.hidden = coincidencias.length > 0;
  resumen.textContent = coincidencias.length === 1 ? "1 posible coincidencia" : `${coincidencias.length} posibles coincidencias`;
  botonRestaurar.hidden = descartadas === 0;
  botonRestaurar.textContent = `Restaurar descartadas (${descartadas})`;
}

function crearTarjeta(c) {
  const mio = c.miReporte;
  // otroReporte: el reporte de la otra persona (versiones anteriores de la API solo mandaban "hallazgo")
  const otro = c.otroReporte || c.hallazgo;
  const encontre = c.lado === "encontrada";
  const imagen = (src, alt) => crearElemento("img", { atributos: { src: resolverImagen(src), alt, width: 400, height: 300, loading: "lazy", decoding: "async" } });

  return crearElemento("article", { clase: "coincidencia", atributos: { "data-id": c.id } }, [
    crearElemento("p", { clase: "coincidencia__aviso", texto: encontre ? "Quizá encontraste a una mascota que alguien busca" : "Se ha encontrado una coincidencia" }),
    crearElemento("div", { clase: "coincidencia__cuerpo" }, [
      // Lo que reportó el usuario
      crearElemento("section", { clase: "coincidencia__lado coincidencia__lado--mio" }, [
        crearElemento("h2", { clase: "coincidencia__subtitulo", texto: "Tu reporte" }),
        crearElemento("figure", { clase: "coincidencia__foto" }, imagen(mio.foto, mio.fotoAlt || "Tu mascota")),
        crearElemento("p", { clase: "coincidencia__texto", texto: mio.descripcion }),
        crearElemento("p", { clase: "texto-pequeno", texto: `Zona: ${mio.zona}` }),
      ]),
      // El reporte de la otra persona (la mascota que encontraron o la que perdieron)
      crearElemento("section", { clase: "coincidencia__lado coincidencia__lado--hallazgo" }, [
        crearElemento("div", { clase: "coincidencia__cabecera" }, [
          crearElemento("h2", { clase: "coincidencia__subtitulo", texto: "Posible coincidencia" }),
          crearElemento("span", { clase: "similitud", texto: `${c.similitud}% de similitud`, atributos: { "aria-label": `${c.similitud} por ciento de similitud` } }),
        ]),
        crearElemento("figure", { clase: "coincidencia__foto" }, imagen(otro.foto, otro.fotoAlt || (encontre ? "Mascota perdida" : "Mascota encontrada"))),
        crearElemento("p", { clase: "coincidencia__texto", texto: otro.descripcion }),
        crearElemento("p", { clase: "texto-pequeno", texto: `Zona: ${otro.zona} · Reportado ${tiempoRelativo(c.fecha)}`
          + (c.distanciaKm != null ? ` · 📍 a ${c.distanciaKm} km de tu reporte` : "") }),
        verificacionSena(c),
        c.mismaFoto
          ? crearElemento("p", { clase: "coincidencia__misma-foto texto-pequeno", texto: "⚠️ Usa la misma fotografía que el reporte original, así que la foto no prueba que sea la misma mascota. Pide una foto actual antes de ir por ella." })
          : crearElemento("p", { clase: "texto-pequeno texto-suave", texto: c.porIA
            ? "🤖 La IA comparó las fotos de las dos mascotas."
            : "Comparado por descripción y zona (sin IA)." }),
        crearElemento("div", { clase: "coincidencia__acciones" }, [
          crearElemento("button", { clase: "boton boton--primario", texto: "Contactar", atributos: { type: "button", "data-accion": "contactar" } }),
          crearElemento("button", { clase: "boton boton--peligro", texto: "Declinar", atributos: { type: "button", "data-accion": "declinar" } }),
        ]),
      ]),
    ]),
  ]);
}

/**
 * Seña secreta del dueño:
 *  - al dueño se le muestra su seña junto a lo que respondió quien encontró, para que decida;
 *  - a quien encontró se le avisa que debe describir la seña antes de ver el contacto.
 */
function verificacionSena(c) {
  const v = c.verificacion;
  if (!v) return null;
  if (v.tuSena !== undefined) {
    return crearElemento("div", { clase: "verificacion-sena" }, [
      crearElemento("p", { texto: `🔒 Tu seña secreta: «${v.tuSena}»` }),
      crearElemento("p", { texto: v.respuesta
        ? `Quien la encontró describe: «${v.respuesta}». ¿Coincide? Si no, puedes declinar.`
        : "Quien la encontró todavía no describe la seña. Le pedimos hacerlo antes de ver tus datos." }),
    ]);
  }
  return crearElemento("div", { clase: "verificacion-sena" }, [
    crearElemento("p", { texto: v.requerida
      ? "🔒 El dueño pidió confirmar una seña particular de su mascota. Descríbela para ver sus datos de contacto."
      : `✅ Ya describiste la seña: «${v.respuesta}». El dueño la revisará.` }),
  ]);
}

/** Pide a quien encontró la mascota que describa la seña; al responder se recargan sus coincidencias. */
function pedirSena(c) {
  const dialogo = crearElemento("dialog", { clase: "modal", atributos: { "aria-labelledby": "sena-titulo" } });
  const campo = crearElemento("textarea", { clase: "campo__control", atributos: { rows: 3, maxlength: 300, placeholder: "Por ejemplo: tiene una mancha blanca en el pecho", "aria-label": "Describe la seña" } });
  const error = crearElemento("p", { clase: "campo__error", atributos: { role: "alert" } });
  const enviar = crearElemento("button", { clase: "boton boton--primario", texto: "Enviar", atributos: { type: "button" } });
  const cancelar = crearElemento("button", { clase: "boton boton--contorno", texto: "Cancelar", atributos: { type: "button" } });
  cancelar.addEventListener("click", () => { dialogo.close(); dialogo.remove(); });
  enviar.addEventListener("click", async () => {
    const respuesta = campo.value.trim();
    if (respuesta.length < 3) { error.textContent = "Escribe al menos 3 caracteres."; return; }
    enviar.disabled = true;
    const r = await responderSena(c.id, respuesta);
    enviar.disabled = false;
    if (!r.ok) { error.textContent = r.error; return; }
    dialogo.close(); dialogo.remove();
    await cargar();
    abrirContacto(c.id); // ya tiene el contacto del dueño
  });
  dialogo.append(
    crearElemento("h2", { clase: "modal__titulo", texto: "Confirma que es la misma mascota", atributos: { id: "sena-titulo" } }),
    crearElemento("p", { texto: "El dueño registró una seña particular que no aparece en la foto. Describe alguna seña que tenga la mascota que encontraste (manchas, cicatrices, collar…). El dueño revisará tu respuesta." }),
    campo, error,
    crearElemento("div", { clase: "modal__acciones" }, [cancelar, enviar]),
  );
  document.body.append(dialogo);
  dialogo.showModal();
  campo.focus();
}

function abrirContacto(id) {
  const c = coincidencias.find((x) => x.id === id);
  if (!c) return;
  // Si el dueño pidió seña, primero se describe; el contacto llega después
  if (c.verificacion?.requerida) { pedirSena(c); return; }
  const { contacto } = c.otroReporte || c.hallazgo;
  modal.querySelector("p").textContent = c.lado === "encontrada"
    ? "Comunícate con quien perdió a la mascota para confirmar si es la suya."
    : "Comunícate con quien reportó a la mascota para confirmar si es la tuya.";
  document.getElementById("contacto-nombre").textContent = contacto.nombre;
  const tel = document.getElementById("contacto-telefono");
  const digitos = (contacto.telefono || "").replace(/\D/g, "");
  // Sin teléfono la API manda "": se avisa con texto y sin enlace
  tel.textContent = digitos ? contacto.telefono : "No indicó teléfono";
  if (digitos) tel.href = `tel:${digitos}`;
  else tel.removeAttribute("href");
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
