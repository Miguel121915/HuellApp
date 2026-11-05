/**
 * asistente-adopcion.js — Botón flotante de ayuda + chat con KIRO dentro del formulario de adopción.
 *
 * Responde al instante con las preguntas frecuentes que dio de alta el refugio (y, si ninguna
 * sirve, con respuestas generales de HuellApp, señaladas como tales). Mientras el usuario
 * escribe, sugiere en tiempo real las preguntas que más se parecen a su duda.
 * Todo el texto entra con textContent (las respuestas las escribe el refugio).
 */
import { crearBuscador } from "../core/buscador-faq.js";
import { crearElemento, debounce, rutaDesdeRaiz } from "../core/utils.js";
import { PREGUNTAS_GENERALES, SALUDO_ASISTENTE, SIN_RESPUESTA } from "../data/preguntas-adopcion.js";

const SALUDO = /^\s*(hola|buen[oa]s?|que tal|hey|saludos)\b/i;
const GRACIAS = /\b(gracias|thank|perfecto|listo|ok|vale)\b/i;
const PAUSA_MS = 450; // pausa breve para que se sienta como conversación

/**
 * @param {HTMLElement} contenedor  Dónde se monta (el <dialog> del formulario)
 * @returns {{preparar:(datos:{refugio:string, telefono?:string, preguntas:object[]})=>void, cerrar:()=>void}}
 */
export function montarAsistente(contenedor) {
  let buscadorRefugio = crearBuscador([]);
  const buscadorGeneral = crearBuscador(PREGUNTAS_GENERALES);
  let preguntasRefugio = [];
  let refugio = "el refugio";
  let telefono = "";
  let temporizador;

  /* ----- Estructura ----- */
  const kiro = () => crearElemento("img", { clase: "asistente__avatar", atributos: { src: rutaDesdeRaiz("assets/img/kiro/kiro.svg"), alt: "", width: 36, height: 38 } });
  const boton = crearElemento("button", {
    clase: "asistente__boton",
    atributos: { type: "button", "aria-expanded": "false", "aria-controls": "asistente-panel", "aria-label": "¿Dudas? Pregúntale a KIRO, el asistente de adopción" },
  }, [kiro(), crearElemento("span", { texto: "¿Dudas? Pregúntale a KIRO" })]);

  const mensajes = crearElemento("ol", { clase: "asistente__mensajes", atributos: { role: "log", "aria-live": "polite", "aria-label": "Conversación con KIRO" } });
  const sugerencias = crearElemento("div", { clase: "asistente__sugerencias", atributos: { "aria-label": "Preguntas sugeridas" } });
  const vivas = crearElemento("ul", { clase: "asistente__vivas", atributos: { id: "asistente-vivas", "aria-label": "Preguntas parecidas a lo que escribes" } });
  const entrada = crearElemento("input", {
    clase: "campo__control",
    atributos: { type: "text", maxlength: 200, autocomplete: "off", placeholder: "Ej. ¿Sirve mi recibo de luz?", "aria-label": "Escribe tu duda", "aria-describedby": "asistente-vivas" },
  });
  const formulario = crearElemento("form", { clase: "asistente__formulario", atributos: { novalidate: true } }, [
    entrada,
    crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: "Enviar", atributos: { type: "submit" } }),
  ]);
  const cerrar = crearElemento("button", { clase: "asistente__cerrar", texto: "×", atributos: { type: "button", "aria-label": "Cerrar asistente" } });
  const titulo = crearElemento("span", { clase: "asistente__subtitulo", texto: "" });
  const panel = crearElemento("section", { clase: "asistente__panel", atributos: { id: "asistente-panel", "aria-labelledby": "asistente-titulo", hidden: true } }, [
    crearElemento("header", { clase: "asistente__cabecera" }, [
      kiro(),
      crearElemento("div", {}, [crearElemento("h2", { clase: "asistente__titulo", texto: "Asistente de adopción", atributos: { id: "asistente-titulo" } }), titulo]),
      cerrar,
    ]),
    mensajes, sugerencias, vivas, formulario,
  ]);
  contenedor.append(boton, panel);

  /* ----- Mensajes ----- */
  function agregar(quien, contenido, fuente = "") {
    const burbuja = crearElemento("li", { clase: `asistente__mensaje asistente__mensaje--${quien}` }, [].concat(contenido));
    if (fuente) burbuja.append(crearElemento("span", { clase: "asistente__fuente", texto: fuente }));
    mensajes.append(burbuja);
    mensajes.scrollTop = mensajes.scrollHeight;
    return burbuja;
  }

  const chips = (lista) => lista.map((p) => crearElemento("button", { clase: "asistente__chip", texto: p.pregunta, atributos: { type: "button", "data-pregunta": p.pregunta } }));

  function mostrarSugerencias() {
    const base = preguntasRefugio.length ? preguntasRefugio : PREGUNTAS_GENERALES;
    sugerencias.replaceChildren(...chips(base.slice(0, 4)));
  }

  /** Busca primero en las del refugio; si nada sirve, en las generales. */
  function resolver(texto) {
    const delRefugio = buscadorRefugio.buscar(texto);
    if (delRefugio.length) return { resultados: delRefugio, fuente: `Respuesta de ${refugio}` };
    const generales = buscadorGeneral.buscar(texto);
    if (generales.length) return { resultados: generales, fuente: "Respuesta general de HuellApp (confírmala con el refugio)" };
    return null;
  }

  function responder(texto) {
    clearTimeout(temporizador);
    if (!texto.trim()) return;
    agregar("usuario", document.createTextNode(texto));
    vivas.replaceChildren();
    const escribiendo = agregar("bot", crearElemento("span", { clase: "asistente__escribiendo", texto: "KIRO está escribiendo…" }));

    temporizador = setTimeout(() => {
      escribiendo.remove();
      const hallado = resolver(texto);
      if (hallado) {
        const [mejor, ...otras] = hallado.resultados;
        agregar("bot", [crearElemento("strong", { clase: "asistente__pregunta", texto: mejor.item.pregunta }), crearElemento("p", { texto: mejor.item.respuesta })], hallado.fuente);
        if (otras.length) agregar("bot", [crearElemento("span", { texto: "También te puede servir:" }), crearElemento("div", { clase: "asistente__relacionadas" }, chips(otras.map((o) => o.item)))]);
      } else if (SALUDO.test(texto)) {
        agregar("bot", document.createTextNode("¡Hola! 🐾 Pregúntame sobre los documentos, el comprobante de domicilio, las fotos del espacio o los requisitos de adopción."));
      } else if (GRACIAS.test(texto)) {
        agregar("bot", document.createTextNode("¡Con gusto! Si te surge otra duda, aquí estoy. Mucha suerte con tu solicitud 🐾"));
      } else {
        agregar("bot", [document.createTextNode(SIN_RESPUESTA), ...(telefono ? [crearElemento("a", { clase: "enlace asistente__llamar", texto: `Llamar a ${refugio}: ${telefono}`, atributos: { href: `tel:${telefono.replace(/\D/g, "")}` } })] : [])]);
      }
    }, PAUSA_MS);
  }

  /* ----- Sugerencias en tiempo real mientras se escribe ----- */
  const sugerirMientrasEscribe = debounce(() => {
    const texto = entrada.value;
    if (texto.trim().length < 3) { vivas.replaceChildren(); return; }
    const hallado = resolver(texto);
    vivas.replaceChildren(...(hallado ? [
      crearElemento("li", { clase: "asistente__vivas-titulo", texto: "¿Quieres preguntar…?" }),
      ...hallado.resultados.map((r) => crearElemento("li", {}, chips([r.item]))),
    ] : []));
  }, 200);

  /* ----- Eventos ----- */
  function abrir(abierto) {
    panel.hidden = !abierto;
    boton.setAttribute("aria-expanded", String(abierto));
    boton.classList.toggle("asistente__boton--abierto", abierto);
    if (abierto) entrada.focus();
    else boton.focus();
  }
  boton.addEventListener("click", () => abrir(panel.hidden));
  cerrar.addEventListener("click", () => abrir(false));
  panel.addEventListener("keydown", (e) => {
    if (e.key === "Escape") { e.stopPropagation(); e.preventDefault(); abrir(false); } // no cierra el formulario
  });
  entrada.addEventListener("input", sugerirMientrasEscribe);
  formulario.addEventListener("submit", (e) => {
    e.preventDefault();
    e.stopPropagation(); // es un formulario dentro del diálogo: no debe enviar la solicitud
    responder(entrada.value);
    entrada.value = "";
  });
  panel.addEventListener("click", (e) => {
    const chip = e.target.closest("[data-pregunta]");
    if (chip) { responder(chip.dataset.pregunta); entrada.focus(); }
  });

  return {
    /** Carga las preguntas del refugio y reinicia la conversación (al abrir el formulario de otra mascota). */
    preparar(datos) {
      refugio = datos.refugio || "el refugio";
      telefono = datos.telefono || "";
      preguntasRefugio = datos.preguntas || [];
      buscadorRefugio = crearBuscador(preguntasRefugio);
      titulo.textContent = refugio;
      mensajes.replaceChildren();
      vivas.replaceChildren();
      entrada.value = "";
      agregar("bot", document.createTextNode(SALUDO_ASISTENTE(refugio)));
      mostrarSugerencias();
      panel.hidden = true;
      boton.setAttribute("aria-expanded", "false");
      boton.classList.remove("asistente__boton--abierto");
    },
    cerrar: () => { clearTimeout(temporizador); panel.hidden = true; boton.setAttribute("aria-expanded", "false"); },
  };
}
