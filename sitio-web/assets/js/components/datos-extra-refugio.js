/**
 * datos-extra-refugio.js — Ubicación (mapa) y contacto extra del refugio: municipio, CP,
 * WhatsApp, redes, necesidades y si recibe perros/gatos. Son los mismos datos que captura
 * la app móvil y todos son opcionales.
 *
 * Lo usan registro-refugio.html y refugio/perfil.html. El HTML lo inserta montarDatosExtra();
 * el mapa usa Leaflet + OpenStreetMap (se carga en la página con <script src="…leaflet.js">).
 */

const CENTRO_POR_DEFECTO = [19.4006, -99.0148]; // Cd. Nezahualcóyotl
const plantilla = `
  <legend>Ubicación y contacto (opcional)</legend>
  <p class="campo__ayuda">Con la ubicación, los usuarios de la app verán tu refugio en el mapa de refugios cercanos y podrán pedir «Cómo llegar».</p>
  <div class="formulario-grid">
    <div class="campo campo--completo">
      <span class="campo__etiqueta">Ubicación en el mapa</span>
      <div id="mapa-ubicacion" class="mapa-ubicacion" role="application" aria-label="Mapa: haz clic para marcar el refugio"></div>
      <div class="mapa-ubicacion__acciones">
        <button type="button" class="boton boton--contorno boton--pequeno" id="boton-mi-ubicacion">Usar mi ubicación</button>
        <span class="campo__ayuda" id="texto-ubicacion">Haz clic en el mapa para marcar el refugio.</span>
      </div>
      <input type="hidden" name="latitud" id="latitud">
      <input type="hidden" name="longitud" id="longitud">
    </div>
    <div class="campo"><label class="campo__etiqueta" for="municipio">Municipio o alcaldía</label><input class="campo__control" id="municipio" name="municipio" type="text" maxlength="100"><span class="campo__error" role="status"></span></div>
    <div class="campo"><label class="campo__etiqueta" for="codigoPostal">Código postal</label><input class="campo__control" id="codigoPostal" name="codigoPostal" type="text" inputmode="numeric" maxlength="5"><span class="campo__error" role="status"></span></div>
    <div class="campo"><label class="campo__etiqueta" for="whatsapp">WhatsApp</label><input class="campo__control" id="whatsapp" name="whatsapp" type="tel" maxlength="25"><span class="campo__error" role="status"></span></div>
    <div class="campo"><span class="campo__etiqueta">Animales que reciben</span>
      <label><input type="checkbox" name="tienePerros" checked> Perros</label>
      <label><input type="checkbox" name="tieneGatos" checked> Gatos</label>
    </div>
    <div class="campo"><label class="campo__etiqueta" for="redes">Redes sociales (una por línea)</label><textarea class="campo__control" id="redes" name="redes" rows="3" placeholder="Facebook: Mi Refugio&#10;Instagram: @mirefugio"></textarea><span class="campo__error" role="status"></span></div>
    <div class="campo"><label class="campo__etiqueta" for="necesidades">¿Qué necesitan? (una por línea)</label><textarea class="campo__control" id="necesidades" name="necesidades" rows="3" placeholder="Croquetas para cachorro&#10;Cobijas"></textarea><span class="campo__error" role="status"></span></div>
  </div>`;

/** Inserta los campos en `contenedor` (un <fieldset> vacío) y prepara el mapa. */
export function montarDatosExtra(contenedor) {
  contenedor.innerHTML = plantilla;
  const lat = contenedor.querySelector("#latitud");
  const lng = contenedor.querySelector("#longitud");
  const texto = contenedor.querySelector("#texto-ubicacion");
  const divMapa = contenedor.querySelector("#mapa-ubicacion");
  let mapa = null;
  let marcador = null;

  function marcar(latitud, longitud, centrar = false) {
    lat.value = latitud.toFixed(6);
    lng.value = longitud.toFixed(6);
    texto.textContent = `Ubicación marcada: ${lat.value}, ${lng.value}`;
    if (!mapa) return;
    if (marcador) marcador.setLatLng([latitud, longitud]);
    else marcador = window.L.marker([latitud, longitud]).addTo(mapa);
    if (centrar) mapa.setView([latitud, longitud], 16);
  }

  if (window.L) {
    mapa = window.L.map(divMapa).setView(CENTRO_POR_DEFECTO, 12);
    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "© OpenStreetMap",
    }).addTo(mapa);
    mapa.on("click", (e) => marcar(e.latlng.lat, e.latlng.lng));
  } else {
    divMapa.hidden = true;
    texto.textContent = "No se pudo cargar el mapa (revisa tu internet). Puedes usar «Usar mi ubicación».";
  }

  contenedor.querySelector("#boton-mi-ubicacion").addEventListener("click", () => {
    if (!navigator.geolocation) { texto.textContent = "Tu navegador no permite obtener la ubicación."; return; }
    texto.textContent = "Obteniendo tu ubicación…";
    navigator.geolocation.getCurrentPosition(
      (p) => marcar(p.coords.latitude, p.coords.longitude, true),
      () => { texto.textContent = "No pudimos obtener tu ubicación. Marca el refugio haciendo clic en el mapa."; },
      { enableHighAccuracy: true, timeout: 15000 },
    );
  });

  return {
    /** Rellena los campos con los datos de un refugio de la API. */
    rellenar(refugio) {
      const f = contenedor;
      f.querySelector("#municipio").value = refugio.municipio || "";
      f.querySelector("#codigoPostal").value = refugio.codigoPostal || "";
      f.querySelector("#whatsapp").value = refugio.whatsapp || "";
      f.querySelector("#redes").value = (refugio.redes || []).join("\n");
      f.querySelector("#necesidades").value = (refugio.necesidades || []).join("\n");
      f.querySelector('[name="tienePerros"]').checked = refugio.tienePerros !== false;
      f.querySelector('[name="tieneGatos"]').checked = refugio.tieneGatos !== false;
      if (refugio.latitud != null && refugio.longitud != null) marcar(refugio.latitud, refugio.longitud, true);
      setTimeout(() => mapa?.invalidateSize(), 0);
    },
    /** Lee los campos en el formato que espera la API. */
    leer() {
      const f = contenedor;
      const lineas = (id) => f.querySelector(id).value.split("\n").map((t) => t.trim()).filter(Boolean);
      return {
        latitud: lat.value ? Number(lat.value) : null,
        longitud: lng.value ? Number(lng.value) : null,
        municipio: f.querySelector("#municipio").value.trim(),
        codigoPostal: f.querySelector("#codigoPostal").value.trim(),
        whatsapp: f.querySelector("#whatsapp").value.trim(),
        redes: lineas("#redes").slice(0, 5),
        necesidades: lineas("#necesidades").slice(0, 10),
        tienePerros: f.querySelector('[name="tienePerros"]').checked,
        tieneGatos: f.querySelector('[name="tieneGatos"]').checked,
      };
    },
    /** Revisa formato; devuelve un texto de error o "". */
    validar() {
      const cp = contenedor.querySelector("#codigoPostal").value.trim();
      const wa = contenedor.querySelector("#whatsapp").value.trim();
      if (cp && !/^\d{5}$/.test(cp)) return "El código postal debe tener 5 dígitos.";
      if (wa && !/^[\d\s+()-]{8,}$/.test(wa)) return "El WhatsApp debe tener al menos 8 dígitos.";
      return "";
    },
  };
}
