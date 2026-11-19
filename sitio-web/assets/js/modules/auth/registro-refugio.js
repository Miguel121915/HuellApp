/**
 * registro-refugio.js — Alta de refugio en 4 pasos (los mismos datos que la app móvil), y el mismo
 * formulario en MODO APELACIÓN (registro-refugio.html?apelacion=1).
 *
 * Registro:
 *   1. Tu refugio (tipo, descripción, capacidad, animales…)   2. Responsable y cuenta
 *   3. Ubicación y contacto (mapa, redes…)                   4. Documentos, resumen y aceptación
 *   Cada paso se valida antes de avanzar y lo escrito no se pierde al regresar.
 *   «Rescatista independiente (sin acta)»: en lugar del acta sube fotos del lugar y debe dar al
 *   menos una red social o referencia; su perfil mostrará esa insignia.
 *   Al enviarse, el refugio queda en estado "Pendiente de verificación".
 *
 * Apelación: solo para un refugio rechazado con sesión iniciada. Se ven todos los pasos juntos
 *   (sin barra de pasos) con sus datos y documentos precargados; los documentos que el
 *   administrador señaló como erróneos deben reemplazarse. Al reenviar vuelve a "pendiente".
 */
import { registrarRefugio, obtenerApelacion, enviarApelacion, refrescarSesion } from "../../core/auth.js";
import { redirigirSiHaySesion, requerirRol, RUTA_ESTADO_REFUGIO } from "../../core/router-guard.js";
import { montarDatosExtra } from "../../components/datos-extra-refugio.js";
import { crearElemento, irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError, formatearTamano, leerComoDataUrl, validarDocumento, ETIQUETAS_DOCUMENTO } from "../../core/utils.js";

const TIPO_INDEPENDIENTE = "Rescatista independiente";

/** Documentos de cada tipo de refugio: [tipo, obligatorio] (el campo del formulario se llama igual). */
const DOCUMENTOS_FORMAL = [["acta", true], ["domicilio", true], ["identificacion", true], ["permiso", false]];
const DOCUMENTOS_INDEPENDIENTE = [["identificacion", true], ["domicilio", true], ["lugar", true], ["lugar2", false]];

const MODO_APELACION = new URLSearchParams(window.location.search).get("apelacion") === "1";

const formulario = document.getElementById("form-registro");
const alerta = document.getElementById("alerta");
const botonEnviar = document.getElementById("boton-enviar");
const botonSiguiente = document.getElementById("boton-siguiente");
const botonAnterior = document.getElementById("boton-anterior");
const pasos = [...formulario.querySelectorAll(".paso")];
const f = formulario.elements;
const campo = (nombre) => f[nombre].closest(".campo");

let independiente = false;
const documentos = () => (independiente ? DOCUMENTOS_INDEPENDIENTE : DOCUMENTOS_FORMAL);

// Ubicación y contacto (paso 3). En la apelación no se piden.
const datosExtra = MODO_APELACION ? null : montarDatosExtra(document.getElementById("datos-extra"), { ubicacionObligatoria: true });

if (MODO_APELACION) {
  iniciarApelacion();
} else if (!redirigirSiHaySesion()) {
  document.body.removeAttribute("data-protegida");
  iniciarRegistro();
}

/* ---------- Tipo de refugio: formal o rescatista independiente ---------- */

/** Muestra los documentos que corresponden y el aviso para rescatistas independientes. */
function aplicarTipo(esIndependiente) {
  independiente = esIndependiente;
  document.getElementById("aviso-independiente").hidden = !esIndependiente;
  document.getElementById("campo-rfc").hidden = esIndependiente;
  const visibles = new Set(documentos().map(([tipo]) => tipo));
  formulario.querySelectorAll("[data-documento]").forEach((zona) => { zona.hidden = !visibles.has(zona.dataset.documento); });
  document.getElementById("ayuda-documentos").textContent = esIndependiente
    ? "Como rescatista independiente: tu identificación, un comprobante de domicilio y fotos del lugar donde tienes a los animales. Un administrador los revisa; no se muestran a los usuarios."
    : "Un administrador los revisa antes de activar tu panel. No se muestran a los usuarios.";
}

/* ---------- Validación ---------- */

function validarArchivo(archivo, obligatorio, mensajeFalta = "Sube este documento (PDF, JPG o PNG).") {
  if (!archivo) return obligatorio ? mensajeFalta : "";
  return validarDocumento(archivo);
}

const entero = (v) => /^\d+$/.test(String(v).trim());

/** Errores de cada paso del registro: { nombreCampo: mensaje } (mensaje vacío = bien). */
function erroresDelPaso(n) {
  const anio = f.anioFundacion.value.trim();
  if (n === 1) return {
    nombreRefugio: f.nombreRefugio.value.trim().length < 3 ? "Escribe el nombre del refugio." : "",
    tipoOrganizacion: f.tipoOrganizacion.value ? "" : "Elige el tipo de organización.",
    anioFundacion: anio && (!entero(anio) || Number(anio) < 1900 || Number(anio) > new Date().getFullYear()) ? "Escribe un año válido." : "",
    rfc: !independiente && f.rfc.value.trim() && !/^[A-Za-zÑñ&]{3,4}\d{6}[A-Za-z\d]{3}$/.test(f.rfc.value.trim()) ? "El RFC tiene 12 o 13 caracteres (por ejemplo ABC120101XYZ)." : "",
    descripcion: f.descripcion.value.trim().length < 20 ? "Cuéntanos en al menos 20 caracteres qué hace tu refugio." : "",
    capacidad: !entero(f.capacidad.value) || Number(f.capacidad.value) < 1 ? "Escribe cuántos animales caben, aproximadamente." : "",
    animalesActuales: !entero(f.animalesActuales.value) ? "Escribe cuántos animales tienen hoy (puede ser 0)." : "",
    entregaEsterilizados: f.entregaEsterilizados.value ? "" : "Elige una opción.",
  };
  if (n === 2) return {
    responsable: f.responsable.value.trim().length < 3 ? "Escribe el nombre del responsable." : "",
    cargoResponsable: f.cargoResponsable.value.trim().length < 2 ? "Escribe el cargo (por ejemplo, Fundadora)." : "",
    telefono: !/^[\d\s+()-]{8,}$/.test(f.telefono.value) ? "Escribe un teléfono de al menos 8 dígitos." : "",
    correo: !esCorreoValido(f.correo.value.trim()) ? "Escribe un correo válido, por ejemplo refugio@correo.com." : "",
    password: f.password.value.length < 8 ? "Usa al menos 8 caracteres." : "",
    confirmar: f.confirmar.value !== f.password.value ? "Las contraseñas no coinciden." : "",
  };
  if (n === 3) return validarUbicacionYHorario();
  const errores = {};
  documentos().forEach(([tipo, obligatorio]) => { errores[tipo] = validarArchivo(f[tipo].files[0], obligatorio); });
  return errores;
}

function validarUbicacionYHorario() {
  return {
    direccion: f.direccion.value.trim().length < 8 ? "Escribe la dirección completa del refugio." : "",
    horaApertura: !f.horaApertura.value || !f.horaCierre.value ? "Indica el horario de atención." : (f.horaCierre.value <= f.horaApertura.value ? "La hora de cierre debe ser posterior a la de apertura." : ""),
  };
}

/** Marca los errores; devuelve true si hay alguno. */
function mostrarErrores(errores) {
  Object.entries(errores).forEach(([nombre, msg]) => marcarError(campo(nombre), msg));
  const hay = Object.values(errores).some(Boolean);
  if (hay) {
    mostrarAlerta(alerta, "error", "Hay campos por corregir. Revisa los mensajes en rojo.");
    formulario.querySelector(".campo--error .campo__control")?.focus();
  }
  return hay;
}

/* ---------- Datos que se envían ---------- */

function leerDatos() {
  return {
    nombreRefugio: f.nombreRefugio.value.trim(),
    responsable: f.responsable.value.trim(),
    telefono: f.telefono.value.trim(),
    direccion: f.direccion.value.trim(),
    horario: `${f.horaApertura.value} - ${f.horaCierre.value}`,
  };
}

function leerDatosRegistro() {
  return {
    ...leerDatos(),
    ...datosExtra.leer(),
    tipoOrganizacion: f.tipoOrganizacion.value,
    anioFundacion: f.anioFundacion.value.trim(),
    rfc: independiente ? "" : f.rfc.value.trim().toUpperCase(),
    descripcion: f.descripcion.value.trim(),
    capacidad: f.capacidad.value.trim(),
    animalesActuales: f.animalesActuales.value.trim(),
    entregaEsterilizados: f.entregaEsterilizados.value,
    cargoResponsable: f.cargoResponsable.value.trim(),
    correo: f.correo.value.trim(),
    password: f.password.value,
  };
}

/** Los archivos elegidos viajan al servidor en base64 (data URL); él los valida y los guarda. */
function leerArchivosElegidos() {
  return Promise.all(documentos()
    .filter(([tipo]) => f[tipo].files[0])
    .map(async ([tipo]) => ({ tipo, nombre: f[tipo].files[0].name, dataUrl: await leerComoDataUrl(f[tipo].files[0]) })));
}

/** Envía con el botón desactivado; muestra el error de lectura de archivos si lo hay. */
async function enviar(accion) {
  botonEnviar.disabled = true;
  let archivos;
  try {
    archivos = await leerArchivosElegidos();
  } catch {
    botonEnviar.disabled = false;
    mostrarAlerta(alerta, "error", "No pudimos leer uno de los archivos. Vuelve a seleccionarlo e inténtalo de nuevo.");
    return null;
  }
  const r = await accion(archivos);
  botonEnviar.disabled = false;
  if (!r.ok) mostrarAlerta(alerta, "error", r.error);
  return r.ok ? r : null;
}

/* ---------- Registro nuevo en 4 pasos ---------- */

function iniciarRegistro() {
  let actual = 1;
  const indicadores = [...document.querySelectorAll("#pasos-registro [data-paso]")];

  function irAlPaso(n) {
    actual = n;
    pasos.forEach((p) => { p.hidden = Number(p.dataset.paso) !== n; });
    indicadores.forEach((li) => {
      const paso = Number(li.dataset.paso);
      li.classList.toggle("hecho", paso < n);
      if (paso === n) li.setAttribute("aria-current", "step"); else li.removeAttribute("aria-current");
    });
    botonAnterior.hidden = n === 1;
    botonSiguiente.hidden = n === 4;
    botonEnviar.hidden = n !== 4;
    if (n === 3) datosExtra.ajustarMapa(); // el mapa estaba oculto: hay que volver a medirlo
    if (n === 4) pintarResumen();
    ocultarAlerta(alerta);
    document.getElementById("registro-titulo").scrollIntoView({ behavior: "smooth", block: "start" });
  }

  /** Valida el paso actual; devuelve true si se puede avanzar. */
  function pasoValido() {
    if (mostrarErrores(erroresDelPaso(actual))) return false;
    if (actual === 3) {
      const errorExtra = datosExtra.validar();
      if (errorExtra) { mostrarAlerta(alerta, "error", errorExtra); return false; }
      // Sin acta, las redes o referencias ayudan al administrador a confirmar el trabajo de rescate
      if (independiente && !datosExtra.leer().redes.length) {
        mostrarAlerta(alerta, "error", "Como rescatista independiente, agrega al menos una red social o referencia donde se vea tu trabajo de rescate (en «Redes sociales»).");
        document.getElementById("redes")?.focus();
        return false;
      }
    }
    return true;
  }

  f.tipoOrganizacion.addEventListener("change", () => aplicarTipo(f.tipoOrganizacion.value === TIPO_INDEPENDIENTE));
  botonSiguiente.addEventListener("click", () => { if (pasoValido()) irAlPaso(actual + 1); });
  botonAnterior.addEventListener("click", () => irAlPaso(actual - 1));
  // «Editar» del resumen: regresa al paso de esa sección
  document.getElementById("resumen").addEventListener("click", (e) => {
    const destino = e.target.closest("[data-ir-paso]");
    if (destino) irAlPaso(Number(destino.dataset.irPaso));
  });

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    if (actual !== 4) { botonSiguiente.click(); return; } // Enter en un campo: avanza como «Siguiente»
    if (!pasoValido()) return;
    const aceptado = ["terminos", "privacidad", "veraz"].every((n) => f[n].checked);
    marcarError(document.getElementById("campo-aceptacion"), aceptado ? "" : "Marca las tres casillas para enviar tu solicitud.");
    if (!aceptado) return;

    const r = await enviar((archivos) => registrarRefugio({ ...leerDatosRegistro(), documentos: archivos }));
    if (!r) return;
    mostrarAlerta(alerta, "exito", "Solicitud enviada. Tu refugio queda en estado Pendiente de verificación. Te llevamos al inicio de sesión…");
    setTimeout(() => irA("pages/login.html"), 2200);
  });

  aplicarTipo(false);
  irAlPaso(1);
}

const ESTERILIZADOS = { si: "Sí, todos", algunos: "Algunos", no: "No" };

/** Resumen de lo capturado (paso 4), con un «Editar» por sección. */
function pintarResumen() {
  const d = leerDatosRegistro();
  const seccion = (titulo, paso, filas) => crearElemento("div", { clase: "resumen-registro__seccion" }, [
    crearElemento("div", { clase: "resumen-registro__cabecera" }, [
      crearElemento("h3", { texto: titulo }),
      crearElemento("button", { clase: "enlace", texto: "Editar", atributos: { type: "button", "data-ir-paso": paso } }),
    ]),
    crearElemento("dl", {}, filas.filter(([, v]) => v !== "" && v != null).map(([dt, dd]) =>
      crearElemento("div", {}, [crearElemento("dt", { texto: dt }), crearElemento("dd", { texto: String(dd) })]))),
  ]);
  document.getElementById("resumen").replaceChildren(
    seccion("Tu refugio", 1, [
      ["Nombre", d.nombreRefugio], ["Tipo", independiente ? "Rescatista independiente (sin acta)" : d.tipoOrganizacion],
      ["Año de fundación", d.anioFundacion], ["RFC", d.rfc], ["Capacidad", d.capacidad ? `${d.capacidad} animales` : ""],
      ["Animales hoy", d.animalesActuales], ["¿Esterilizados?", ESTERILIZADOS[d.entregaEsterilizados]],
    ]),
    seccion("Responsable y cuenta", 2, [["Responsable", d.responsable], ["Cargo", d.cargoResponsable], ["Teléfono", d.telefono], ["Correo", d.correo]]),
    seccion("Ubicación y contacto", 3, [
      ["Dirección", d.direccion], ["Horario", d.horario], ["Municipio", d.municipio], ["Código postal", d.codigoPostal],
      ["Ubicación en el mapa", d.latitud != null ? "Marcada ✔" : ""], ["WhatsApp", d.whatsapp],
      ["Animales que reciben", [d.tienePerros && "Perros", d.tieneGatos && "Gatos"].filter(Boolean).join(" y ")],
      ["Redes o referencias", d.redes.join(" · ")],
    ]),
  );
}

/* ---------- Modo apelación ---------- */

async function iniciarApelacion() {
  // Solo un refugio con sesión (aún sin aprobar) puede apelar; el servidor además exige que esté rechazado
  if (!requerirRol("refugio", { permitirRefugioNoVerificado: true })) return;

  // Todo junto, sin pasos: solo los datos que se corrigen al apelar y los documentos
  document.getElementById("pasos-registro").hidden = true;
  formulario.querySelectorAll(".solo-registro").forEach((el) => { el.hidden = true; });
  pasos.forEach((p) => { p.hidden = false; });
  botonSiguiente.hidden = true;
  botonAnterior.hidden = true;
  botonEnviar.hidden = false;

  document.title = "Apelar solicitud · HuellApp";
  document.getElementById("registro-titulo").textContent = "Apelación de tu solicitud";
  document.getElementById("registro-intro").textContent = "Corrige lo que te indicó el administrador y vuelve a enviar tu solicitud. Quedará otra vez como Pendiente de verificación.";
  botonEnviar.textContent = "Reenviar solicitud";
  const volver = document.getElementById("boton-volver");
  volver.href = "estado-refugio.html";
  volver.textContent = "Cancelar";

  // La cuenta ya existe: el correo se muestra pero no se edita, y la contraseña no se pide
  f.correo.readOnly = true;
  campo("correo").append(crearElemento("span", { clase: "campo__ayuda", texto: "El correo de tu cuenta no se puede cambiar." }));
  campo("password").hidden = true;

  botonEnviar.disabled = true;
  mostrarAlerta(alerta, "aviso", "Cargando tus datos…");
  const refugio = await obtenerApelacion();
  if (!refugio) { irA(RUTA_ESTADO_REFUGIO); return; } // ya no está rechazada: no hay nada que apelar
  ocultarAlerta(alerta);
  botonEnviar.disabled = false;

  aplicarTipo(Boolean(refugio.independiente));
  document.getElementById("aviso-independiente").hidden = true;
  precargar(refugio);
  const requeridos = prepararDocumentos(refugio.documentos);

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const errores = {
      nombreRefugio: f.nombreRefugio.value.trim().length < 3 ? "Escribe el nombre del refugio." : "",
      responsable: f.responsable.value.trim().length < 3 ? "Escribe el nombre del responsable." : "",
      telefono: !/^[\d\s+()-]{8,}$/.test(f.telefono.value) ? "Escribe un teléfono de al menos 8 dígitos." : "",
      ...validarUbicacionYHorario(),
    };
    documentos().forEach(([tipo]) => {
      const mensaje = requeridos[tipo] === "error" ? "Este documento fue señalado como erróneo: sube un archivo nuevo." : "Sube este documento (PDF, JPG o PNG).";
      errores[tipo] = validarArchivo(f[tipo].files[0], Boolean(requeridos[tipo]), mensaje);
    });
    if (mostrarErrores(errores)) return;

    const r = await enviar((archivos) => enviarApelacion({ ...leerDatos(), documentos: archivos }));
    if (!r) return;
    try { await refrescarSesion(); } catch { /* la pantalla de estado vuelve a consultarlo */ }
    formulario.querySelectorAll("input, button, select, textarea").forEach((c) => { c.disabled = true; });
    mostrarAlerta(alerta, "exito", "¡Apelación enviada! Tu solicitud volvió a estar Pendiente de verificación. Te llevamos a tu pantalla de estado…");
    setTimeout(() => irA(RUTA_ESTADO_REFUGIO), 2000);
  });
}

/** Rellena los datos del refugio y muestra el motivo del rechazo. */
function precargar(refugio) {
  f.nombreRefugio.value = refugio.nombre;
  f.responsable.value = refugio.responsable;
  f.telefono.value = refugio.telefono;
  f.direccion.value = refugio.direccion;
  const [apertura, cierre] = refugio.horario.split(" - ");
  if (apertura && cierre) { f.horaApertura.value = apertura; f.horaCierre.value = cierre; }
  f.correo.value = refugio.correo;

  document.getElementById("apelacion-motivo").textContent = refugio.motivoRechazo || "El administrador no indicó un motivo.";
  document.getElementById("aviso-apelacion").hidden = false;
}

/**
 * Muestra junto a cada documento el archivo que ya se subió y, si el administrador lo señaló,
 * un aviso para reemplazarlo.
 * @returns {Record<string, false|"error"|"falta">} qué documentos deben subirse sí o sí
 */
function prepararDocumentos(subidos) {
  const requeridos = {};
  documentos().forEach(([tipo, obligatorio]) => {
    const actual = subidos.find((d) => d.tipo === tipo);
    const zona = campo(tipo);
    const input = f[tipo];
    requeridos[tipo] = actual?.conError ? "error" : (obligatorio && !actual ? "falta" : false);

    const estado = crearElemento("span", { clase: "documento-actual", atributos: { id: `actual-${tipo}` } });
    if (actual) {
      estado.textContent = `Archivo actual: ${actual.nombre} (${formatearTamano(actual.tamano)})${actual.conError ? "" : ". Se conserva si no eliges otro."}`;
    } else {
      estado.textContent = obligatorio ? `Aún no has subido: ${ETIQUETAS_DOCUMENTO[tipo] || tipo}.` : "Opcional: puedes agregarlo ahora.";
    }
    const descripciones = [estado.id];

    if (actual?.conError) {
      zona.classList.add("campo--observado");
      const aviso = crearElemento("p", { clase: "campo__aviso", atributos: { id: `aviso-${tipo}` } }, [
        crearElemento("strong", { texto: "Señalado como erróneo. " }),
        document.createTextNode("Sube un archivo nuevo para reemplazarlo."),
      ]);
      zona.insertBefore(aviso, input);
      descripciones.unshift(aviso.id);
    }
    zona.insertBefore(estado, input.nextSibling);
    input.setAttribute("aria-describedby", descripciones.join(" "));

    // Al elegir un archivo se indica que reemplazará al actual
    const textoOriginal = estado.textContent;
    input.addEventListener("change", () => {
      const archivo = input.files[0];
      zona.classList.toggle("campo--reemplazado", Boolean(archivo));
      if (!archivo) { estado.textContent = textoOriginal; return; }
      estado.textContent = actual ? `Se reemplazará «${actual.nombre}» por «${archivo.name}».` : `Se subirá «${archivo.name}».`;
    });
  });
  return requeridos;
}
