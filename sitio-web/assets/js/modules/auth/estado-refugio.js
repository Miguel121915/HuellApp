/**
 * estado-refugio.js — Mensaje para refugios pendientes, rechazados o suspendidos.
 * Un refugio aprobado que llegue aquí es redirigido a su panel.
 */
import { requerirRol, RUTA_INICIO_POR_ROL } from "../../core/router-guard.js";
import { refrescarSesion, cerrarSesion } from "../../core/auth.js";
import { irA } from "../../core/utils.js";

const sesion = requerirRol("refugio", { permitirRefugioNoVerificado: true });

const MENSAJES = {
  pendiente: { clase: "pendiente", etiqueta: "Pendiente de verificación", titulo: "Estamos revisando tus documentos", texto: "Un administrador validará tu solicitud. Cuando se apruebe podrás entrar a tu panel." },
  rechazado: { clase: "rechazado", etiqueta: "Solicitud rechazada", titulo: "Tu solicitud necesita cambios", texto: "" },
  suspendido: { clase: "rechazado", etiqueta: "Refugio suspendido", titulo: "Tu refugio está suspendido", texto: "Contacta a un administrador de HuellApp para conocer el motivo." },
};

/** Formulario de registro en modo apelación (el modo se indica con ?apelacion=1). */
const RUTA_APELACION = "pages/registro-refugio.html?apelacion=1";

if (sesion) {
  document.getElementById("boton-apelar").addEventListener("click", () => irA(RUTA_APELACION));
  document.getElementById("boton-actualizar").addEventListener("click", () => window.location.reload());
  document.getElementById("boton-salir").addEventListener("click", () => { cerrarSesion(); irA("pages/login.html"); });
  mostrarEstado();
}

/** Pide el estado actual al servidor (puede haber cambiado desde el último inicio de sesión). */
async function mostrarEstado() {
  let refugio = null;
  try {
    ({ refugio } = await refrescarSesion());
  } catch {
    refugio = { nombre: "", estado: sesion.refugioEstado, motivoRechazo: "" }; // sin conexión: se usa lo último que se supo
  }

  if (refugio?.estado === "aprobado") { irA(RUTA_INICIO_POR_ROL.refugio); return; }

  const m = MENSAJES[refugio?.estado] || MENSAJES.pendiente;
  const insignia = document.getElementById("estado-insignia");
  insignia.textContent = m.etiqueta;
  insignia.className = `insignia insignia--${m.clase}`;
  document.getElementById("estado-titulo").textContent = m.titulo;
  const motivo = refugio?.motivoRechazo ? `Motivo: ${refugio.motivoRechazo}` : "";
  document.getElementById("estado-texto").textContent =
    refugio?.estado === "rechazado" ? (motivo || "Motivo: no se indicó un motivo.") : [m.texto, motivo].filter(Boolean).join(" ");
  document.getElementById("estado-refugio-nombre").textContent = refugio?.nombre || "Tu refugio";

  // Rechazado: puede corregir y reenviar. Pendiente tras una apelación: se le confirma que se recibió.
  document.getElementById("boton-apelar").hidden = refugio?.estado !== "rechazado";
  const avisoApelacion = document.getElementById("estado-apelacion");
  if (refugio?.estado === "rechazado") {
    avisoApelacion.textContent = "Puedes corregir tus datos y reemplazar los documentos señalados con «Solicitar apelación». Tu solicitud volverá a revisión.";
    avisoApelacion.hidden = false;
  } else if (refugio?.estado === "pendiente" && refugio.apelaciones > 0) {
    document.getElementById("estado-titulo").textContent = "Recibimos tu apelación";
    document.getElementById("estado-texto").textContent = "Un administrador volverá a revisar tu solicitud con los cambios que enviaste. Cuando se apruebe podrás entrar a tu panel.";
    avisoApelacion.hidden = true;
  }
}
