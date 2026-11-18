/**
 * verificar-correo.js — Pantalla «Confirma tu correo»: el código de 6 dígitos que llega al registrarse.
 * Si el código es correcto, la API entrega la sesión y se entra directo.
 */
import { verificarCorreo, reenviarCodigoCorreo, leerCorreoPendiente } from "../../core/auth.js";
import { redirigirSiHaySesion, destinoDeSesion } from "../../core/router-guard.js";
import { irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError } from "../../core/utils.js";
import { iniciarCuentaAtras } from "./cuenta-atras.js";

if (!redirigirSiHaySesion()) iniciar();

function iniciar() {
  const formulario = document.getElementById("form-codigo");
  const alerta = document.getElementById("alerta");
  const campoCorreo = document.getElementById("campo-correo");
  const campoCodigo = document.getElementById("campo-codigo");
  const boton = document.getElementById("boton-confirmar");
  const reenviar = document.getElementById("boton-reenviar");

  // El correo viene del registro o del inicio de sesión; si no, se pide aquí
  const pendiente = leerCorreoPendiente();
  if (pendiente) {
    document.getElementById("correo-destino").textContent = pendiente;
  } else {
    document.getElementById("texto-destino").textContent = "Escribe tu correo y el código de 6 dígitos que te enviamos para activar tu cuenta.";
    campoCorreo.hidden = false;
  }
  const correo = () => pendiente || formulario.correo.value.trim();
  // Recién llegó un código: hay que esperar 1 minuto para pedir otro
  const espera = iniciarCuentaAtras(reenviar, "Reenviar código");
  if (pendiente) espera.iniciar(60);
  (pendiente ? formulario.codigo : formulario.correo).focus();

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const errorCorreo = pendiente ? "" : !esCorreoValido(correo()) ? "Escribe el correo con el que te registraste." : "";
    const codigo = formulario.codigo.value.replace(/\D/g, "");
    const errorCodigo = codigo.length === 6 ? "" : "El código tiene 6 dígitos.";
    marcarError(campoCorreo, errorCorreo);
    marcarError(campoCodigo, errorCodigo);
    if (errorCorreo || errorCodigo) return;

    boton.disabled = true;
    boton.textContent = "Confirmando…";
    const r = await verificarCorreo({ correo: correo(), codigo });
    boton.disabled = false;
    boton.textContent = "Confirmar y entrar";
    if (r.ok && r.sesion) {
      mostrarAlerta(alerta, "exito", "¡Listo! Tu correo quedó confirmado. Entrando…");
      setTimeout(() => irA(destinoDeSesion(r.sesion)), 900);
      return;
    }
    if (r.codigo === "ya-confirmado") { mostrarAlerta(alerta, "aviso", r.error); setTimeout(() => irA("pages/login.html"), 1600); return; }
    marcarError(campoCodigo, r.error || "No pudimos confirmar el código.");
    formulario.codigo.select();
  });

  reenviar.addEventListener("click", async () => {
    ocultarAlerta(alerta);
    if (!esCorreoValido(correo())) { marcarError(campoCorreo, "Escribe el correo con el que te registraste."); return; }
    reenviar.disabled = true;
    const r = await reenviarCodigoCorreo(correo());
    if (r.ok) {
      mostrarAlerta(alerta, "exito", "Te enviamos un código nuevo. El anterior ya no sirve.");
      espera.iniciar(r.esperaSegundos || 60);
    } else {
      mostrarAlerta(alerta, "error", r.error);
      espera.iniciar(r.datos?.esperaSegundos || 0);
    }
  });
}
