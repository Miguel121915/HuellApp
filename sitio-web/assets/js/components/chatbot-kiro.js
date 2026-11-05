/**
 * chatbot-kiro.js — Chatbot simulado KIRO (respuestas predefinidas).
 * Busca palabras clave en la pregunta y muestra la respuesta en el globo de diálogo.
 */
import { preguntasKiro, SALUDO_KIRO, RESPUESTA_VACIA, RESPUESTA_DESCONOCIDA } from "../data/mock-kiro.js";
import { normalizarTexto, crearElemento, rutaDesdeRaiz } from "../core/utils.js";

/** Devuelve la pregunta frecuente que mejor coincide, o null si ninguna. */
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

/**
 * Conecta el formulario, el globo y las preguntas sugeridas.
 * @param {{formulario:HTMLFormElement, entrada:HTMLInputElement, globo:HTMLElement,
 *          enlace:HTMLAnchorElement, sugerencias:HTMLElement}} elementos
 */
export function montarChatbot({ formulario, entrada, globo, enlace, sugerencias }) {
  let temporizador;

  function decir(texto, enlaceInfo = null) {
    globo.textContent = texto;
    if (enlaceInfo) {
      enlace.textContent = enlaceInfo.texto;
      enlace.href = rutaDesdeRaiz(enlaceInfo.ruta);
      enlace.hidden = false;
    } else {
      enlace.hidden = true;
    }
  }

  function preguntar(texto) {
    clearTimeout(temporizador);
    if (!texto.trim()) { decir(RESPUESTA_VACIA); return; }
    decir("Pensando…");
    temporizador = setTimeout(() => {
      const hallada = buscarRespuesta(texto);
      if (hallada) decir(hallada.respuesta, hallada.enlace);
      else decir(RESPUESTA_DESCONOCIDA);
    }, 350); // pequeña pausa para que se sienta como una conversación
  }

  formulario.addEventListener("submit", (evento) => {
    evento.preventDefault();
    preguntar(entrada.value);
  });

  // Preguntas frecuentes como botones (delegación de eventos)
  const fragmento = document.createDocumentFragment();
  preguntasKiro.filter((p) => !p.oculta).slice(0, 6).forEach((p) => {
    const li = crearElemento("li", {}, crearElemento("button", { clase: "chip", texto: p.pregunta, atributos: { type: "button", "data-pregunta": p.pregunta } }));
    fragmento.append(li);
  });
  sugerencias.append(fragmento);
  sugerencias.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-pregunta]");
    if (!boton) return;
    entrada.value = boton.dataset.pregunta;
    preguntar(boton.dataset.pregunta);
  });

  decir(SALUDO_KIRO);
}
