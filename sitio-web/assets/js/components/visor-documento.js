/**
 * visor-documento.js — Visor de documentos privados (PDF o imagen).
 * El archivo se descarga con la sesión y se muestra desde una URL temporal del navegador (blob),
 * nunca desde una carpeta pública. Lo usan la revisión de solicitudes y los documentos de mascotas.
 */
import { crearElemento } from "../core/utils.js";

/**
 * @param {{area:HTMLElement, titulo:HTMLElement, abrir:HTMLAnchorElement}} nodos
 *   area = contenedor del visor, titulo = texto con el documento abierto, abrir = enlace "Abrir en pestaña nueva"
 */
export function crearVisor({ area, titulo, abrir }) {
  let urlActual = null; // URL temporal del documento que se está viendo
  let pedido = 0;       // para ignorar respuestas viejas si se hace clic rápido en varios documentos
  const contenidoInicial = [...area.childNodes].map((n) => n.cloneNode(true));
  const tituloInicial = titulo.textContent;

  function liberar() {
    if (urlActual) URL.revokeObjectURL(urlActual);
    urlActual = null;
    abrir.hidden = true;
  }

  /**
   * @param {() => Promise<Blob>} descargar  Función que trae el archivo
   * @param {string} etiqueta  Ej. "Certificado de vacunación — cartilla.pdf"
   */
  async function mostrar(descargar, etiqueta) {
    const actual = ++pedido;
    titulo.textContent = etiqueta;
    area.replaceChildren(crearElemento("p", { clase: "vacio", texto: "Cargando documento…" }));
    try {
      const archivo = await descargar();
      if (actual !== pedido) return; // se pidió otro documento mientras descargaba este
      liberar();
      urlActual = URL.createObjectURL(archivo);
      area.replaceChildren(archivo.type === "application/pdf"
        ? crearElemento("iframe", { clase: "visor__marco", atributos: { src: urlActual, title: `Documento: ${etiqueta}` } })
        : crearElemento("img", { clase: "visor__imagen", atributos: { src: urlActual, alt: `Documento: ${etiqueta}` } }));
      abrir.href = urlActual;
      abrir.hidden = false;
    } catch (error) {
      if (actual !== pedido) return;
      area.replaceChildren(crearElemento("p", { clase: "vacio", texto: error.message || "No se pudo abrir el documento." }));
    }
  }

  /** Vuelve al estado inicial ("Ningún documento abierto"). */
  function reiniciar() {
    pedido++;
    liberar();
    titulo.textContent = tituloInicial;
    area.replaceChildren(...contenidoInicial.map((n) => n.cloneNode(true)));
  }

  window.addEventListener("pagehide", liberar);
  return { mostrar, reiniciar, liberar };
}
