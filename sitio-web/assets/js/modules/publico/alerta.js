/**
 * alerta.js — Página pública de una alerta (se abre desde WhatsApp, Facebook o el QR del cartel).
 * No pide cuenta. Para avisar o contactar se entra a HuellApp.
 */
import { crearElemento, resolverImagen, tiempoRelativo } from "../../core/utils.js";
import { abrirCompartir, enlaceCartel } from "../../components/compartir-alerta.js";
import { cargarAlerta, encabezado, titulo, datos } from "./datos-alerta.js";

const contenedor = document.getElementById("alerta");

try {
  const a = await cargarAlerta();
  const cabeza = encabezado(a);
  document.title = `${cabeza.texto}: ${titulo(a)} · HuellApp`;

  const acciones = crearElemento("div", { clase: "alerta__acciones" });
  const compartir = crearElemento("button", { clase: "boton boton--primario", texto: "📤 Compartir", atributos: { type: "button" } });
  compartir.addEventListener("click", () => abrirCompartir(a));
  acciones.append(compartir);
  if (a.esAlerta && a.estado !== "reunido") {
    acciones.append(crearElemento("a", { clase: "boton boton--contorno", texto: "🖨️ Imprimir cartel", atributos: { href: await enlaceCartel(a.id) } }));
  }

  const ayuda = a.estado === "reunido"
    ? "Gracias a todos los que compartieron esta alerta. 💚"
    : a.tipo === "perdida"
      ? "¿La viste o sabes dónde está? Entra a HuellApp para avisar: con tu reporte buscamos coincidencias y le llega un aviso a su familia."
      : a.tipo === "encontrada"
        ? "¿Es tu mascota o conoces a su familia? Entra a HuellApp y repórtala como perdida: así le llega el aviso a quien la encontró."
        : "";

  contenedor.replaceChildren(
    crearElemento("article", { clase: `alerta__tarjeta alerta__tarjeta--${cabeza.clase}` }, [
      crearElemento("p", { clase: "alerta__banda", texto: cabeza.texto }),
      a.foto ? crearElemento("img", { clase: "alerta__foto", atributos: { src: resolverImagen(a.foto), alt: a.fotoAlt, width: 640, height: 480 } }) : null,
      crearElemento("div", { clase: "alerta__cuerpo" }, [
        crearElemento("h1", { clase: "alerta__nombre", texto: a.esAlerta ? titulo(a) : "Publicación de la comunidad" }),
        a.esAlerta
          ? crearElemento("dl", { clase: "alerta__datos" }, datos(a).map(([etiqueta, valor]) =>
            crearElemento("div", {}, [crearElemento("dt", { texto: etiqueta }), crearElemento("dd", { texto: valor })])))
          : null,
        crearElemento("p", { clase: "alerta__descripcion", texto: a.esAlerta ? (a.descripcion || "") : a.texto }),
        crearElemento("p", { clase: "alerta__autor", texto: `Publicado por ${a.publicadoPor} · ${tiempoRelativo(a.fecha)}` }),
        acciones,
        ayuda ? crearElemento("div", { clase: "alerta__ayuda" }, [
          crearElemento("p", { texto: ayuda }),
          crearElemento("a", { clase: "boton boton--secundario", texto: "Entrar a HuellApp", atributos: { href: "login.html" } }),
        ]) : null,
      ]),
    ]),
  );
} catch (error) {
  contenedor.replaceChildren(crearElemento("div", { clase: "alerta__vacia" }, [
    crearElemento("h1", { texto: "No encontramos esta alerta" }),
    crearElemento("p", { texto: error.message || "Puede que ya la hayan quitado." }),
    crearElemento("a", { clase: "boton boton--primario", texto: "Ir a HuellApp", atributos: { href: "login.html" } }),
  ]));
}
