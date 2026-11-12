/**
 * reportar.js — Reportar mascota perdida/encontrada: cámara (getUserMedia) con captura en
 * <canvas>, vista previa y formulario. Si el permiso se deniega, se ofrece subir un archivo.
 */
import { requerirRol } from "../../core/router-guard.js";
import { protegerAcciones } from "../../components/aviso-cuenta.js";
import { montarNavbar, refrescarInsigniaCoincidencias } from "../../components/navbar.js";
import { iniciarCamara, detenerCamara, capturarFoto, ErrorCamara } from "../../components/camara.js";
import { crearReporte } from "../../core/servicios.js";
import { montarMapaPunto } from "../../components/mapa-punto.js";
import { crearElemento, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta, resolverImagen, tiempoRelativo, validarImagen } from "../../core/utils.js";

const sesion = requerirRol("usuario") // el visitante va al login: solo puede ver las mascotas en adopción;
protegerAcciones(sesion, { envios: ["#formulario-reporte"], accion: "reportar una mascota" });

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
    especie: document.getElementById("campo-especie"),
    situacion: document.getElementById("campo-situacion"),
    descripcion: document.getElementById("campo-descripcion"),
    zona: document.getElementById("campo-zona"),
    fecha: document.getElementById("campo-fecha"),
  };

  let foto = ""; // data URL de la foto tomada o subida
  let camaraEncendida = false;

  /* ----- Paso 0: «Se me perdió» o «La encontré» (cada uno con su formulario) ----- */
  const eleccion = document.getElementById("eleccion-reporte");
  const pasos = document.getElementById("pasos-reporte");
  // Punto en el mapa: las coincidencias se buscan por distancia real
  const mapaPunto = montarMapaPunto(document.getElementById("mapa-reporte"), document.getElementById("texto-mapa"), document.getElementById("boton-mi-ubicacion"));
  const TEXTOS = {
    perdida: { titulo: "2. Datos de tu mascota", fecha: "¿Cuándo se perdió?", zona: "¿Dónde se perdió?", collar: "Collar, placa o chip", mapa: "Marca en el mapa dónde se perdió (recomendado)", boton: "Publicar alerta de búsqueda" },
    encontrada: { titulo: "2. Datos de la mascota que encontraste", fecha: "¿Cuándo la viste?", zona: "¿Dónde la encontraste?", collar: "¿Trae collar o placa? ¿Cómo es?", mapa: "Marca en el mapa dónde la encontraste (recomendado)", boton: "Publicar mascota encontrada" },
  };

  function elegir(tipo) {
    formulario.elements.tipo.value = tipo;
    const t = TEXTOS[tipo];
    document.getElementById("titulo-formulario").textContent = t.titulo;
    document.getElementById("etiqueta-fecha").textContent = t.fecha;
    document.getElementById("etiqueta-zona").textContent = t.zona;
    document.getElementById("etiqueta-collar").textContent = t.collar;
    document.getElementById("etiqueta-mapa").textContent = t.mapa;
    mapaPunto.ajustar();
    botonEnviar.textContent = t.boton;
    formulario.querySelectorAll("[data-solo]").forEach((el) => { el.hidden = el.dataset.solo !== tipo; });
    pasos.classList.toggle("reportar--perdida", tipo === "perdida");
    pasos.classList.toggle("reportar--encontrada", tipo === "encontrada");
    eleccion.hidden = true;
    pasos.hidden = false;
    history.replaceState(null, "", `?tipo=${tipo}`);
    if (!camaraEncendida) { camaraEncendida = true; encender(); } // la cámara se pide hasta elegir
    pasos.scrollIntoView({ block: "start", behavior: "smooth" });
  }

  eleccion.addEventListener("click", (e) => {
    const opcion = e.target.closest("[data-tipo]");
    if (opcion) elegir(opcion.dataset.tipo);
  });
  document.getElementById("cambiar-tipo").addEventListener("click", () => {
    pasos.hidden = true;
    eleccion.hidden = false;
    history.replaceState(null, "", "?");
  });
  // La fecha no puede ser futura
  document.getElementById("fecha").max = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16);

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
    const texto = (nombre) => String(datos.get(nombre) || "").trim();
    const descripcion = texto("descripcion");
    const zona = texto("zona");
    const especie = texto("especie");
    const situacion = tipo === "encontrada" ? texto("situacion") : "";
    const fechaLocal = texto("fecha");
    const fecha = fechaLocal ? new Date(fechaLocal) : null;

    const errores = {
      especie: especie ? "" : "Elige la especie.",
      situacion: tipo === "encontrada" && !situacion ? "Cuéntanos dónde está ahora la mascota." : "",
      descripcion: descripcion.length >= 10 ? "" : "Escribe al menos 10 caracteres: manchas, cicatrices, carácter…",
      zona: zona ? "" : (tipo === "perdida" ? "Indica dónde se perdió." : "Indica dónde la encontraste."),
      fecha: fecha && fecha.getTime() > Date.now() + 60000 ? "La fecha no puede ser futura." : "",
    };
    Object.entries(errores).forEach(([nombre, msg]) => marcarError(campos[nombre], msg));
    marcarError(campoFoto, foto ? "" : "Toma una foto o sube un archivo.");

    if (Object.values(errores).some(Boolean) || !foto) {
      document.querySelector(".campo--error")?.scrollIntoView({ block: "center", behavior: "smooth" });
      return;
    }
    const reporte = {
      tipo, descripcion, zona, foto, especie, situacion,
      nombre: tipo === "perdida" ? texto("nombre") : "",
      color: texto("color"), tamano: texto("tamano"), collar: texto("collar"),
      fecha: fecha ? fecha.toISOString() : "",
      ...(mapaPunto.leer() ?? {}),
      senaSecreta: tipo === "perdida" ? texto("senaSecreta") : "",
    };

    const enviar = async (datosExtra = {}) => {
      botonEnviar.disabled = true;
      const textoBoton = botonEnviar.textContent;
      botonEnviar.textContent = "Publicando…";
      const terminarAnalisis = mostrarAnalizando();
      try {
        return await crearReporte({ ...reporte, ...datosExtra });
      } finally {
        terminarAnalisis();
        botonEnviar.disabled = false;
        botonEnviar.textContent = textoBoton;
      }
    };
    let resultado = await enviar();

    // ¿Alguien ya reportó a esta mascota? La persona decide si es la misma o publica de todos modos
    if (!resultado.ok && resultado.codigo === "posible-duplicado") {
      const publicar = await preguntarDuplicado(tipo, resultado.datos.duplicados || []);
      if (!publicar) {
        mostrarAlerta(alerta, "aviso", "No publicamos tu reporte. Puedes comentar en la alerta que ya existe en el foro para sumar información.");
        alerta.scrollIntoView({ block: "center", behavior: "smooth" });
        return;
      }
      resultado = await enviar({ foto: resultado.datos.foto || foto, confirmarDuplicado: true });
    }

    if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error || "No pudimos enviar tu reporte. Inténtalo de nuevo."); return; }
    const n = resultado.coincidenciasNuevas;
    mostrarAlerta(alerta, "exito", "¡Tu alerta ya está publicada en el foro! "
      + (n > 0 ? `Por la descripción encontramos ${n === 1 ? "1 posible coincidencia" : `${n} posibles coincidencias`}. ` : "")
      + (resultado.iaPendiente
        ? "🤖 Ahora la IA está revisando la foto y comparándola con otros reportes; en uno o dos minutos verás el resultado en «Coincidencias»."
        : "Te avisaremos en «Coincidencias» si aparece una mascota parecida."));
    refrescarInsigniaCoincidencias();
    const tipoPublicado = tipo;
    formulario.reset();
    mapaPunto.limpiar();
    elegir(tipoPublicado); // deja el mismo formulario listo (por si reporta otra mascota)
    repetir();
    alerta.scrollIntoView({ block: "center", behavior: "smooth" });
  });

  // Desde el muro se llega con ?tipo=perdida o ?tipo=encontrada
  const tipoInicial = new URLSearchParams(location.search).get("tipo");
  if (TEXTOS[tipoInicial]) elegir(tipoInicial);
}

/* ----- Aviso mientras se publica el reporte (la IA trabaja después, en segundo plano) ----- */
const ETAPAS_ANALISIS = [
  "Subiendo la foto…",
  "Publicando tu alerta en el foro…",
  "Buscando coincidencias por descripción y zona…",
];

/** Muestra un recuadro con mensajes que avanzan por etapas; devuelve la función para quitarlo. */
function mostrarAnalizando() {
  const texto = document.createElement("p");
  texto.className = "analizando__texto";
  texto.setAttribute("role", "status");
  texto.setAttribute("aria-live", "polite");
  texto.textContent = ETAPAS_ANALISIS[0];
  const capa = document.createElement("div");
  capa.className = "analizando";
  capa.innerHTML = '<div class="analizando__caja"><span class="analizando__giro" aria-hidden="true"></span><p class="texto-pequeno texto-suave">Solo unos segundos. La IA revisará la foto después, sin que tengas que esperar.</p></div>';
  capa.querySelector(".analizando__caja").prepend(texto);
  document.body.append(capa);
  let etapa = 0;
  const reloj = setInterval(() => {
    etapa = Math.min(etapa + 1, ETAPAS_ANALISIS.length - 1);
    texto.textContent = ETAPAS_ANALISIS[etapa];
  }, 1500);
  return () => { clearInterval(reloj); capa.remove(); };
}

/* ----- Posible reporte duplicado (la misma mascota ya tiene una alerta) ----- */
/** Muestra los reportes parecidos y resuelve true si la persona quiere publicar de todos modos. */
function preguntarDuplicado(tipo, duplicados) {
  return new Promise((resolver) => {
    const dialogo = crearElemento("dialog", { clase: "modal modal--ancho duplicado", atributos: { "aria-labelledby": "duplicado-titulo" } });
    const cerrar = (valor) => { dialogo.close(); dialogo.remove(); resolver(valor); };
    const tarjetas = duplicados.map((d) => crearElemento("article", { clase: "duplicado__reporte" }, [
      d.foto ? crearElemento("img", { atributos: { src: resolverImagen(d.foto), alt: `Foto del reporte de ${d.autor}`, width: 120, height: 90 } }) : null,
      crearElemento("div", {}, [
        crearElemento("strong", { texto: d.nombre ? `${d.nombre} · ${d.tipo === "perdida" ? "perdida" : "encontrada"}` : (d.tipo === "perdida" ? "Mascota perdida" : "Mascota encontrada") }),
        crearElemento("p", { clase: "texto-pequeno", texto: d.descripcion }),
        crearElemento("p", { clase: "texto-pequeno texto-suave", texto: `Zona: ${d.zona} · Reportó ${d.autor} ${tiempoRelativo(d.fecha)}` }),
      ]),
    ]));
    const botonNo = crearElemento("button", { clase: "boton boton--primario", texto: "Es la misma, no publicar", atributos: { type: "button" } });
    const botonSi = crearElemento("button", { clase: "boton boton--contorno", texto: "Es otra mascota, publicar", atributos: { type: "button" } });
    botonNo.addEventListener("click", () => cerrar(false));
    botonSi.addEventListener("click", () => cerrar(true));
    dialogo.addEventListener("cancel", (e) => { e.preventDefault(); cerrar(false); });
    dialogo.append(
      crearElemento("h2", { clase: "modal__titulo", texto: "¿Ya reportaron a esta mascota?", atributos: { id: "duplicado-titulo" } }),
      crearElemento("p", { texto: tipo === "perdida"
        ? "Encontramos una alerta muy parecida (quizá la subió un familiar). Si es la misma mascota, no hace falta otra: comenta en esa alerta del foro para sumar información."
        : "Alguien ya reportó haber encontrado a una mascota muy parecida. Si es la misma, comenta en esa alerta del foro." }),
      ...tarjetas,
      crearElemento("div", { clase: "modal__acciones" }, [botonSi, botonNo]),
    );
    document.body.append(dialogo);
    dialogo.showModal();
    botonNo.focus();
  });
}
