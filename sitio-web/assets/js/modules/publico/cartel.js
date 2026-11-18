/**
 * cartel.js — Cartel imprimible «SE BUSCA» / «BUSCA A SU FAMILIA» con foto, datos y un código QR
 * que lleva a la alerta pública. Se imprime en tamaño carta o se guarda como PDF desde el navegador.
 */
import { crearElemento, resolverImagen } from "../../core/utils.js";
import { enlaceAlerta } from "../../components/compartir-alerta.js";
import { dibujarQr } from "../../components/seguridad-cuenta.js";
import { cargarAlerta, encabezado, titulo, datos, id } from "./datos-alerta.js";

const contenedor = document.getElementById("cartel");
const botonImprimir = document.getElementById("boton-imprimir");
document.getElementById("volver").href = `alerta.html?id=${encodeURIComponent(id())}`;

try {
  const a = await cargarAlerta();
  if (!a.esAlerta) throw new Error("Solo las alertas de mascotas perdidas o encontradas tienen cartel.");
  const cabeza = encabezado(a);
  const url = await enlaceAlerta(a.id);
  document.title = `Cartel: ${cabeza.texto} ${titulo(a)} · HuellApp`;

  const qr = crearElemento("div", { clase: "cartel__qr" });
  const llamado = a.tipo === "perdida"
    ? "¿La has visto? Escanea el código y avisa en HuellApp."
    : "¿Es tuya o conoces a su familia? Escanea el código.";

  contenedor.replaceChildren(crearElemento("article", { clase: `cartel__hoja cartel__hoja--${cabeza.clase}` }, [
    crearElemento("h1", { clase: "cartel__banda", texto: cabeza.texto }),
    crearElemento("p", { clase: "cartel__nombre", texto: titulo(a) }),
    a.foto
      ? crearElemento("img", { clase: "cartel__foto", atributos: { src: resolverImagen(a.foto), alt: a.fotoAlt, width: 640, height: 480 } })
      : crearElemento("div", { clase: "cartel__foto cartel__foto--vacia", texto: "🐾" }),
    crearElemento("dl", { clase: "cartel__datos" }, datos(a).map(([etiqueta, valor]) =>
      crearElemento("div", {}, [crearElemento("dt", { texto: etiqueta }), crearElemento("dd", { texto: valor })]))),
    a.descripcion ? crearElemento("p", { clase: "cartel__descripcion", texto: a.descripcion }) : null,
    crearElemento("div", { clase: "cartel__pie" }, [
      qr,
      crearElemento("div", { clase: "cartel__llamado" }, [
        crearElemento("p", { clase: "cartel__llamado-texto", texto: llamado }),
        crearElemento("p", { clase: "cartel__url", texto: url }),
        crearElemento("img", { clase: "cartel__logo", atributos: { src: resolverImagen("assets/img/logos/logo-huellapp.png"), alt: "HuellApp", width: 900, height: 312 } }),
      ]),
    ]),
  ]));
  await dibujarQr(qr, url);
  qr.querySelector("svg")?.setAttribute("aria-label", "Código QR que abre la alerta en HuellApp");
  botonImprimir.disabled = false;
  botonImprimir.addEventListener("click", () => window.print());
} catch (error) {
  contenedor.replaceChildren(crearElemento("div", { clase: "alerta__vacia" }, [
    crearElemento("h1", { texto: "No pudimos preparar el cartel" }),
    crearElemento("p", { texto: error.message || "Puede que la alerta ya no esté disponible." }),
  ]));
}
