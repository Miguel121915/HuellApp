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
    L.circleMarker(punto, { radius: 10, color: "#fff", weight: 3, fillColor: color, fillOpacity: 1 })
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
