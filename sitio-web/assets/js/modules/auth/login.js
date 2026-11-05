/**
 * login.js — Pantalla de inicio de sesión con selector de rol.
 */
import { iniciarSesion } from "../../core/auth.js";
import { redirigirSiHaySesion, destinoDeSesion } from "../../core/router-guard.js";
import { CUENTAS_DEMO } from "../../data/cuentas-demo.js";
import { irA, esCorreoValido, mostrarAlerta, ocultarAlerta, marcarError } from "../../core/utils.js";

if (!redirigirSiHaySesion()) iniciar();

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
  };

  function seleccionarRol(rol) {
    rolActivo = rol;
    pestanas.forEach((p) => {
      const activa = p.dataset.rol === rol;
      p.setAttribute("aria-selected", String(activa));
      p.tabIndex = activa ? 0 : -1;
    });
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

    if (!resultado.ok) { mostrarAlerta(alerta, "error", resultado.error); return; }
    irA(destinoDeSesion(resultado.sesion));
  });

  seleccionarRol("usuario");
}
