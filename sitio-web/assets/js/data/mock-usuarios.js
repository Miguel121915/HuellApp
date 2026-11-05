/**
 * mock-usuarios.js — Cuentas demo.
 * AVISO: contraseñas en texto plano SOLO porque es un mock sin backend.
 * El backend real debe guardar hashes y nunca devolver la contraseña.
 */
export const ROLES = Object.freeze({ USUARIO: "usuario", REFUGIO: "refugio", ADMIN: "admin" });

export const mockUsuarios = [
  { id: "usr-1", nombre: "Ana López", correo: "ana@huellapp.mx", password: "Demo1234", rol: "usuario" },
  { id: "usr-2", nombre: "Fernando Ruiz", correo: "refugio@huellapp.mx", password: "Demo1234", rol: "refugio", refugioId: "ref-1" },
  { id: "usr-3", nombre: "Marco Pineda", correo: "pendiente@huellapp.mx", password: "Demo1234", rol: "refugio", refugioId: "ref-5" },
  { id: "usr-4", nombre: "Rosa Camacho", correo: "rechazado@huellapp.mx", password: "Demo1234", rol: "refugio", refugioId: "ref-6" },
  { id: "usr-5", nombre: "Administrador", correo: "admin@huellapp.mx", password: "Demo1234", rol: "admin" },
];

/** Cuentas que se muestran como atajo en la pantalla de login. */
export const CUENTAS_DEMO = [
  { etiqueta: "Usuario", rol: "usuario", correo: "ana@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio verificado", rol: "refugio", correo: "refugio@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio pendiente", rol: "refugio", correo: "pendiente@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Refugio rechazado", rol: "refugio", correo: "rechazado@huellapp.mx", password: "Demo1234" },
  { etiqueta: "Administrador", rol: "admin", correo: "admin@huellapp.mx", password: "Demo1234" },
];
