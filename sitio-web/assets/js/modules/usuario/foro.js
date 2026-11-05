/**
 * foro.js — Muro estilo Facebook: crear publicación (texto + foto), feed con "me gusta"
 * en forma de huella y comentarios simulados. El feed se carga por lotes con
 * IntersectionObserver (scroll infinito sencillo) y usa delegación de eventos.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { escucharLikes } from "../../components/like-huella.js";
import { crearTarjetaPublicacion, renderComentarios } from "../../components/tarjeta-publicacion.js";
import { obtenerPublicacionesForo, crearPublicacionForo, agregarComentario, establecerLike } from "../../core/servicios.js";
import { limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta, redimensionarImagen, validarImagen } from "../../core/utils.js";

const LOTE = 5;
const MAX_TEXTO = 600;

const sesion = requerirRol("usuario");

if (sesion) {
  montarNavbar({ sesion, activa: "foro" });
  iniciarForo();
}

async function iniciarForo() {
  const feed = document.getElementById("feed");
  const zonaMas = document.getElementById("zona-mas");
  const botonMas = document.getElementById("boton-mas");
  const estado = document.getElementById("feed-estado");

  const publicaciones = await obtenerPublicacionesForo();
  let mostradas = 0;
  estado.hidden = true;

  /* ----- Feed por lotes ----- */
  function cargarLote() {
    const lote = publicaciones.slice(mostradas, mostradas + LOTE);
    const fragmento = document.createDocumentFragment(); // un solo reflow por lote
    lote.forEach((p) => fragmento.append(crearTarjetaPublicacion(p, { liked: p.yaDioLike })));
    feed.append(fragmento);
    mostradas += lote.length;
    zonaMas.hidden = mostradas >= publicaciones.length;
    if (!zonaMas.hidden) { observador.unobserve(zonaMas); observador.observe(zonaMas); } // vuelve a evaluar
  }
  const observador = new IntersectionObserver((entradas) => {
    if (entradas.some((e) => e.isIntersecting)) cargarLote();
  }, { rootMargin: "300px" });
  botonMas.addEventListener("click", cargarLote);
  cargarLote();

  /* ----- "Me gusta" (huella) ----- */
  escucharLikes(feed, establecerLike);

  /* ----- Comentarios (delegación) ----- */
  feed.addEventListener("click", (evento) => {
    const boton = evento.target.closest(".comentarios-toggle");
    if (!boton) return;
    const seccion = document.getElementById(boton.getAttribute("aria-controls"));
    const abrir = seccion.hidden;
    seccion.hidden = !abrir;
    boton.setAttribute("aria-expanded", String(abrir));
    if (abrir) seccion.querySelector("input").focus();
  });

  feed.addEventListener("submit", async (evento) => {
    const formulario = evento.target.closest(".comentarios__form");
    if (!formulario) return;
    evento.preventDefault();
    const entrada = formulario.elements.comentario;
    const texto = entrada.value.trim();
    if (!texto) return;
    const tarjeta = formulario.closest(".publicacion");
    const resultado = await agregarComentario(tarjeta.dataset.id, { texto });
    if (resultado.ok) {
      renderComentarios(tarjeta, resultado.comentarios);
      entrada.value = "";
      entrada.focus();
    }
  });

  /* ----- Crear publicación ----- */
  const formulario = document.getElementById("formulario-publicar");
  const campoTexto = document.getElementById("campo-texto");
  const campoFoto = document.getElementById("campo-foto");
  const alerta = document.getElementById("alerta-publicar");
  const entradaTexto = document.getElementById("publicar-texto");
  const entradaFoto = document.getElementById("publicar-foto");
  const vista = document.getElementById("publicar-vista");
  const vistaImg = vista.querySelector("img");
  const contador = document.getElementById("publicar-contador");
  const botonPublicar = document.getElementById("boton-publicar");
  let fotoUrl = "";
  limpiarErroresAlEscribir(formulario);

  function quitarFoto() {
    fotoUrl = "";
    entradaFoto.value = "";
    vista.hidden = true;
    vistaImg.removeAttribute("src");
    marcarError(campoFoto, "");
  }

  entradaTexto.addEventListener("input", () => { contador.textContent = `${entradaTexto.value.length}/${MAX_TEXTO}`; });
  document.getElementById("publicar-quitar").addEventListener("click", quitarFoto);

  entradaFoto.addEventListener("change", async () => {
    const archivo = entradaFoto.files[0];
    if (!archivo) { quitarFoto(); return; }
    const error = validarImagen(archivo);
    if (error) { quitarFoto(); marcarError(campoFoto, error); return; }
    marcarError(campoFoto, "");
    try {
      fotoUrl = await redimensionarImagen(archivo); // imagen reducida (data URL): es lo que se envía al servidor
    } catch {
      quitarFoto();
      marcarError(campoFoto, "No pudimos leer esa imagen. Prueba con otra.");
      return;
    }
    vistaImg.src = fotoUrl;
    vista.hidden = false;
  });

  formulario.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    ocultarAlerta(alerta);
    const texto = entradaTexto.value.trim();
    if (texto.length < 5) { marcarError(campoTexto, "Escribe al menos 5 caracteres."); entradaTexto.focus(); return; }
    marcarError(campoTexto, "");

    botonPublicar.disabled = true;
    const resultado = await crearPublicacionForo({ texto, foto: fotoUrl });
    botonPublicar.disabled = false;

    if (!resultado.ok) { mostrarAlerta(alerta, "error", "No pudimos publicar. Inténtalo de nuevo."); return; }
    publicaciones.unshift(resultado.publicacion);
    mostradas += 1;
    feed.prepend(crearTarjetaPublicacion(resultado.publicacion));
    fotoUrl = "";
    entradaFoto.value = ""; vista.hidden = true; vistaImg.removeAttribute("src");
    entradaTexto.value = ""; contador.textContent = `0/${MAX_TEXTO}`;
    mostrarAlerta(alerta, "exito", "¡Publicación compartida con la comunidad!");
    setTimeout(() => ocultarAlerta(alerta), 4000);
  });
}
