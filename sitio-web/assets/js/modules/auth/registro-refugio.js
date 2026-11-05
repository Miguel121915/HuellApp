/**
 * registro-refugio.js — Alta de refugio con carga de documentos, y el mismo formulario en
 * MODO APELACIÓN (registro-refugio.html?apelacion=1).
 *
 * - Registro: al enviarse, el refugio queda en estado "Pendiente de verificación".
 * - Apelación: solo para un refugio rechazado con sesión iniciada. Se precargan sus datos y
 *   documentos; los que el administrador señaló como erróneos llevan un aviso y deben
 *   reemplazarse. Al reenviar, el servidor deja la solicitud otra vez en "pendiente" (vuelve a
 *   la bandeja del administrador) y se regresa a la pantalla de estado.
 */
import { registrarRefugio, obtenerApelacion, enviarApelacion, refrescarSesion } from "../../core/auth.js";
import { redirigirSiHaySesion, requerirRol, RUTA_ESTADO_REFUGIO } from "../../core/router-guard.js";
import { crearElemento, irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError, formatearTamano, leerComoDataUrl, validarDocumento } from "../../core/utils.js";

/** Documentos que pide el formulario: [campo, tipo guardado, obligatorio] */
const DOCUMENTOS = [
  ["acta", "acta", true],
  ["domicilio", "domicilio", true],
  ["identificacion", "identificacion", true],
  ["permiso", "permiso", false],
];

const MODO_APELACION = new URLSearchParams(window.location.search).get("apelacion") === "1";

const formulario = document.getElementById("form-registro");
const alerta = document.getElementById("alerta");
const boton = document.getElementById("boton-enviar");
const f = formulario.elements;
const campo = (nombre) => f[nombre].closest(".campo");

if (MODO_APELACION) {
  iniciarApelacion();
} else if (!redirigirSiHaySesion()) {
  document.body.removeAttribute("data-protegida");
  iniciarRegistro();
}

/* ---------- Comunes a los dos modos ---------- */

/** Valida un archivo; devuelve texto de error o "". */
function validarArchivo(archivo, obligatorio, mensajeFalta = "Sube este documento (PDF, JPG o PNG).") {
  if (!archivo) return obligatorio ? mensajeFalta : "";
  return validarDocumento(archivo);
}

/** Errores de los datos del refugio (nombre, responsable, teléfono, dirección y horario). */
function validarDatos() {
  return {
    nombreRefugio: f.nombreRefugio.value.trim().length < 3 ? "Escribe el nombre del refugio." : "",
    responsable: f.responsable.value.trim().length < 3 ? "Escribe el nombre del responsable." : "",
    telefono: !/^[\d\s+()-]{8,}$/.test(f.telefono.value) ? "Escribe un teléfono de al menos 8 dígitos." : "",
    direccion: f.direccion.value.trim().length < 8 ? "Escribe la dirección completa del refugio." : "",
    horaApertura: !f.horaApertura.value || !f.horaCierre.value ? "Indica el horario de atención." : (f.horaCierre.value <= f.horaApertura.value ? "La hora de cierre debe ser posterior a la de apertura." : ""),
  };
}

function leerDatos() {
  return {
    nombreRefugio: f.nombreRefugio.value.trim(),
    responsable: f.responsable.value.trim(),
    telefono: f.telefono.value.trim(),
    direccion: f.direccion.value.trim(),
    horario: `${f.horaApertura.value} - ${f.horaCierre.value}`,
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

/** Los archivos elegidos viajan al servidor en base64 (data URL); él los valida y los guarda. */
function leerArchivosElegidos() {
  return Promise.all(DOCUMENTOS
    .filter(([nombre]) => f[nombre].files[0])
    .map(async ([nombre, tipo]) => ({ tipo, nombre: f[nombre].files[0].name, dataUrl: await leerComoDataUrl(f[nombre].files[0]) })));
}

/** Envía con el botón desactivado; muestra el error de lectura de archivos si lo hay. */
async function enviar(accion) {
  boton.disabled = true;
  let documentos;
  try {
    documentos = await leerArchivosElegidos();
  } catch {
    boton.disabled = false;
    mostrarAlerta(alerta, "error", "No pudimos leer uno de los archivos. Vuelve a seleccionarlo e inténtalo de nuevo.");
    return null;
  }
  const r = await accion(documentos);
  boton.disabled = false;
  if (!r.ok) mostrarAlerta(alerta, "error", r.error);
  return r.ok ? r : null;
}

/* ---------- Registro nuevo ---------- */

function iniciarRegistro() {
  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const errores = {
      ...validarDatos(),
      correo: !esCorreoValido(f.correo.value.trim()) ? "Escribe un correo válido, por ejemplo refugio@correo.com." : "",
      password: f.password.value.length < 8 ? "Usa al menos 8 caracteres." : "",
    };
    DOCUMENTOS.forEach(([nombre, , obligatorio]) => { errores[nombre] = validarArchivo(f[nombre].files[0], obligatorio); });
    if (mostrarErrores(errores)) return;

    const r = await enviar((documentos) => registrarRefugio({ ...leerDatos(), correo: f.correo.value.trim(), password: f.password.value, documentos }));
    if (!r) return;
    mostrarAlerta(alerta, "exito", "Solicitud enviada. Tu refugio queda en estado Pendiente de verificación. Te llevamos al inicio de sesión…");
    setTimeout(() => irA("pages/login.html"), 2200);
  });
}

/* ---------- Modo apelación ---------- */

async function iniciarApelacion() {
  // Solo un refugio con sesión (aún sin aprobar) puede apelar; el servidor además exige que esté rechazado
  if (!requerirRol("refugio", { permitirRefugioNoVerificado: true })) return;

  document.title = "Apelar solicitud · HuellApp";
  document.getElementById("registro-titulo").textContent = "Apelación de tu solicitud";
  document.getElementById("registro-intro").textContent = "Corrige lo que te indicó el administrador y vuelve a enviar tu solicitud. Quedará otra vez como Pendiente de verificación.";
  boton.textContent = "Reenviar solicitud";
  const volver = document.getElementById("boton-volver");
  volver.href = "estado-refugio.html";
  volver.textContent = "Cancelar";

  // La cuenta ya existe: el correo se muestra pero no se edita, y la contraseña no se pide
  f.correo.readOnly = true;
  campo("correo").append(crearElemento("span", { clase: "campo__ayuda", texto: "El correo de tu cuenta no se puede cambiar." }));
  campo("password").hidden = true;

  boton.disabled = true;
  mostrarAlerta(alerta, "aviso", "Cargando tus datos…");
  const refugio = await obtenerApelacion();
  if (!refugio) { irA(RUTA_ESTADO_REFUGIO); return; } // ya no está rechazada: no hay nada que apelar
  ocultarAlerta(alerta);
  boton.disabled = false;

  precargar(refugio);
  const requeridos = prepararDocumentos(refugio.documentos);

  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);
    const errores = validarDatos();
    DOCUMENTOS.forEach(([nombre, tipo]) => {
      const mensaje = requeridos[tipo] === "error" ? "Este documento fue señalado como erróneo: sube un archivo nuevo." : "Sube este documento (PDF, JPG o PNG).";
      errores[nombre] = validarArchivo(f[nombre].files[0], Boolean(requeridos[tipo]), mensaje);
    });
    if (mostrarErrores(errores)) return;

    const r = await enviar((documentos) => enviarApelacion({ ...leerDatos(), documentos }));
    if (!r) return;
    try { await refrescarSesion(); } catch { /* la pantalla de estado vuelve a consultarlo */ }
    formulario.querySelectorAll("input, button").forEach((c) => { c.disabled = true; });
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
function prepararDocumentos(documentos) {
  const requeridos = {};
  DOCUMENTOS.forEach(([nombre, tipo, obligatorio]) => {
    const actual = documentos.find((d) => d.tipo === tipo);
    const zona = campo(nombre);
    const input = f[nombre];
    requeridos[tipo] = actual?.conError ? "error" : (obligatorio && !actual ? "falta" : false);

    const estado = crearElemento("span", { clase: "documento-actual", atributos: { id: `actual-${nombre}` } });
    if (actual) {
      estado.textContent = `Archivo actual: ${actual.nombre} (${formatearTamano(actual.tamano)})${actual.conError ? "" : ". Se conserva si no eliges otro."}`;
    } else {
      estado.textContent = obligatorio ? "Aún no has subido este documento." : "Opcional: puedes agregarlo ahora.";
    }
    const descripciones = [estado.id];

    if (actual?.conError) {
      zona.classList.add("campo--observado");
      const aviso = crearElemento("p", { clase: "campo__aviso", atributos: { id: `aviso-${nombre}` } }, [
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
