/** registro-usuario.js — Alta de usuario normal. */
import { registrarUsuario } from "../../core/auth.js";
import { redirigirSiHaySesion } from "../../core/router-guard.js";
import { irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError } from "../../core/utils.js";

if (!redirigirSiHaySesion()) {
  const formulario = document.getElementById("form-registro");
  const alerta = document.getElementById("alerta");
  const boton = document.getElementById("boton-enviar");
  const campo = (nombre) => formulario.elements[nombre].closest(".campo");

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const f = formulario.elements;

    const errores = {
      nombre: f.nombre.value.trim().length < 3 ? "Escribe tu nombre completo." : "",
      correo: !esCorreoValido(f.correo.value.trim()) ? "Escribe un correo válido, por ejemplo nombre@correo.com." : "",
      telefono: f.telefono.value && !/^[\d\s+()-]{8,}$/.test(f.telefono.value) ? "Usa solo números, mínimo 8 dígitos." : "",
      password: f.password.value.length < 8 ? "Usa al menos 8 caracteres." : "",
      confirmar: f.confirmar.value !== f.password.value ? "Las contraseñas no coinciden." : "",
    };
    Object.entries(errores).forEach(([nombre, msg]) => marcarError(campo(nombre), msg));
    if (Object.values(errores).some(Boolean)) return;

    boton.disabled = true;
    const r = await registrarUsuario({
      nombre: f.nombre.value.trim(), correo: f.correo.value.trim(),
      telefono: f.telefono.value.trim(), password: f.password.value,
    });
    boton.disabled = false;

    if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
    mostrarAlerta(alerta, "exito", "Cuenta creada. Te llevamos al inicio de sesión…");
    setTimeout(() => irA("pages/login.html"), 1400);
  });
}
