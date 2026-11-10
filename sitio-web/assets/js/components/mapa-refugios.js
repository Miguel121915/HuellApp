/**
 * mapa-refugios.js — Mapa de refugios verificados (HU-11) con Leaflet y OpenStreetMap.
 * Igual que «Refugios cercanos» de la app: un marcador por refugio que registró su ubicación,
 * y el botón «Cerca de mí» centra el mapa en la persona y ordena por distancia.
 *
 * Leaflet se carga como <script> clásico en la página (variable global L).
 */
import { crearElemento } from "../core/utils.js";

const CENTRO_MEXICO = [19.4326, -99.1332]; // CDMX, si ningún refugio tiene ubicación
let mapa = null;
let capaMarcadores = null;
let marcadorPersona = null;

const tieneUbicacion = (r) => Number.isFinite(Number(r.latitud)) && Number.isFinite(Number(r.longitud))
  && r.latitud !== null && r.longitud !== null && r.latitud !== "" && r.longitud !== "";

/** Distancia en km entre dos puntos (fórmula de Haversine). */
export function distanciaKm([lat1, lon1], [lat2, lon2]) {
  const rad = (g) => (g * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lon2 - lon1) / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Dibuja (o actualiza) el mapa.
 * @param {HTMLElement} contenedor
 * @param {object[]} refugios  con {id, nombre, direccion, horario, latitud, longitud}
 * @param {{alElegir:(id:string)=>void, aviso:HTMLElement}} opciones
 */
export function dibujarMapaRefugios(contenedor, refugios, { alElegir, aviso }) {
  if (!window.L) {
    contenedor.hidden = true;
    aviso.textContent = "No se pudo cargar el mapa (revisa tu conexión a internet).";
    return;
  }
  const L = window.L;
  if (!mapa) {
    mapa = L.map(contenedor, { scrollWheelZoom: false }).setView(CENTRO_MEXICO, 11);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(mapa);
    capaMarcadores = L.layerGroup().addTo(mapa);
    // El popup usa un enlace normal; se intercepta para no recargar la página
    contenedor.addEventListener("click", (e) => {
      const enlace = e.target.closest("[data-refugio]");
      if (!enlace) return;
      e.preventDefault();
      alElegir(enlace.dataset.refugio);
    });
  }
  capaMarcadores.clearLayers();

  const conUbicacion = refugios.filter(tieneUbicacion);
  const icono = L.divIcon({ className: "marcador-refugio", html: "🏠", iconSize: [34, 34], iconAnchor: [17, 30], popupAnchor: [0, -26] });
  conUbicacion.forEach((r) => {
    // El contenido del popup se arma con nodos (textContent): nunca HTML con datos del refugio
    const popup = crearElemento("div", { clase: "mapa-popup" }, [
      crearElemento("strong", { texto: r.nombre }),
      crearElemento("span", { texto: r.direccion }),
      crearElemento("span", { texto: `Horario: ${r.horario}` }),
      r.distanciaKm != null ? crearElemento("span", { texto: `A ${r.distanciaKm.toFixed(1)} km de ti` }) : null,
      crearElemento("a", { clase: "enlace", texto: "Ver mascotas →", atributos: { href: `?id=${encodeURIComponent(r.id)}`, "data-refugio": r.id } }),
    ].filter(Boolean));
    L.marker([Number(r.latitud), Number(r.longitud)], { icon: icono, title: r.nombre, alt: r.nombre })
      .bindPopup(popup)
      .addTo(capaMarcadores);
  });

  const sinUbicacion = refugios.length - conUbicacion.length;
  aviso.textContent = conUbicacion.length === 0
    ? "Ningún refugio de la lista ha registrado su ubicación en el mapa todavía."
    : `${conUbicacion.length} refugio(s) en el mapa${sinUbicacion ? ` · ${sinUbicacion} sin ubicación registrada (aparecen en la lista)` : ""}.`;

  const puntos = conUbicacion.map((r) => [Number(r.latitud), Number(r.longitud)]);
  if (marcadorPersona) puntos.push(marcadorPersona.getLatLng());
  if (puntos.length === 1) mapa.setView(puntos[0], 14);
  else if (puntos.length > 1) mapa.fitBounds(L.latLngBounds(puntos), { padding: [40, 40], maxZoom: 14 });
  setTimeout(() => mapa.invalidateSize(), 0); // por si el contenedor estaba oculto al crearse
}

/** Pide la ubicación de la persona y la marca en el mapa. Devuelve [lat, lon] o lanza un Error con el motivo. */
export function ubicarPersona() {
  return new Promise((resolver, rechazar) => {
    if (!navigator.geolocation) { rechazar(new Error("Tu navegador no permite obtener la ubicación.")); return; }
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        const punto = [coords.latitude, coords.longitude];
        if (mapa && window.L) {
          marcadorPersona?.remove();
          marcadorPersona = window.L.circleMarker(punto, { radius: 9, color: "#1b4f4a", fillColor: "#75e6da", fillOpacity: 0.9 })
            .bindTooltip("Estás aquí").addTo(mapa);
        }
        resolver(punto);
      },
      (error) => rechazar(new Error(error.code === error.PERMISSION_DENIED
        ? "No diste permiso para usar tu ubicación. Actívalo en el candado de la barra de direcciones."
        : "No pudimos obtener tu ubicación. Inténtalo de nuevo.")),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 },
    );
  });
}
