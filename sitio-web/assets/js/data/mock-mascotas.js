/**
 * mock-mascotas.js — Mascotas de los refugios y publicaciones públicas de cada refugio.
 * especie: perro | gato · sexo: macho | hembra · tamano: pequeño | mediano | grande
 * estatus: disponible | en proceso | adoptado  (el usuario solo ve las "disponible")
 * La edad se guarda en MESES para poder filtrar por etapa de vida.
 * (La Fase 3 conecta este mock con el CRUD del inventario del refugio.)
 */
import { haceHoras } from "../core/utils.js";

const F = "assets/img/mascotas/";

export const mockMascotas = [
  // Centro Fernandino el chico
  { id: "mas-1", refugioId: "ref-1", nombre: "Max", especie: "perro", raza: "Mestizo", edadMeses: 24, sexo: "macho", tamano: "mediano", salud: "Vacunado y desparasitado", descripcion: "Juguetón y muy cariñoso. Se lleva bien con niños y otros perros.", foto: F + "perro-cafe.svg", estatus: "disponible" },
  { id: "mas-2", refugioId: "ref-1", nombre: "Luna", especie: "perro", raza: "Labrador mestiza", edadMeses: 8, sexo: "hembra", tamano: "mediano", salud: "Vacunas al día", descripcion: "Cachorra llena de energía; necesita espacio para correr.", foto: F + "perro-dorado.svg", estatus: "disponible" },
  { id: "mas-3", refugioId: "ref-1", nombre: "Canela", especie: "perro", raza: "Criolla", edadMeses: 36, sexo: "hembra", tamano: "pequeño", salud: "Esterilizada y vacunada", descripcion: "Tranquila, ideal para departamento. Le encantan los paseos cortos.", foto: F + "perro-dalmata.svg", estatus: "disponible" },
  { id: "mas-4", refugioId: "ref-1", nombre: "Simón", especie: "gato", raza: "Doméstico", edadMeses: 12, sexo: "macho", tamano: "pequeño", salud: "Vacunado", descripcion: "Curioso y sociable. Duerme en cualquier regazo disponible.", foto: F + "gato-naranja.svg", estatus: "disponible" },
  { id: "mas-5", refugioId: "ref-1", nombre: "Nube", especie: "gato", raza: "Doméstico", edadMeses: 6, sexo: "hembra", tamano: "pequeño", salud: "Desparasitada", descripcion: "Gatita muy dulce. Busca un hogar con paciencia y mucho cariño.", foto: F + "gato-blanco.svg", estatus: "disponible" },
  { id: "mas-6", refugioId: "ref-1", nombre: "Bobby", especie: "perro", raza: "Mestizo", edadMeses: 48, sexo: "macho", tamano: "grande", salud: "En tratamiento", descripcion: "Todavía en recuperación; aún no está disponible.", foto: F + "perro-negro.svg", estatus: "en proceso" },

  // Centro PetCare
  { id: "mas-7", refugioId: "ref-2", nombre: "Rocky", especie: "perro", raza: "Pastor mestizo", edadMeses: 60, sexo: "macho", tamano: "grande", salud: "Vacunado y esterilizado", descripcion: "Leal y protector. Necesita un hogar con patio.", foto: F + "perro-negro.svg", estatus: "disponible" },
  { id: "mas-8", refugioId: "ref-2", nombre: "Bella", especie: "perro", raza: "Chihuahua mix", edadMeses: 18, sexo: "hembra", tamano: "pequeño", salud: "Vacunas al día", descripcion: "Pequeña pero valiente. Se apega muy rápido a su persona.", foto: F + "perro-cafe.svg", estatus: "disponible" },
  { id: "mas-9", refugioId: "ref-2", nombre: "Tom", especie: "gato", raza: "Atigrado", edadMeses: 30, sexo: "macho", tamano: "mediano", salud: "Vacunado y esterilizado", descripcion: "Independiente pero cariñoso cuando agarra confianza.", foto: F + "gato-gris.svg", estatus: "disponible" },
  { id: "mas-10", refugioId: "ref-2", nombre: "Mía", especie: "gato", raza: "Doméstico", edadMeses: 96, sexo: "hembra", tamano: "mediano", salud: "Revisión geriátrica al día", descripcion: "Una señora tranquila que merece una vejez consentida.", foto: F + "gato-negro.svg", estatus: "disponible" },
  { id: "mas-11", refugioId: "ref-2", nombre: "Toby", especie: "perro", raza: "Cruza de poodle", edadMeses: 4, sexo: "macho", tamano: "pequeño", salud: "Primera vacuna aplicada", descripcion: "Cachorro curioso que ya aprende a sentarse.", foto: F + "perro-dorado.svg", estatus: "disponible" },

  // Refugio y centro de cuidados PetFriend
  { id: "mas-12", refugioId: "ref-3", nombre: "Duque", especie: "perro", raza: "Gran danés mestizo", edadMeses: 84, sexo: "macho", tamano: "grande", salud: "Vacunado", descripcion: "Un gigante bueno. Camina tranquilo con correa.", foto: F + "perro-dalmata.svg", estatus: "disponible" },
  { id: "mas-13", refugioId: "ref-3", nombre: "Kira", especie: "perro", raza: "Husky mestiza", edadMeses: 14, sexo: "hembra", tamano: "mediano", salud: "Vacunada y esterilizada", descripcion: "Muy activa; ama los paseos largos y los juegos.", foto: F + "perro-cafe.svg", estatus: "disponible" },
  { id: "mas-14", refugioId: "ref-3", nombre: "Pelusa", especie: "gato", raza: "Persa mestiza", edadMeses: 24, sexo: "hembra", tamano: "mediano", salud: "Vacunada", descripcion: "Pelaje esponjoso y carácter dulce. Disfruta los cepillados.", foto: F + "gato-blanco.svg", estatus: "disponible" },
  { id: "mas-15", refugioId: "ref-3", nombre: "Bruno", especie: "perro", raza: "Criollo", edadMeses: 120, sexo: "macho", tamano: "mediano", salud: "Control de artritis", descripcion: "Senior sereno que solo pide una cama blandita y compañía.", foto: F + "perro-negro.svg", estatus: "disponible" },
  { id: "mas-16", refugioId: "ref-3", nombre: "Chispa", especie: "perro", raza: "Mestiza", edadMeses: 5, sexo: "hembra", tamano: "pequeño", salud: "Desparasitada", descripcion: "Cachorrita traviesa, rescatada junto a sus hermanos.", foto: F + "perro-dorado.svg", estatus: "adoptado" },

  // Refugio Michis & Cats (solo gatos)
  { id: "mas-17", refugioId: "ref-4", nombre: "Michi", especie: "gato", raza: "Doméstico", edadMeses: 10, sexo: "macho", tamano: "pequeño", salud: "Vacunado", descripcion: "Le encanta perseguir cualquier cosa que se mueva.", foto: F + "gato-gris-2.svg", estatus: "disponible" },
  { id: "mas-18", refugioId: "ref-4", nombre: "Oreo", especie: "gato", raza: "Bicolor", edadMeses: 20, sexo: "macho", tamano: "mediano", salud: "Vacunado y esterilizado", descripcion: "Sociable y dormilón. Convive bien con otros gatos.", foto: F + "gato-negro.svg", estatus: "disponible" },
  { id: "mas-19", refugioId: "ref-4", nombre: "Nala", especie: "gato", raza: "Doméstica", edadMeses: 36, sexo: "hembra", tamano: "mediano", salud: "Esterilizada", descripcion: "Elegante y reservada; se vuelve muy cariñosa en casa.", foto: F + "gato-naranja.svg", estatus: "disponible" },
  { id: "mas-20", refugioId: "ref-4", nombre: "Garfield", especie: "gato", raza: "Atigrado", edadMeses: 72, sexo: "macho", tamano: "grande", salud: "Dieta controlada", descripcion: "Le gusta comer y dormir. Busca un hogar tranquilo.", foto: F + "gato-naranja.svg", estatus: "disponible" },
  { id: "mas-21", refugioId: "ref-4", nombre: "Cleo", especie: "gato", raza: "Doméstica", edadMeses: 3, sexo: "hembra", tamano: "pequeño", salud: "Primera vacuna aplicada", descripcion: "Gatita rescatada; muy juguetona y mimosa.", foto: F + "gato-gris.svg", estatus: "disponible" },
  { id: "mas-22", refugioId: "ref-4", nombre: "Sombra", especie: "gato", raza: "Doméstico", edadMeses: 108, sexo: "macho", tamano: "mediano", salud: "Revisión geriátrica al día", descripcion: "Senior tranquilo, ideal para quien busca compañía serena.", foto: F + "gato-negro.svg", estatus: "disponible" },
  { id: "mas-23", refugioId: "ref-4", nombre: "Pixel", especie: "gato", raza: "Doméstico", edadMeses: 14, sexo: "macho", tamano: "pequeño", salud: "Vacunado", descripcion: "Travieso y aventurero. Necesita juguetes y rascadores.", foto: F + "gato-gris-2.svg", estatus: "disponible" },
];

/** Publicaciones que cada refugio muestra en su página pública (Fase 3 permite crearlas). */
export const mockPublicacionesRefugio = [
  { id: "rp-1", refugioId: "ref-1", mascotaId: "mas-2", autor: "Centro Fernandino el chico", fecha: haceHoras(20), texto: "Conoce a Luna: 8 meses, mucha energía y un corazón enorme. Estamos recibiendo solicitudes de adopción esta semana.", foto: "assets/img/mascotas/perro-dorado.svg", fotoAlt: "Luna, cachorra dorada" },
  { id: "rp-2", refugioId: "ref-1", mascotaId: "mas-4", autor: "Centro Fernandino el chico", fecha: haceHoras(90), texto: "Simón busca familia. Es sociable, está vacunado y se lleva bien con niños.", foto: "assets/img/mascotas/gato-naranja.svg", fotoAlt: "Simón, gato naranja" },
  { id: "rp-3", refugioId: "ref-4", mascotaId: "mas-22", autor: "Refugio Michis & Cats", fecha: haceHoras(48), texto: "Los gatitos senior también merecen un hogar. Sombra tiene 9 años y mucho amor para dar.", foto: "assets/img/mascotas/gato-negro.svg", fotoAlt: "Sombra, gato negro" },
];
