/** panel.js — Resumen del refugio: contadores, accesos rápidos y últimas mascotas. */
import { requerirRol } from "../../core/router-guard.js";
import { obtenerMiRefugio } from "../../core/auth.js";
import { obtenerResumen } from "../../core/servicios-refugio.js";
import { montarNavbar } from "../../components/navbar.js";
import { crearElemento, resolverImagen, ESTATUS_MASCOTA } from "../../core/utils.js";

const sesion = requerirRol("refugio");

if (sesion) {
  montarNavbar({ sesion, activa: "panel" });
  iniciar();
}

async function iniciar() {
  const refugio = await obtenerMiRefugio();
  document.getElementById("panel-titulo").textContent = refugio.nombre;
  document.title = `Panel · ${refugio.nombre} · HuellApp`;

  const resumen = await obtenerResumen();
  document.querySelectorAll("[data-resumen]").forEach((nodo) => { nodo.textContent = String(resumen[nodo.dataset.resumen]); });

  const lista = document.getElementById("recientes");
  document.getElementById("sin-recientes").hidden = resumen.recientes.length > 0;
  const fragmento = document.createDocumentFragment();
  resumen.recientes.forEach((m) => {
    const estatus = ESTATUS_MASCOTA[m.estatus] || { etiqueta: m.estatus, clase: "pendiente" };
    fragmento.append(crearElemento("li", { clase: "reciente" }, [
      crearElemento("img", { clase: "tabla__foto", atributos: { src: resolverImagen(m.foto), alt: `Foto de ${m.nombre}`, width: 56, height: 56, loading: "lazy" } }),
      crearElemento("span", { clase: "reciente__nombre", texto: m.nombre }),
      crearElemento("span", { clase: `insignia insignia--${estatus.clase}`, texto: estatus.etiqueta }),
    ]));
  });
  lista.replaceChildren(fragmento);
}
