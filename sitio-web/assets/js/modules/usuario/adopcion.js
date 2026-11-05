/**
 * adopcion.js — Formulario de solicitud de adopción (diálogo de la página de refugios).
 * Datos personales, datos del hogar y documentos (identificación, comprobante de domicilio y
 * de 1 a 3 fotos del espacio). Incluye el asistente KIRO con las preguntas frecuentes del refugio.
 */
import { montarAsistente } from "../../components/asistente-adopcion.js";
import { enviarSolicitudAdopcion } from "../../core/servicios.js";
import {
  crearElemento, esCorreoValido, leerComoDataUrl, limpiarErroresAlEscribir, marcarError, mostrarAlerta, ocultarAlerta,
  redimensionarImagen, resolverImagen, validarDocumento, validarImagen,
} from "../../core/utils.js";

const MAX_FOTOS = 3;
const MAX_MOTIVO = 800;

/**
 * @param {{sesion:object, alEnviar:(solicitud:object)=>void}} opciones
 * @returns {{abrir:(mascota:object, refugio:object, preguntas:object[])=>void}}
 */
export function montarFormularioAdopcion({ sesion, alEnviar }) {
  const modal = document.getElementById("modal-adopcion");
  const formulario = document.getElementById("formulario-adopcion");
  const f = formulario.elements;
  const alerta = document.getElementById("alerta-adopcion");
  const botonEnviar = document.getElementById("enviar-adopcion");
  const listaFotos = document.getElementById("ad-fotos");
  const contador = document.getElementById("ad-contador");
  const asistente = montarAsistente(modal);
  const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

  let mascota = null;
  let fotos = []; // { nombre, dataUrl } ya reducidas a JPEG

  /* ---------- Fotos del espacio (se acumulan hasta 3, con vista previa) ---------- */
  function dibujarFotos() {
    listaFotos.replaceChildren(...fotos.map((foto, i) => crearElemento("li", { clase: "adopcion__foto-item" }, [
      crearElemento("img", { atributos: { src: foto.dataUrl, alt: `Foto ${i + 1} del espacio: ${foto.nombre}`, width: 96, height: 72 } }),
      crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Quitar", atributos: { type: "button", "data-quitar": i, "aria-label": `Quitar foto ${i + 1}` } }),
    ])));
    f.vivienda.disabled = fotos.length >= MAX_FOTOS;
  }

  f.vivienda.addEventListener("change", async () => {
    const archivos = [...f.vivienda.files];
    f.vivienda.value = ""; // permite elegir más en otra vuelta
    const zona = campo("vivienda");
    marcarError(zona, "");
    for (const archivo of archivos) {
      if (fotos.length >= MAX_FOTOS) { marcarError(zona, `Puedes subir máximo ${MAX_FOTOS} fotos.`); break; }
      const error = validarImagen(archivo, 10) || (/^image\/(jpeg|png)$/.test(archivo.type) ? "" : "Usa fotos JPG o PNG.");
      if (error) { marcarError(zona, `«${archivo.name}»: ${error}`); continue; }
      try {
        fotos.push({ nombre: archivo.name.replace(/\.\w+$/, "") + ".jpg", dataUrl: await redimensionarImagen(archivo, 1024) });
      } catch {
        marcarError(zona, `No pudimos leer «${archivo.name}». Prueba con otra foto.`);
      }
    }
    dibujarFotos();
  });
  listaFotos.addEventListener("click", (e) => {
    const boton = e.target.closest("[data-quitar]");
    if (!boton) return;
    fotos.splice(Number(boton.dataset.quitar), 1);
    dibujarFotos();
    f.vivienda.focus();
  });

  /* ---------- Validación ---------- */
  function validar() {
    const texto = (nombre) => f[nombre].value.trim();
    const errores = {
      nombre: texto("nombre").length < 3 ? "Escribe tu nombre completo." : "",
      correo: esCorreoValido(texto("correo")) ? "" : "Escribe un correo válido, por ejemplo nombre@correo.com.",
      telefono: /^[\d\s+()-]{8,}$/.test(texto("telefono")) ? "" : "Escribe un teléfono de al menos 8 dígitos.",
      direccion: texto("direccion").length < 8 ? "Escribe la dirección completa (calle, número y colonia)." : "",
      tipoVivienda: f.tipoVivienda.value ? "" : "Elige el tipo de vivienda.",
      viviendaPropia: f.viviendaPropia.value ? "" : "Indica si la vivienda es propia, rentada o de un familiar.",
      motivo: texto("motivo").length < 20 ? "Cuéntale al refugio un poco más (al menos 20 caracteres)." : "",
      identificacion: f.identificacion.files[0] ? validarDocumento(f.identificacion.files[0]) : "Adjunta tu identificación oficial.",
      domicilio: f.domicilio.files[0] ? validarDocumento(f.domicilio.files[0]) : "Adjunta tu comprobante de domicilio.",
      vivienda: fotos.length ? "" : "Agrega al menos una foto del espacio donde vivirá la mascota.",
      otro: f.otro.files[0] ? validarDocumento(f.otro.files[0]) : "",
      aceptaTerminos: f.aceptaTerminos.checked ? "" : "Necesitamos tu autorización para enviar la solicitud.",
    };
    Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(campo(nombre), mensaje));
    const hay = Object.values(errores).some(Boolean);
    if (hay) {
      mostrarAlerta(alerta, "error", "Hay campos por completar. Revisa los mensajes en rojo.");
      formulario.querySelector(".campo--error input, .campo--error select, .campo--error textarea")?.focus();
    }
    return !hay;
  }

  async function leerDocumentos() {
    const archivo = async (tipo, entrada) => ({ tipo, nombre: entrada.files[0].name.slice(0, 120), dataUrl: await leerComoDataUrl(entrada.files[0]) });
    return [
      await archivo("identificacion", f.identificacion),
      await archivo("domicilio", f.domicilio),
      ...fotos.map((foto) => ({ tipo: "vivienda", nombre: foto.nombre.slice(0, 120), dataUrl: foto.dataUrl })),
      ...(f.otro.files[0] ? [await archivo("otro", f.otro)] : []),
    ];
  }

  /* ---------- Eventos ---------- */
  limpiarErroresAlEscribir(formulario);
  f.motivo.addEventListener("input", () => { contador.textContent = `${f.motivo.value.length}/${MAX_MOTIVO}`; });
  document.getElementById("cancelar-adopcion").addEventListener("click", () => modal.close());
  modal.addEventListener("close", () => asistente.cerrar());

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    if (!validar()) return;

    botonEnviar.disabled = true;
    let documentos;
    try {
      documentos = await leerDocumentos();
    } catch {
      botonEnviar.disabled = false;
      mostrarAlerta(alerta, "error", "No pudimos leer uno de los archivos. Vuelve a elegirlo.");
      return;
    }
    mostrarAlerta(alerta, "aviso", "Enviando tu solicitud…");
    const r = await enviarSolicitudAdopcion({
      mascotaId: mascota.id,
      nombre: f.nombre.value.trim(), correo: f.correo.value.trim(), telefono: f.telefono.value.trim(),
      direccion: f.direccion.value.trim(), ocupacion: f.ocupacion.value.trim(),
      tipoVivienda: f.tipoVivienda.value, viviendaPropia: f.viviendaPropia.value,
      otrasMascotas: f.otrasMascotas.value.trim(), motivo: f.motivo.value.trim(),
      aceptaTerminos: f.aceptaTerminos.checked, documentos,
    });
    botonEnviar.disabled = false;
    if (!r.ok) { mostrarAlerta(alerta, "error", r.error); return; }
    modal.close();
    mascota = null; // la próxima vez el formulario empieza limpio
    alEnviar(r.solicitud);
  });

  /* ---------- Abrir ---------- */
  function reiniciar() {
    formulario.reset();
    fotos = [];
    dibujarFotos();
    contador.textContent = `0/${MAX_MOTIVO}`;
    formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
    ocultarAlerta(alerta);
    // Se precargan los datos que ya conocemos de la sesión
    f.nombre.value = sesion.nombre || "";
    f.correo.value = sesion.correo || "";
  }

  return {
    abrir(nueva, refugio, preguntas) {
      // Si vuelve a abrir la misma mascota, conserva lo que ya había escrito
      if (mascota?.id !== nueva.id) {
        reiniciar();
        asistente.preparar({ refugio: refugio.nombre, telefono: refugio.telefono, preguntas });
      }
      mascota = nueva;
      document.getElementById("adopcion-titulo").textContent = `Adoptar a ${nueva.nombre}`;
      document.getElementById("adopcion-refugio").textContent = `${nueva.raza} · ${refugio.nombre}`;
      const foto = document.getElementById("adopcion-foto");
      foto.src = resolverImagen(nueva.foto);
      foto.alt = `Foto de ${nueva.nombre}`;
      modal.showModal();
      f.nombre.focus();
    },
  };
}
