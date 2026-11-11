/**
 * foro.js — Muro estilo Facebook: crear publicación (texto + foto), feed con "me gusta"
 * en forma de huella y comentarios simulados. El feed se carga por lotes con
 * IntersectionObserver (scroll infinito sencillo) y usa delegación de eventos.
 */
import { requerirRol } from "../../core/router-guard.js";
import { protegerAcciones } from "../../components/aviso-cuenta.js";
import { montarNavbar } from "../../components/navbar.js";
import { escucharLikes } from "../../components/like-huella.js";
import { crearTarjetaPublicacion, renderComentarios } from "../../components/tarjeta-publicacion.js";
import { obtenerPublicacionesForo, crearPublicacionForo, agregarComentario, establecerLike, marcarReunido } from "../../core/servicios.js";
import { crearElemento, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta, redimensionarImagen, resolverImagen, tiempoRelativo, validarImagen } from "../../core/utils.js";

const LOTE = 5;
const MAX_TEXTO = 600;

/** Pestañas del muro (ver la API: GET /foro?categoria=…). */
const PESTANAS = {
  busca: {
    ayuda: "Mascotas perdidas que sus familias siguen buscando. Si viste a alguna, escríbelo en los comentarios.",
    accion: { texto: "Se me perdió mi mascota", href: "reportar.html?tipo=perdida" },
    vacio: "No hay mascotas perdidas en este momento.",
  },
  familia: {
    ayuda: "Mascotas que alguien encontró en la calle y que buscan a su familia. ¿Reconoces a alguna?",
    accion: { texto: "Encontré una mascota", href: "reportar.html?tipo=encontrada" },
    vacio: "No hay mascotas encontradas esperando a su familia.",
  },
  reunidos: {
    ayuda: "Mascotas que ya volvieron a casa gracias a la comunidad. 💚",
    accion: null,
    vacio: "Todavía no hay reencuentros. ¡El primero puede ser el tuyo!",
  },
  comunidad: {
    ayuda: "Tips, historias y preguntas de la comunidad.",
    accion: null,
    vacio: "Aún no hay publicaciones. ¡Sé el primero en compartir algo!",
  },
};

const sesion = requerirRol("usuario", { permitirInvitado: true });
protegerAcciones(sesion, {
  clics: [".like-huella", "#publicar-foto", 'label[for="publicar-foto"]'],
  envios: ["#formulario-publicar", ".comentarios__form"],
  accion: "participar en el foro",
});

if (sesion) {
  montarNavbar({ sesion, activa: "foro" });
  iniciarForo();
}

async function iniciarForo() {
  const feed = document.getElementById("feed");
  const zonaMas = document.getElementById("zona-mas");
  const botonMas = document.getElementById("boton-mas");
  const estado = document.getElementById("feed-estado");

  let publicaciones = [];
  let mostradas = 0;
  let pestana = PESTANAS[new URLSearchParams(location.search).get("pestana")] ? new URLSearchParams(location.search).get("pestana") : "busca";

  /* ----- Pestañas: Se buscan · Buscan a su familia · Reunidos · Comunidad ----- */
  const barra = document.getElementById("pestanas-muro");
  const formularioPublicar = document.getElementById("formulario-publicar");
  const avisoPestana = document.getElementById("aviso-pestana");
  let consulta = 0;

  async function mostrarPestana(nueva) {
    pestana = nueva;
    barra.querySelectorAll("[role=tab]").forEach((t) => {
      const activa = t.dataset.pestana === nueva;
      t.setAttribute("aria-selected", String(activa));
      t.tabIndex = activa ? 0 : -1;
    });
    const p = PESTANAS[nueva];
    // Publicar texto libre solo en «Comunidad»; las alertas se crean desde «Reportar»
    formularioPublicar.hidden = nueva !== "comunidad";
    avisoPestana.replaceChildren(
      crearElemento("p", { texto: p.ayuda }),
      ...(p.accion ? [crearElemento("a", { clase: "boton boton--primario boton--pequeno", texto: p.accion.texto, atributos: { href: p.accion.href } })] : []),
    );
    history.replaceState(null, "", `?pestana=${nueva}`);
    feed.replaceChildren();
    zonaMas.hidden = true;
    estado.hidden = false;
    estado.textContent = "Cargando publicaciones…";
    const yo = ++consulta;
    const lista = await obtenerPublicacionesForo(nueva);
    if (yo !== consulta) return; // ya cambiaron de pestaña
    publicaciones = lista;
    mostradas = 0;
    estado.hidden = publicaciones.length > 0;
    estado.textContent = p.vacio;
    cargarLote();
  }

  barra.addEventListener("click", (e) => {
    const t = e.target.closest("[role=tab]");
    if (t && t.dataset.pestana !== pestana) mostrarPestana(t.dataset.pestana);
  });
  barra.addEventListener("keydown", (e) => { // flechas para moverse entre pestañas (accesibilidad)
    if (!["ArrowRight", "ArrowLeft"].includes(e.key)) return;
    const claves = Object.keys(PESTANAS);
    const i = (claves.indexOf(pestana) + (e.key === "ArrowRight" ? 1 : claves.length - 1)) % claves.length;
    mostrarPestana(claves[i]).then(() => barra.querySelector(`[data-pestana="${claves[i]}"]`).focus());
  });

  /* ----- «¡Ya apareció!» (solo quien publicó la alerta) ----- */
  feed.addEventListener("click", async (e) => {
    const boton = e.target.closest(".publicacion__reunido");
    if (!boton) return;
    const pub = publicaciones.find((p) => String(p.id) === boton.closest(".publicacion").dataset.id);
    if (!pub || !confirm("¿Tu mascota ya está en casa? La alerta pasará a «Reunidos» y dejaremos de buscar coincidencias.")) return;
    boton.disabled = true;
    const r = await marcarReunido(pub.reporteId);
    if (!r.ok) { boton.disabled = false; alert(r.error); return; }
    boton.closest(".publicacion").replaceWith(crearElemento("p", { clase: "aviso-reunido", texto: "💚 ¡Qué alegría! La alerta pasó a «Reunidos»." }));
  });

  /* ----- Feed por lotes ----- */
  function cargarLote() {
    const lote = publicaciones.slice(mostradas, mostradas + LOTE);
    const fragmento = document.createDocumentFragment(); // un solo reflow por lote
    lote.forEach((p) => fragmento.append(crearTarjeta(p, { liked: p.yaDioLike })));
    feed.append(fragmento);
    mostradas += lote.length;
    zonaMas.hidden = mostradas >= publicaciones.length;
    if (!zonaMas.hidden) { observador.unobserve(zonaMas); observador.observe(zonaMas); } // vuelve a evaluar
  }
  const observador = new IntersectionObserver((entradas) => {
    if (entradas.some((e) => e.isIntersecting)) cargarLote();
  }, { rootMargin: "300px" });
  botonMas.addEventListener("click", cargarLote);
  mostrarPestana(pestana);

  /* ----- "Me gusta" (huella) ----- */
  escucharLikes(feed, establecerLike);

  /* ----- Detalle de la alerta / publicación (HU-5): botón «Ver detalle» o clic en la foto ----- */
  feed.addEventListener("click", (evento) => {
    const disparador = evento.target.closest(".publicacion__ver-detalle, .publicacion__foto");
    if (!disparador) return;
    const id = disparador.closest(".publicacion").dataset.id;
    const pub = publicaciones.find((p) => String(p.id) === id);
    if (pub) abrirDetalle(pub);
  });

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
    feed.prepend(crearTarjeta(resultado.publicacion));
    fotoUrl = "";
    entradaFoto.value = ""; vista.hidden = true; vistaImg.removeAttribute("src");
    entradaTexto.value = ""; contador.textContent = `0/${MAX_TEXTO}`;
    mostrarAlerta(alerta, "exito", "¡Publicación compartida con la comunidad!");
    setTimeout(() => ocultarAlerta(alerta), 4000);
  });
}

/* ==========================================================
   Pestañas del muro y alertas de mascotas (HU-5)
   Cada alerta está ligada a su reporte; la API dice en qué pestaña va (pub.categoria).
   ========================================================== */

/** "perdida" | "encontrada" | null según la pestaña de la publicación. */
function tipoDeAlerta(pub) {
  if (pub.categoria === "busca") return "perdida";
  if (pub.categoria === "familia") return "encontrada";
  if (pub.categoria === "reunidos") return "reunido";
  return null;
}

const ETIQUETA_ALERTA = { perdida: "🔎 Se busca", encontrada: "🏠 Busca a su familia", reunido: "💚 Reunido con su familia" };

/** Tarjeta del feed: a las alertas les agrega su etiqueta, «Ver detalle» y, a su dueño, «¡Ya apareció!». */
function crearTarjeta(pub, opciones) {
  const tipo = tipoDeAlerta(pub);
  const tarjeta = crearTarjetaPublicacion(tipo ? { ...pub, etiqueta: ETIQUETA_ALERTA[tipo] } : pub, opciones);
  if (tipo) {
    tarjeta.classList.add("publicacion--alerta", `publicacion--${tipo}`);
    const pie = tarjeta.querySelector(".publicacion__pie");
    pie?.append(
      crearElemento("button", { clase: "boton boton--contorno boton--pequeno publicacion__ver-detalle", texto: "Ver detalle", atributos: { type: "button" } }),
    );
    if (pub.esMiAlerta && tipo !== "reunido") {
      pie?.append(crearElemento("button", { clase: "boton boton--primario boton--pequeno publicacion__reunido", texto: "💚 ¡Ya apareció!", atributos: { type: "button" } }));
    }
  }
  const foto = tarjeta.querySelector(".publicacion__foto");
  if (foto) foto.title = "Ver en grande";
  return tarjeta;
}

let dialogoDetalle = null;

/** Diálogo con la foto en grande y el texto completo de la alerta o publicación. */
function abrirDetalle(pub) {
  if (!dialogoDetalle) {
    dialogoDetalle = crearElemento("dialog", { clase: "modal modal--ancho detalle-alerta", atributos: { "aria-labelledby": "detalle-alerta-titulo" } });
    dialogoDetalle.addEventListener("click", (e) => { if (e.target === dialogoDetalle) dialogoDetalle.close(); }); // clic fuera cierra
    document.body.append(dialogoDetalle);
  }
  const tipo = tipoDeAlerta(pub);
  const fecha = new Date(pub.fecha);
  const fechaLegible = Number.isNaN(fecha.getTime()) ? "" : fecha.toLocaleString("es-MX", { dateStyle: "long", timeStyle: "short" });

  const cerrar = crearElemento("button", { clase: "boton boton--primario", texto: "Cerrar", atributos: { type: "button" } });
  cerrar.addEventListener("click", () => dialogoDetalle.close());

  dialogoDetalle.replaceChildren(...[
    crearElemento("h2", { clase: "modal__titulo", texto: tipo ? ETIQUETA_ALERTA[tipo] : "Publicación", atributos: { id: "detalle-alerta-titulo" } }),
    pub.foto
      ? crearElemento("figure", { clase: "detalle-alerta__foto" },
        crearElemento("img", { atributos: { src: resolverImagen(pub.foto), alt: pub.fotoAlt || `Foto publicada por ${pub.autor}` } }))
      : null,
    crearElemento("p", { clase: "detalle-alerta__meta texto-pequeno texto-suave" }, [
      document.createTextNode(`Publicado por ${pub.autor}`),
      fechaLegible ? document.createTextNode(` · ${fechaLegible} (${tiempoRelativo(pub.fecha)})`) : null,
    ]),
    crearElemento("p", { clase: "detalle-alerta__texto", texto: pub.texto }),
    crearElemento("div", { clase: "modal__acciones" }, [
      tipo ? crearElemento("a", { clase: "boton boton--secundario", texto: "Ver mis coincidencias", atributos: { href: "coincidencias.html" } }) : null,
      cerrar,
    ]),
  ].filter(Boolean));
  if (typeof dialogoDetalle.showModal === "function") dialogoDetalle.showModal();
  cerrar.focus();
}
