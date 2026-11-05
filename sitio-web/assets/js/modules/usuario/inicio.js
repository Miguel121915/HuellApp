/**
 * inicio.js — Pantalla de inicio (igual que en la app móvil): bienvenida con búsqueda,
 * accesos rápidos, mascotas en adopción y el asistente KIRO. La ven el usuario y el visitante.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { montarChatbot } from "../../components/chatbot-kiro.js";
import { obtenerRefugiosConMascotas } from "../../core/servicios.js";
import { crearElemento, formatearEdad, irA, resolverImagen } from "../../core/utils.js";

const MAX_MASCOTAS = 8;
const sesion = requerirRol("usuario", { permitirInvitado: true });

if (sesion) {
  montarNavbar({ sesion, activa: "inicio" });

  // Búsqueda: lleva a Refugios con el texto escrito
  document.getElementById("inicio-buscador").addEventListener("submit", (evento) => {
    evento.preventDefault();
    const texto = document.getElementById("inicio-busqueda").value.trim();
    irA(`pages/usuario/refugios.html${texto ? `?q=${encodeURIComponent(texto)}` : ""}`);
  });

  cargarMascotas();

  montarChatbot({
    formulario: document.getElementById("kiro-formulario"),
    entrada: document.getElementById("kiro-entrada"),
    globo: document.getElementById("kiro-globo"),
    enlace: document.getElementById("kiro-enlace"),
    sugerencias: document.getElementById("kiro-sugerencias"),
  });
}

/** Las primeras mascotas disponibles de todos los refugios, como en la app. */
async function cargarMascotas() {
  const lista = document.getElementById("lista-mascotas");
  const vacio = document.getElementById("sin-mascotas");
  let mascotas = [];
  try {
    // Una sola petición con todos los refugios y sus mascotas
    const refugios = await obtenerRefugiosConMascotas();
    mascotas = refugios.flatMap((r) => r.mascotas || []).slice(0, MAX_MASCOTAS);
  } catch {
    // sin conexión: la franja de aviso del sitio ya lo explica
  }
  vacio.hidden = mascotas.length > 0;
  lista.replaceChildren(...mascotas.map(crearTarjeta));
}

function crearTarjeta(m) {
  const foto = crearElemento("img", { atributos: { src: resolverImagen(m.foto), alt: `Foto de ${m.nombre}`, loading: "lazy" } });
  return crearElemento("a", { clase: "mascota-mini", atributos: { href: `refugios.html?id=${encodeURIComponent(m.refugioId)}` } }, [
    crearElemento("div", { clase: "mascota-mini__foto" }, [
      foto,
      crearElemento("span", { clase: "mascota-mini__insignia", texto: "En adopción" }),
    ]),
    crearElemento("div", { clase: "mascota-mini__datos" }, [
      crearElemento("span", { clase: "mascota-mini__nombre", texto: m.nombre }),
      crearElemento("span", { clase: "mascota-mini__detalle", texto: `${m.especie === "gato" ? "Gato" : "Perro"} · ${formatearEdad(m.edadMeses)}` }),
    ]),
  ]);
}
