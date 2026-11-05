/**
 * aviso-cuenta.js — Para el visitante (rol "invitado"): puede ver todas las secciones, pero al
 * intentar hacer algo (publicar, comentar, dar "me gusta", reportar, adoptar…) se le pide iniciar
 * sesión o crear una cuenta. Es lo mismo que hace la app móvil.
 *
 * Uso:
 *   protegerAcciones(sesion, {
 *     clics: [".like-huella", "#boton-subir"],          // botones que no puede usar
 *     envios: ["#formulario-publicar", ".comentarios__form"], // formularios que no puede enviar
 *     accion: "participar en el foro",
 *   });
 */
import { rutaDesdeRaiz, irA } from "../core/utils.js";

let dialogo = null;

function crearDialogo() {
  dialogo = document.createElement("dialog");
  dialogo.className = "modal aviso-cuenta";
  dialogo.setAttribute("aria-labelledby", "aviso-cuenta-titulo");
  dialogo.innerHTML = `
    <h2 id="aviso-cuenta-titulo" class="modal__titulo">Inicia sesión para continuar</h2>
    <p id="aviso-cuenta-texto"></p>
    <div class="modal__acciones">
      <button type="button" class="boton boton--contorno" data-aviso="cerrar">Ahora no</button>
      <a class="boton boton--secundario" data-aviso="registro">Crear cuenta</a>
      <a class="boton boton--primario" data-aviso="login">Iniciar sesión</a>
    </div>`;
  dialogo.querySelector('[data-aviso="login"]').href = rutaDesdeRaiz("pages/login.html");
  dialogo.querySelector('[data-aviso="registro"]').href = rutaDesdeRaiz("pages/registro-usuario.html");
  dialogo.querySelector('[data-aviso="cerrar"]').addEventListener("click", () => dialogo.close());
  document.body.append(dialogo);
}

/** Muestra el aviso. `accion` completa la frase "Para ___ necesitas una cuenta". */
export function pedirCuenta(accion = "hacer esto") {
  if (!dialogo) crearDialogo();
  dialogo.querySelector("#aviso-cuenta-texto").textContent =
    `Para ${accion} necesitas una cuenta de HuellApp. Es gratis y toma un minuto.`;
  if (typeof dialogo.showModal === "function") dialogo.showModal();
  else if (window.confirm(`Para ${accion} necesitas una cuenta. ¿Ir a iniciar sesión?`)) irA("pages/login.html");
}

/** Si la sesión es de visitante, bloquea los clics y envíos indicados y muestra el aviso. */
export function protegerAcciones(sesion, { clics = [], envios = [], accion = "hacer esto" } = {}) {
  if (sesion?.rol !== "invitado") return;
  const bloquear = (evento) => {
    evento.preventDefault();
    evento.stopImmediatePropagation();
    pedirCuenta(accion);
  };
  // Fase de captura: se atrapa antes que los listeners propios de la página
  if (clics.length) {
    document.addEventListener("click", (e) => {
      if (e.target.closest(clics.join(","))) bloquear(e);
    }, true);
  }
  if (envios.length) {
    document.addEventListener("submit", (e) => {
      if (e.target.closest(envios.join(","))) bloquear(e);
    }, true);
  }
}
