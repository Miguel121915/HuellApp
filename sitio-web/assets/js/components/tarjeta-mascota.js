/**
 * tarjeta-mascota.js — Tarjeta reutilizable de una mascota (refugios hoy, inventario en la Fase 3).
 * Todo el texto entra con textContent; las fotos usan loading="lazy" con tamaño definido.
 */
import { crearElemento, resolverImagen, formatearEdad } from "../core/utils.js";

const ETIQUETA_ESPECIE = { perro: "Perro", gato: "Gato" };
const mayuscula = (t) => t.charAt(0).toUpperCase() + t.slice(1);

/** Texto del botón según la solicitud de adopción que ya tenga el usuario por esta mascota. */
const ESTADO_SOLICITUD = {
  pendiente: "Solicitud enviada",
  "en revision": "Solicitud en revisión",
  aprobada: "Solicitud aprobada",
};

/** Botón "Adoptar" del pie de la tarjeta (o el estado de la solicitud, si ya envió una). */
function crearPieAdopcion(m, estadoSolicitud) {
  const texto = ESTADO_SOLICITUD[estadoSolicitud];
  const boton = texto
    ? crearElemento("button", { clase: "boton boton--bloque boton--adoptar boton--adoptar-enviada", texto, atributos: { type: "button", disabled: true } })
    : crearElemento("button", {
      clase: "boton boton--bloque boton--adoptar",
      atributos: { type: "button", "data-adoptar": m.id, "aria-label": `Adoptar a ${m.nombre}` },
    }, [crearElemento("span", { texto: "🐾", atributos: { "aria-hidden": "true" } }), document.createTextNode("Adoptar")]);
  return crearElemento("div", { clase: "mascota__pie" }, boton);
}

/** Corazón de favoritos sobre la foto (HU-12). Lo atiende la página con delegación en [data-favorito]. */
export function crearBotonFavorito(m, activo) {
  return crearElemento("button", {
    clase: `mascota__favorito${activo ? " mascota__favorito--activo" : ""}`,
    texto: activo ? "♥" : "♡",
    atributos: {
      type: "button", "data-favorito": m.id, "aria-pressed": String(!!activo),
      "aria-label": activo ? `Quitar a ${m.nombre} de favoritos` : `Guardar a ${m.nombre} en favoritos`,
      title: activo ? "Quitar de favoritos" : "Guardar en favoritos",
    },
  });
}

/** Cambia el corazón sin redibujar la tarjeta. */
export function marcarFavorito(boton, activo, nombre) {
  boton.classList.toggle("mascota__favorito--activo", activo);
  boton.textContent = activo ? "♥" : "♡";
  boton.setAttribute("aria-pressed", String(activo));
  boton.setAttribute("aria-label", activo ? `Quitar a ${nombre} de favoritos` : `Guardar a ${nombre} en favoritos`);
  boton.title = activo ? "Quitar de favoritos" : "Guardar en favoritos";
}

/**
 * @param {object} m  mascota (la sirve la API: GET /api/refugios/:id/mascotas)
 * @param {{conAdopcion?:boolean, estadoSolicitud?:string, conFavorito?:boolean, esFavorito?:boolean, conContacto?:boolean}} opciones
 *   conAdopcion: agrega el botón "Adoptar"; estadoSolicitud: estado de la solicitud que ya envió el usuario;
 *   conFavorito/esFavorito: corazón de favoritos; conContacto: botón "Preguntar al refugio" (HU-13)
 */
export function crearTarjetaMascota(m, { conAdopcion = false, estadoSolicitud = "", conFavorito = false, esFavorito = false, conContacto = false } = {}) {
  const foto = crearElemento("img", {
    atributos: { src: resolverImagen(m.foto), alt: `${ETIQUETA_ESPECIE[m.especie] || "Mascota"} llamado ${m.nombre}`, width: 400, height: 300, loading: "lazy", decoding: "async" },
  });
  const datos = [formatearEdad(m.edadMeses), mayuscula(m.sexo), `Tamaño ${m.tamano}`].map((t) => crearElemento("li", { clase: "mascota__dato", texto: t }));

  return crearElemento("article", { clase: "mascota", atributos: { "data-id": m.id } }, [
    crearElemento("figure", { clase: "mascota__foto" }, [foto, ...(conFavorito ? [crearBotonFavorito(m, esFavorito)] : [])]),
    crearElemento("div", { clase: "mascota__cuerpo" }, [
      crearElemento("div", { clase: "mascota__encabezado" }, [
        crearElemento("h3", { clase: "mascota__nombre", texto: m.nombre }),
        crearElemento("span", { clase: `mascota__especie mascota__especie--${m.especie}`, texto: ETIQUETA_ESPECIE[m.especie] || m.especie }),
      ]),
      crearElemento("p", { clase: "texto-suave texto-pequeno", texto: m.raza }),
      crearElemento("ul", { clase: "mascota__datos" }, datos),
      crearElemento("p", { clase: "mascota__descripcion", texto: m.descripcion }),
      crearElemento("p", { clase: "mascota__salud texto-pequeno", texto: `Salud: ${m.salud}` }),
      ...(conAdopcion ? [crearPieAdopcion(m, estadoSolicitud)] : []),
      ...(conContacto ? [crearElemento("button", {
        clase: "boton boton--contorno boton--pequeno boton--bloque mascota__contactar",
        texto: "Preguntar al refugio",
        atributos: { type: "button", "data-contactar": m.id, "aria-label": `Preguntar al refugio por ${m.nombre}` },
      })] : []),
    ]),
  ]);
}
