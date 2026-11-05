/**
 * mock-foro.js — Publicaciones simuladas del foro.
 * (Se sustituirá por GET /api/foro/publicaciones cuando exista backend.)
 * `likes` es el contador base; el "me gusta" del usuario actual se suma aparte.
 */
import { haceHoras } from "../core/utils.js";

export const mockForo = [
  {
    id: "pub-1", autor: "Miguel Peña", fecha: haceHoras(3), likes: 12,
    texto: "Yo llevé a mi perro a la veterinaria Huellitas y Salud porque tenía varios días aletargado y mal. Desde que llegamos, la atención fue muy buena y el veterinario revisó a mi mascota con bastante cuidado. También me explicó qué tenía y cómo debía darle el medicamento. En general, quedé satisfecho con el servicio y el trato que recibimos, por lo que sí recomendaría esta veterinaria.",
    foto: "assets/img/mascotas/perro-cafe.svg", fotoAlt: "Perro café recibiendo atención veterinaria",
    comentarios: [{ autor: "Laura Méndez", texto: "¡Gracias por la recomendación! Justo buscaba una veterinaria por la zona." }],
  },
  {
    id: "pub-2", autor: "Enrique Nieto", fecha: haceHoras(7), likes: 8,
    texto: "Hola, estoy buscando a mi gato que se perdió hace unos días. Es un gato de tamaño mediano, de color gris con rayas negras, tiene los ojos verdes y un collar azul. Se perdió cerca de la colonia Las Flores, aproximadamente en la zona del parque principal. Es un poco tímido y puede asustarse fácilmente, por lo que agradecería mucho si alguien lo ha visto o tiene información sobre él. Cualquier dato puede ayudarme a encontrarlo.",
    foto: "assets/img/mascotas/gato-gris.svg", fotoAlt: "Gato gris con rayas oscuras y ojos verdes",
    comentarios: [],
  },
  {
    id: "pub-3", autor: "Sofía Ortega", fecha: haceHoras(26), likes: 31,
    texto: "¡Final feliz! Hace una semana adopté a Canela en el Centro Fernandino y ya se adueñó de la sala. Si estás pensando en adoptar, anímate: te cambian la vida (y el sillón).",
    foto: "assets/img/mascotas/perro-dorado.svg", fotoAlt: "Perra dorada recién adoptada",
    comentarios: [{ autor: "Ana López", texto: "¡Qué hermosa! Felicidades 🐾" }, { autor: "Diego Torres", texto: "Bienvenida a la familia, Canela." }],
  },
  {
    id: "pub-4", autor: "Carlos Vega", fecha: haceHoras(30), likes: 5,
    texto: "Encontré un perro blanco con manchas negras cerca del mercado de la colonia Evolución. Trae collar rojo pero sin placa. Está tranquilo y lo tengo resguardado. Si es tuyo, escríbeme por aquí.",
    foto: "assets/img/mascotas/perro-dalmata.svg", fotoAlt: "Perro blanco con manchas negras",
    comentarios: [],
  },
  {
    id: "pub-5", autor: "Rosa Camacho", fecha: haceHoras(52), likes: 17,
    texto: "Tip para estas fechas: revisa que tu mascota traiga collar con teléfono actualizado. Con una placa, una mascota extraviada regresa a casa mucho más rápido.",
    foto: "", fotoAlt: "", comentarios: [{ autor: "Marco Pineda", texto: "Muy buen consejo. Además ayuda ponerles microchip." }],
  },
  {
    id: "pub-6", autor: "Laura Méndez", fecha: haceHoras(75), likes: 22,
    texto: "Mi michi Oreo cumple un año de ser adoptado. Gracias a todos los que ayudan a que más gatitos encuentren hogar.",
    foto: "assets/img/mascotas/gato-blanco.svg", fotoAlt: "Gato blanco de ojos azules",
    comentarios: [],
  },
  {
    id: "pub-7", autor: "Diego Torres", fecha: haceHoras(98), likes: 9,
    texto: "Este fin de semana haremos una jornada de adopción en el Refugio PetFriend. Habrá cachorros, adultos y también seniors que merecen una segunda oportunidad. ¡Los esperamos!",
    foto: "assets/img/mascotas/perro-negro.svg", fotoAlt: "Perro negro de ojos tiernos",
    comentarios: [],
  },
  {
    id: "pub-8", autor: "Ana López", fecha: haceHoras(120), likes: 4,
    texto: "¿Alguien conoce una buena veterinaria de gatos cerca de la colonia San Miguel? Mi gato Tom necesita sus vacunas.",
    foto: "", fotoAlt: "", comentarios: [],
  },
];
