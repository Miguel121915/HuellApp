/**
 * mapa-refugios.js — Mapa de refugios verificados (HU-11) con Leaflet y OpenStreetMap.
 * Igual que «Refugios cercanos» de la app: un marcador por refugio que registró su ubicación,
 * y el botón «Cerca de mí» centra el mapa en la persona y ordena por distancia.
 *
 * Leaflet se carga como <script> clásico en la página (variable global L).
 */
import { crearElemento, rutaDesdeRaiz } from "../core/utils.js";

const CENTRO_MEXICO = [19.4326, -99.1332]; // CDMX, si ningún refugio tiene ubicación
let mapa = null;
let capaMarcadores = null;
let marcadorPersona = null;

/** Coordenadas utilizables: números, dentro de rango y no el punto vacío (0, 0) de un dato mal guardado. */
const tieneUbicacion = (r) => {
  if (r.latitud == null || r.longitud == null || r.latitud === "" || r.longitud === "") return false;
  const lat = Number(r.latitud);
  const lng = Number(r.longitud);
  return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0);
};

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
  // Huellita (imagen SVG local: no depende de que el sistema tenga emojis ni de internet)
  const icono = L.icon({
    iconUrl: rutaDesdeRaiz("assets/img/iconos/huella-mapa.svg"),
    iconSize: [36, 45], iconAnchor: [18, 44], popupAnchor: [0, -40], className: "marcador-refugio",
  });
  const usadas = new Map(); // refugios en el MISMO punto: se separan un poco para que se vean todos
  conUbicacion.forEach((r) => {
    let lat = Number(r.latitud);
    let lng = Number(r.longitud);
    const clave = `${lat.toFixed(5)},${lng.toFixed(5)}`;
    const repetidos = usadas.get(clave) || 0;
    usadas.set(clave, repetidos + 1);
    if (repetidos) { // ~20 m alrededor del punto original
      const angulo = repetidos * 2.4;
      lat += 0.00018 * Math.cos(angulo);
      lng += 0.00018 * Math.sin(angulo);
    }
    // El contenido del popup se arma con nodos (textContent): nunca HTML con datos del refugio
    const popup = crearElemento("div", { clase: "mapa-popup" }, [
      crearElemento("strong", { texto: r.nombre }),
      crearElemento("span", { texto: r.direccion }),
      crearElemento("span", { texto: `Horario: ${r.horario}` }),
      r.distanciaKm != null ? crearElemento("span", { texto: `A ${r.distanciaKm.toFixed(1)} km de ti` }) : null,
      crearElemento("a", { clase: "enlace", texto: "Ver mascotas →", atributos: { href: `?id=${encodeURIComponent(r.id)}`, "data-refugio": r.id } }),
    ].filter(Boolean));
    L.marker([lat, lng], { icon: icono, title: r.nombre, alt: r.nombre })
      .bindPopup(popup)
      .addTo(capaMarcadores);
  });

  // Los que no tienen ubicación válida se nombran: así se sabe exactamente cuál falta y por qué
  const sinUbicacion = refugios.filter((r) => !tieneUbicacion(r)).map((r) => r.nombre);
  const nombres = sinUbicacion.slice(0, 3).join(", ") + (sinUbicacion.length > 3 ? ` y ${sinUbicacion.length - 3} más` : "");
  aviso.textContent = conUbicacion.length === 0
    ? (refugios.length ? `Ningún refugio ha registrado su ubicación todavía (${nombres}). Aparecen en la lista de abajo.` : "No hay refugios verificados todavía.")
    : `${conUbicacion.length} de ${refugios.length} refugio(s) en el mapa.`
      + (sinUbicacion.length ? ` Sin ubicación registrada: ${nombres} (aparecen en la lista; el refugio puede agregarla en su Perfil).` : "");

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
