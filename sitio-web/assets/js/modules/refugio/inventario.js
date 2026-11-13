/**
 * inventario.js — CRUD completo de las mascotas del refugio.
 * Tabla con búsqueda (debounce), filtros, cambio rápido de estatus, y diálogos <dialog>
 * para crear/editar y para confirmar la eliminación. Un solo listener por tabla (delegación).
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearVisor } from "../../components/visor-documento.js";
import {
  listarMascotas, guardarMascota, cambiarEstatus, eliminarMascota, contarPublicacionesDeMascota,
  listarDocumentosMascota, subirDocumentoMascota, eliminarDocumentoMascota, descargarDocumentoMascota, sugerirDescripcionMascota,
} from "../../core/servicios-refugio.js";
import {
  crearElemento, debounce, formatearEdad, formatearFecha, formatearTamano, leerComoDataUrl, limpiarErroresAlEscribir, marcarError,
  mostrarAlerta, ocultarAlerta, normalizarTexto, resolverImagen, redimensionarImagen, validarDocumento, validarImagen,
  ESTATUS_MASCOTA, ETIQUETAS_DOCUMENTO_MASCOTA,
} from "../../core/utils.js";

const LOTE = 10;
const FOTO_POR_DEFECTO = "assets/img/mascotas/sin-foto.svg";
const mayuscula = (t) => t.charAt(0).toUpperCase() + t.slice(1);

const sesion = requerirRol("refugio");

/* Elementos */
const cuerpo = document.getElementById("cuerpo-tabla");
const contenedorTabla = document.getElementById("contenedor-tabla");
const conteo = document.getElementById("conteo");
const anuncio = document.getElementById("anuncio");
const vacio = document.getElementById("sin-mascotas");
const sinResultados = document.getElementById("sin-resultados");
const botonMas = document.getElementById("boton-mas");
const buscar = document.getElementById("filtro-texto");
const filtroEspecie = document.getElementById("filtro-especie");
const filtroEstatus = document.getElementById("filtro-estatus");

const modal = document.getElementById("modal-mascota");
const formulario = document.getElementById("formulario-mascota");
const alertaModal = document.getElementById("alerta-modal");
const botonGuardar = document.getElementById("boton-guardar");
const vistaFoto = document.getElementById("vista-foto");
const modalBorrar = document.getElementById("modal-borrar");

let mascotas = [];
let filtradas = [];
let mostradas = 0;
let editandoId = null;   // null = creando
let borrandoId = null;
let fotoActual = "";     // data URL / ruta de la foto elegida ("" = usar la imagen por defecto)

if (sesion) {
  montarNavbar({ sesion, activa: "inventario" });
  iniciar();
}

async function iniciar() {
  mascotas = await listarMascotas();
  aplicarFiltros();
  enlazarEventos();
  if (new URLSearchParams(window.location.search).get("nueva") === "1") {
    history.replaceState(null, "", window.location.pathname); // para que al recargar no se reabra el formulario
    abrirFormulario();
  }
}

/* ---------- Lista ---------- */

function aplicarFiltros() {
  const texto = normalizarTexto(buscar.value);
  filtradas = mascotas.filter((m) =>
    (!texto || normalizarTexto(`${m.nombre} ${m.raza}`).includes(texto)) &&
    (!filtroEspecie.value || m.especie === filtroEspecie.value) &&
    (!filtroEstatus.value || m.estatus === filtroEstatus.value));
  cuerpo.replaceChildren();
  mostradas = 0;
  mostrarMas();
}

function mostrarMas() {
  const lote = filtradas.slice(mostradas, mostradas + LOTE);
  const fragmento = document.createDocumentFragment();
  lote.forEach((m) => fragmento.append(crearFila(m)));
  cuerpo.append(fragmento);
  mostradas += lote.length;

  conteo.textContent = filtradas.length === 1 ? "1 mascota" : `${filtradas.length} mascotas`;
  vacio.hidden = mascotas.length > 0;
  sinResultados.hidden = mascotas.length === 0 || filtradas.length > 0;
  contenedorTabla.hidden = filtradas.length === 0;
  botonMas.hidden = mostradas >= filtradas.length;
}

function crearFila(m) {
  const selector = crearElemento("select", { clase: "campo__control tabla__select", atributos: { "data-accion": "estatus", "aria-label": `Estatus de ${m.nombre}` } },
    Object.entries(ESTATUS_MASCOTA).map(([valor, { etiqueta }]) => crearElemento("option", { texto: etiqueta, atributos: { value: valor, selected: valor === m.estatus } })));

  return crearElemento("tr", { atributos: { "data-id": m.id } }, [
    crearElemento("td", {}, crearElemento("img", { clase: "tabla__foto", atributos: { src: resolverImagen(m.foto), alt: `Foto de ${m.nombre}`, width: 56, height: 56, loading: "lazy", decoding: "async" } })),
    crearElemento("th", { texto: m.nombre, atributos: { scope: "row" } }),
    crearElemento("td", { texto: mayuscula(m.especie) }),
    crearElemento("td", { texto: m.raza }),
    crearElemento("td", { texto: formatearEdad(m.edadMeses) }),
    crearElemento("td", { texto: mayuscula(m.sexo) }),
    crearElemento("td", { texto: mayuscula(m.tamano) }),
    crearElemento("td", {}, selector),
    crearElemento("td", {}, crearElemento("div", { clase: "tabla__acciones" }, [
      crearElemento("button", { clase: "boton boton--secundario boton--pequeno", texto: "Editar", atributos: { type: "button", "data-accion": "editar", "aria-label": `Editar a ${m.nombre}` } }),
      crearElemento("button", {
        clase: "boton boton--contorno boton--pequeno", texto: `Documentos (${m.documentos?.total ?? 0})`,
        atributos: { type: "button", "data-accion": "documentos", "aria-label": `Documentos de ${m.nombre}: ${m.documentos?.total ?? 0}` },
      }),
      crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Eliminar", atributos: { type: "button", "data-accion": "eliminar", "aria-label": `Eliminar a ${m.nombre}` } }),
    ])),
  ]);
}

async function recargar(mensaje) {
  mascotas = await listarMascotas();
  aplicarFiltros();
  if (mensaje) anuncio.textContent = mensaje;
}

/* ---------- Formulario crear / editar ---------- */

const campo = (nombre) => formulario.querySelector(`[data-campo="${nombre}"]`);

function mostrarVistaFoto() {
  vistaFoto.querySelector("img").src = resolverImagen(fotoActual || FOTO_POR_DEFECTO);
}

function abrirFormulario(mascota = null) {
  editandoId = mascota ? mascota.id : null;
  formulario.reset();
  ocultarAlerta(alertaModal);
  formulario.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
  document.getElementById("ayuda-descripcion").textContent = AYUDA_DESCRIPCION;
  document.getElementById("modal-titulo").textContent = mascota ? `Editar a ${mascota.nombre}` : "Agregar mascota";

  if (mascota) {
    const { elements: f } = formulario;
    f.nombre.value = mascota.nombre;
    f.especie.value = mascota.especie;
    f.raza.value = mascota.raza;
    const enAnios = mascota.edadMeses >= 12 && mascota.edadMeses % 12 === 0;
    f.edad.value = enAnios ? mascota.edadMeses / 12 : mascota.edadMeses;
    f.unidad.value = enAnios ? "anios" : "meses";
    f.sexo.value = mascota.sexo;
    f.tamano.value = mascota.tamano;
    f.salud.value = mascota.salud;
    f.estatus.value = mascota.estatus;
    f.descripcion.value = mascota.descripcion;
  }
  fotoActual = mascota && mascota.foto !== FOTO_POR_DEFECTO ? mascota.foto : "";
  mostrarVistaFoto();
  modal.showModal();
  formulario.elements.nombre.focus();
}

/** Valida y devuelve los datos listos para guardar, o null si hay errores. */
function leerFormulario() {
  const f = formulario.elements;
  const edad = Number(f.edad.value);
  const edadMeses = f.unidad.value === "anios" ? edad * 12 : edad;
  const texto = (campoForm) => campoForm.value.trim();

  const errores = {
    nombre: texto(f.nombre).length < 2 ? "Escribe el nombre de la mascota (mínimo 2 letras)." : "",
    especie: f.especie.value ? "" : "Elige la especie.",
    raza: texto(f.raza) ? "" : "Indica la raza o «Mestizo».",
    edad: !Number.isInteger(edad) || edad < 1 || edadMeses > 360 ? "Indica una edad válida (número entero mayor a 0, máximo 30 años)." : "",
    sexo: f.sexo.value ? "" : "Elige el sexo.",
    tamano: f.tamano.value ? "" : "Elige el tamaño.",
    salud: texto(f.salud) ? "" : "Describe el estado de salud (vacunas, esterilización, tratamientos).",
    descripcion: texto(f.descripcion).length < 10 ? "Escribe una descripción de al menos 10 caracteres." : "",
  };
  Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(campo(nombre), mensaje));
  if (Object.values(errores).some(Boolean)) {
    formulario.querySelector(".campo--error .campo__control")?.focus();
    return null;
  }
  return {
    nombre: texto(f.nombre), especie: f.especie.value, raza: texto(f.raza), edadMeses, sexo: f.sexo.value, tamano: f.tamano.value,
    salud: texto(f.salud), descripcion: texto(f.descripcion), estatus: f.estatus.value, foto: fotoActual || FOTO_POR_DEFECTO,
  };
}

async function guardarFormulario(evento) {
  evento.preventDefault();
  ocultarAlerta(alertaModal);
  const datos = leerFormulario();
  if (!datos) return;

  botonGuardar.disabled = true;
  const resultado = await guardarMascota(datos, editandoId);
  botonGuardar.disabled = false;

  if (!resultado.ok) { mostrarAlerta(alertaModal, "error", resultado.error); return; }
  const era = editandoId ? "actualizada" : "agregada";
  modal.close();
  await recargar(`${datos.nombre} fue ${era}.`);
}

/* ---------- Borrador de descripción con IA (HU-17) ---------- */

const AYUDA_DESCRIPCION = "Llena los datos (y la foto, si tienes) y la IA te propone un borrador que puedes editar.";

/**
 * Pide a la API un borrador con los datos del formulario, lo que ya esté escrito en la descripción
 * (como notas) y la foto. El texto queda en el campo para revisarlo: no se guarda hasta «Guardar».
 */
async function sugerirDescripcion() {
  const f = formulario.elements;
  const boton = document.getElementById("sugerir-descripcion");
  const ayuda = document.getElementById("ayuda-descripcion");
  const edad = Number(f.edad.value);
  const datos = {
    nombre: f.nombre.value.trim(), especie: f.especie.value, raza: f.raza.value.trim(),
    edadMeses: Number.isInteger(edad) && edad > 0 ? (f.unidad.value === "anios" ? edad * 12 : edad) : null,
    sexo: f.sexo.value, tamano: f.tamano.value, salud: f.salud.value.trim(),
    notas: f.descripcion.value.trim(), foto: fotoActual || "",
  };
  if (!datos.especie && !datos.notas) {
    marcarError(campo("descripcion"), "Elige al menos la especie o escribe unas notas para generar el borrador.");
    return;
  }
  marcarError(campo("descripcion"), "");
  boton.disabled = true;
  boton.textContent = "Generando…";
  ayuda.textContent = "Escribiendo un borrador… puede tardar unos segundos.";
  const r = await sugerirDescripcionMascota(datos);
  boton.disabled = false;
  boton.textContent = "✨ Sugerir con IA";
  if (!r.ok) { ayuda.textContent = AYUDA_DESCRIPCION; marcarError(campo("descripcion"), r.error); return; }
  f.descripcion.value = r.descripcion;
  f.descripcion.focus();
  ayuda.textContent = r.iaUsada
    ? "✨ Borrador hecho con IA: revísalo y corrige lo que no sea exacto antes de guardar."
    : "La IA no respondió: te dejamos una plantilla para completar.";
}

/* ---------- Eventos ---------- */

function enlazarEventos() {
  buscar.addEventListener("input", debounce(aplicarFiltros, 250));
  [filtroEspecie, filtroEstatus].forEach((s) => s.addEventListener("change", aplicarFiltros));
  document.getElementById("limpiar-filtros").addEventListener("click", () => { buscar.value = ""; filtroEspecie.value = ""; filtroEstatus.value = ""; aplicarFiltros(); });
  document.querySelector(".herramientas").addEventListener("submit", (e) => e.preventDefault());
  botonMas.addEventListener("click", mostrarMas);

  document.querySelectorAll("[data-nueva]").forEach((b) => b.addEventListener("click", () => abrirFormulario()));

  // Delegación en la tabla: editar, eliminar y cambiar estatus
  cuerpo.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-accion]");
    if (!boton || boton.tagName === "SELECT") return;
    const id = boton.closest("tr").dataset.id;
    const mascota = mascotas.find((m) => m.id === id);
    if (!mascota) return;
    if (boton.dataset.accion === "editar") abrirFormulario(mascota);
    if (boton.dataset.accion === "eliminar") pedirConfirmacion(mascota);
    if (boton.dataset.accion === "documentos") abrirDocumentos(mascota);
  });
  cuerpo.addEventListener("change", async (evento) => {
    const selector = evento.target.closest('[data-accion="estatus"]');
    if (!selector) return;
    const id = selector.closest("tr").dataset.id;
    const resultado = await cambiarEstatus(id, selector.value);
    await recargar(resultado.ok ? `Estatus de ${resultado.mascota.nombre}: ${ESTATUS_MASCOTA[selector.value].etiqueta}.` : resultado.error);
  });

  /* Formulario */
  formulario.addEventListener("submit", guardarFormulario);
  limpiarErroresAlEscribir(formulario);
  document.getElementById("cancelar-mascota").addEventListener("click", () => modal.close());
  formulario.elements.foto.addEventListener("change", async (evento) => {
    const archivo = evento.target.files[0];
    const zona = campo("foto");
    if (!archivo) return;
    const error = validarImagen(archivo);
    if (error) { marcarError(zona, error); evento.target.value = ""; return; }
    try {
      fotoActual = await redimensionarImagen(archivo);
      marcarError(zona, "");
      mostrarVistaFoto();
    } catch {
      marcarError(zona, "No pudimos leer esa imagen. Prueba con otra.");
    }
  });
  document.getElementById("sugerir-descripcion").addEventListener("click", sugerirDescripcion);
  document.getElementById("quitar-foto").addEventListener("click", () => {
    fotoActual = "";
    formulario.elements.foto.value = "";
    mostrarVistaFoto();
  });

  /* Confirmación de eliminación */
  document.getElementById("cancelar-borrar").addEventListener("click", () => modalBorrar.close());
  document.getElementById("confirmar-borrar").addEventListener("click", confirmarBorrado);

  enlazarDocumentos();
}

/* ---------- Documentos de la mascota ---------- */

const modalDocs = document.getElementById("modal-documentos");
const listaDocs = document.getElementById("lista-docs");
const formularioDoc = document.getElementById("formulario-doc");
const alertaDocs = document.getElementById("alerta-docs");
const botonSubirDoc = document.getElementById("boton-subir-doc");
const zonaVisorDocs = document.getElementById("visor-docs-zona");
const visorDocs = crearVisor({
  area: document.getElementById("visor-docs"),
  titulo: document.getElementById("visor-docs-titulo"),
  abrir: document.getElementById("visor-docs-abrir"),
});
let docsMascota = null;  // mascota cuyo diálogo está abierto
let documentos = [];
let docsCambiaron = false;

async function abrirDocumentos(mascota) {
  docsMascota = mascota;
  docsCambiaron = false;
  formularioDoc.reset();
  formularioDoc.querySelectorAll(".campo").forEach((c) => marcarError(c, ""));
  ocultarAlerta(alertaDocs);
  visorDocs.reiniciar();
  zonaVisorDocs.hidden = true;
  document.getElementById("documentos-titulo").textContent = `Documentos de ${mascota.nombre}`;
  listaDocs.replaceChildren(crearElemento("li", { clase: "vacio", texto: "Cargando documentos…" }));
  modalDocs.showModal();
  documentos = await listarDocumentosMascota(mascota.id);
  renderDocumentos();
}

function renderDocumentos() {
  document.getElementById("sin-docs").hidden = documentos.length > 0;
  const fragmento = document.createDocumentFragment();
  documentos.forEach((d) => {
    const etiqueta = ETIQUETAS_DOCUMENTO_MASCOTA[d.tipo] || d.tipo;
    fragmento.append(crearElemento("li", { clase: "doc-mascota", atributos: { "data-id": d.id } }, [
      crearElemento("div", { clase: "doc-mascota__info" }, [
        crearElemento("strong", { texto: etiqueta }),
        crearElemento("span", { clase: "texto-suave texto-pequeno", texto: `${d.nombre} · ${formatearTamano(d.tamano)} · ${formatearFecha(d.fecha)}` }),
      ]),
      crearElemento("div", { clase: "doc-mascota__acciones" }, [
        crearElemento("span", { clase: `insignia insignia--${d.verificado ? "aprobado" : "pendiente"}`, texto: d.verificado ? "Revisado por HuellApp" : "Pendiente de revisión" }),
        crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Ver", atributos: { type: "button", "data-doc-accion": "ver", "aria-label": `Ver ${etiqueta}` } }),
        crearElemento("button", { clase: "boton boton--peligro boton--pequeno", texto: "Eliminar", atributos: { type: "button", "data-doc-accion": "eliminar", "aria-label": `Eliminar ${etiqueta}` } }),
      ]),
    ]));
  });
  listaDocs.replaceChildren(fragmento);
}

function enlazarDocumentos() {
  const tipo = formularioDoc.elements.tipo;
  tipo.append(...Object.entries(ETIQUETAS_DOCUMENTO_MASCOTA).map(([valor, etiqueta]) => crearElemento("option", { texto: etiqueta, atributos: { value: valor } })));
  limpiarErroresAlEscribir(formularioDoc);

  document.getElementById("cerrar-documentos").addEventListener("click", () => modalDocs.close());
  modalDocs.addEventListener("close", async () => {
    visorDocs.reiniciar();
    if (docsCambiaron) await recargar(); // actualiza el contador "Documentos (n)" de la tabla
  });

  listaDocs.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("[data-doc-accion]");
    if (!boton) return;
    const documento = documentos.find((d) => d.id === boton.closest("li").dataset.id);
    if (!documento) return;
    const etiqueta = ETIQUETAS_DOCUMENTO_MASCOTA[documento.tipo] || documento.tipo;

    if (boton.dataset.docAccion === "ver") {
      zonaVisorDocs.hidden = false;
      listaDocs.querySelectorAll(".doc-mascota").forEach((li) => li.classList.toggle("doc-mascota--activo", li.dataset.id === documento.id));
      visorDocs.mostrar(() => descargarDocumentoMascota(docsMascota.id, documento.id), `${etiqueta} — ${documento.nombre}`);
      return;
    }
    // Eliminar (con confirmación nativa: es una acción pequeña dentro del diálogo)
    if (!window.confirm(`¿Eliminar «${documento.nombre}»? Esta acción no se puede deshacer.`)) return;
    const resultado = await eliminarDocumentoMascota(docsMascota.id, documento.id);
    if (!resultado.ok) { mostrarAlerta(alertaDocs, "error", resultado.error); return; }
    documentos = documentos.filter((d) => d.id !== documento.id);
    docsCambiaron = true;
    visorDocs.reiniciar();
    zonaVisorDocs.hidden = true;
    renderDocumentos();
    document.getElementById("anuncio-docs").textContent = `${etiqueta} eliminado.`;
  });

  formularioDoc.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    ocultarAlerta(alertaDocs);
    const archivo = formularioDoc.elements.archivo.files[0];
    const errores = { tipo: tipo.value ? "" : "Elige el tipo de documento.", archivo: validarDocumento(archivo) };
    Object.entries(errores).forEach(([nombre, mensaje]) => marcarError(formularioDoc.querySelector(`[data-campo="${nombre}"]`), mensaje));
    if (errores.tipo || errores.archivo) return;

    botonSubirDoc.disabled = true;
    try {
      const dataUrl = await leerComoDataUrl(archivo);
      const resultado = await subirDocumentoMascota(docsMascota.id, { tipo: tipo.value, nombre: archivo.name.slice(0, 120), dataUrl });
      if (!resultado.ok) { mostrarAlerta(alertaDocs, "error", resultado.error); return; }
      documentos.push(resultado.documento);
      docsCambiaron = true;
      formularioDoc.reset();
      renderDocumentos();
      mostrarAlerta(alertaDocs, "exito", "Documento subido. El equipo de HuellApp lo revisará.");
    } catch {
      mostrarAlerta(alertaDocs, "error", "No pudimos leer ese archivo. Prueba con otro.");
    } finally {
      botonSubirDoc.disabled = false;
    }
  });
}

async function pedirConfirmacion(mascota) {
  borrandoId = mascota.id;
  const publicaciones = await contarPublicacionesDeMascota(mascota.id);
  document.getElementById("borrar-texto").textContent = `¿Eliminar a ${mascota.nombre} del inventario? Esta acción no se puede deshacer.`;
  const aviso = document.getElementById("borrar-aviso");
  aviso.hidden = publicaciones === 0;
  aviso.textContent = publicaciones === 1 ? "También se eliminará 1 publicación que la muestra." : `También se eliminarán ${publicaciones} publicaciones que la muestran.`;
  modalBorrar.showModal();
}

async function confirmarBorrado() {
  const mascota = mascotas.find((m) => m.id === borrandoId);
  modalBorrar.close();
  const resultado = await eliminarMascota(borrandoId);
  await recargar(resultado.ok ? `${mascota?.nombre || "La mascota"} fue eliminada.` : resultado.error);
}
