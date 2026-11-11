/**
 * mapa-punto.js — Mapa pequeño para marcar UN punto (dónde se perdió o dónde la vieron).
 * Toca el mapa para colocar el pin, o usa «Usar mi ubicación». Usa Leaflet + OpenStreetMap
 * (la página debe cargar leaflet.css y leaflet.js). Si Leaflet no cargó, queda el botón de ubicación.
 */
const CENTRO_POR_DEFECTO = [19.4326, -99.1332]; // Ciudad de México

/**
 * @param {HTMLElement} divMapa   contenedor del mapa
 * @param {HTMLElement} texto     donde se escribe el estado («Ubicación marcada…»)
 * @param {HTMLButtonElement} botonUbicacion
 * @returns {{ leer: () => ({latitud:number, longitud:number}|null), limpiar: () => void, ajustar: () => void }}
 */
export function montarMapaPunto(divMapa, texto, botonUbicacion) {
  let punto = null;
  let mapa = null;
  let marcador = null;
  const mensajeInicial = texto.textContent;

  function marcar(latitud, longitud, centrar = false) {
    punto = { latitud: Number(latitud.toFixed(6)), longitud: Number(longitud.toFixed(6)) };
    texto.textContent = "📍 Punto marcado. Puedes moverlo tocando otra parte del mapa.";
    if (!mapa) return;
    if (marcador) marcador.setLatLng([latitud, longitud]);
    else marcador = window.L.marker([latitud, longitud]).addTo(mapa);
    if (centrar) mapa.setView([latitud, longitud], 16);
  }

  if (window.L) {
    mapa = window.L.map(divMapa).setView(CENTRO_POR_DEFECTO, 11);
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap" }).addTo(mapa);
    mapa.on("click", (e) => marcar(e.latlng.lat, e.latlng.lng));
  } else {
    divMapa.hidden = true;
    texto.textContent = "No se pudo cargar el mapa (revisa tu internet). Puedes usar «Usar mi ubicación».";
  }

  botonUbicacion.addEventListener("click", () => {
    if (!navigator.geolocation) { texto.textContent = "Tu navegador no permite obtener la ubicación."; return; }
    texto.textContent = "Obteniendo tu ubicación…";
    navigator.geolocation.getCurrentPosition(
      (p) => marcar(p.coords.latitude, p.coords.longitude, true),
      () => { texto.textContent = "No pudimos obtener tu ubicación. Toca el mapa para marcar el punto."; },
      { enableHighAccuracy: true, timeout: 15000 },
    );
  });

  return {
    leer: () => punto,
    limpiar() {
      punto = null;
      marcador?.remove();
      marcador = null;
      texto.textContent = mensajeInicial;
    },
    /** Leaflet necesita recalcular su tamaño cuando el mapa estaba oculto. */
    ajustar: () => setTimeout(() => mapa?.invalidateSize(), 0),
  };
}
