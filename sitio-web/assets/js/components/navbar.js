/**
 * navbar.js — Encabezado turquesa + navegación superior fija (escritorio).
 * Se monta dentro de <header id="encabezado" class="encabezado"> en cada página.
 * Cada rol tiene su propio menú; las Fases 3 y 4 añaden los de refugio y administrador.
 */
import { rutaDesdeRaiz, irA } from "../core/utils.js";
import { cerrarSesion } from "../core/auth.js";
import { obtenerResumenCoincidencias } from "../core/servicios.js";
import { obtenerResumenAdmin } from "../core/servicios-admin.js";

/* Iconos SVG propios (trazo, hereda el color del texto). Contenido estático y de confianza. */
const PATA = '<g fill="currentColor" stroke="none"><ellipse cx="12" cy="15.5" rx="3.6" ry="2.8"/><ellipse cx="6.8" cy="11.6" rx="1.6" ry="2.1"/><ellipse cx="10" cy="8" rx="1.6" ry="2.2"/><ellipse cx="14" cy="8" rx="1.6" ry="2.2"/><ellipse cx="17.2" cy="11.6" rx="1.6" ry="2.1"/></g>';
const svg = (contenido) => `<svg class="nav__icono" viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${contenido}</svg>`;

const ICONOS = {
  foro: svg('<path d="M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-7l-5 4v-4H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/>'),
  refugios: svg('<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M12 17.5s-3.5-2.2-3.5-4.5a2 2 0 0 1 3.5-1.3 2 2 0 0 1 3.5 1.3c0 2.3-3.5 4.5-3.5 4.5z"/>'),
  inicio: svg('<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>'),
  reportar: svg('<path d="M4 7h3l2-3h6l2 3h3a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z"/>'),
  coincidencias: svg('<circle cx="9" cy="12" r="6"/><circle cx="15" cy="12" r="6"/>'),
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
  ],
  refugio: [
    { id: "panel", etiqueta: "Panel", ruta: "pages/refugio/panel.html" },
    { id: "inventario", etiqueta: "Inventario", ruta: "pages/refugio/inventario.html" },
    { id: "publicaciones", etiqueta: "Publicaciones", ruta: "pages/refugio/publicaciones.html" },
    { id: "adopciones", etiqueta: "Adopciones", ruta: "pages/refugio/adopciones.html" },
    { id: "preguntas", etiqueta: "Preguntas", ruta: "pages/refugio/preguntas.html" },
    { id: "perfil", etiqueta: "Perfil", ruta: "pages/refugio/perfil.html" },
  ],
  admin: [
    { id: "solicitudes", etiqueta: "Solicitudes", ruta: "pages/admin/solicitudes.html", insignia: true },
    { id: "refugios", etiqueta: "Refugios", ruta: "pages/admin/refugios.html" },
  ],
};

const HUELLA_LOGO = "assets/img/logos/huella.svg";
const INICIO_POR_ROL = { usuario: "pages/usuario/inicio.html", refugio: "pages/refugio/panel.html", admin: "pages/admin/solicitudes.html" };

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
        <button class="boton boton--contorno boton--pequeno" id="boton-salir" type="button">Cerrar sesión</button>
      </div>
    </div>`;

  // El nombre se inserta con textContent: nunca como HTML
  encabezado.querySelector("#nombre-usuario").textContent = sesion.nombre;
  encabezado.querySelector("#boton-salir").addEventListener("click", () => {
    cerrarSesion();
    irA("pages/login.html");
  });

  if (sesion.rol === "usuario") await refrescarInsigniaCoincidencias();
  if (sesion.rol === "admin") await refrescarInsigniaSolicitudes();
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
