/**
 * reportar.js — Reportar mascota perdida/encontrada: cámara (getUserMedia) con captura en
 * <canvas>, vista previa y formulario. Si el permiso se deniega, se ofrece subir un archivo.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar, refrescarInsigniaCoincidencias } from "../../components/navbar.js";
import { iniciarCamara, detenerCamara, capturarFoto, ErrorCamara } from "../../components/camara.js";
import { crearReporte } from "../../core/servicios.js";
import { limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta, validarImagen } from "../../core/utils.js";

const sesion = requerirRol("usuario");

if (sesion) {
  montarNavbar({ sesion, activa: "reportar" });
  iniciarReportar();
}

function iniciarReportar() {
  const video = document.getElementById("video");
  const lienzo = document.getElementById("lienzo");
  const vista = document.getElementById("vista-previa");
  const mensaje = document.getElementById("camara-mensaje");
  const botonTomar = document.getElementById("boton-tomar");
  const botonRepetir = document.getElementById("boton-repetir");
  const botonReintentar = document.getElementById("boton-reintentar");
  const botonSubir = document.getElementById("boton-subir");
  const entradaArchivo = document.getElementById("entrada-archivo");
  const alertaCamara = document.getElementById("alerta-camara");
  const campoFoto = document.getElementById("campo-foto-reporte");

  const formulario = document.getElementById("formulario-reporte");
  const alerta = document.getElementById("alerta-reporte");
  const botonEnviar = document.getElementById("boton-enviar");
  const campos = {
    tipo: document.getElementById("campo-tipo"),
    descripcion: document.getElementById("campo-descripcion"),
    zona: document.getElementById("campo-zona"),
  };

  let foto = ""; // data URL de la foto tomada o subida

  /* ----- Estados de la cámara ----- */
  function mostrarMensaje(texto) { mensaje.textContent = texto; mensaje.hidden = !texto; }

  async function encender() {
    ocultarAlerta(alertaCamara);
    botonReintentar.hidden = true;
    mostrarMensaje("Solicitando acceso a la cámara…");
    botonTomar.disabled = true;
    try {
      await iniciarCamara(video);
      mostrarMensaje("");
      video.hidden = false;
      botonTomar.disabled = false;
    } catch (error) {
      const texto = error instanceof ErrorCamara ? error.message : "No pudimos iniciar la cámara.";
      mostrarMensaje("Cámara no disponible");
      mostrarAlerta(alertaCamara, "aviso", texto);
      botonReintentar.hidden = false; // el usuario puede volver a intentarlo o subir un archivo
    }
  }

  function mostrarFoto(dataUrl) {
    foto = dataUrl;
    vista.src = dataUrl;
    vista.hidden = false;
    video.hidden = true;
    botonTomar.hidden = true;
    botonRepetir.hidden = false;
    mostrarMensaje("");
    marcarError(campoFoto, "");
  }

  function repetir() {
    foto = "";
    vista.hidden = true; vista.removeAttribute("src");
    botonRepetir.hidden = true;
    botonTomar.hidden = false;
    entradaArchivo.value = "";
    encender();
  }

  /* ----- Eventos de la cámara ----- */
  botonTomar.addEventListener("click", () => {
    if (!video.videoWidth) return; // la cámara aún no entrega imagen
    mostrarFoto(capturarFoto(video, lienzo));
    detenerCamara(video); // apaga la luz de la cámara
  });
  botonRepetir.addEventListener("click", repetir);
  botonReintentar.addEventListener("click", encender);
  botonSubir.addEventListener("click", () => entradaArchivo.click());

  entradaArchivo.addEventListener("change", () => {
    const archivo = entradaArchivo.files[0];
    if (!archivo) return;
    const error = validarImagen(archivo);
    if (error) { marcarError(campoFoto, error); entradaArchivo.value = ""; return; }
    const lector = new FileReader();
    lector.onload = () => { detenerCamara(video); mostrarFoto(String(lector.result)); botonReintentar.hidden = true; ocultarAlerta(alertaCamara); };
    lector.readAsDataURL(archivo);
  });

  window.addEventListener("pagehide", () => detenerCamara(video)); // nunca dejar la cámara encendida

  /* ----- Formulario ----- */
  limpiarErroresAlEscribir(formulario);
  formulario.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    ocultarAlerta(alerta);
    const datos = new FormData(formulario);
    const tipo = datos.get("tipo");
    const descripcion = String(datos.get("descripcion")).trim();
    const zona = String(datos.get("zona")).trim();

    marcarError(campos.tipo, tipo ? "" : "Indica si la mascota está perdida o fue encontrada.");
    marcarError(campos.descripcion, descripcion.length >= 15 ? "" : "Describe a la mascota con al menos 15 caracteres (color, tamaño, señas).");
    marcarError(campos.zona, zona ? "" : "Indica la zona donde se perdió o se encontró.");
    marcarError(campoFoto, foto ? "" : "Toma una foto o sube un archivo.");

    if (!tipo || descripcion.length < 15 || !zona || !foto) {
      document.querySelector(".campo--error")?.scrollIntoView({ block: "center", behavior: "smooth" });
      return;
    }

    botonEnviar.disabled = true;
    const resultado = await crearReporte({ tipo, descripcion, zona, foto });
    botonEnviar.disabled = false;

    if (!resultado.ok) { mostrarAlerta(alerta, "error", "No pudimos enviar tu reporte. Inténtalo de nuevo."); return; }
    const n = resultado.coincidenciasNuevas;
    mostrarAlerta(alerta, "exito", n > 0
      ? `¡Reporte enviado! Encontramos ${n === 1 ? "1 posible coincidencia" : `${n} posibles coincidencias`}: revísalas en «Coincidencias».`
      : "¡Reporte enviado! Te avisaremos en «Coincidencias» si aparece una mascota parecida.");
    refrescarInsigniaCoincidencias();
    formulario.reset();
    repetir();
    alerta.scrollIntoView({ block: "center", behavior: "smooth" });
  });

  encender();
}
