/**
 * mock-coincidencias.js — Reportes del usuario y posibles coincidencias (simuladas).
 * El porcentaje de similitud lo calcularía el backend comparando fotos y descripciones.
 */
import { haceHoras } from "../core/utils.js";

export const mockMisReportes = [
  {
    id: "rep-1", tipo: "perdida", especie: "gato", fecha: haceHoras(60),
    descripcion: "Hola, estoy buscando a mi gato que se perdió cerca del parque de la colonia San Miguel. Es gordito, de color gris con rayas oscuras y tiene los ojos verdes. Responde al nombre de Tom. Si alguien lo ha visto, agradecería mucho cualquier información.",
    zona: "Parque de la colonia San Miguel",
    foto: "assets/img/mascotas/gato-gris.svg", fotoAlt: "Tom, gato gris con rayas oscuras",
  },
];

export const mockCoincidencias = [
  {
    id: "coin-1", reporteId: "rep-1", similitud: 92, fecha: haceHoras(2),
    hallazgo: {
      descripcion: "Encontré un gato cerca del parque de la colonia San Miguel. Es gordito, gris con rayas oscuras y tiene los ojos verdes. Parece estar perdido y es bastante tranquilo. Si alguien reconoce estas características, puede contactarme para confirmar si es su gato.",
      zona: "Parque de la colonia San Miguel", foto: "assets/img/mascotas/gato-gris-2.svg", fotoAlt: "Gato gris con rayas oscuras encontrado",
      contacto: { nombre: "Carlos Vega", telefono: "55 1010 2020", correo: "carlos.vega@ejemplo.mx" },
    },
  },
  {
    id: "coin-2", reporteId: "rep-1", similitud: 74, fecha: haceHoras(9),
    hallazgo: {
      descripcion: "Vi un gato gris merodeando por la calle Flores, a unas cuadras del parque. Se acerca a la gente y parece acostumbrado a vivir en casa, pero no pude ver el color de sus ojos.",
      zona: "Calle Flores, col. San Miguel", foto: "assets/img/mascotas/gato-gris.svg", fotoAlt: "Gato gris visto en la calle",
      contacto: { nombre: "Marisol Reyes", telefono: "55 3030 4040", correo: "marisol.reyes@ejemplo.mx" },
    },
  },
  {
    id: "coin-3", reporteId: "rep-1", similitud: 58, fecha: haceHoras(21),
    hallazgo: {
      descripcion: "Llegó a mi patio un gato de pelo corto, color gris claro. Está flaquito y no trae collar. Lo estoy alimentando mientras busco a su dueño.",
      zona: "Col. Evolución, cerca del mercado", foto: "assets/img/mascotas/gato-blanco.svg", fotoAlt: "Gato claro encontrado en un patio",
      contacto: { nombre: "Héctor Salas", telefono: "55 5050 6060", correo: "hector.salas@ejemplo.mx" },
    },
  },
];
