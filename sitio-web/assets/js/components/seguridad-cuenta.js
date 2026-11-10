/**
 * seguridad-cuenta.js — Ventana «Seguridad» (botón del encabezado, todos los roles con cuenta):
 * activar o quitar la verificación en dos pasos con Google Authenticator.
 *
 * Activar: la API genera un secreto → se muestra como código QR (y como clave para escribirla a mano)
 * → la persona lo escanea en Google Authenticator → escribe el código de 6 dígitos para confirmar.
 * El QR se dibuja en el navegador: el secreto nunca se manda a otro sitio.
 */
import { estado2fa, preparar2fa, activar2fa, desactivar2fa } from "../core/auth.js";
import { rutaDesdeRaiz } from "../core/utils.js";

const LIBRERIA_QR = "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js";
let dialogo = null;

function cargarEstilos() {
  for (const archivo of ["assets/css/components/modal.css", "assets/css/components/seguridad.css"]) {
    const href = rutaDesdeRaiz(archivo);
    if ([...document.styleSheets].some((h) => h.href && h.href.endsWith(archivo))) continue;
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = href;
    document.head.append(link);
  }
}

function cargarLibreriaQr() {
  if (window.qrcode) return Promise.resolve(true);
  return new Promise((resolver) => {
    const script = document.createElement("script");
    script.src = LIBRERIA_QR;
    script.onload = () => resolver(Boolean(window.qrcode));
    script.onerror = () => resolver(false);
    document.head.append(script);
  });
}

function crearDialogo() {
  cargarEstilos();
  dialogo = document.createElement("dialog");
  dialogo.className = "modal seguridad";
  dialogo.setAttribute("aria-labelledby", "seguridad-titulo");
  dialogo.innerHTML = `
    <h2 id="seguridad-titulo" class="modal__titulo">Seguridad de tu cuenta</h2>
    <div id="seguridad-alerta" role="alert" hidden></div>
    <div id="seguridad-contenido"><p>Cargando…</p></div>
    <div class="modal__acciones">
      <button type="button" class="boton boton--contorno" data-seguridad="cerrar">Cerrar</button>
    </div>`;
  dialogo.querySelector('[data-seguridad="cerrar"]').addEventListener("click", () => dialogo.close());
  document.body.append(dialogo);
}

const contenido = () => dialogo.querySelector("#seguridad-contenido");

function alerta(tipo, mensaje) {
  const zona = dialogo.querySelector("#seguridad-alerta");
  if (!mensaje) { zona.hidden = true; zona.textContent = ""; return; }
  zona.className = `alerta alerta--${tipo}`;
  zona.textContent = mensaje;
  zona.hidden = false;
}

/** Formulario de un código de 6 dígitos; `alEnviar(codigo)` devuelve { ok, error }. */
function formularioCodigo(textoBoton, alEnviar) {
  const form = document.createElement("form");
  form.className = "seguridad__codigo";
  form.noValidate = true;
  form.innerHTML = `
    <label class="campo__etiqueta" for="seguridad-codigo">Código de 6 dígitos</label>
    <div class="seguridad__fila">
      <input class="campo__control campo__control--codigo" id="seguridad-codigo" name="codigo" type="text" inputmode="numeric" autocomplete="one-time-code" maxlength="7" placeholder="123456">
      <button class="boton boton--primario" type="submit"></button>
    </div>`;
  const boton = form.querySelector("button");
  boton.textContent = textoBoton;
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const codigo = form.codigo.value.replace(/\s+/g, "");
    if (!/^\d{6}$/.test(codigo)) { alerta("error", "Escribe los 6 dígitos que muestra Google Authenticator."); return; }
    boton.disabled = true;
    const r = await alEnviar(codigo);
    boton.disabled = false;
    if (!r.ok) { alerta("error", r.error); form.codigo.select(); }
  });
  return form;
}

function mostrarInactivo() {
  alerta();
  const zona = contenido();
  zona.innerHTML = `
    <p><strong>Verificación en dos pasos: desactivada.</strong></p>
    <p>Al activarla, además de tu contraseña (o de tu cuenta de Google) te pediremos un código de 6 dígitos
      de la app <strong>Google Authenticator</strong> de tu teléfono. Así nadie entra a tu cuenta aunque sepa tu contraseña.</p>
    <button type="button" class="boton boton--primario" id="seguridad-activar">Activar</button>`;
  zona.querySelector("#seguridad-activar").addEventListener("click", mostrarConfiguracion);
}

async function mostrarConfiguracion() {
  alerta();
  contenido().innerHTML = "<p>Generando tu código QR…</p>";
  let datos;
  try {
    datos = await preparar2fa();
  } catch (error) {
    alerta("error", error.message);
    return;
  }
  const hayQr = await cargarLibreriaQr();
  const zona = contenido();
  zona.innerHTML = `
    <ol class="seguridad__pasos">
      <li>Instala <strong>Google Authenticator</strong> en tu teléfono (Android o iPhone).</li>
      <li>En la app toca <strong>+</strong> → <strong>Escanear un código QR</strong> y apunta a este código:</li>
    </ol>
    <div class="seguridad__qr" id="seguridad-qr"></div>
    <p class="texto-pequeno">¿No puedes escanear? Elige <strong>Introducir clave de configuración</strong> y escribe:</p>
    <p class="seguridad__clave" id="seguridad-clave"></p>
    <ol class="seguridad__pasos" start="3"><li>Escribe el código que aparece en la app para confirmar:</li></ol>`;
  zona.querySelector("#seguridad-clave").textContent = datos.secreto.replace(/(.{4})/g, "$1 ").trim();
  const qr = zona.querySelector("#seguridad-qr");
  if (hayQr) {
    const generador = window.qrcode(0, "M");
    generador.addData(datos.enlace);
    generador.make();
    qr.innerHTML = generador.createSvgTag({ cellSize: 5, margin: 2, scalable: true }); // SVG creado aquí mismo, sin datos de terceros
    qr.querySelector("svg")?.setAttribute("aria-label", "Código QR para Google Authenticator");
  } else {
    qr.textContent = "No se pudo dibujar el código QR (¿sin internet?). Usa la clave de abajo.";
  }
  zona.append(formularioCodigo("Activar", async (codigo) => {
    const r = await activar2fa(codigo);
    if (r.ok) {
      mostrarActivo();
      alerta("exito", "¡Listo! La próxima vez que inicies sesión te pediremos el código de Google Authenticator.");
    }
    return r;
  }));
  zona.querySelector("#seguridad-codigo").focus();
}

function mostrarActivo() {
  alerta();
  const zona = contenido();
  zona.innerHTML = `
    <p><strong>Verificación en dos pasos: activada ✔</strong></p>
    <p>Cada vez que inicies sesión te pediremos el código de Google Authenticator.</p>
    <details class="seguridad__quitar">
      <summary>Desactivar o cambiar de teléfono</summary>
      <p class="texto-pequeno">Escribe un código vigente para confirmar que eres tú. Después podrás activarla de nuevo con otro teléfono.</p>
    </details>`;
  zona.querySelector(".seguridad__quitar").append(formularioCodigo("Desactivar", async (codigo) => {
    const r = await desactivar2fa(codigo);
    if (r.ok) {
      mostrarInactivo();
      alerta("aviso", "Desactivaste la verificación en dos pasos. Puedes borrar HuellApp de Google Authenticator.");
    }
    return r;
  }));
}

/** Abre la ventana de seguridad. */
export async function abrirSeguridad() {
  if (!dialogo) crearDialogo();
  alerta();
  contenido().innerHTML = "<p>Cargando…</p>";
  dialogo.showModal();
  try {
    (await estado2fa()) ? mostrarActivo() : mostrarInactivo();
  } catch (error) {
    alerta("error", error.message);
  }
}
