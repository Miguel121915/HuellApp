/**
 * compartir-alerta.js — Enlaces públicos de una alerta y el menú «Compartir».
 *
 * La alerta se ve sin cuenta en  pages/alerta.html?id=…  y su cartel imprimible en  pages/cartel.html?id=…
 * La dirección base sale de SITIO_URL (api/.env) cuando está configurada (después del despliegue);
 * si no, de la dirección desde la que se abrió el sitio.
 */
import { obtenerConfigAuth } from "../core/auth.js";
import { crearElemento, rutaDesdeRaiz } from "../core/utils.js";

let base = null;
async function sitioBase() {
  if (base !== null) return base;
  const { sitioUrl } = await obtenerConfigAuth();
  base = sitioUrl || new URL(rutaDesdeRaiz(""), window.location.href).href.replace(/\/$/, "");
  return base;
}

export async function enlaceAlerta(id) {
  return `${await sitioBase()}/pages/alerta.html?id=${encodeURIComponent(id)}`;
}
export async function enlaceCartel(id) {
  return `${await sitioBase()}/pages/cartel.html?id=${encodeURIComponent(id)}`;
}

const ESPECIE = { perro: "un perrito", gato: "un gatito", otro: "una mascota" };

/** Texto corto para WhatsApp o redes, según el tipo de alerta. */
export function textoParaCompartir(a) {
  const quien = a.nombre || ESPECIE[a.especie] || "una mascota";
  const zona = a.zona ? ` en ${a.zona}` : "";
  if (a.estado === "reunido") return `💚 ¡${a.nombre || "La mascota"} ya está en casa! Gracias a todos los que compartieron en HuellApp.`;
  if (a.tipo === "perdida") return `🔎 SE BUSCA: ${quien}, se perdió${zona}. ¿La has visto? Comparte para ayudar a que vuelva a casa:`;
  if (a.tipo === "encontrada") return `🏠 Encontraron a ${quien}${zona}. ¿Es tuya o conoces a su familia? Mira la alerta:`;
  return "Mira esta publicación en HuellApp:";
}

let dialogo = null;

/**
 * Abre el menú para compartir una alerta: WhatsApp, Facebook, copiar enlace y (si es alerta) cartel.
 * En celulares con «compartir» del sistema, se ofrece también ese botón.
 * @param {{id:string, tipo?:string, estado?:string, nombre?:string, especie?:string, zona?:string, esAlerta?:boolean}} alerta
 */
export async function abrirCompartir(alerta) {
  const url = await enlaceAlerta(alerta.id);
  const texto = textoParaCompartir(alerta);
  dialogo?.remove();
  const aviso = crearElemento("p", { clase: "compartir__aviso", atributos: { role: "status" } });
  const opcion = (etiqueta, icono, extra) => crearElemento(extra.href ? "a" : "button", {
    clase: "compartir__opcion",
    atributos: extra.href ? { href: extra.href, target: "_blank", rel: "noopener" } : { type: "button" },
  }, [crearElemento("span", { texto: icono, atributos: { "aria-hidden": "true" } }), document.createTextNode(etiqueta)]);

  const copiar = opcion("Copiar enlace", "🔗", {});
  copiar.addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(url); aviso.textContent = "Enlace copiado. Pégalo donde quieras."; }
    catch { aviso.textContent = url; }
  });
  const opciones = [
    opcion("WhatsApp", "💬", { href: `https://wa.me/?text=${encodeURIComponent(`${texto} ${url}`)}` }),
    opcion("Facebook", "📘", { href: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}` }),
    copiar,
  ];
  if (navigator.share) {
    const sistema = opcion("Más opciones", "📤", {});
    sistema.addEventListener("click", () => navigator.share({ title: "HuellApp", text: texto, url }).catch(() => {}));
    opciones.push(sistema);
  }
  if (alerta.esAlerta !== false && alerta.tipo && alerta.estado !== "reunido") {
    opciones.push(opcion("Imprimir cartel con QR", "🖨️", { href: await enlaceCartel(alerta.id) }));
  }

  const cerrar = crearElemento("button", { clase: "boton boton--contorno boton--pequeno", texto: "Cerrar", atributos: { type: "button" } });
  dialogo = crearElemento("dialog", { clase: "modal compartir", atributos: { "aria-labelledby": "compartir-titulo" } }, [
    crearElemento("h2", { clase: "modal__titulo", texto: "Compartir alerta", atributos: { id: "compartir-titulo" } }),
    crearElemento("p", { clase: "texto-suave texto-pequeno", texto: "Mientras más personas la vean, más fácil es que vuelva a casa." }),
    crearElemento("div", { clase: "compartir__opciones" }, opciones),
    aviso,
    crearElemento("div", { clase: "modal__acciones" }, cerrar),
  ]);
  cerrar.addEventListener("click", () => dialogo.close());
  dialogo.addEventListener("close", () => dialogo.remove());
  document.body.append(dialogo);
  dialogo.showModal();
}
