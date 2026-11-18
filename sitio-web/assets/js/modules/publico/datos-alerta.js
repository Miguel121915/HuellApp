/**
 * datos-alerta.js — Carga una alerta pública (GET /api/alertas/{id}) y arma sus textos.
 * Lo usan la página de la alerta y el cartel imprimible.
 */
import { get } from "../../core/api.js";

export const id = () => new URLSearchParams(window.location.search).get("id") || "";

export async function cargarAlerta() {
  if (!/^\d+$/.test(id())) throw new Error("Este enlace no es válido.");
  return (await get(`/alertas/${id()}`)).alerta;
}

const ESPECIE = { perro: "Perro", gato: "Gato", otro: "Mascota" };

/** Encabezado grande según el tipo y estado de la alerta. */
export function encabezado(a) {
  if (a.estado === "reunido") return { texto: "¡Ya está en casa!", clase: "reunido" };
  if (a.tipo === "perdida") return { texto: "Se busca", clase: "perdida" };
  if (a.tipo === "encontrada") return { texto: "Busca a su familia", clase: "encontrada" };
  return { texto: "Comunidad HuellApp", clase: "comunidad" };
}

export const titulo = (a) => a.nombre || ESPECIE[a.especie] || "Mascota";

const fecha = (iso) => (iso ? new Date(iso).toLocaleDateString("es-MX", { day: "numeric", month: "long", year: "numeric" }) : "");

const SITUACION = { conmigo: "Está a salvo con quien la encontró", refugio: "La llevaron a un refugio o veterinaria", vista: "La vieron, pero no la pudieron resguardar" };

/** Lista de [etiqueta, valor] con los datos que sí existen. */
export function datos(a) {
  return [
    ["Especie", ESPECIE[a.especie]],
    ["Color", a.color],
    ["Tamaño", a.tamano],
    ["Collar o placa", a.collar],
    [a.tipo === "encontrada" ? "Dónde la encontraron" : "Dónde se perdió", a.zona],
    [a.tipo === "encontrada" ? "Cuándo" : "Desde cuándo", fecha(a.fechaEvento)],
    ["Ahora", SITUACION[a.situacion]],
  ].filter(([, valor]) => valor);
}
