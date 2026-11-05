/**
 * perfil.js — Perfil del refugio: estado de verificación, datos de contacto editables,
 * datos que solo cambia un administrador y documentos registrados.
 */
import { requerirRol } from "../../core/router-guard.js";
import { obtenerMiRefugio } from "../../core/auth.js";
import { actualizarPerfil } from "../../core/servicios-refugio.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearElemento, ETIQUETAS_DOCUMENTO, formatearTamano, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta } from "../../core/utils.js";

const sesion = requerirRol("refugio");

const formulario = document.getElementById("formulario-perfil");
const alerta = document.getElementById("alerta-perfil");
const botonGuardar = document.getElementById("boton-guardar");
const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

if (sesion) {
  montarNavbar({ sesion, activa: "perfil" });
  mostrarPerfil();
  formulario.addEventListener("submit", guardar);
  limpiarErroresAlEscribir(formulario);
}

/** "09:00 - 18:00" → ["09:00", "18:00"] (con valores por defecto si el formato no coincide) */
function separarHorario(horario = "") {
  const m = horario.match(/(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})/);
  return m ? [m[1], m[2]] : ["09:00", "18:00"];
}

async function mostrarPerfil() {
  const refugio = await obtenerMiRefugio();
  document.getElementById("perfil-nombre").textContent = refugio.nombre;
  document.getElementById("dato-nombre").textContent = refugio.nombre;
  document.getElementById("dato-responsable").textContent = refugio.responsable;
  document.getElementById("dato-correo").textContent = refugio.correo;

  const insignia = document.getElementById("estado-insignia");
  insignia.textContent = "Refugio verificado";
  insignia.className = "insignia insignia--aprobado";

  const { elements: f } = formulario;
  const [apertura, cierre] = separarHorario(refugio.horario);
  f.telefono.value = refugio.telefono || "";
  f.direccion.value = refugio.direccion || "";
  f.horaApertura.value = apertura;
  f.horaCierre.value = cierre;
  f.descripcion.value = refugio.descripcion || "";

  const lista = document.getElementById("lista-documentos");
  const documentos = refugio.documentos || [];
  document.getElementById("sin-documentos").hidden = documentos.length > 0;
  lista.replaceChildren(...documentos.map((d) => crearElemento("li", { clase: "documento" }, [
    crearElemento("strong", { texto: ETIQUETAS_DOCUMENTO[d.tipo] || d.tipo }),
    crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${d.nombre} · ${formatearTamano(d.tamano)}` }),
  ])));
}

async function guardar(evento) {
  evento.preventDefault();
  ocultarAlerta(alerta);
  const f = formulario.elements;
  const telefono = f.telefono.value.trim();
  const direccion = f.direccion.value.trim();
  const descripcion = f.descripcion.value.trim();

  const errores = {
    telefono: telefono.replace(/\D/g, "").length === 10 ? "" : "Escribe un teléfono de 10 dígitos.",
    direccion: direccion.length >= 5 ? "" : "Escribe la dirección completa del refugio.",
    horario: f.horaCierre.value > f.horaApertura.value ? "" : "La hora de cierre debe ser posterior a la de apertura.",
    descripcion: descripcion.length <= 400 ? "" : "La descripción no puede pasar de 400 caracteres.",
  };
  Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(campo(nombre), mensaje));
  if (Object.values(errores).some(Boolean)) { formulario.querySelector(".campo--error .campo__control")?.focus(); return; }

  botonGuardar.disabled = true;
  const resultado = await actualizarPerfil({
    telefono, direccion, descripcion, horario: `${f.horaApertura.value} - ${f.horaCierre.value}`,
  });
  botonGuardar.disabled = false;

  if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error); return; }
  mostrarAlerta(alerta, "exito", "Perfil actualizado. Los usuarios ya ven tus nuevos datos de contacto.");
}
