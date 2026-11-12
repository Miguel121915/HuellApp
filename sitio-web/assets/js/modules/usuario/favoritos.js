/**
 * favoritos.js — HU-12: mascotas que el usuario guardó con ♡. Se pueden quitar y comparar
 * (de 2 a 3 a la vez) en una tabla lado a lado. Son las mismas que en la app móvil.
 */
import { requerirRol } from "../../core/router-guard.js";
import { montarNavbar } from "../../components/navbar.js";
import { pedirCuenta } from "../../components/aviso-cuenta.js";
import { crearTarjetaMascota } from "../../components/tarjeta-mascota.js";
import { obtenerFavoritos, establecerFavorito } from "../../core/servicios.js";
import { crearElemento, formatearEdad, mostrarAlerta, ESTATUS_MASCOTA } from "../../core/utils.js";

const MAX_COMPARAR = 3;

const sesion = requerirRol("usuario") // el visitante va al login: solo puede ver las mascotas en adopción;
const lista = document.getElementById("lista-favoritos");
const vacio = document.getElementById("sin-favoritos");
const alerta = document.getElementById("alerta");
const anuncio = document.getElementById("anuncio");
const barra = document.getElementById("barra-comparar");
const botonComparar = document.getElementById("boton-comparar");
const seccionComparacion = document.getElementById("comparacion");

let favoritos = [];
const seleccion = new Set();

if (sesion) {
  montarNavbar({ sesion, activa: "favoritos" });
  if (sesion.rol === "invitado") mostrarParaVisitante();
  else { enlazarEventos(); cargar(); }
}

function mostrarParaVisitante() {
  const boton = crearElemento("button", { clase: "boton boton--primario", texto: "Iniciar sesión para ver mis favoritos", atributos: { type: "button" } });
  boton.addEventListener("click", () => pedirCuenta("guardar y comparar mascotas favoritas"));
  lista.replaceWith(crearElemento("section", { clase: "vacio tarjeta tarjeta--blanca" }, [
    crearElemento("p", { texto: "Con una cuenta puedes guardar las mascotas que te gusten y compararlas antes de decidir." }),
    boton,
  ]));
}

async function cargar() {
  try {
    favoritos = await obtenerFavoritos();
  } catch (error) {
    mostrarAlerta(alerta, "error", error.message);
    return;
  }
  [...seleccion].forEach((id) => { if (!favoritos.some((m) => m.id === id)) seleccion.delete(id); });
  dibujar();
}

function dibujar() {
  vacio.hidden = favoritos.length > 0;
  barra.hidden = favoritos.length < 2;
  lista.replaceChildren(...favoritos.map((m) => {
    const tarjeta = crearTarjetaMascota(m, { conFavorito: true, esFavorito: true });
    const cuerpo = tarjeta.querySelector(".mascota__cuerpo");
    const estatus = m.estatus !== "disponible"
      ? [crearElemento("p", { clase: `insignia insignia--${ESTATUS_MASCOTA[m.estatus]?.clase || "adoptado"}`, texto: ESTATUS_MASCOTA[m.estatus]?.etiqueta || m.estatus })]
      : [];
    const casilla = crearElemento("input", { atributos: { type: "checkbox", "data-comparar": m.id } });
    casilla.checked = seleccion.has(m.id);
    cuerpo.append(
      ...estatus,
      crearElemento("a", { clase: "enlace texto-pequeno", texto: `${m.refugioNombre} →`, atributos: { href: `refugios.html?id=${encodeURIComponent(m.refugioId)}` } }),
      crearElemento("label", { clase: "casilla favorito__comparar" }, [casilla, crearElemento("span", { texto: "Comparar" })]),
    );
    return tarjeta;
  }));
  actualizarBarra();
}

function actualizarBarra() {
  const n = seleccion.size;
  document.getElementById("texto-seleccion").textContent = n === 0
    ? `Marca de 2 a ${MAX_COMPARAR} mascotas para compararlas.`
    : `${n} de ${MAX_COMPARAR} seleccionadas.`;
  botonComparar.disabled = n < 2;
  lista.querySelectorAll("[data-comparar]").forEach((c) => { c.disabled = !c.checked && n >= MAX_COMPARAR; });
}

/* ---------- Comparación lado a lado ---------- */

const FILAS = [
  ["Especie", (m) => (m.especie === "perro" ? "Perro" : "Gato")],
  ["Raza", (m) => m.raza],
  ["Edad", (m) => formatearEdad(m.edadMeses)],
  ["Sexo", (m) => m.sexo.charAt(0).toUpperCase() + m.sexo.slice(1)],
  ["Tamaño", (m) => m.tamano.charAt(0).toUpperCase() + m.tamano.slice(1)],
  ["Salud", (m) => m.salud],
  ["Estatus", (m) => ESTATUS_MASCOTA[m.estatus]?.etiqueta || m.estatus],
  ["Refugio", (m) => m.refugioNombre + (m.refugioMunicipio ? ` (${m.refugioMunicipio})` : "")],
  ["Descripción", (m) => m.descripcion],
];

function comparar() {
  const elegidas = favoritos.filter((m) => seleccion.has(m.id));
  if (elegidas.length < 2) return;
  const cabecera = crearElemento("thead", {}, crearElemento("tr", {}, [
    crearElemento("th", { atributos: { scope: "col" } }, crearElemento("span", { clase: "solo-lector", texto: "Dato" })),
    ...elegidas.map((m) => crearElemento("th", { atributos: { scope: "col" }, texto: m.nombre })),
  ]));
  const cuerpo = crearElemento("tbody", {}, FILAS.map(([etiqueta, valor]) => {
    const valores = elegidas.map(valor);
    const distintos = new Set(valores).size > 1;
    return crearElemento("tr", { clase: distintos ? "comparacion__fila--distinta" : "" }, [
      crearElemento("th", { atributos: { scope: "row" }, texto: etiqueta }),
      ...valores.map((v) => crearElemento("td", { texto: v || "—" })),
    ]);
  }));
  document.getElementById("tabla-comparacion").replaceChildren(cabecera, cuerpo);
  seccionComparacion.hidden = false;
  seccionComparacion.scrollIntoView({ behavior: "smooth", block: "start" });
}

function enlazarEventos() {
  lista.addEventListener("change", (evento) => {
    const casilla = evento.target.closest("[data-comparar]");
    if (!casilla) return;
    if (casilla.checked) seleccion.add(casilla.dataset.comparar); else seleccion.delete(casilla.dataset.comparar);
    actualizarBarra();
  });

  lista.addEventListener("click", async (evento) => {
    const corazon = evento.target.closest("[data-favorito]");
    if (!corazon) return;
    const m = favoritos.find((x) => x.id === corazon.dataset.favorito);
    corazon.disabled = true;
    const r = await establecerFavorito(corazon.dataset.favorito, false);
    if (!r.ok) { corazon.disabled = false; mostrarAlerta(alerta, "error", r.error); return; }
    seleccion.delete(corazon.dataset.favorito);
    anuncio.textContent = `${m?.nombre || "La mascota"} se quitó de tus favoritos.`;
    seccionComparacion.hidden = true;
    await cargar();
  });

  botonComparar.addEventListener("click", comparar);
  document.getElementById("cerrar-comparacion").addEventListener("click", () => { seccionComparacion.hidden = true; });
}
