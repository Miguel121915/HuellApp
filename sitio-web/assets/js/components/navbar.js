/**
 * navbar.js — Encabezado turquesa + navegación superior fija (escritorio).
 * Se monta dentro de <header id="encabezado" class="encabezado"> en cada página.
 * Cada rol tiene su propio menú; las Fases 3 y 4 añaden los de refugio y administrador.
 */
import { rutaDesdeRaiz, irA } from "../core/utils.js";
import { cerrarSesion, obtenerSesion } from "../core/auth.js";
import { obtenerResumenCoincidencias } from "../core/servicios.js";
import { obtenerResumenAdmin } from "../core/servicios-admin.js";
import { obtenerResumen as obtenerResumenRefugio } from "../core/servicios-refugio.js";

/* Iconos SVG propios (trazo, hereda el color del texto). Contenido estático y de confianza. */
const PATA = '<g fill="currentColor" stroke="none"><ellipse cx="12" cy="15.5" rx="3.6" ry="2.8"/><ellipse cx="6.8" cy="11.6" rx="1.6" ry="2.1"/><ellipse cx="10" cy="8" rx="1.6" ry="2.2"/><ellipse cx="14" cy="8" rx="1.6" ry="2.2"/><ellipse cx="17.2" cy="11.6" rx="1.6" ry="2.1"/></g>';
const svg = (contenido) => `<svg class="nav__icono" viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${contenido}</svg>`;

const ICONOS = {
  foro: svg('<path d="M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-7l-5 4v-4H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/>'),
  refugios: svg('<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M12 17.5s-3.5-2.2-3.5-4.5a2 2 0 0 1 3.5-1.3 2 2 0 0 1 3.5 1.3c0 2.3-3.5 4.5-3.5 4.5z"/>'),
  inicio: svg('<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>'),
  reportar: svg('<path d="M4 7h3l2-3h6l2 3h3a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z"/>'),
  coincidencias: svg('<circle cx="9" cy="12" r="6"/><circle cx="15" cy="12" r="6"/>'),
  favoritos: svg('<path d="M12 20s-7-4.4-7-9.6A4.1 4.1 0 0 1 12 8a4.1 4.1 0 0 1 7 2.4C19 15.6 12 20 12 20z"/>'),
  mensajes: svg('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>'),
  requisitos: svg('<path d="M9 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3"/><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M8 11h8M8 15h5"/>'),
  // Refugio
  panel: svg('<rect x="3" y="3" width="8" height="8" rx="1.5"/><rect x="13" y="3" width="8" height="8" rx="1.5"/><rect x="3" y="13" width="8" height="8" rx="1.5"/><rect x="13" y="13" width="8" height="8" rx="1.5"/>'),
  inventario: svg('<path d="M3 8l9-5 9 5v9l-9 5-9-5z"/><path d="M3 8l9 5 9-5M12 13v9"/>'),
  publicaciones: svg('<path d="M4 4h16v13H8l-4 4z"/><path d="M8 9h8M8 13h5"/>'),
  adopciones: svg('<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M12 18s-3-1.9-3-3.9a1.7 1.7 0 0 1 3-1.1 1.7 1.7 0 0 1 3 1.1c0 2-3 3.9-3 3.9z"/>'),
  preguntas: svg('<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 0 1 4.9.6c0 1.7-2.4 2.2-2.4 3.9"/><path d="M12 17.2v.1"/>'),
  // Administrador
  solicitudes: svg('<path d="M9 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3"/><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M9 14l2 2 4-4"/>'),
  perfil: svg('<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>'),
};
// Decoran foro (huella dentro del globo) y reportar (huella dentro de la cámara)
ICONOS.foro = ICONOS.foro.replace("</svg>", `<g transform="translate(5.5 3.2) scale(.55)">${PATA}</g></svg>`);
ICONOS.reportar = ICONOS.reportar.replace("</svg>", `<g transform="translate(7 7.2) scale(.42)">${PATA}</g></svg>`);

/* Menú por rol. `id` es el que usa cada página para marcar su enlace como activo. */
const MENUS = {
  usuario: [
    { id: "foro", etiqueta: "Foro", ruta: "pages/usuario/foro.html" },
    { id: "refugios", etiqueta: "Refugios", ruta: "pages/usuario/refugios.html" },
    { id: "inicio", etiqueta: "Inicio", ruta: "pages/usuario/inicio.html" },
    { id: "reportar", etiqueta: "Reportar", ruta: "pages/usuario/reportar.html" },
    { id: "coincidencias", etiqueta: "Coincidencias", ruta: "pages/usuario/coincidencias.html", insignia: true },
    { id: "favoritos", etiqueta: "Favoritos", ruta: "pages/usuario/favoritos.html" },
    { id: "mensajes", etiqueta: "Mensajes", ruta: "pages/usuario/mensajes.html" },
  ],
  refugio: [
    { id: "panel", etiqueta: "Panel", ruta: "pages/refugio/panel.html" },
    { id: "inventario", etiqueta: "Inventario", ruta: "pages/refugio/inventario.html" },
    { id: "publicaciones", etiqueta: "Publicaciones", ruta: "pages/refugio/publicaciones.html" },
    { id: "adopciones", etiqueta: "Adopciones", ruta: "pages/refugio/adopciones.html" },
    { id: "mensajes", etiqueta: "Mensajes", ruta: "pages/refugio/mensajes.html", insignia: true },
    { id: "requisitos", etiqueta: "Requisitos", ruta: "pages/refugio/requisitos.html" },
    { id: "preguntas", etiqueta: "Preguntas", ruta: "pages/refugio/preguntas.html" },
    { id: "perfil", etiqueta: "Perfil", ruta: "pages/refugio/perfil.html" },
  ],
  admin: [
    { id: "solicitudes", etiqueta: "Solicitudes", ruta: "pages/admin/solicitudes.html", insignia: true },
    { id: "refugios", etiqueta: "Refugios", ruta: "pages/admin/refugios.html" },
  ],
};
// Visitante sin cuenta: ve las mismas secciones que un usuario; al intentar hacer algo se le pide cuenta
MENUS.invitado = MENUS.usuario.map(({ insignia, ...item }) => item);

const HUELLA_LOGO = "assets/img/logos/huella.svg";
const INICIO_POR_ROL = { usuario: "pages/usuario/inicio.html", refugio: "pages/refugio/panel.html", admin: "pages/admin/solicitudes.html", invitado: "pages/usuario/inicio.html" };

/**
 * Dibuja el encabezado.
 * @param {{sesion:object, activa:string}} opciones  `activa` = id del enlace de la página actual
 */
export async function montarNavbar({ sesion, activa }) {
  const encabezado = document.getElementById("encabezado");
  if (!encabezado) return;

  const enlaces = (MENUS[sesion.rol] || []).map((item) => `
    <a class="nav__enlace" href="${rutaDesdeRaiz(item.ruta)}"${item.id === activa ? ' aria-current="page"' : ""}>
      ${ICONOS[item.id]}
      <span>${item.etiqueta}</span>
      ${item.insignia ? `<span class="nav__insignia" id="insignia-${item.id}" hidden></span>` : ""}
    </a>`).join("");

  encabezado.innerHTML = `
    <div class="encabezado__interno">
      <a class="marca" href="${rutaDesdeRaiz(INICIO_POR_ROL[sesion.rol] || "index.html")}" aria-label="HuellApp, ir al inicio">
        <span class="logo-texto marca__texto">HuellApp</span>
        <img class="marca__huella" src="${rutaDesdeRaiz(HUELLA_LOGO)}" alt="" width="48" height="48">
      </a>
      <nav class="nav" aria-label="Principal">${enlaces}</nav>
      <div class="encabezado__acciones">
        <span class="encabezado__usuario texto-pequeno" id="nombre-usuario"></span>
        ${sesion.rol === "invitado" ? "" : '<button class="boton boton--contorno boton--pequeno" id="boton-seguridad" type="button" title="Verificación en dos pasos">🔒 Seguridad</button>'}
        <button class="boton boton--contorno boton--pequeno" id="boton-salir" type="button">${sesion.rol === "invitado" ? "Iniciar sesión" : "Cerrar sesión"}</button>
      </div>
    </div>`;

  // El nombre se inserta con textContent: nunca como HTML
  encabezado.querySelector("#nombre-usuario").textContent = sesion.nombre;
  encabezado.querySelector("#boton-salir").addEventListener("click", () => {
    cerrarSesion();
    irA("pages/login.html");
  });
  encabezado.querySelector("#boton-seguridad")?.addEventListener("click", async () => {
    const { abrirSeguridad } = await import("./seguridad-cuenta.js"); // se carga solo cuando se usa
    abrirSeguridad();
  });

  if (sesion.rol === "usuario") {
    await refrescarInsigniaCoincidencias();
    // La IA busca coincidencias en segundo plano: se revisa cada 30 s y se avisa si llegan nuevas
    setInterval(() => { if (!document.hidden) refrescarInsigniaCoincidencias(); }, 30000);
  }
  if (sesion.rol === "admin") await refrescarInsigniaSolicitudes();
  if (sesion.rol === "refugio") await refrescarInsigniaMensajes();
}

/** Número rojo de "Mensajes" del refugio (mensajes nuevos sin leer). */
export async function refrescarInsigniaMensajes() {
  const insignia = document.getElementById("insignia-mensajes");
  if (!insignia) return;
  let total = 0;
  try {
    total = (await obtenerResumenRefugio()).mensajesNuevos || 0;
  } catch {
    return; // sin conexión: la franja de aviso ya lo explica
  }
  insignia.textContent = String(total);
  insignia.hidden = total === 0;
  insignia.setAttribute("aria-label", `${total} mensajes nuevos`);
}

/** Actualiza el número rojo de "Coincidencias". Se llama al montar y tras declinar una. */
export async function refrescarInsigniaCoincidencias() {
  const insignia = document.getElementById("insignia-coincidencias");
  if (!insignia) return;
  let total = 0;
  try {
    total = (await obtenerResumenCoincidencias()).pendientes;
  } catch {
    return; // sin conexión: la franja de aviso ya lo explica; el menú sigue funcionando
  }
  insignia.textContent = String(total);
  insignia.hidden = total === 0;
  insignia.setAttribute("aria-label", `${total} coincidencias nuevas`);

  // ¿Llegaron coincidencias desde la última vez? (en «Coincidencias» se marcan como vistas)
  const clave = `huellapp:coincidencias-vistas:${obtenerSesion()?.id ?? ""}`;
  const vistas = Number(localStorage.getItem(clave) ?? NaN);
  const enCoincidencias = location.pathname.endsWith("/coincidencias.html");
  if (enCoincidencias || Number.isNaN(vistas) || total < vistas) {
    localStorage.setItem(clave, String(total));
  } else if (total > vistas) {
    localStorage.setItem(clave, String(total));
    avisarCoincidencias(total - vistas);
  }
}

/** Aviso emergente dentro del sitio: «Encontramos N posibles coincidencias». */
function avisarCoincidencias(nuevas) {
  document.querySelector(".aviso-coincidencias")?.remove();
  const aviso = document.createElement("div");
  aviso.className = "aviso-coincidencias";
  aviso.setAttribute("role", "status");
  aviso.innerHTML = '<span class="aviso-coincidencias__icono" aria-hidden="true">🐾</span><p></p><a class="boton boton--primario boton--pequeno">Ver</a><button type="button" class="aviso-coincidencias__cerrar" aria-label="Cerrar aviso">×</button>';
  aviso.querySelector("p").textContent = nuevas === 1
    ? "Encontramos 1 posible coincidencia para tu reporte."
    : `Encontramos ${nuevas} posibles coincidencias para tus reportes.`;
  aviso.querySelector("a").href = rutaDesdeRaiz("pages/usuario/coincidencias.html");
  aviso.querySelector("button").addEventListener("click", () => aviso.remove());
  document.body.append(aviso);
  setTimeout(() => aviso.remove(), 15000);
}

/** Actualiza el número rojo de "Solicitudes" (refugios pendientes de revisar). Solo administrador. */
export async function refrescarInsigniaSolicitudes() {
  const insignia = document.getElementById("insignia-solicitudes");
  if (!insignia) return;
  let total = 0;
  try {
    total = (await obtenerResumenAdmin()).pendientes;
  } catch {
    return; // sin conexión: la franja de aviso ya lo explica
  }
  insignia.textContent = String(total);
  insignia.hidden = total === 0;
  insignia.setAttribute("aria-label", `${total} solicitudes pendientes`);
}
