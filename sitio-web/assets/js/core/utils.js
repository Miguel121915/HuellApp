/**
 * utils.js — Utilidades compartidas.
 */

import { API_ORIGEN } from "./config.js";

/** Carpeta raíz del proyecto, calculada desde este módulo (assets/js/core/). */
const RAIZ = new URL("../../../", import.meta.url);

/** Devuelve la URL absoluta de una ruta relativa a la raíz. Ej: rutaDesdeRaiz("pages/login.html") */
export function rutaDesdeRaiz(ruta) {
  return new URL(ruta, RAIZ).href;
}

/** Redirige sin dejar la página actual en el historial. */
export function irA(ruta) {
  window.location.replace(rutaDesdeRaiz(ruta));
}

/** Retrasa la ejecución hasta que el usuario deja de escribir (buscadores/filtros). */
export function debounce(fn, espera = 300) {
  let temporizador;
  return (...args) => {
    clearTimeout(temporizador);
    temporizador = setTimeout(() => fn(...args), espera);
  };
}

export function esCorreoValido(valor) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(valor);
}

export function formatearTamano(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/** Muestra un mensaje en un contenedor de alerta. tipo: error | exito | aviso */
export function mostrarAlerta(contenedor, tipo, mensaje) {
  contenedor.className = `alerta alerta--${tipo}`;
  contenedor.textContent = mensaje; // textContent evita inyección de HTML
  contenedor.hidden = false;
}

export function ocultarAlerta(contenedor) {
  contenedor.hidden = true;
  contenedor.textContent = "";
}

/** Marca o limpia el error de un campo. `campo` es el contenedor .campo */
export function marcarError(campo, mensaje) {
  campo.classList.toggle("campo--error", Boolean(mensaje));
  const zona = campo.querySelector(".campo__error");
  if (zona) zona.textContent = mensaje || "";
  const control = campo.querySelector(".campo__control");
  if (control) control.setAttribute("aria-invalid", mensaje ? "true" : "false");
}

/* ---------- Helpers añadidos en la Fase 2 ---------- */

/**
 * Crea un elemento DOM sin usar innerHTML (evita inyección de HTML con texto de usuarios).
 * @param {string} etiqueta  Ej: "div"
 * @param {{clase?:string, texto?:string, atributos?:Record<string,any>}} opciones
 * @param {Node|Node[]} hijos
 */
export function crearElemento(etiqueta, opciones = {}, hijos = []) {
  const { clase, texto, atributos = {} } = opciones;
  const nodo = document.createElement(etiqueta);
  if (clase) nodo.className = clase;
  if (texto !== undefined) nodo.textContent = texto;
  for (const [nombre, valor] of Object.entries(atributos)) {
    if (valor === false || valor === null || valor === undefined) continue;
    nodo.setAttribute(nombre, valor === true ? "" : String(valor));
  }
  nodo.append(...[].concat(hijos).filter(Boolean));
  return nodo;
}

/** Minúsculas, sin acentos y sin espacios extra: para buscar y comparar texto. */
export function normalizarTexto(texto = "") {
  return texto.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();
}

/**
 * Resuelve la URL de una imagen según de dónde venga:
 *  - blob:/data:/http(s) .......... se usa tal cual
 *  - /uploads/... ................. fotos subidas: viven en el servidor (API)
 *  - assets/... ................... ilustraciones incluidas en el sitio
 */
export function resolverImagen(src) {
  if (!src) return "";
  if (/^(blob:|data:|https?:)/.test(src)) return src;
  if (src.startsWith("/uploads/")) return API_ORIGEN + src;
  return rutaDesdeRaiz(src);
}

export function formatearEdad(meses) {
  if (meses < 12) return `${meses} ${meses === 1 ? "mes" : "meses"}`;
  const anios = Math.floor(meses / 12);
  return `${anios} ${anios === 1 ? "año" : "años"}`;
}

/** "hace 3 h", "hace 2 días"... */
export function tiempoRelativo(iso) {
  const minutos = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
  if (minutos < 1) return "ahora mismo";
  if (minutos < 60) return `hace ${minutos} min`;
  const horas = Math.round(minutos / 60);
  if (horas < 24) return `hace ${horas} h`;
  const dias = Math.round(horas / 24);
  return `hace ${dias} ${dias === 1 ? "día" : "días"}`;
}

/** Devuelve un mensaje de error si el archivo no es una imagen válida; "" si todo está bien. */
export function validarImagen(archivo, maxMB = 5) {
  if (!archivo) return "Selecciona una imagen.";
  if (!archivo.type.startsWith("image/")) return "El archivo debe ser una imagen (JPG, PNG o WebP).";
  if (archivo.size > maxMB * 1024 * 1024) return `La imagen pesa más de ${maxMB} MB.`;
  return "";
}

/** Fecha ISO de hace `horas` horas (para que los mocks siempre se vean recientes). */
export const haceHoras = (horas) => new Date(Date.now() - horas * 3600 * 1000).toISOString();

/**
 * Reduce una imagen a `maxLado` px y la devuelve como data URL JPEG.
 * Reduce el peso de las fotos antes de enviarlas al servidor (las cámaras dan imágenes de varios MB).
 * @param {File} archivo
 * @returns {Promise<string>}
 */
export function redimensionarImagen(archivo, maxLado = 640, calidad = 0.8) {
  return new Promise((resolver, rechazar) => {
    const url = URL.createObjectURL(archivo);
    const img = new Image();
    img.onload = () => {
      const escala = Math.min(1, maxLado / Math.max(img.naturalWidth, img.naturalHeight));
      const lienzo = document.createElement("canvas");
      lienzo.width = Math.round(img.naturalWidth * escala);
      lienzo.height = Math.round(img.naturalHeight * escala);
      const ctx = lienzo.getContext("2d");
      ctx.fillStyle = "#fff"; // los PNG transparentes no quedan con fondo negro en JPEG
      ctx.fillRect(0, 0, lienzo.width, lienzo.height);
      ctx.drawImage(img, 0, 0, lienzo.width, lienzo.height);
      URL.revokeObjectURL(url);
      resolver(lienzo.toDataURL("image/jpeg", calidad));
    };
    img.onerror = () => { URL.revokeObjectURL(url); rechazar(new Error("No se pudo leer la imagen.")); };
    img.src = url;
  });
}

/** Estatus de una mascota: etiqueta visible y variante de color de la insignia. */
export const ESTATUS_MASCOTA = Object.freeze({
  disponible: { etiqueta: "Disponible", clase: "aprobado" },
  "en proceso": { etiqueta: "En proceso", clase: "pendiente" },
  adoptado: { etiqueta: "Adoptado", clase: "adoptado" },
});

/**
 * Quita el error de un campo en cuanto el usuario lo corrige (en vez de esperar al siguiente envío).
 * Usa la fase de captura para correr antes que los listeners propios de cada input.
 */
export function limpiarErroresAlEscribir(formulario) {
  const limpiar = (evento) => {
    const campo = evento.target.closest(".campo");
    if (campo && campo.classList.contains("campo--error")) marcarError(campo, "");
  };
  formulario.addEventListener("input", limpiar, true);
  formulario.addEventListener("change", limpiar, true);
}

/** Lee un archivo y lo devuelve como data URL (base64), el formato con que se envía al servidor. */
export function leerComoDataUrl(archivo) {
  return new Promise((resolver, rechazar) => {
    const lector = new FileReader();
    lector.onload = () => resolver(String(lector.result));
    lector.onerror = () => rechazar(new Error("No se pudo leer el archivo."));
    lector.readAsDataURL(archivo);
  });
}

/** Nombre legible de cada tipo de documento que sube un refugio. */
export const ETIQUETAS_DOCUMENTO = Object.freeze({
  acta: "Acta constitutiva",
  domicilio: "Comprobante de domicilio",
  identificacion: "Identificación del responsable",
  permiso: "Permiso de refugio",
});

/** Documentos privados (refugios y mascotas): PDF, JPG o PNG de máx. 5 MB. Devuelve el error o "". */
export function validarDocumento(archivo) {
  if (!archivo) return "Selecciona un archivo.";
  if (!["application/pdf", "image/jpeg", "image/png"].includes(archivo.type)) return "Formato no permitido. Usa PDF, JPG o PNG.";
  if (archivo.size > 5 * 1024 * 1024) return `El archivo pesa ${formatearTamano(archivo.size)}. El máximo es 5 MB.`;
  return "";
}

/** Nombre legible de cada tipo de documento especial de una mascota. */
export const ETIQUETAS_DOCUMENTO_MASCOTA = Object.freeze({
  vacunacion: "Certificado de vacunación",
  esterilizacion: "Registro de esterilización",
  desparasitacion: "Registro de desparasitación",
  pedigree: "Pedigree",
  medico: "Expediente médico",
  otro: "Otro documento",
});

/** Estado de un refugio: etiqueta visible y variante de color de la insignia. */
export const ESTADOS_REFUGIO = Object.freeze({
  pendiente: { etiqueta: "Pendiente", clase: "pendiente" },
  aprobado: { etiqueta: "Verificado", clase: "aprobado" },
  rechazado: { etiqueta: "Rechazado", clase: "rechazado" },
  suspendido: { etiqueta: "Suspendido", clase: "rechazado" },
});

/** "17 oct 2026" */
export function formatearFecha(iso) {
  return new Date(iso).toLocaleDateString("es-MX", { day: "numeric", month: "short", year: "numeric" });
}
