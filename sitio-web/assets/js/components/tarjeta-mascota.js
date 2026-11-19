/**
 * tarjeta-mascota.js — Tarjeta reutilizable de una mascota (refugios y favoritos).
 * Al frente la foto, el nombre y la raza; al pasar el cursor (o al enfocarla con el teclado, o con un
 * toque en celular) se voltea y muestra sus datos y los botones. El carrusel de fotos (crearCarrusel)
 * va en la cabecera del formulario de adopción.
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
  const fotos = (m.fotos?.length ? m.fotos : [m.foto]).filter(Boolean).slice(0, 3);
  const especie = ETIQUETA_ESPECIE[m.especie] || m.especie;
  const datos = [formatearEdad(m.edadMeses), mayuscula(m.sexo), `Tamaño ${m.tamano}`].map((t) => crearElemento("li", { clase: "mascota__dato", texto: t }));

  // Frente: solo visual (aria-hidden); el reverso trae el nombre, los datos y los botones
  const frente = crearElemento("div", { clase: "mascota__cara mascota__frente", atributos: { "aria-hidden": "true" } }, [
    crearElemento("img", { clase: "mascota__portada", atributos: { src: resolverImagen(fotos[0]), alt: "", width: 400, height: 300, loading: "lazy", decoding: "async" } }),
    fotos.length > 1 ? crearElemento("span", { clase: "mascota__num-fotos", texto: `📷 ${fotos.length}` }) : null,
    crearElemento("div", { clase: "mascota__resumen" }, [
      crearElemento("div", { clase: "mascota__encabezado" }, [
        crearElemento("span", { clase: "mascota__nombre", texto: m.nombre }),
        crearElemento("span", { clase: `mascota__especie mascota__especie--${m.especie}`, texto: especie }),
      ]),
      crearElemento("span", { clase: "mascota__linea", texto: `${m.raza} · ${formatearEdad(m.edadMeses)}` }),
      ESTADO_SOLICITUD[estadoSolicitud] ? crearElemento("span", { clase: "mascota__estado", texto: ESTADO_SOLICITUD[estadoSolicitud] }) : null,
    ].filter(Boolean)),
  ].filter(Boolean));

  // Reverso: solo la información y los botones (las fotos se ven al frente y en el formulario de adopción)
  const reverso = crearElemento("div", { clase: "mascota__cara mascota__reverso" }, [
    crearElemento("div", { clase: "mascota__cuerpo" }, [
      crearElemento("div", { clase: "mascota__encabezado" }, [
        crearElemento("h3", { clase: "mascota__nombre", texto: m.nombre }),
        crearElemento("span", { clase: `mascota__especie mascota__especie--${m.especie}`, texto: especie }),
        ...(conFavorito ? [crearBotonFavorito(m, esFavorito)] : []),
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

  const tarjeta = crearElemento("article", { clase: "mascota", atributos: { "data-id": m.id } },
    crearElemento("div", { clase: "mascota__giro" }, [frente, reverso]));
  // Sin cursor (celular) no hay «pasar por encima»: un toque fuera de los botones voltea la tarjeta
  tarjeta.addEventListener("click", (evento) => {
    if (!SIN_CURSOR.matches || evento.target.closest("button, a, input, label, select")) return;
    tarjeta.classList.toggle("mascota--volteada");
  });
  return tarjeta;
}

const SIN_CURSOR = window.matchMedia("(hover: none)");

/** Carrusel de hasta 3 fotos con flechas y puntos (sin flechas si solo hay una foto). Lo usa el formulario de adopción. */
export function crearCarrusel(fotos, descripcion) {
  const imagenes = fotos.map((f, i) => crearElemento("img", {
    clase: `carrusel__foto${i === 0 ? " carrusel__foto--activa" : ""}`,
    atributos: {
      src: resolverImagen(f), alt: fotos.length > 1 ? `${descripcion} (foto ${i + 1} de ${fotos.length})` : descripcion,
      width: 400, height: 300, loading: "lazy", decoding: "async",
    },
  }));
  const carrusel = crearElemento("div", { clase: "carrusel" }, imagenes);
  if (fotos.length < 2) return carrusel;

  let actual = 0;
  const puntos = fotos.map((_, i) => crearElemento("button", {
    clase: "carrusel__punto",
    atributos: { type: "button", "aria-label": `Ver foto ${i + 1} de ${fotos.length}`, "aria-current": String(i === 0) },
  }));
  const ir = (i) => {
    actual = (i + fotos.length) % fotos.length;
    imagenes.forEach((img, j) => img.classList.toggle("carrusel__foto--activa", j === actual));
    puntos.forEach((p, j) => p.setAttribute("aria-current", String(j === actual)));
  };
  const flecha = (clase, texto, etiqueta, paso) => {
    const boton = crearElemento("button", { clase: `carrusel__flecha carrusel__flecha--${clase}`, texto, atributos: { type: "button", "aria-label": etiqueta } });
    boton.addEventListener("click", () => ir(actual + paso));
    return boton;
  };
  puntos.forEach((p, i) => p.addEventListener("click", () => ir(i)));
  carrusel.append(
    flecha("anterior", "‹", "Foto anterior", -1),
    flecha("siguiente", "›", "Foto siguiente", 1),
    crearElemento("div", { clase: "carrusel__puntos" }, puntos),
  );
  return carrusel;
}
