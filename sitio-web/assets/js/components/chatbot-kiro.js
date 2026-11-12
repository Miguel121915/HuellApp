/**
 * chatbot-kiro.js — KIRO, el asistente de adopción (HU-7).
 * Pregunta a la API (POST /api/kiro): con IA (Gemini) contesta y recomienda mascotas REALES disponibles.
 * Si la API no responde, usa las respuestas predefinidas de mock-kiro.js (sin conexión).
 */
import { preguntasKiro, SALUDO_KIRO, RESPUESTA_VACIA, RESPUESTA_DESCONOCIDA } from "../data/mock-kiro.js";
import { normalizarTexto, crearElemento, rutaDesdeRaiz, resolverImagen } from "../core/utils.js";
import { post } from "../core/api.js";

/** Secciones a las que KIRO puede mandar a la persona. */
const ENLACES = {
  refugios: { texto: "Ver refugios y mascotas", ruta: "pages/usuario/refugios.html" },
  reportar: { texto: "Ir a Reportar", ruta: "pages/usuario/reportar.html" },
  coincidencias: { texto: "Ver mis coincidencias", ruta: "pages/usuario/coincidencias.html" },
  favoritos: { texto: "Ver mis favoritos", ruta: "pages/usuario/favoritos.html" },
  foro: { texto: "Ir al foro", ruta: "pages/usuario/foro.html" },
  mensajes: { texto: "Ver mis mensajes", ruta: "pages/usuario/mensajes.html" },
  solicitudes: { texto: "Ver refugios", ruta: "pages/usuario/refugios.html" },
};

const EDAD = (meses) => (meses < 12 ? `${meses} meses` : `${Math.floor(meses / 12)} año${Math.floor(meses / 12) === 1 ? "" : "s"}`);

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

/**
 * Conecta el formulario, el globo y las preguntas sugeridas.
 * @param {{formulario:HTMLFormElement, entrada:HTMLInputElement, globo:HTMLElement,
 *          enlace:HTMLAnchorElement, sugerencias:HTMLElement}} elementos
 */
export function montarChatbot({ formulario, entrada, globo, enlace, sugerencias }) {
  const historial = []; // [{rol:'usuario'|'kiro', texto}] para que KIRO recuerde la conversación
  let turno = 0;

  // Tarjetas de las mascotas que recomienda KIRO (debajo del globo)
  const recomendadas = crearElemento("ul", { clase: "kiro__mascotas", atributos: { "aria-label": "Mascotas que recomienda KIRO" } });
  enlace.after(recomendadas);

  function decir(texto, enlaceInfo = null, mascotas = []) {
    globo.textContent = texto;
    if (enlaceInfo) {
      enlace.textContent = enlaceInfo.texto;
      enlace.href = rutaDesdeRaiz(enlaceInfo.ruta);
      enlace.hidden = false;
    } else {
      enlace.hidden = true;
    }
    recomendadas.replaceChildren(...mascotas.map((m) => crearElemento("li", {}, crearElemento("a", {
      clase: "kiro__mascota",
      atributos: { href: `${rutaDesdeRaiz("pages/usuario/refugios.html")}?id=${encodeURIComponent(m.refugioId)}` },
    }, [
      crearElemento("img", { atributos: { src: resolverImagen(m.foto), alt: "", width: 56, height: 56, loading: "lazy" } }),
      crearElemento("span", {}, [
        crearElemento("strong", { texto: m.nombre }),
        crearElemento("small", { texto: `${m.raza} · ${EDAD(m.edadMeses)} · ${m.tamano}` }),
        crearElemento("small", { texto: m.refugioNombre }),
      ]),
    ]))));
  }

  async function preguntar(texto) {
    const pregunta = texto.trim();
    if (!pregunta) { decir(RESPUESTA_VACIA); return; }
    const mio = ++turno;
    decir("Pensando… 🐾");
    try {
      const r = await post("/kiro", { mensaje: pregunta, historial: historial.slice(-8) });
      if (mio !== turno) return; // llegó una pregunta más nueva
      historial.push({ rol: "usuario", texto: pregunta }, { rol: "kiro", texto: r.respuesta });
      decir(r.respuesta, ENLACES[r.enlace] || null, r.mascotas || []);
    } catch (error) {
      if (mio !== turno) return;
      if (error.estado === 429) { decir(error.message); return; }
      // Sin conexión con la API: respuestas predefinidas
      const hallada = buscarRespuesta(pregunta);
      if (hallada) decir(hallada.respuesta, hallada.enlace);
      else decir(RESPUESTA_DESCONOCIDA);
    }
  }

  formulario.addEventListener("submit", (evento) => {
    evento.preventDefault();
    preguntar(entrada.value);
    entrada.value = "";
  });

  // Preguntas frecuentes como botones (delegación de eventos)
  const fragmento = document.createDocumentFragment();
  [{ pregunta: "Recomiéndame una mascota para un departamento" }, ...preguntasKiro.filter((p) => !p.oculta).slice(0, 5)].forEach((p) => {
    const li = crearElemento("li", {}, crearElemento("button", { clase: "chip", texto: p.pregunta, atributos: { type: "button", "data-pregunta": p.pregunta } }));
    fragmento.append(li);
  });
  sugerencias.append(fragmento);
  sugerencias.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-pregunta]");
    if (!boton) return;
    preguntar(boton.dataset.pregunta);
  });

  decir(SALUDO_KIRO);
}
