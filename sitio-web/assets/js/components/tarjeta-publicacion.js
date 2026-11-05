/**
 * tarjeta-publicacion.js — Tarjeta reutilizable de una publicación (foro y páginas de refugio).
 * Diseño de las capturas: foto a la izquierda; autor, texto y "me gusta" a la derecha.
 * Todo el texto de usuarios entra con textContent (nunca innerHTML).
 */
import { crearElemento, resolverImagen, tiempoRelativo } from "../core/utils.js";
import { crearBotonLike } from "./like-huella.js";

/** Dibuja (o redibuja) la lista de comentarios dentro de la sección de la tarjeta. */
export function renderComentarios(tarjeta, comentarios) {
  const lista = tarjeta.querySelector(".comentarios__lista");
  const fragmento = document.createDocumentFragment();
  comentarios.forEach((c) => {
    fragmento.append(crearElemento("li", { clase: "comentario" }, [
      crearElemento("strong", { clase: "comentario__autor", texto: c.autor }),
      crearElemento("span", { texto: c.texto }),
    ]));
  });
  lista.replaceChildren(fragmento);
  tarjeta.querySelector(".comentarios__cuenta").textContent = String(comentarios.length);
}

/**
 * @param {object} pub  { id, autor, fecha, texto, foto, fotoAlt, likes, comentarios }
 * @param {{liked?:boolean, conLikes?:boolean, conComentarios?:boolean}} opciones
 */
export function crearTarjetaPublicacion(pub, { liked = false, conLikes = true, conComentarios = true } = {}) {
  const tarjeta = crearElemento("article", {
    clase: `publicacion tarjeta${pub.foto ? "" : " publicacion--sin-foto"}`,
    atributos: { "data-id": pub.id },
  });

  if (pub.foto) {
    tarjeta.append(crearElemento("figure", { clase: "publicacion__foto" },
      crearElemento("img", { atributos: { src: resolverImagen(pub.foto), alt: pub.fotoAlt || `Foto publicada por ${pub.autor}`, width: 400, height: 300, loading: "lazy", decoding: "async" } })));
  }

  const contenido = crearElemento("div", { clase: "publicacion__contenido" }, [
    crearElemento("header", { clase: "publicacion__cabecera" }, [
      crearElemento("h3", { clase: "tarjeta__titulo", texto: pub.autor }),
      crearElemento("time", { clase: "publicacion__fecha texto-pequeno texto-suave", texto: tiempoRelativo(pub.fecha), atributos: { datetime: pub.fecha } }),
    ]),
    ...(pub.etiqueta ? [crearElemento("span", { clase: "publicacion__etiqueta", texto: pub.etiqueta })] : []),
    crearElemento("p", { clase: "tarjeta__cuerpo publicacion__texto", texto: pub.texto }),
  ]);

  if (conLikes || conComentarios) {
    const pie = crearElemento("footer", { clase: "publicacion__pie" });
    if (conLikes) pie.append(crearBotonLike({ id: pub.id, base: pub.likes, activo: liked }));
    if (conComentarios) {
      pie.append(crearElemento("button", {
        clase: "comentarios-toggle",
        atributos: { type: "button", "aria-expanded": "false", "aria-controls": `comentarios-${pub.id}` },
      }, [document.createTextNode("Comentarios ("), crearElemento("span", { clase: "comentarios__cuenta", texto: String(pub.comentarios.length) }), document.createTextNode(")")]));
    }
    contenido.append(pie);
  }

  if (conComentarios) {
    const seccion = crearElemento("section", { clase: "comentarios", atributos: { id: `comentarios-${pub.id}`, hidden: true, "aria-label": "Comentarios" } }, [
      crearElemento("ul", { clase: "comentarios__lista" }),
      crearElemento("form", { clase: "comentarios__form", atributos: { novalidate: true } }, [
        crearElemento("label", { clase: "solo-lector", texto: "Escribe un comentario", atributos: { for: `comentar-${pub.id}` } }),
        crearElemento("input", { clase: "campo__control", atributos: { id: `comentar-${pub.id}`, name: "comentario", type: "text", maxlength: 300, placeholder: "Escribe un comentario…", autocomplete: "off" } }),
        crearElemento("button", { clase: "boton boton--primario boton--pequeno", texto: "Enviar", atributos: { type: "submit" } }),
      ]),
    ]);
    contenido.append(seccion);
  }

  tarjeta.append(contenido);
  if (conComentarios) renderComentarios(tarjeta, pub.comentarios);
  return tarjeta;
}
