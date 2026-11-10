/**
 * login.js — Pantalla de inicio de sesión con selector de rol.
 */
import { iniciarSesion, iniciarSesionGoogle, verificarCodigo2fa, obtenerConfigAuth, entrarComoInvitado } from "../../core/auth.js";
import { redirigirSiHaySesion, destinoDeSesion } from "../../core/router-guard.js";
import { CUENTAS_DEMO } from "../../data/cuentas-demo.js";
import { irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError } from "../../core/utils.js";

if (!redirigirSiHaySesion()) iniciar();

/**
 * Dibuja el botón oficial de Google si la API tiene un Client ID configurado.
 * `alRecibir(idToken)` se llama cuando la persona elige su cuenta de Google.
 */
async function montarBotonGoogle(alRecibir) {
  const { googleClientId } = await obtenerConfigAuth();
  if (!googleClientId) return; // sin GOOGLE_CLIENT_ID en api/.env no se muestra
  try {
    await cargarScript("https://accounts.google.com/gsi/client");
  } catch {
    return; // sin internet: se sigue entrando con correo y contraseña
  }
  const zona = document.getElementById("zona-google");
  window.google.accounts.id.initialize({
    client_id: googleClientId,
    callback: (respuesta) => alRecibir(respuesta.credential),
    ux_mode: "popup",
    use_fedcm_for_prompt: true,
  });
  zona.hidden = false;
  window.google.accounts.id.renderButton(document.getElementById("boton-google"), {
    type: "standard", theme: "outline", size: "large", shape: "pill", text: "continue_with", locale: "es",
    width: Math.min(360, zona.clientWidth || 360),
  });
}

function cargarScript(src) {
  return new Promise((resolver, rechazar) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = resolver;
    script.onerror = rechazar;
    document.head.append(script);
  });
}

function iniciar() {
  const formulario = document.getElementById("form-login");
  const alerta = document.getElementById("alerta");
  const pestanas = [...document.querySelectorAll("[data-rol]")];
  const enlaceRegistro = document.getElementById("enlace-registro");
  const campoCorreo = document.getElementById("campo-correo");
  const campoPassword = document.getElementById("campo-password");
  const boton = document.getElementById("boton-entrar");

  let rolActivo = "usuario";

  /* ---------- Pestañas de rol (teclado: flechas izquierda/derecha) ---------- */
  const REGISTRO_POR_ROL = {
    usuario: { href: "registro-usuario.html", texto: "Regístrate" },
    refugio: { href: "registro-refugio.html", texto: "Registra tu refugio" },
    admin: null, // los administradores no se auto-registran
    invitado: { href: "registro-usuario.html", texto: "Crea una cuenta" },
  };
  const textoInvitado = document.getElementById("texto-invitado");

  function seleccionarRol(rol) {
    rolActivo = rol;
    pestanas.forEach((p) => {
      const activa = p.dataset.rol === rol;
      p.setAttribute("aria-selected", String(activa));
      p.tabIndex = activa ? 0 : -1;
    });
    // El visitante no escribe correo ni contraseña
    const invitado = rol === "invitado";
    campoCorreo.hidden = invitado;
    campoPassword.hidden = invitado;
    document.getElementById("zona-google").classList.toggle("login__google--oculto", invitado);
    textoInvitado.hidden = !invitado;
    boton.textContent = invitado ? "Entrar como visitante" : "Entrar";
    const registro = REGISTRO_POR_ROL[rol];
    enlaceRegistro.hidden = !registro;
    if (registro) {
      enlaceRegistro.querySelector("a").href = registro.href;
      enlaceRegistro.querySelector("a").textContent = registro.texto;
    }
    ocultarAlerta(alerta);
  }

  document.getElementById("selector-rol").addEventListener("click", (e) => {
    const pestana = e.target.closest("[data-rol]");
    if (pestana) seleccionarRol(pestana.dataset.rol);
  });

  document.getElementById("selector-rol").addEventListener("keydown", (e) => {
    if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
    const i = pestanas.findIndex((p) => p.dataset.rol === rolActivo);
    const siguiente = pestanas[(i + (e.key === "ArrowRight" ? 1 : pestanas.length - 1)) % pestanas.length];
    seleccionarRol(siguiente.dataset.rol);
    siguiente.focus();
  });

  /* ---------- Cuentas demo (un solo listener por delegación) ---------- */
  const listaDemo = document.getElementById("lista-demo");
  const fragmento = document.createDocumentFragment();
  CUENTAS_DEMO.forEach((cuenta, indice) => {
    const fila = document.createElement("li");
    fila.className = "demo__item";
    const texto = document.createElement("span");
    texto.textContent = `${cuenta.etiqueta}: ${cuenta.correo}`;
    const usar = document.createElement("button");
    usar.type = "button";
    usar.className = "boton boton--secundario boton--pequeno";
    usar.dataset.indice = String(indice);
    usar.textContent = "Usar";
    fila.append(texto, usar);
    fragmento.append(fila);
  });
  listaDemo.append(fragmento);

  listaDemo.addEventListener("click", (e) => {
    const boton = e.target.closest("[data-indice]");
    if (!boton) return;
    const cuenta = CUENTAS_DEMO[Number(boton.dataset.indice)];
    seleccionarRol(cuenta.rol);
    formulario.correo.value = cuenta.correo;
    formulario.password.value = cuenta.password;
    formulario.password.focus();
  });

  /* ---------- Envío ---------- */
  formulario.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta);

    if (rolActivo === "invitado") {
      irA(destinoDeSesion(entrarComoInvitado()));
      return;
    }

    const correo = formulario.correo.value.trim();
    const password = formulario.password.value;

    const errorCorreo = !correo ? "Escribe tu correo." : !esCorreoValido(correo) ? "Revisa el formato del correo, por ejemplo nombre@correo.com." : "";
    const errorPassword = password ? "" : "Escribe tu contraseña.";
    marcarError(campoCorreo, errorCorreo);
    marcarError(campoPassword, errorPassword);
    if (errorCorreo || errorPassword) return;

    boton.disabled = true;
    boton.textContent = "Entrando…";
    const resultado = await iniciarSesion({ rol: rolActivo, correo, password });
    boton.disabled = false;
    boton.textContent = "Entrar";
    terminarPaso(resultado);
  });

  /** Después de la contraseña o de Google: entra, o pide el código de dos pasos. */
  function terminarPaso(resultado) {
    if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error); return; }
    if (resultado.requiere2fa) { mostrarPaso2fa(resultado.desafio); return; }
    irA(destinoDeSesion(resultado.sesion));
  }

  /* ---------- Segundo paso: código de Google Authenticator ---------- */
  const form2fa = document.getElementById("form-2fa");
  const alerta2fa = document.getElementById("alerta-2fa");
  const campoCodigo = document.getElementById("campo-codigo");
  const botonVerificar = document.getElementById("boton-verificar");
  const ocultosEn2fa = [formulario, document.getElementById("selector-rol"), enlaceRegistro, document.querySelector(".demo")];
  let desafio = null;

  function mostrarPaso2fa(nuevoDesafio) {
    desafio = nuevoDesafio;
    ocultosEn2fa.forEach((el) => { el.hidden = true; });
    form2fa.hidden = false;
    ocultarAlerta(alerta2fa);
    form2fa.codigo.value = "";
    marcarError(campoCodigo, "");
    form2fa.codigo.focus();
  }

  function volverAlLogin(mensaje) {
    desafio = null;
    form2fa.hidden = true;
    ocultosEn2fa.forEach((el) => { el.hidden = false; });
    seleccionarRol(rolActivo);
    if (mensaje) mostrarAlerta(alerta, "aviso", mensaje);
  }

  document.getElementById("boton-volver").addEventListener("click", () => volverAlLogin());

  form2fa.addEventListener("submit", async (e) => {
    e.preventDefault();
    ocultarAlerta(alerta2fa);
    const codigo = form2fa.codigo.value.replace(/\s+/g, "");
    const error = /^\d{6}$/.test(codigo) ? "" : "Escribe los 6 dígitos que muestra Google Authenticator.";
    marcarError(campoCodigo, error);
    if (error) return;

    botonVerificar.disabled = true;
    botonVerificar.textContent = "Verificando…";
    const resultado = await verificarCodigo2fa({ desafio, codigo });
    botonVerificar.disabled = false;
    botonVerificar.textContent = "Verificar";
    if (resultado.ok) { irA(destinoDeSesion(resultado.sesion)); return; }
    if (/5 minutos|Vuelve a iniciar sesión/.test(resultado.error)) { volverAlLogin(resultado.error); return; }
    mostrarAlerta(alerta2fa, "error", resultado.error);
    form2fa.codigo.select();
  });

  /* ---------- «Continuar con Google» (Google Identity Services) ---------- */
  montarBotonGoogle(async (idToken) => {
    ocultarAlerta(alerta);
    terminarPaso(await iniciarSesionGoogle({ rol: rolActivo === "invitado" ? "usuario" : rolActivo, idToken }));
  });

  seleccionarRol("usuario");
  if (new URLSearchParams(window.location.search).get("motivo") === "cuenta") {
    mostrarAlerta(alerta, "aviso", "Para usar esa sección necesitas iniciar sesión o crear una cuenta.");
  }
}
