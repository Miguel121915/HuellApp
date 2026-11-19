/**
 * geocodificar.js — Dirección ↔ punto en el mapa con Nominatim (el buscador gratuito de OpenStreetMap,
 * el mismo proyecto de los mapas). Sin cuenta ni llave. Sus reglas piden pocas consultas: aquí solo se
 * busca cuando la persona termina de escribir la dirección o toca «Usar mi ubicación», nunca por cada tecla.
 */
const NOMINATIM = "https://nominatim.openstreetmap.org";

async function consultar(ruta, parametros) {
  const url = `${NOMINATIM}/${ruta}?${new URLSearchParams({ format: "jsonv2", "accept-language": "es", ...parametros })}`;
  const respuesta = await fetch(url, { headers: { Accept: "application/json" } });
  if (!respuesta.ok) throw new Error(`Nominatim respondió ${respuesta.status}`);
  return respuesta.json();
}

/**
 * Busca una dirección escrita (en México). Devuelve { latitud, longitud } o null si no se encontró
 * o no hay internet.
 */
export async function buscarDireccion(texto) {
  try {
    const [lugar] = await consultar("search", { q: texto, countrycodes: "mx", limit: "1" });
    return lugar ? { latitud: Number(lugar.lat), longitud: Number(lugar.lon) } : null;
  } catch {
    return null;
  }
}

/**
 * Lo contrario: la dirección de un punto. Devuelve { direccion, municipio, codigoPostal } (textos, pueden
 * venir vacíos) o null si no se pudo.
 */
export async function direccionDe(latitud, longitud) {
  try {
    const r = await consultar("reverse", { lat: String(latitud), lon: String(longitud), zoom: "18", addressdetails: "1" });
    const a = r?.address;
    if (!a) return null;
    const calle = [a.road || a.pedestrian || a.footway, a.house_number].filter(Boolean).join(" ");
    const colonia = a.neighbourhood || a.suburb || a.quarter || a.hamlet || "";
    return {
      direccion: [calle, colonia].filter(Boolean).join(", "),
      municipio: a.city || a.town || a.village || a.municipality || a.county || "",
      codigoPostal: /^\d{5}$/.test(a.postcode || "") ? a.postcode : "",
    };
  } catch {
    return null;
  }
}
