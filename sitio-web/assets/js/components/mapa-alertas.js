/**
 * mapa-alertas.js — «Alertas cerca de ti» en el Inicio: mascotas perdidas (rojo) y encontradas (verde)
 * con Leaflet y OpenStreetMap. Datos de GET /api/alertas, que ya vienen con la ubicación APROXIMADA
 * (~300 m): por eso cada punto se dibuja con un círculo tenue alrededor (la zona, no la casa).
 *
 * Leaflet se carga como <script> clásico en la página (variable global L).
 */
import { crearElemento, rutaDesdeRaiz, tiempoRelativo } from "../core/utils.js";

const CENTRO_MEXICO = [19.4326, -99.1332];
const COLORES = { perdida: "#b42318", encontrada: "#1b4f4a" };
const ETIQUETAS = { perdida: "Se busca", encontrada: "Busca a su familia" };
const ESPECIE = { perro: "Perro", gato: "Gato", otro: "Mascota" };

// Siluetas del marcador según la especie (viewBox 40×40): cabeza de gato, cabeza de perro o
// huellita para otras mascotas. Son textos fijos (sin datos de usuarios), así que es seguro
// meterlos como HTML del icono. La app usa las mismas en lib/widgets/mapa_alertas.dart.
const SILUETAS = {
  gato: '<path d="M7 4 L16.5 12.5 Q20 11.6 23.5 12.5 L33 4 Q35.5 13 34 19.5 Q37 25 34 30.5 Q29 37 20 37 Q11 37 6 30.5 Q3 25 6 19.5 Q4.5 13 7 4 Z"/>',
  perro: '<path d="M12 9 Q4 6 2.5 15 Q1.5 24 6.5 27 Q9.5 28.5 10.5 24 Z"/><path d="M28 9 Q36 6 37.5 15 Q38.5 24 33.5 27 Q30.5 28.5 29.5 24 Z"/><ellipse cx="20" cy="22" rx="11.5" ry="13.5"/>',
  otro: '<ellipse cx="20" cy="27" rx="9" ry="8"/><circle cx="9.5" cy="17.5" r="4"/><circle cx="16.5" cy="10.5" r="4"/><circle cx="23.5" cy="10.5" r="4"/><circle cx="30.5" cy="17.5" r="4"/>',
};
// Ojos y hocico (en blanco) y la nariz del perro (del color de la alerta)
const CARITAS = {
  gato: '<g fill="#fff"><ellipse cx="14" cy="22.5" rx="2.2" ry="2.8"/><ellipse cx="26" cy="22.5" rx="2.2" ry="2.8"/><path d="M17.8 28 H22.2 L20 30.6 Z"/></g>',
  perro: '<g fill="#fff"><circle cx="15.5" cy="19.5" r="2.2"/><circle cx="24.5" cy="19.5" r="2.2"/><ellipse cx="20" cy="29" rx="6" ry="4.6"/></g><ellipse cx="20" cy="27.2" rx="2.6" ry="1.8" fill="currentColor"/>',
  otro: "",
};

/** Icono de la alerta: la silueta de su especie, roja (se busca) o verde (busca a su familia). */
function iconoAlerta(L, especie, color) {
  const clave = SILUETAS[especie] ? especie : "otro";
  const silueta = SILUETAS[clave];
  return L.divIcon({
    className: "marcador-alerta",
    // Primero la silueta en blanco y más gruesa (el borde), encima la de color y luego la carita
    html: `<svg viewBox="0 0 40 40" width="38" height="38" style="color:${color}" aria-hidden="true">`
      + `<g fill="#fff" stroke="#fff" stroke-width="5" stroke-linejoin="round">${silueta}</g>`
      + `<g fill="currentColor">${silueta}</g>${CARITAS[clave]}</svg>`,
    iconSize: [38, 38],
    iconAnchor: [19, 19],
    popupAnchor: [0, -16],
    tooltipAnchor: [16, 0],
  });
}

let mapa = null;
let marcadorPersona = null;

/**
 * Dibuja el mapa con las alertas.
 * @param {HTMLElement} contenedor
 * @param {object[]} alertas  {id, tipo, nombre, especie, zona, fecha, latitud, longitud}
 * @param {{aviso:HTMLElement, botonCerca?:HTMLButtonElement}} opciones
 */
export function dibujarMapaAlertas(contenedor, alertas, { aviso, botonCerca }) {
  if (!window.L) {
    contenedor.hidden = true;
    aviso.textContent = "No se pudo cargar el mapa (revisa tu conexión a internet).";
    return;
  }
  const L = window.L;
  mapa = L.map(contenedor, { scrollWheelZoom: false }).setView(CENTRO_MEXICO, 11);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 18, // más cerca no tiene sentido: la ubicación es aproximada
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(mapa);

  // Si el contenedor cambia de tamaño (la página termina de acomodarse, se gira el celular),
  // Leaflet vuelve a medir: si no, quedan franjas grises sin mapa
  new ResizeObserver(() => mapa.invalidateSize()).observe(contenedor);

  const puntos = [];
  alertas.forEach((a) => {
    const punto = [Number(a.latitud), Number(a.longitud)];
    if (!Number.isFinite(punto[0]) || !Number.isFinite(punto[1])) return;
    const color = COLORES[a.tipo] || COLORES.encontrada;
    L.circle(punto, { radius: 220, color, weight: 1, opacity: 0.35, fillOpacity: 0.12, interactive: false }).addTo(mapa);
    // El popup se arma con nodos (textContent): nunca HTML con datos de los usuarios
    const popup = crearElemento("div", { clase: "mapa-popup" }, [
      crearElemento("span", { clase: `mapa-popup__tipo mapa-popup__tipo--${a.tipo}`, texto: ETIQUETAS[a.tipo] || "Alerta" }),
      crearElemento("strong", { texto: a.nombre || ESPECIE[a.especie] || "Mascota" }),
      a.zona ? crearElemento("span", { texto: `📍 ${a.zona}` }) : null,
      crearElemento("span", { clase: "texto-suave", texto: tiempoRelativo(a.fecha) }),
      crearElemento("a", { clase: "enlace", texto: "Ver alerta →", atributos: { href: rutaDesdeRaiz(`pages/alerta.html?id=${encodeURIComponent(a.id)}`) } }),
    ]);
    L.marker(punto, { icon: iconoAlerta(L, a.especie, color), alt: `${ETIQUETAS[a.tipo] || "Alerta"}: ${ESPECIE[a.especie] || "Mascota"}` })
      .addTo(mapa)
      .bindPopup(popup)
      .bindTooltip(`${ETIQUETAS[a.tipo] || "Alerta"}: ${a.nombre || ESPECIE[a.especie] || "Mascota"}`);
    puntos.push(punto);
  });

  if (puntos.length) {
    mapa.fitBounds(puntos, { padding: [40, 40], maxZoom: 14 });
    aviso.textContent = `${puntos.length} ${puntos.length === 1 ? "alerta activa" : "alertas activas"}. La ubicación es aproximada para cuidar la privacidad de quien reportó.`;
  } else {
    aviso.textContent = "Por ahora no hay alertas activas con ubicación. ¡Buena señal! 🐾";
  }

  botonCerca?.addEventListener("click", () => {
    if (!navigator.geolocation) { aviso.textContent = "Tu navegador no permite saber tu ubicación."; return; }
    botonCerca.disabled = true;
    navigator.geolocation.getCurrentPosition((pos) => {
      botonCerca.disabled = false;
      const yo = [pos.coords.latitude, pos.coords.longitude];
      marcadorPersona?.remove();
      marcadorPersona = L.circleMarker(yo, { radius: 8, color: "#fff", weight: 3, fillColor: "#2563eb", fillOpacity: 1 })
        .addTo(mapa).bindTooltip("Tú estás aquí");
      mapa.setView(yo, 14);
    }, () => {
      botonCerca.disabled = false;
      aviso.textContent = "No pudimos saber tu ubicación. Revisa el permiso del navegador.";
    }, { timeout: 10000 });
  });
}
