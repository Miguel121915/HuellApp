/** inicio.js — Pantalla de inicio: KIRO y su buscador de dudas. */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { montarChatbot } from "../../components/chatbot-kiro.js";

const sesion = requerirRol("usuario");

if (sesion) {
  montarNavbar({ sesion, activa: "inicio" });
  montarChatbot({
    formulario: document.getElementById("kiro-formulario"),
    entrada: document.getElementById("kiro-entrada"),
    globo: document.getElementById("kiro-globo"),
    enlace: document.getElementById("kiro-enlace"),
    sugerencias: document.getElementById("kiro-sugerencias"),
  });
}
