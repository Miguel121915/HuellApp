/**
 * chatbot-kiro.js — KIRO, el asistente de adopción (HU-7), como burbuja flotante.
 *
 * Una burbuja con la cara de KIRO (abajo a la derecha) abre un panel de chat a un lado, sin mover
 * la página. Se monta en todas las páginas del usuario y del visitante (lo llama navbar.js).
 * Pregunta a la API (POST /api/kiro): con IA (Gemini) contesta, recomienda mascotas REALES y, con
 * sesión, busca en los reportes de perdidas y encontradas. Si la API no responde, usa las
 * respuestas predefinidas de mock-kiro.js.
 * La conversación se guarda en sessionStorage: sigue al cambiar de página dentro de la pestaña.
 * Todo el texto entra con textContent (las respuestas vienen de una IA).
 */
import { preguntasKiro, SALUDO_KIRO, RESPUESTA_VACIA, RESPUESTA_DESCONOCIDA } from "../data/mock-kiro.js";
import { normalizarTexto, crearElemento, rutaDesdeRaiz, resolverImagen } from "../core/utils.js";
import { post } from "../core/api.js";
import { obtenerSesion } from "../core/auth.js";

/** Secciones a las que KIRO puede mandar a la persona. */
const ENLACES = {
  refugios: { texto: "Ver refugios y mascotas", ruta: "pages/usuario/refugios.html" },
  reportar: { texto: "Ir a Reportar", ruta: "pages/usuario/reportar.html" },
  coincidencias: { texto: "Ver mis coincidencias", ruta: "pages/usuario/coincidencias.html" },
  favoritos: { texto: "Ver mis favoritos", ruta: "pages/usuario/favoritos.html" },
  foro: { texto: "Ir al foro", ruta: "pages/usuario/foro.html" },
  mensajes: { texto: "Ver mis mensajes", ruta: "pages/usuario/mensajes.html" },
  solicitudes: { texto: "Ver mis solicitudes", ruta: "pages/usuario/solicitudes.html" },
};
const SUGERIDAS = ["Recomiéndame una mascota para un departamento", "¿Qué necesito para adoptar?", "Se me perdió mi mascota, ¿qué hago?", "¿Cómo cuido a un perrito recién adoptado?"];
const MAX_GUARDADOS = 30;

const EDAD = (meses) => (meses < 12 ? `${meses} meses` : `${Math.floor(meses / 12)} año${Math.floor(meses / 12) === 1 ? "" : "s"}`);
const DIA = (iso) => (iso ? new Date(iso).toLocaleDateString("es-MX", { day: "numeric", month: "short" }) : "");
const imagenKiro = (clase) => crearElemento("img", { clase, atributos: { src: rutaDesdeRaiz("assets/img/kiro/kiro.svg"), alt: "", width: 40, height: 42 } });

/** Devuelve la pregunta frecuente que mejor coincide, o null si ninguna (respaldo sin conexión). */
export function buscarRespuesta(texto) {
  const consulta = normalizarTexto(texto);
  if (!consulta) return null;
  let mejor = null;
  let mejorPuntaje = 0;
  for (const item of preguntasKiro) {
    const puntaje = item.claves.filter((clave) => consulta.includes(normalizarTexto(clave))).length;
    if (puntaje > mejorPuntaje) { mejor = item; mejorPuntaje = puntaje; }
  }
  return mejor;
}

/* ---------- Tarjetas ---------- */

function tarjetaMascota(m) {
  return crearElemento("li", {}, crearElemento("a", {
    clase: "kirof__tarjeta",
    atributos: { href: `${rutaDesdeRaiz("pages/usuario/refugios.html")}?id=${encodeURIComponent(m.refugioId)}` },
  }, [
    crearElemento("img", { atributos: { src: resolverImagen(m.foto), alt: "", width: 52, height: 52, loading: "lazy" } }),
    crearElemento("span", {}, [
      crearElemento("strong", { texto: m.nombre }),
      crearElemento("small", { texto: `${m.raza} · ${EDAD(m.edadMeses)} · ${m.tamano}` }),
      crearElemento("small", { texto: m.refugioNombre }),
    ]),
  ]));
}

/** Reporte (perdida o encontrada) que encontró KIRO: lleva a su pestaña del muro. */
function tarjetaReporte(r) {
  const perdida = r.tipo === "perdida";
  const quien = r.nombre || (r.especie === "gato" ? "Gato" : r.especie === "perro" ? "Perro" : "Mascota");
  const rasgos = [r.color, r.tamano].filter(Boolean).join(" · ");
  return crearElemento("li", {}, crearElemento("a", {
    clase: `kirof__tarjeta${perdida ? " kirof__tarjeta--perdida" : ""}`,
    atributos: { href: `${rutaDesdeRaiz("pages/usuario/foro.html")}?pestana=${perdida ? "busca" : "familia"}` },
  }, [
    crearElemento("img", { atributos: { src: resolverImagen(r.foto), alt: "", width: 52, height: 52, loading: "lazy" } }),
    crearElemento("span", {}, [
      crearElemento("strong", { texto: `${perdida ? "Se busca" : "Encontrada"}: ${quien}` }),
      ...(rasgos ? [crearElemento("small", { texto: rasgos })] : []),
      crearElemento("small", { texto: `${r.zona} · ${perdida ? "se perdió" : "la vieron"} el ${DIA(r.fecha)}` }),
    ]),
  ]));
}

/* ---------- Burbuja + panel ---------- */

/** Monta la burbuja y el panel una sola vez por página. */
export function montarKiroFlotante() {
  if (document.querySelector(".kirof")) return;
  if (!document.querySelector('link[data-kiro-flotante]')) {
    document.head.append(crearElemento("link", { atributos: { rel: "stylesheet", href: rutaDesdeRaiz("assets/css/components/kiro-flotante.css"), "data-kiro-flotante": true } }));
  }

  // La conversación es de esta persona: si cambia la sesión, empieza de nuevo
  const clave = `huellapp:kiro:${obtenerSesion()?.id ?? "visitante"}`;
  let guardados = [];
  try { guardados = JSON.parse(sessionStorage.getItem(clave) || "[]"); } catch { guardados = []; }
  const guardar = () => sessionStorage.setItem(clave, JSON.stringify(guardados.slice(-MAX_GUARDADOS)));

  const burbuja = crearElemento("button", {
    clase: "kirof__burbuja",
    atributos: { type: "button", "aria-expanded": "false", "aria-controls": "kirof-panel", "aria-label": "Abrir el chat con KIRO, el asistente" },
  }, [imagenKiro("kirof__burbuja-imagen"), crearElemento("span", { clase: "kirof__burbuja-texto", texto: "¿Te ayudo?" })]);

  const mensajes = crearElemento("ol", { clase: "kirof__mensajes", atributos: { role: "log", "aria-live": "polite", "aria-label": "Conversación con KIRO" } });
  const sugerencias = crearElemento("div", { clase: "kirof__sugerencias", atributos: { "aria-label": "Preguntas sugeridas" } },
    SUGERIDAS.map((p) => crearElemento("button", { clase: "kirof__chip", texto: p, atributos: { type: "button", "data-pregunta": p } })));
  const entrada = crearElemento("input", { atributos: { type: "text", maxlength: 500, autocomplete: "off", placeholder: "Pregúntale a KIRO", "aria-label": "Escribe tu pregunta para KIRO" } });
  const enviar = crearElemento("button", { clase: "kirof__enviar", atributos: { type: "submit", "aria-label": "Enviar" } });
  enviar.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12l16-8-6 16-2.5-6.5z"/></svg>';
  const formulario = crearElemento("form", { clase: "kirof__formulario", atributos: { novalidate: true } }, [entrada, enviar]);
  const cerrar = crearElemento("button", { clase: "kirof__cerrar", texto: "×", atributos: { type: "button", "aria-label": "Cerrar el chat" } });
  const panel = crearElemento("section", { clase: "kirof__panel", atributos: { id: "kirof-panel", "aria-labelledby": "kirof-titulo", hidden: true } }, [
    crearElemento("header", { clase: "kirof__cabecera" }, [
      imagenKiro("kirof__avatar"),
      crearElemento("div", {}, [
        crearElemento("h2", { clase: "kirof__titulo", texto: "KIRO", atributos: { id: "kirof-titulo" } }),
        crearElemento("span", { clase: "kirof__subtitulo", texto: "Tu asistente de adopción" }),
      ]),
      cerrar,
    ]),
    mensajes, sugerencias, formulario,
  ]);
  document.body.append(crearElemento("div", { clase: "kirof" }, [panel, burbuja]));

  /* ----- Mensajes ----- */
  function pintar({ rol, texto, mascotas = [], reportes = [], enlace = null }) {
    const burbujaMsj = crearElemento("li", { clase: `kirof__mensaje kirof__mensaje--${rol}` }, [crearElemento("p", { texto })]);
    if (mascotas.length || reportes.length) {
      burbujaMsj.append(crearElemento("ul", { clase: "kirof__tarjetas", atributos: { "aria-label": "Mascotas y reportes que encontró KIRO" } },
        [...mascotas.map(tarjetaMascota), ...reportes.map(tarjetaReporte)]));
    }
    const destino = ENLACES[enlace];
    if (destino) burbujaMsj.append(crearElemento("a", { clase: "kirof__enlace", texto: `${destino.texto} →`, atributos: { href: rutaDesdeRaiz(destino.ruta) } }));
    mensajes.append(burbujaMsj);
    mensajes.scrollTop = mensajes.scrollHeight;
    return burbujaMsj;
  }
  function agregar(mensaje) {
    guardados.push(mensaje);
    guardar();
    pintar(mensaje);
    sugerencias.hidden = true;
  }

  pintar({ rol: "kiro", texto: `${SALUDO_KIRO} 🐾 Cuéntame cómo es tu hogar y te recomiendo una mascota, o pregúntame lo que quieras sobre adoptar o sobre mascotas perdidas.` });
  guardados.forEach(pintar);
  sugerencias.hidden = guardados.length > 0;

  let pensando = false;
  async function preguntar(texto) {
    const pregunta = texto.trim();
    if (pensando) return;
    if (!pregunta) { pintar({ rol: "kiro", texto: RESPUESTA_VACIA }); return; }
    // Historial para que KIRO recuerde la conversación (sin la pregunta actual)
    const historial = guardados.slice(-8).map((m) => ({ rol: m.rol === "kiro" ? "kiro" : "usuario", texto: m.texto }));
    agregar({ rol: "usuario", texto: pregunta });
    pensando = true;
    enviar.disabled = true;
    const escribiendo = pintar({ rol: "kiro", texto: "KIRO está pensando… 🐾" });
    escribiendo.classList.add("kirof__mensaje--pensando");
    try {
      const r = await post("/kiro", { mensaje: pregunta, historial });
      escribiendo.remove();
      agregar({ rol: "kiro", texto: r.respuesta, mascotas: r.mascotas || [], reportes: r.reportes || [], enlace: r.enlace || null });
    } catch (error) {
      escribiendo.remove();
      if (error.estado === 429) { agregar({ rol: "kiro", texto: error.message }); return; }
      // Sin conexión con la API: respuestas predefinidas
      const hallada = buscarRespuesta(pregunta);
      agregar(hallada ? { rol: "kiro", texto: hallada.respuesta, enlace: Object.keys(ENLACES).find((k) => ENLACES[k].ruta === hallada.enlace?.ruta) || null }
        : { rol: "kiro", texto: RESPUESTA_DESCONOCIDA });
    } finally {
      pensando = false;
      enviar.disabled = false;
    }
  }

  /* ----- Abrir y cerrar ----- */
  function abrir(abierto) {
    panel.hidden = !abierto;
    burbuja.setAttribute("aria-expanded", String(abierto));
    burbuja.classList.toggle("kirof__burbuja--abierta", abierto);
    document.documentElement.classList.toggle("kirof-abierto", abierto);
    if (abierto) { mensajes.scrollTop = mensajes.scrollHeight; entrada.focus(); } else burbuja.focus();
  }
  burbuja.addEventListener("click", () => abrir(panel.hidden));
  cerrar.addEventListener("click", () => abrir(false));
  panel.addEventListener("keydown", (e) => { if (e.key === "Escape") { e.preventDefault(); abrir(false); } });
  formulario.addEventListener("submit", (e) => {
    e.preventDefault();
    const texto = entrada.value;
    entrada.value = "";
    preguntar(texto);
  });
  sugerencias.addEventListener("click", (e) => {
    const chip = e.target.closest("[data-pregunta]");
    if (chip) { preguntar(chip.dataset.pregunta); entrada.focus(); }
  });
}
