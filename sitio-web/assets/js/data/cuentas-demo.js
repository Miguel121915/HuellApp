/**
 * cuentas-demo.js — Atajos de la pantalla de login para probar cada rol.
 * Coinciden con las cuentas que carga la semilla del backend (backend/database/datos-demo.json).
 * AVISO: solo para desarrollo. Quita este archivo y el bloque de demo del login al publicar.
 */
export const CUENTAS_DEMO = [
  { etiqueta: "Usuario", rol: "usuario", correo: "ana@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio verificado", rol: "refugio", correo: "refugio@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio pendiente", rol: "refugio", correo: "pendiente@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio rechazado", rol: "refugio", correo: "rechazado@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Administrador", rol: "admin", correo: "admin@huellapp.mx", password: "Demo1234" },
];
