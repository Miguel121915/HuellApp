/**
 * recuperar.js — «¿Olvidaste tu contraseña?» en dos pasos:
 *   1) el correo de la cuenta → la API manda un código de 6 dígitos (si la cuenta existe; no lo revela)
 *   2) el código + la contraseña nueva → se cambia y se vuelve al inicio de sesión
 */
import { pedirRecuperacion, confirmarRecuperacion } from "../../core/auth.js";
import { redirigirSiHaySesion } from "../../core/router-guard.js";
import { irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError } from "../../core/utils.js";
import { iniciarCuentaAtras } from "./cuenta-atras.js";

if (!redirigirSiHaySesion()) iniciar();

function iniciar() {
  const alerta = document.getElementById("alerta");
  const formCorreo = document.getElementById("form-correo");
  const formNueva = document.getElementById("form-nueva");
  const campo = (id) => document.getElementById(`campo-${id}`);
  const paso = document.getElementById("paso");
  const espera = iniciarCuentaAtras(document.getElementById("boton-reenviar"), "Reenviar código");
  let correo = "";

  function irAlPaso(numero) {
    formCorreo.hidden = numero !== 1;
    formNueva.hidden = numero !== 2;
    paso.textContent = `Paso ${numero} de 2`;
    (numero === 1 ? formCorreo.correo : formNueva.codigo).focus();
  }

  async function enviarCodigo() {
    const r = await pedirRecuperacion(correo);
    if (!r.ok) { mostrarAlerta(alerta, "error", r.error); espera.iniciar(r.datos?.esperaSegundos || 0); return false; }
    espera.iniciar(r.esperaSegundos || 60);
    return true;
  }

  formCorreo.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    correo = formCorreo.correo.value.trim();
    const error = esCorreoValido(correo) ? "" : "Escribe un correo válido, por ejemplo nombre@correo.com.";
    marcarError(campo("correo"), error);
    if (error) return;
    const boton = document.getElementById("boton-enviar");
    boton.disabled = true;
    boton.textContent = "Enviando…";
    const ok = await enviarCodigo();
    boton.disabled = false;
    boton.textContent = "Enviar código";
    if (!ok) return;
    document.getElementById("correo-destino").textContent = correo;
    irAlPaso(2);
  });

  formNueva.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const codigo = formNueva.codigo.value.replace(/\D/g, "");
    const password = formNueva.password.value;
    const errores = {
      codigo: codigo.length === 6 ? "" : "El código tiene 6 dígitos.",
      password: password.length >= 8 ? "" : "La contraseña debe tener al menos 8 caracteres.",
      confirmar: formNueva.confirmar.value === password ? "" : "Las contraseñas no coinciden.",
    };
    Object.entries(errores).forEach(([id, msg]) => marcarError(campo(id), msg));
    if (Object.values(errores).some(Boolean)) return;

    const boton = document.getElementById("boton-cambiar");
    boton.disabled = true;
    boton.textContent = "Cambiando…";
    const r = await confirmarRecuperacion({ correo, codigo, password });
    boton.disabled = false;
    boton.textContent = "Cambiar contraseña";
    if (!r.ok) {
      if (r.codigo === "codigo-incorrecto" || r.codigo === "codigo-vencido") marcarError(campo("codigo"), r.error);
      else mostrarAlerta(alerta, "error", r.error);
      return;
    }
    formNueva.hidden = true;
    paso.textContent = "Listo";
    mostrarAlerta(alerta, "exito", "Tu contraseña cambió. Te llevamos al inicio de sesión…");
    setTimeout(() => irA("pages/login.html"), 1800);
  });

  document.getElementById("boton-reenviar").addEventListener("click", async () => {
    ocultarAlerta(alerta);
    if (await enviarCodigo()) mostrarAlerta(alerta, "exito", "Si la cuenta existe, te enviamos un código nuevo. El anterior ya no sirve.");
  });
  document.getElementById("boton-otro-correo").addEventListener("click", () => { ocultarAlerta(alerta); irAlPaso(1); });

  irAlPaso(1);
}
