/**
 * perfil.js — Mi perfil (usuario): datos de la cuenta (solo lectura), mi actividad y los datos
 * editables (teléfono, ciudad y datos del hogar). Son los mismos que en la app móvil.
 * El nombre y el correo no se editan: identifican la cuenta.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { obtenerMiPerfil, actualizarMiPerfil } from "../../core/servicios.js";
import { formatearFecha, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";

const MAX_SOBRE_MI = 300;

const sesion = requerirRol("usuario");
const contenedor = document.getElementById("perfil");
const alertaCarga = document.getElementById("alerta-carga");
const formulario = document.getElementById("formulario-perfil");
const alerta = document.getElementById("alerta-perfil");
const botonGuardar = document.getElementById("boton-guardar");
const contador = document.getElementById("contador-sobre-mi");
const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

if (sesion) {
  montarNavbar({ sesion, activa: "perfil" });
  formulario.addEventListener("submit", guardar);
  formulario.elements.sobreMi.addEventListener("input", contar);
  limpiarErroresAlEscribir(formulario);
  document.getElementById("boton-seguridad").addEventListener("click", async () => {
    const { abrirSeguridad } = await import("../../components/seguridad-cuenta.js");
    await abrirSeguridad();
    // Al cerrar la ventana se vuelve a leer el perfil, por si activó o quitó la verificación en dos pasos
    document.querySelector("dialog.seguridad")?.addEventListener("close", cargar, { once: true });
  });
  cargar();
}

async function cargar() {
  try {
    const { perfil, actividad } = await obtenerMiPerfil();
    mostrarCuenta(perfil, actividad);
    rellenar(perfil);
    ocultarAlerta(alertaCarga);
    contenedor.hidden = false;
  } catch (error) {
    mostrarAlerta(alertaCarga, "error", error.message);
  }
}

const texto = (id, valor) => { document.getElementById(id).textContent = valor; };

function mostrarCuenta(perfil, actividad) {
  const iniciales = perfil.nombre.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join("");
  texto("avatar", iniciales || "🐾");
  texto("titulo-cuenta", perfil.nombre);
  texto("miembro-desde", perfil.miembroDesde ? `En HuellApp desde el ${formatearFecha(perfil.miembroDesde)}` : "");
  texto("dato-nombre", perfil.nombre);
  texto("dato-correo", perfil.correo);
  texto("dato-acceso", perfil.conGoogle ? "Contraseña o cuenta de Google" : "Correo y contraseña");

  const dosPasos = document.getElementById("dato-2fa");
  dosPasos.textContent = perfil.dosPasos ? "Activada" : "Desactivada";
  dosPasos.className = `insignia insignia--${perfil.dosPasos ? "aprobado" : "pendiente"}`;

  texto("cuenta-reportes", String(actividad.reportes));
  texto("cuenta-favoritos", String(actividad.favoritos));
  texto("cuenta-solicitudes", String(actividad.solicitudes));
  texto("cuenta-publicaciones", String(actividad.publicaciones));
}

function rellenar(perfil) {
  const f = formulario.elements;
  f.telefono.value = perfil.telefono || "";
  f.ciudad.value = perfil.ciudad || "";
  f.ocupacion.value = perfil.ocupacion || "";
  f.tipoVivienda.value = perfil.tipoVivienda || "";
  f.otrasMascotas.value = perfil.otrasMascotas || "";
  f.sobreMi.value = perfil.sobreMi || "";
  contar();
}

function contar() {
  contador.textContent = `${formulario.elements.sobreMi.value.length}/${MAX_SOBRE_MI}`;
}

/** Mismas reglas que el servidor (que de todos modos vuelve a revisar todo). */
function validar(datos) {
  const largoEntre = (valor, min) => valor === "" || valor.length >= min;
  return {
    telefono: datos.telefono === "" || /^[\d\s+()-]{8,}$/.test(datos.telefono) ? "" : "Usa solo números, espacios, + - y paréntesis (mínimo 8).",
    ciudad: largoEntre(datos.ciudad, 2) ? "" : "Escribe al menos 2 letras.",
    ocupacion: largoEntre(datos.ocupacion, 2) ? "" : "Escribe al menos 2 letras.",
    sobreMi: datos.sobreMi.length <= MAX_SOBRE_MI ? "" : `Máximo ${MAX_SOBRE_MI} caracteres.`,
  };
}

async function guardar(evento) {
  evento.preventDefault();
  ocultarAlerta(alerta);
  const f = formulario.elements;
  const datos = {
    telefono: f.telefono.value.trim(),
    ciudad: f.ciudad.value.trim(),
    ocupacion: f.ocupacion.value.trim(),
    tipoVivienda: f.tipoVivienda.value,
    otrasMascotas: f.otrasMascotas.value.trim(),
    sobreMi: f.sobreMi.value.trim(),
  };
  const errores = validar(datos);
  Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(campo(nombre), mensaje));
  if (Object.values(errores).some(Boolean)) { formulario.querySelector(".campo--error .campo__control")?.focus(); return; }

  botonGuardar.disabled = true;
  const resultado = await actualizarMiPerfil(datos);
  botonGuardar.disabled = false;

  if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error); return; }
  mostrarCuenta(resultado.perfil, resultado.actividad);
  rellenar(resultado.perfil);
  mostrarAlerta(alerta, "exito", "¡Listo! Guardamos los cambios de tu perfil.");
}
