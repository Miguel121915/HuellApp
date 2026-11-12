/**
 * avisos.js — Campana de avisos del encabezado (HU-19).
 * Consulta GET /api/avisos cada 30 s, muestra el número de no leídos y la lista al tocarla.
 * Si la persona lo permite, avisa también con una notificación del navegador cuando llega
 * algo nuevo y la pestaña no está a la vista.
 */
import { get, post } from "../core/api.js";
import { crearElemento, rutaDesdeRaiz, irA } from "../core/utils.js";

const CADA_MS = 30000;

/** A qué página lleva cada sección del aviso. */
const RUTAS = {
  coincidencias: "pages/usuario/coincidencias.html",
  solicitudes: "pages/usuario/refugios.html",
  mensajes: "pages/usuario/mensajes.html",
  foro: "pages/usuario/foro.html",
  "refugio-mensajes": "pages/refugio/mensajes.html",
  "refugio-adopciones": "pages/refugio/adopciones.html",
  "estado-refugio": "pages/refugio/panel.html",
};

const hace = (iso) => {
  const min = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (min < 1) return "ahora";
  if (min < 60) return `hace ${min} min`;
  if (min < 1440) return `hace ${Math.round(min / 60)} h`;
  return new Date(iso).toLocaleDateString("es-MX");
};

/** Agrega la campana dentro de `contenedor` (las acciones del encabezado). */
export function montarAvisos(contenedor) {
  const zona = crearElemento("div", { clase: "avisos" });
  const boton = crearElemento("button", {
    clase: "boton boton--contorno boton--pequeno avisos__boton",
    atributos: { type: "button", "aria-haspopup": "true", "aria-expanded": "false", title: "Avisos" },
  }, [
    crearElemento("span", { texto: "🔔", atributos: { "aria-hidden": "true" } }),
    crearElemento("span", { clase: "solo-lector", texto: "Avisos" }),
  ]);
  const insignia = crearElemento("span", { clase: "nav__insignia avisos__insignia", atributos: { hidden: true } });
  boton.append(insignia);
  const panel = crearElemento("div", { clase: "avisos__panel", atributos: { hidden: true, role: "dialog", "aria-label": "Avisos" } });
  zona.append(boton, panel);
  contenedor.prepend(zona);

  let avisos = [];
  let noLeidos = 0;
  let ultimoVisto = null; // id del aviso más nuevo ya conocido (para notificar solo lo nuevo)

  function pintarInsignia() {
    insignia.textContent = noLeidos > 9 ? "9+" : String(noLeidos);
    insignia.hidden = noLeidos === 0;
    boton.setAttribute("aria-label", noLeidos ? `Avisos: ${noLeidos} sin leer` : "Avisos");
  }

  function pintarPanel() {
    const permiso = "Notification" in window ? Notification.permission : "denied";
    panel.replaceChildren(...[
      crearElemento("div", { clase: "avisos__cabecera" }, [
        crearElemento("strong", { texto: "Avisos" }),
        noLeidos ? crearElemento("button", { clase: "enlace", texto: "Marcar todo como leído", atributos: { type: "button", "data-accion": "todos" } }) : null,
      ]),
      avisos.length
        ? crearElemento("ul", { clase: "avisos__lista" }, avisos.map((a) => crearElemento("li", {}, crearElemento("button", {
          clase: `avisos__item${a.leido ? "" : " avisos__item--nuevo"}`,
          atributos: { type: "button", "data-id": a.id, "data-seccion": a.seccion },
        }, [
          crearElemento("strong", { texto: a.titulo }),
          a.texto ? crearElemento("span", { texto: a.texto }) : null,
          crearElemento("small", { texto: hace(a.fecha) }),
        ]))))
        : crearElemento("p", { clase: "texto-suave texto-pequeno", texto: "No tienes avisos todavía." }),
      permiso === "default"
        ? crearElemento("button", { clase: "boton boton--secundario boton--pequeno", texto: "Recibir avisos del navegador", atributos: { type: "button", "data-accion": "permiso" } })
        : null,
    ].filter(Boolean)); // replaceChildren escribiría «null» como texto
  }

  function notificar(nuevos) {
    if (!("Notification" in window) || Notification.permission !== "granted" || !document.hidden) return;
    nuevos.slice(0, 3).forEach((a) => {
      const n = new Notification(a.titulo, { body: a.texto || "HuellApp", icon: rutaDesdeRaiz("assets/img/favicon.svg"), tag: `aviso-${a.id}` });
      n.onclick = () => { window.focus(); abrir(a); };
    });
  }

  async function actualizar() {
    try {
      const r = await get("/avisos");
      const nuevos = ultimoVisto === null ? [] : r.avisos.filter((a) => !a.leido && Number(a.id) > Number(ultimoVisto));
      avisos = r.avisos;
      noLeidos = r.noLeidos;
      if (avisos.length) ultimoVisto = avisos.reduce((max, a) => Math.max(max, Number(a.id)), Number(ultimoVisto || 0));
      else if (ultimoVisto === null) ultimoVisto = 0;
      pintarInsignia();
      if (!panel.hidden) pintarPanel();
      notificar(nuevos);
    } catch { /* sin conexión: se reintenta en 30 s */ }
  }

  async function abrir(aviso) {
    if (!aviso.leido) { try { await post("/avisos/leidos", { ids: [aviso.id] }); } catch { /* no importa */ } }
    irA(RUTAS[aviso.seccion] || RUTAS.foro);
  }

  function alternar(abrirPanel = panel.hidden) {
    panel.hidden = !abrirPanel;
    boton.setAttribute("aria-expanded", String(abrirPanel));
    if (abrirPanel) pintarPanel();
  }

  boton.addEventListener("click", () => alternar());
  document.addEventListener("click", (e) => { if (!zona.contains(e.target)) alternar(false); });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !panel.hidden) { alternar(false); boton.focus(); } });

  panel.addEventListener("click", async (e) => {
    const item = e.target.closest("[data-id]");
    if (item) { abrir(avisos.find((a) => a.id === item.dataset.id)); return; }
    const accion = e.target.closest("[data-accion]")?.dataset.accion;
    if (accion === "todos") {
      try { await post("/avisos/leidos", {}); } catch { return; }
      avisos = avisos.map((a) => ({ ...a, leido: true }));
      noLeidos = 0;
      pintarInsignia();
      pintarPanel();
    } else if (accion === "permiso") {
      await Notification.requestPermission();
      pintarPanel();
    }
  });

  actualizar();
  const conPermiso = () => "Notification" in window && Notification.permission === "granted";
  setInterval(() => { if (!document.hidden || conPermiso()) actualizar(); }, CADA_MS);
}
