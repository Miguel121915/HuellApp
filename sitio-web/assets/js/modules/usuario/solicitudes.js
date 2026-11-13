/**
 * solicitudes.js — «Mis solicitudes» (HU-14) en la web: el estado de cada solicitud de adopción y la
 * nota del refugio. En las aprobadas, la guía de cuidado después de adoptar (HU-23): una guía base
 * por especie y edad (al instante) y consejos con IA para esa mascota (se piden y se guardan).
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { obtenerMisSolicitudesAdopcion, obtenerGuiaCuidados, personalizarGuiaCuidados } from "../../core/servicios.js";
import { crearElemento, formatearFecha, mostrarAlerta, resolverImagen } from "../../core/utils.js";

const ESTADOS = {
  pendiente: { texto: "Pendiente", clase: "pendiente" },
  "en revision": { texto: "En revisión", clase: "pendiente" },
  aprobada: { texto: "¡Aprobada! 🎉", clase: "aprobado" },
  rechazada: { texto: "No aprobada", clase: "rechazado" },
};
const ETAPAS = { cachorro: "Etapa: cachorro", adulto: "Etapa: adulto", senior: "Etapa: edad avanzada (senior)" };

const sesion = requerirRol("usuario");
const lista = document.getElementById("lista-solicitudes");
const vacio = document.getElementById("sin-solicitudes");
const alerta = document.getElementById("alerta");
const modal = document.getElementById("modal-guia");
const consejos = document.getElementById("guia-consejos");
const secciones = document.getElementById("guia-secciones");

let solicitudes = [];
let abierta = null;

if (sesion) {
  montarNavbar({ sesion, activa: "solicitudes" });
  enlazarEventos();
  cargar();
}

async function cargar() {
  try {
    solicitudes = await obtenerMisSolicitudesAdopcion();
  } catch (error) {
    mostrarAlerta(alerta, "error", error.message || "No pudimos cargar tus solicitudes.");
    return;
  }
  vacio.hidden = solicitudes.length > 0;
  lista.replaceChildren(...solicitudes.map(crearItem));
  // Si llegan desde un aviso «¡Aprobaron tu solicitud!», se abre la guía de la más reciente aprobada
  if (new URLSearchParams(location.search).get("guia") === "1") {
    const aprobada = solicitudes.find((s) => s.estado === "aprobada");
    if (aprobada) abrirGuia(aprobada.id);
  }
}

function crearItem(s) {
  const estado = ESTADOS[s.estado] || { texto: s.estado, clase: "pendiente" };
  const nota = (s.notaRefugio || "").trim();
  return crearElemento("li", {}, crearElemento("article", { clase: "mi-solicitud tarjeta tarjeta--blanca" }, [
    crearElemento("img", { clase: "mi-solicitud__foto", atributos: { src: resolverImagen(s.mascotaFoto), alt: "", width: 72, height: 72, loading: "lazy" } }),
    crearElemento("div", { clase: "mi-solicitud__info" }, [
      crearElemento("strong", { texto: s.mascotaNombre }),
      crearElemento("span", { texto: s.refugioNombre }),
      crearElemento("small", { clase: "texto-suave", texto: `Enviada el ${formatearFecha(s.fecha)}` }),
      ...(nota ? [crearElemento("p", { clase: "mi-solicitud__nota", texto: `Nota del refugio: ${nota}` })] : []),
    ]),
    crearElemento("div", { clase: "mi-solicitud__lado" }, [
      crearElemento("span", { clase: `insignia insignia--${estado.clase}`, texto: estado.texto }),
      ...(s.estado === "aprobada" ? [crearElemento("button", {
        clase: "boton boton--primario boton--pequeno", texto: "Ver guía de cuidado",
        atributos: { type: "button", "data-guia": s.id, "aria-label": `Ver la guía para cuidar a ${s.mascotaNombre}` },
      })] : []),
    ]),
  ]));
}

/* ---------- Guía de cuidado (HU-23) ---------- */

const texto = (clase, contenido) => crearElemento("p", { clase, texto: contenido });

async function abrirGuia(id) {
  abierta = id;
  document.getElementById("guia-titulo").textContent = "Guía de cuidado";
  document.getElementById("guia-etapa").textContent = "";
  secciones.replaceChildren(texto("texto-suave", "Cargando la guía…"));
  consejos.replaceChildren();
  if (!modal.open) modal.showModal();

  const r = await obtenerGuiaCuidados(id);
  if (abierta !== id) return;
  if (!r.ok) { secciones.replaceChildren(texto("alerta alerta--error", r.error)); return; }
  const guia = r.guia;
  document.getElementById("guia-titulo").textContent = guia.titulo;
  document.getElementById("guia-etapa").textContent = ETAPAS[guia.etapa] || "";
  secciones.replaceChildren(...guia.secciones.map((sec) => crearElemento("section", { clase: "guia-seccion" }, [
    crearElemento("h3", { texto: `${sec.icono} ${sec.titulo}` }),
    crearElemento("ul", {}, sec.puntos.map((p) => crearElemento("li", { texto: p }))),
  ])));

  if (guia.consejos) { pintarConsejos(guia.consejos); return; }
  // Los consejos con IA tardan unos segundos: la guía base ya se ve mientras tanto
  consejos.replaceChildren(texto("texto-suave texto-pequeno", "Preparando consejos para tu mascota… 🐾"));
  const p = await personalizarGuiaCuidados(id);
  if (abierta !== id) return;
  if (p.ok && p.consejos) pintarConsejos(p.consejos);
  else consejos.replaceChildren(texto("texto-suave texto-pequeno", "Por ahora no pudimos preparar consejos personalizados. La guía de abajo aplica para tu mascota."));
}

function pintarConsejos(lista) {
  consejos.replaceChildren(crearElemento("ul", {}, lista.map((c) => crearElemento("li", { texto: c }))));
}

function enlazarEventos() {
  lista.addEventListener("click", (e) => {
    const boton = e.target.closest("[data-guia]");
    if (boton) abrirGuia(boton.dataset.guia);
  });
  document.getElementById("cerrar-guia").addEventListener("click", () => modal.close());
  modal.addEventListener("close", () => { abierta = null; });
}
