/**
 * mock-refugios.js — Datos simulados de refugios.
 * Estados posibles: pendiente | aprobado | rechazado | suspendido
 * (Se sustituirá por GET /api/refugios cuando exista backend.)
 */
export const ESTADOS_REFUGIO = Object.freeze({
  PENDIENTE: "pendiente",
  APROBADO: "aprobado",
  RECHAZADO: "rechazado",
  SUSPENDIDO: "suspendido",
});

/** Documentos de ejemplo (solo metadatos) de un refugio ya verificado. */
const documentosVerificados = () => [
  { tipo: "acta", nombre: "acta-constitutiva.pdf", tamano: 512340 },
  { tipo: "domicilio", nombre: "comprobante-domicilio.pdf", tamano: 198220 },
  { tipo: "identificacion", nombre: "identificacion-responsable.jpg", tamano: 174905 },
];

export const mockRefugios = [
  { id: "ref-1", nombre: "Centro Fernandino el chico", responsable: "Fernando Ruiz", correo: "refugio@huellapp.mx", telefono: "55 1234 5678", direccion: "Av. Chimalhuacán 120, Cd. Nezahualcóyotl", horario: "09:00 - 18:00", estado: "aprobado", motivoRechazo: "", documentos: documentosVerificados() },
  { id: "ref-2", nombre: "Centro PetCare", responsable: "Laura Méndez", correo: "petcare@huellapp.mx", telefono: "55 2222 3333", direccion: "Calle Sur 8, Col. Providencia", horario: "10:00 - 17:00", estado: "aprobado", motivoRechazo: "", documentos: documentosVerificados() },
  { id: "ref-3", nombre: "Refugio y centro de cuidados PetFriend", responsable: "Diego Torres", correo: "petfriend@huellapp.mx", telefono: "55 4444 5555", direccion: "Av. Bordo de Xochiaca 45", horario: "09:00 - 16:00", estado: "aprobado", motivoRechazo: "", documentos: documentosVerificados() },
  { id: "ref-4", nombre: "Refugio Michis & Cats", responsable: "Sofía Ortega", correo: "michis@huellapp.mx", telefono: "55 6666 7777", direccion: "Calle Gato 3, Col. Evolución", horario: "11:00 - 19:00", estado: "aprobado", motivoRechazo: "", documentos: documentosVerificados() },
  { id: "ref-5", nombre: "Patitas Felices", responsable: "Marco Pineda", correo: "pendiente@huellapp.mx", telefono: "55 8888 1111", direccion: "Av. Texcoco 300", horario: "09:00 - 18:00", estado: "pendiente", motivoRechazo: "",
    documentos: [
      { tipo: "acta", nombre: "acta-constitutiva.pdf", tamano: 482113 },
      { tipo: "domicilio", nombre: "comprobante-domicilio.jpg", tamano: 210332 },
      { tipo: "identificacion", nombre: "ine-responsable.jpg", tamano: 190442 },
    ] },
  { id: "ref-6", nombre: "Hogar Peludo", responsable: "Rosa Camacho", correo: "rechazado@huellapp.mx", telefono: "55 9999 0000", direccion: "Calle Luna 12", horario: "10:00 - 15:00", estado: "rechazado",
    motivoRechazo: "El comprobante de domicilio tiene más de 3 meses de antigüedad. Sube uno reciente.", documentos: [] },
];
