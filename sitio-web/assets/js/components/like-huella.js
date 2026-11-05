/**
 * like-huella.js — Botón de "me gusta" con forma de HUELLA de perro.
 * Un clic suma +1 y colorea la huella; otro clic lo quita (toggle).
 * Usa delegación de eventos: un solo listener en el contenedor, no uno por botón.
 */

const SVG_HUELLA = `<svg class="like-huella__icono" viewBox="0 0 64 64" aria-hidden="true" focusable="false"><g fill="currentColor"><ellipse cx="32" cy="43" rx="14" ry="11"/><ellipse cx="13" cy="29" rx="6" ry="8" transform="rotate(-22 13 29)"/><ellipse cx="25" cy="16" rx="6" ry="9" transform="rotate(-8 25 16)"/><ellipse cx="39" cy="16" rx="6" ry="9" transform="rotate(8 39 16)"/><ellipse cx="51" cy="29" rx="6" ry="8" transform="rotate(22 51 29)"/></g></svg>`;

/** Crea el botón. `base` es el total SIN contar el "me gusta" del usuario actual. */
export function crearBotonLike({ id, base = 0, activo = false }) {
  const boton = document.createElement("button");
  boton.type = "button";
  boton.className = "like-huella";
  boton.dataset.likeId = id;
  boton.dataset.base = String(base);
  boton.innerHTML = `${SVG_HUELLA}<span class="like-huella__cuenta"></span>`; // contenido estático y de confianza
  actualizarBotonLike(boton, activo);
  return boton;
}

/** Refleja el estado (activo/inactivo) y el total en el botón. */
export function actualizarBotonLike(boton, activo) {
  const total = Number(boton.dataset.base) + (activo ? 1 : 0);
  boton.setAttribute("aria-pressed", String(activo));
  boton.setAttribute("aria-label", `Me gusta, ${total}`);
  boton.classList.toggle("like-huella--activo", activo);
  boton.querySelector(".like-huella__cuenta").textContent = String(total);
}

/**
 * Escucha los clics de todos los botones dentro de `contenedor`.
 * @param {(id:string, activo:boolean)=>Promise<{ok:boolean, activo:boolean}>} guardarLike
 */
export function escucharLikes(contenedor, guardarLike) {
  contenedor.addEventListener("click", async (evento) => {
    const boton = evento.target.closest(".like-huella");
    if (!boton || !contenedor.contains(boton)) return;

    const anterior = boton.getAttribute("aria-pressed") === "true";
    actualizarBotonLike(boton, !anterior); // respuesta inmediata
    const resultado = await guardarLike(boton.dataset.likeId, !anterior);
    actualizarBotonLike(boton, resultado.ok ? resultado.activo : anterior); // revierte si falló
  });
}
