/**
 * Pruebas de la API de HuellApp (hablan con el servidor por HTTP, igual que el sitio y la app).
 *
 * Se ejecutan con:  php artisan test
 * Ese comando crea una base APARTE ("huellapp_test"), enciende un servidor temporal y corre estas
 * pruebas; no toca tus datos. Necesitan Node.js (solo para las pruebas).
 *
 * Para correrlas a mano contra un servidor ya encendido:  API_BASE=http://127.0.0.1:3000 node --test pruebas/api.test.js
 * (ojo: modifican datos; úsalas solo sobre una base recién creada con "migrate:fresh --seed").
 */
import { test } from "node:test";
import assert from "node:assert/strict";

const base = process.env.API_BASE || "http://127.0.0.1:3999";

/* ---------- Ayudas ---------- */
async function api(metodo, ruta, { token, cuerpo } = {}) {
  const r = await fetch(base + ruta, {
    method: metodo,
    headers: { ...(cuerpo ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: cuerpo ? JSON.stringify(cuerpo) : undefined,
  });
  const tipo = r.headers.get("content-type") || "";
  return { estado: r.status, datos: tipo.includes("json") ? await r.json() : null, respuesta: r };
}
async function entrar(correo, rol, password = "Demo1234") {
  const { estado, datos } = await api("POST", "/api/auth/login", { cuerpo: { correo, password, rol } });
  assert.equal(estado, 200, `login de ${correo}: ${datos?.error}`);
  return datos;
}
const PNG = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
const PDF = `data:application/pdf;base64,${Buffer.from("%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF\n").toString("base64")}`;
const MASCOTA = { nombre: "Rayo", especie: "perro", raza: "Beagle", edadMeses: 24, sexo: "macho", tamano: "mediano", salud: "Vacunado", descripcion: "Perro muy activo, ideal para familias.", estatus: "disponible" };

/* ---------- Autenticación ---------- */
test("salud y rutas protegidas", async () => {
  assert.equal((await api("GET", "/api/salud")).estado, 200);
  // Leer el foro es público (el visitante también lo ve); las coincidencias sí piden cuenta
  assert.equal((await api("GET", "/api/foro")).estado, 200);
  assert.equal((await api("GET", "/api/coincidencias")).estado, 401);
  assert.equal((await api("GET", "/api/coincidencias", { token: "falso" })).estado, 401);
  assert.equal((await api("GET", "/api/ruta-que-no-existe")).estado, 404);
});

test("login: correcto, incorrecto y rol equivocado", async () => {
  const ok = await entrar("ana@huellapp.mx", "usuario");
  assert.equal(ok.sesion.rol, "usuario");
  assert.ok(ok.token);
  assert.equal(JSON.stringify(ok).includes("password"), false, "nunca se devuelve la contraseña");

  const mal = await api("POST", "/api/auth/login", { cuerpo: { correo: "ana@huellapp.mx", password: "incorrecta1", rol: "usuario" } });
  assert.equal(mal.estado, 401);
  const noExiste = await api("POST", "/api/auth/login", { cuerpo: { correo: "nadie@huellapp.mx", password: "incorrecta1", rol: "usuario" } });
  assert.equal(noExiste.datos.error, mal.datos.error, "mismo mensaje exista o no el correo");

  const rol = await api("POST", "/api/auth/login", { cuerpo: { correo: "ana@huellapp.mx", password: "Demo1234", rol: "refugio" } });
  assert.equal(rol.estado, 403);
});

test("login: se bloquea tras demasiados intentos fallidos", async () => {
  let ultimo;
  for (let i = 0; i < 9; i++) ultimo = await api("POST", "/api/auth/login", { cuerpo: { correo: "bloqueo@huellapp.mx", password: "mala-clave-1" } });
  assert.equal(ultimo.estado, 429);
});

test("registro de usuario: valida y no permite correos repetidos", async () => {
  const nuevo = { nombre: "Persona Nueva", correo: "nueva@ejemplo.mx", telefono: "55 1111 2222", password: "ClaveSegura1" };
  assert.equal((await api("POST", "/api/auth/registro-usuario", { cuerpo: nuevo })).estado, 201);
  assert.equal((await api("POST", "/api/auth/registro-usuario", { cuerpo: { ...nuevo, correo: "NUEVA@ejemplo.mx" } })).estado, 409);
  assert.equal((await api("POST", "/api/auth/registro-usuario", { cuerpo: { ...nuevo, correo: "otra@ejemplo.mx", password: "corta" } })).estado, 400);
  await entrar("nueva@ejemplo.mx", "usuario", "ClaveSegura1");
});

/* ---------- Foro ---------- */
test("foro: listar, publicar con foto, comentar y dar 'me gusta'", async () => {
  const { token } = await entrar("ana@huellapp.mx", "usuario");
  const lista = await api("GET", "/api/foro", { token });
  assert.equal(lista.datos.publicaciones.length, 8);
  assert.ok(lista.datos.publicaciones[0].fecha >= lista.datos.publicaciones[1].fecha, "más recientes primero");

  const conFoto = await api("POST", "/api/foro", { token, cuerpo: { texto: "Mi primera publicación de prueba", foto: PNG } });
  assert.equal(conFoto.estado, 201);
  const pub = conFoto.datos.publicacion;
  assert.match(pub.foto, /^\/uploads\/imagenes\/[0-9a-f-]{36}\.png$/);
  assert.equal(pub.autor, "Ana López");
  const imagen = await fetch(base + pub.foto);
  assert.equal(imagen.status, 200);
  assert.equal(imagen.headers.get("content-type"), "image/png");

  // "me gusta": fijar estado (idempotente)
  const base0 = pub.likes;
  assert.equal((await api("PUT", `/api/foro/${pub.id}/like`, { token, cuerpo: { activo: true } })).datos.activo, true);
  await api("PUT", `/api/foro/${pub.id}/like`, { token, cuerpo: { activo: true } });
  const tras = (await api("GET", "/api/foro", { token })).datos.publicaciones.find((p) => p.id === pub.id);
  assert.equal(tras.yaDioLike, true);
  assert.equal(tras.likes, base0, "likes no incluye el del propio usuario");
  await api("PUT", `/api/foro/${pub.id}/like`, { token, cuerpo: { activo: false } });
  assert.equal((await api("GET", "/api/foro", { token })).datos.publicaciones.find((p) => p.id === pub.id).yaDioLike, false);

  const comentario = await api("POST", `/api/foro/${pub.id}/comentarios`, { token, cuerpo: { texto: "¡Hola!" } });
  assert.equal(comentario.estado, 201);
  assert.deepEqual(comentario.datos.comentarios.at(-1), { autor: "Ana López", texto: "¡Hola!", enRevision: false });
});

test("foro: rechaza datos inválidos, archivos falsos y roles sin permiso", async () => {
  const { token } = await entrar("ana@huellapp.mx", "usuario");
  assert.equal((await api("POST", "/api/foro", { token, cuerpo: { texto: "hey" } })).estado, 400);
  assert.equal((await api("POST", "/api/foro", { token, cuerpo: { texto: "Texto válido largo", foto: "data:image/png;base64,AAAA" } })).estado, 400, "firma de PNG falsa");
  assert.equal((await api("POST", "/api/foro", { token, cuerpo: { texto: "Texto válido largo", foto: "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=" } })).estado, 400, "SVG no permitido");
  assert.equal((await api("POST", "/api/foro/9999/comentarios", { token, cuerpo: { texto: "x" } })).estado, 404);
  const refugio = await entrar("refugio@huellapp.mx", "refugio");
  assert.equal((await api("POST", "/api/foro", { token: refugio.token, cuerpo: { texto: "Un refugio no publica aquí" } })).estado, 403);
});

/* ---------- Refugios públicos ---------- */
test("usuarios solo ven refugios aprobados y mascotas disponibles", async () => {
  const { token } = await entrar("ana@huellapp.mx", "usuario");
  const { refugios } = (await api("GET", "/api/refugios", { token })).datos;
  assert.equal(refugios.length, 4);
  assert.equal(refugios.some((r) => "correo" in r || "documentos" in r), false, "no se exponen correo ni documentos");
  const primero = refugios[0];
  assert.equal((await api("GET", `/api/refugios/${primero.id}/mascotas`, { token })).datos.mascotas.length, 5, "la 'en proceso' no aparece");
  assert.equal((await api("GET", "/api/refugios/5", { token })).estado, 404, "el pendiente no es público");
  assert.equal((await api("GET", "/api/refugios/6", { token })).estado, 404, "el rechazado tampoco");
});

/* ---------- Panel de refugio ---------- */
test("refugio pendiente no puede usar el panel", async () => {
  const { token, sesion } = await entrar("pendiente@huellapp.mx", "refugio");
  assert.equal(sesion.refugioEstado, "pendiente");
  const r = await api("GET", "/api/refugio/mascotas", { token });
  assert.equal(r.estado, 403);
  assert.equal(r.datos.codigo, "refugio-no-aprobado");
  assert.equal((await api("GET", "/api/auth/yo", { token })).datos.refugio.estado, "pendiente");
});

test("inventario: crear, editar, cambiar estatus y eliminar con sus publicaciones", async () => {
  const { token } = await entrar("refugio@huellapp.mx", "refugio");
  const resumen0 = (await api("GET", "/api/refugio/resumen", { token })).datos;
  assert.deepEqual([resumen0.total, resumen0.disponibles, resumen0.enProceso, resumen0.publicaciones], [6, 5, 1, 2]);

  const creada = await api("POST", "/api/refugio/mascotas", { token, cuerpo: { ...MASCOTA, foto: PNG } });
  assert.equal(creada.estado, 201);
  const id = creada.datos.mascota.id;
  assert.match(creada.datos.mascota.foto, /^\/uploads\/imagenes\//);

  assert.equal((await api("POST", "/api/refugio/mascotas", { token, cuerpo: { ...MASCOTA, nombre: "R" } })).estado, 400);
  assert.equal((await api("POST", "/api/refugio/mascotas", { token, cuerpo: { ...MASCOTA, edadMeses: 0 } })).estado, 400);
  assert.equal((await api("POST", "/api/refugio/mascotas", { token, cuerpo: { ...MASCOTA, especie: "pez" } })).estado, 400);

  const sinFoto = await api("POST", "/api/refugio/mascotas", { token, cuerpo: MASCOTA });
  assert.equal(sinFoto.datos.mascota.foto, "assets/img/mascotas/sin-foto.svg");

  const editada = await api("PUT", `/api/refugio/mascotas/${id}`, { token, cuerpo: { ...MASCOTA, nombre: "Rayo II", edadMeses: 8, foto: creada.datos.mascota.foto } });
  assert.equal(editada.datos.mascota.nombre, "Rayo II");
  assert.equal(editada.datos.mascota.edadMeses, 8);

  const estatus = await api("PATCH", `/api/refugio/mascotas/${id}/estatus`, { token, cuerpo: { estatus: "adoptado" } });
  assert.equal(estatus.datos.mascota.estatus, "adoptado");
  assert.equal((await api("PATCH", `/api/refugio/mascotas/${id}/estatus`, { token, cuerpo: { estatus: "regalada" } })).estado, 400);
  await api("PATCH", `/api/refugio/mascotas/${id}/estatus`, { token, cuerpo: { estatus: "disponible" } });

  // publicación → conteo → borrar mascota arrastra la publicación
  const pub = await api("POST", "/api/refugio/publicaciones", { token, cuerpo: { mascotaId: id, texto: "Rayo busca una familia activa." } });
  assert.equal(pub.estado, 201);
  assert.equal(pub.datos.publicacion.foto, creada.datos.mascota.foto, "sin foto propia se usa la de la mascota");
  assert.equal((await api("GET", `/api/refugio/mascotas/${id}/publicaciones/conteo`, { token })).datos.total, 1);
  const borrada = await api("DELETE", `/api/refugio/mascotas/${id}`, { token });
  assert.equal(borrada.datos.publicacionesEliminadas, 1);
  assert.equal((await api("GET", `/api/refugio/mascotas/${id}/publicaciones/conteo`, { token })).estado, 404);
  const listaPub = (await api("GET", "/api/refugio/publicaciones", { token })).datos.publicaciones;
  assert.equal(listaPub.some((p) => p.mascotaId === id), false);
});

test("un refugio no puede ver ni tocar los datos de otro", async () => {
  const a = await entrar("refugio@huellapp.mx", "refugio");
  const b = await entrar("petcare@huellapp.mx", "refugio");
  const mascotaA = (await api("GET", "/api/refugio/mascotas", { token: a.token })).datos.mascotas[0];
  assert.equal((await api("PUT", `/api/refugio/mascotas/${mascotaA.id}`, { token: b.token, cuerpo: MASCOTA })).estado, 404);
  assert.equal((await api("DELETE", `/api/refugio/mascotas/${mascotaA.id}`, { token: b.token })).estado, 404);
  assert.equal((await api("POST", "/api/refugio/publicaciones", { token: b.token, cuerpo: { mascotaId: mascotaA.id, texto: "Intento de publicar ajena" } })).estado, 400);
  const mias = (await api("GET", "/api/refugio/mascotas", { token: b.token })).datos.mascotas;
  assert.equal(mias.some((m) => m.id === mascotaA.id), false);
});

test("perfil del refugio: se edita y los usuarios lo ven; adoptadas se ocultan", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const u = await entrar("ana@huellapp.mx", "usuario");
  const cambios = { telefono: "55 9876 5432", direccion: "Av. Nueva 123, Col. Centro", horario: "08:00 - 20:00", descripcion: "Refugio familiar." };
  assert.equal((await api("PUT", "/api/refugio/perfil", { token: r.token, cuerpo: cambios })).estado, 200);
  assert.equal((await api("PUT", "/api/refugio/perfil", { token: r.token, cuerpo: { ...cambios, horario: "20:00 - 08:00" } })).estado, 400);

  const id = r.sesion.refugioId;
  const publico = (await api("GET", `/api/refugios/${id}`, { token: u.token })).datos.refugio;
  assert.equal(publico.telefono, "55 9876 5432");
  assert.equal(publico.horario, "08:00 - 20:00");

  const mascotas = (await api("GET", `/api/refugios/${id}/mascotas`, { token: u.token })).datos.mascotas;
  const luna = mascotas.find((m) => m.nombre === "Luna");
  await api("PATCH", `/api/refugio/mascotas/${luna.id}/estatus`, { token: r.token, cuerpo: { estatus: "adoptado" } });
  const despues = (await api("GET", `/api/refugios/${id}/mascotas`, { token: u.token })).datos.mascotas;
  assert.equal(despues.some((m) => m.nombre === "Luna"), false);
  const pubs = (await api("GET", `/api/refugios/${id}/publicaciones`, { token: u.token })).datos.publicaciones;
  assert.equal(pubs.some((p) => p.etiqueta === "Mascota: Luna"), false, "su publicación se oculta al ser adoptada");
});

/* ---------- Reportes y coincidencias ---------- */
test("coincidencias: listar, declinar, restaurar y proteger las ajenas", async () => {
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const otro = await entrar("nueva@ejemplo.mx", "usuario", "ClaveSegura1");

  const lista = (await api("GET", "/api/coincidencias", { token: ana.token })).datos.coincidencias;
  assert.deepEqual(lista.map((c) => c.similitud), [92, 74, 58]);
  assert.equal(lista[0].hallazgo.contacto.nombre, "Carlos Vega");
  assert.equal(lista[0].lado, "perdida", "Ana perdió a su mascota");
  assert.deepEqual(lista[0].otroReporte, lista[0].hallazgo, "para quien perdió, otroReporte es el hallazgo");
  assert.ok(lista.every((c) => typeof c.otroReporte.contacto.telefono === "string"), "el teléfono siempre es texto ('' si no lo dio)");
  assert.deepEqual((await api("GET", "/api/coincidencias/resumen", { token: ana.token })).datos, { pendientes: 3, descartadas: 0, analizando: 0, duplicados: [] });

  assert.equal((await api("POST", `/api/coincidencias/${lista[0].id}/descartar`, { token: otro.token })).estado, 404, "no puede declinar la de otra persona");
  await api("POST", `/api/coincidencias/${lista[0].id}/descartar`, { token: ana.token });
  assert.deepEqual((await api("GET", "/api/coincidencias/resumen", { token: ana.token })).datos, { pendientes: 2, descartadas: 1, analizando: 0, duplicados: [] });
  await api("POST", "/api/coincidencias/restaurar", { token: ana.token });
  assert.equal((await api("GET", "/api/coincidencias", { token: ana.token })).datos.coincidencias.length, 3);
  assert.equal((await api("GET", "/api/coincidencias", { token: otro.token })).datos.coincidencias.length, 0, "cada quien ve solo las suyas");
});

test("reportes: un hallazgo parecido genera una coincidencia nueva para el dueño", async () => {
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const otro = await entrar("nueva@ejemplo.mx", "usuario", "ClaveSegura1");
  const sinFoto = await api("POST", "/api/reportes", { token: otro.token, cuerpo: { tipo: "encontrada", descripcion: "Gato gris con rayas oscuras y ojos verdes", zona: "Colonia San Miguel" } });
  assert.equal(sinFoto.estado, 400, "la foto es obligatoria");
  assert.equal((await api("POST", "/api/reportes", { token: otro.token, cuerpo: { tipo: "encontrada", descripcion: "corto", zona: "Colonia San Miguel", foto: PNG } })).estado, 400);

  const r = await api("POST", "/api/reportes", { token: otro.token, cuerpo: {
    tipo: "encontrada", zona: "Parque de la colonia San Miguel", foto: PNG,
    descripcion: "Encontré un gato gordito, gris con rayas oscuras y ojos verdes, cerca del parque de la colonia San Miguel." } });
  assert.equal(r.estado, 201);
  assert.ok(r.datos.coincidenciasNuevas >= 1);
  const resumen = (await api("GET", "/api/coincidencias/resumen", { token: ana.token })).datos;
  assert.equal(resumen.pendientes, 4);

  // Quien encontró la mascota también ve la coincidencia, con el contacto de quien la perdió
  const delOtro = (await api("GET", "/api/coincidencias", { token: otro.token })).datos.coincidencias;
  const conAna = delOtro.find((c) => c.otroReporte.contacto.nombre === "Ana López");
  assert.ok(conAna, "quien encontró ve la coincidencia con la pérdida de Ana");
  assert.equal(conAna.lado, "encontrada");
  assert.equal(conAna.miReporte.tipo, "encontrada");
  assert.equal(conAna.otroReporte.tipo, "perdida");
  // Cada quien descarta por su lado: si quien encontró la descarta, Ana la sigue viendo
  await api("POST", `/api/coincidencias/${conAna.id}/descartar`, { token: otro.token });
  assert.equal((await api("GET", "/api/coincidencias/resumen", { token: ana.token })).datos.pendientes, 4);
  await api("POST", "/api/coincidencias/restaurar", { token: otro.token });

  // La MISMA foto en otro hallazgo se detecta como posible duplicado; quien reporta puede confirmar que es otra
  const IRRELEVANTE = { tipo: "encontrada", zona: "Monterrey Nuevo León", foto: PNG, descripcion: "Perro labrador negro con collar morado muy grande" };
  const repetida = await api("POST", "/api/reportes", { token: otro.token, cuerpo: IRRELEVANTE });
  assert.equal(repetida.estado, 409, "la misma foto ya estaba en otro reporte");
  assert.equal(repetida.datos.codigo, "posible-duplicado");
  const irrelevante = await api("POST", "/api/reportes", { token: otro.token, cuerpo: { ...IRRELEVANTE, confirmarDuplicado: true } });
  assert.equal(irrelevante.estado, 201, irrelevante.datos?.error);
  assert.equal(irrelevante.datos.coincidenciasNuevas, 0, "un reporte sin parecido no genera coincidencias");
});

/* ---------- Registro de refugio y administración ---------- */
test("registro de refugio: guarda documentos y queda pendiente", async () => {
  const solicitud = { nombreRefugio: "Huellas del Sur", responsable: "Elena Soto", correo: "elena@huellasdelsur.mx", telefono: "55 7777 8888", direccion: "Calle Sur 55, Col. Centro", horario: "09:00 - 17:00", password: "ClaveSegura1" };
  const docs = [{ tipo: "acta", nombre: "acta.pdf", dataUrl: PDF }, { tipo: "domicilio", nombre: "luz.pdf", dataUrl: PDF }, { tipo: "identificacion", nombre: "ine.png", dataUrl: PNG }];

  assert.equal((await api("POST", "/api/auth/registro-refugio", { cuerpo: { ...solicitud, documentos: docs.slice(0, 2) } })).estado, 400, "faltan obligatorios");
  assert.equal((await api("POST", "/api/auth/registro-refugio", { cuerpo: { ...solicitud, documentos: [...docs.slice(0, 2), { tipo: "identificacion", nombre: "falso.pdf", dataUrl: "data:application/pdf;base64,AAAA" }] } })).estado, 400, "PDF falso");
  assert.equal((await api("POST", "/api/auth/registro-refugio", { cuerpo: { ...solicitud, documentos: docs } })).estado, 201);
  assert.equal((await api("POST", "/api/auth/registro-refugio", { cuerpo: { ...solicitud, documentos: docs } })).estado, 409, "correo repetido");

  const { sesion } = await entrar("elena@huellasdelsur.mx", "refugio", "ClaveSegura1");
  assert.equal(sesion.refugioEstado, "pendiente");
});

test("administrador: solo él revisa; aprobar, rechazar con motivo, suspender y reactivar", async () => {
  const admin = await entrar("admin@huellapp.mx", "admin");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const refugio = await entrar("refugio@huellapp.mx", "refugio");
  assert.equal((await api("GET", "/api/admin/resumen", { token: ana.token })).estado, 403);
  assert.equal((await api("GET", "/api/admin/resumen", { token: refugio.token })).estado, 403);

  const resumen = (await api("GET", "/api/admin/resumen", { token: admin.token })).datos;
  assert.deepEqual(resumen, { pendientes: 2, aprobados: 4, rechazados: 1, suspendidos: 0, moderacion: 0 });

  const pendientes = (await api("GET", "/api/admin/refugios?estado=pendiente", { token: admin.token })).datos.refugios;
  const nuevo = pendientes.find((r) => r.correo === "elena@huellasdelsur.mx");
  assert.equal(nuevo.documentos.length, 3);
  const demo = pendientes.find((r) => r.correo === "pendiente@huellapp.mx");

  // Documentos: checklist y archivo protegido
  const doc = nuevo.documentos[0];
  assert.equal((await api("PATCH", `/api/admin/documentos/${doc.id}`, { token: admin.token, cuerpo: { verificado: true } })).datos.documento.verificado, true);
  const archivo = await fetch(`${base}/api/admin/documentos/${doc.id}/archivo`, { headers: { Authorization: `Bearer ${admin.token}` } });
  assert.equal(archivo.status, 200);
  assert.equal(archivo.headers.get("content-type"), "application/pdf");
  assert.equal((await fetch(`${base}/api/admin/documentos/${doc.id}/archivo`)).status, 401, "sin sesión no se entrega");
  const demoPdf = await fetch(`${base}/api/admin/documentos/${demo.documentos[0].id}/archivo`, { headers: { Authorization: `Bearer ${admin.token}` } });
  assert.equal((await demoPdf.text()).startsWith("%PDF-"), true, "los documentos de ejemplo son PDF válidos");

  // Rechazo: motivo obligatorio
  assert.equal((await api("POST", `/api/admin/refugios/${nuevo.id}/rechazar`, { token: admin.token, cuerpo: {} })).estado, 400);
  assert.equal((await api("POST", `/api/admin/refugios/${nuevo.id}/rechazar`, { token: admin.token, cuerpo: { motivo: "corto" } })).estado, 400);
  const rechazado = await api("POST", `/api/admin/refugios/${nuevo.id}/rechazar`, { token: admin.token, cuerpo: { motivo: "El acta constitutiva no es legible." } });
  assert.equal(rechazado.datos.refugio.estado, "rechazado");
  assert.equal((await api("POST", `/api/admin/refugios/${nuevo.id}/aprobar`, { token: admin.token })).estado, 409, "ya fue revisada");

  // Aprobación → el refugio pendiente ya puede trabajar y aparece para los usuarios
  assert.equal((await api("POST", `/api/admin/refugios/${demo.id}/aprobar`, { token: admin.token })).datos.refugio.estado, "aprobado");
  const marco = await entrar("pendiente@huellapp.mx", "refugio");
  assert.equal(marco.sesion.refugioEstado, "aprobado");
  assert.equal((await api("POST", "/api/refugio/mascotas", { token: marco.token, cuerpo: MASCOTA })).estado, 201);
  assert.equal((await api("GET", "/api/refugios", { token: ana.token })).datos.refugios.some((r) => r.id === demo.id), true);

  // Suspensión → pierde el acceso y deja de ser público; reactivar lo devuelve
  assert.equal((await api("POST", `/api/admin/refugios/${demo.id}/suspender`, { token: admin.token, cuerpo: { motivo: "Reportes de maltrato en revisión" } })).datos.refugio.estado, "suspendido");
  const bloqueado = await api("GET", "/api/refugio/mascotas", { token: marco.token });
  assert.equal(bloqueado.estado, 403);
  assert.equal(bloqueado.datos.estado, "suspendido");
  assert.equal((await api("GET", `/api/refugios/${demo.id}`, { token: ana.token })).estado, 404);
  assert.equal((await api("POST", `/api/admin/refugios/${demo.id}/reactivar`, { token: admin.token })).datos.refugio.estado, "aprobado");
  assert.equal((await api("GET", "/api/refugio/mascotas", { token: marco.token })).estado, 200);
});

/* ---------- Documentos por mascota ---------- */
test("documentos de mascota: el refugio sube, el admin revisa; nadie más los ve", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const otro = await entrar("petcare@huellapp.mx", "refugio");
  const admin = await entrar("admin@huellapp.mx", "admin");
  const ana = await entrar("ana@huellapp.mx", "usuario");

  // Datos demo: Max tiene 2 documentos (1 revisado) y el conteo sale en el inventario
  const max = (await api("GET", "/api/refugio/mascotas", { token: r.token })).datos.mascotas.find((m) => m.nombre === "Max");
  assert.deepEqual(max.documentos, { total: 2, verificados: 1 });

  // Subir: valida tipo, contenido real y propiedad
  const ruta = `/api/refugio/mascotas/${max.id}/documentos`;
  const subido = await api("POST", ruta, { token: r.token, cuerpo: { tipo: "pedigree", nombre: "pedigree-max.pdf", dataUrl: PDF } });
  assert.equal(subido.estado, 201, subido.datos?.error);
  assert.equal(subido.datos.documento.verificado, false);
  const docId = subido.datos.documento.id;
  assert.equal((await api("POST", ruta, { token: r.token, cuerpo: { tipo: "pasaporte", nombre: "x.pdf", dataUrl: PDF } })).estado, 400);
  const falso = `data:application/pdf;base64,${Buffer.from("no soy un pdf").toString("base64")}`;
  assert.equal((await api("POST", ruta, { token: r.token, cuerpo: { tipo: "otro", nombre: "falso.pdf", dataUrl: falso } })).estado, 400);
  assert.equal((await api("POST", ruta, { token: otro.token, cuerpo: { tipo: "otro", nombre: "ajeno.pdf", dataUrl: PDF } })).estado, 404);
  assert.equal((await api("GET", ruta, { token: otro.token })).estado, 404);
  assert.equal((await api("GET", ruta, { token: r.token })).datos.documentos.length, 3);
  const propio = await api("GET", `${ruta}/${docId}/archivo`, { token: r.token });
  assert.equal(propio.estado, 200);
  assert.equal(propio.respuesta.headers.get("content-type"), "application/pdf");

  // Admin: mascotas del refugio (todas, con conteo), detalle, checklist y archivo
  assert.equal((await api("GET", `/api/admin/refugios/${r.sesion.refugioId}/mascotas`, { token: ana.token })).estado, 403);
  const delRefugio = (await api("GET", `/api/admin/refugios/${r.sesion.refugioId}/mascotas`, { token: admin.token })).datos;
  assert.equal(delRefugio.refugio.id, String(r.sesion.refugioId));
  assert.deepEqual(delRefugio.mascotas.find((m) => m.id === max.id).documentos, { total: 3, verificados: 1 });
  assert.ok(delRefugio.mascotas.some((m) => m.estatus !== "disponible"), "incluye mascotas no disponibles");
  const detalle = (await api("GET", `/api/admin/mascotas/${max.id}`, { token: admin.token })).datos;
  assert.equal(detalle.mascota.nombre, "Max");
  assert.equal(detalle.documentos.length, 3);
  assert.equal((await api("PATCH", `/api/admin/documentos-mascota/${docId}`, { token: admin.token, cuerpo: { verificado: "si" } })).estado, 400);
  assert.equal((await api("PATCH", `/api/admin/documentos-mascota/${docId}`, { token: admin.token, cuerpo: { verificado: true } })).datos.documento.verificado, true);
  assert.equal((await api("PATCH", `/api/admin/documentos-mascota/${docId}`, { token: r.token, cuerpo: { verificado: true } })).estado, 403);
  assert.equal((await api("GET", `/api/admin/documentos-mascota/${docId}/archivo`, { token: admin.token })).estado, 200);
  assert.equal((await api("GET", `/api/admin/documentos-mascota/${docId}/archivo`, { token: ana.token })).estado, 403);
  assert.equal((await api("GET", ruta, { token: r.token })).datos.documentos.find((d) => d.id === docId).verificado, true, "el refugio ve la revisión");

  // Eliminar un documento, y al borrar la mascota se van también sus documentos
  assert.equal((await api("DELETE", `${ruta}/${docId}`, { token: otro.token })).estado, 404);
  assert.equal((await api("DELETE", `${ruta}/${docId}`, { token: r.token })).estado, 200);
  assert.equal((await api("GET", `/api/admin/documentos-mascota/${docId}/archivo`, { token: admin.token })).estado, 404);
  const nueva = (await api("POST", "/api/refugio/mascotas", { token: r.token, cuerpo: MASCOTA })).datos.mascota;
  const doc2 = (await api("POST", `/api/refugio/mascotas/${nueva.id}/documentos`, { token: r.token, cuerpo: { tipo: "vacunacion", nombre: "vacunas.pdf", dataUrl: PDF } })).datos.documento;
  await api("DELETE", `/api/refugio/mascotas/${nueva.id}`, { token: r.token });
  assert.equal((await api("GET", `/api/admin/documentos-mascota/${doc2.id}/archivo`, { token: admin.token })).estado, 404);
});

/* ---------- Republicación automática ---------- */
test("republicación: las vencidas vuelven a salir arriba; se valida, se edita y no se toca lo ajeno", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const otro = await entrar("petcare@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");

  // Demo: la publicación de Simón (hace 10 días, cada 7 días) ya debía republicarse
  const publicas = (await api("GET", `/api/refugios/${r.sesion.refugioId}/publicaciones`, { token: ana.token })).datos.publicaciones;
  assert.equal(publicas[0].etiqueta, "Mascota: Simón", "la republicada sale primero");
  assert.ok(Date.now() - new Date(publicas[0].fecha).getTime() < 5 * 60 * 1000, "con fecha de ahora");
  assert.equal("republicarCadaDias" in publicas[0], false, "los usuarios no ven la configuración");

  const mias = (await api("GET", "/api/refugio/publicaciones", { token: r.token })).datos.publicaciones;
  const simon = mias.find((p) => p.mascotaNombre === "Simón");
  assert.equal(simon.republicarCadaDias, 7);
  assert.equal(simon.republicadaVeces, 1, "se republica una sola vez aunque se consulte varias veces");
  assert.ok(simon.creadoEn < simon.fecha, "conserva la fecha de creación");
  assert.ok(new Date(simon.proximaRepublicacion) > new Date(simon.fecha));

  // Crear con periodicidad: valida 1–90
  const mascota = (await api("GET", "/api/refugio/mascotas", { token: r.token })).datos.mascotas.find((m) => m.estatus !== "adoptado");
  const base = { mascotaId: mascota.id, texto: "Publicación con republicación automática." };
  for (const malo of [91, -1, "cada semana", 2.5]) {
    assert.equal((await api("POST", "/api/refugio/publicaciones", { token: r.token, cuerpo: { ...base, republicarCadaDias: malo } })).estado, 400, `rechaza ${malo}`);
  }
  const creada = await api("POST", "/api/refugio/publicaciones", { token: r.token, cuerpo: { ...base, republicarCadaDias: 14 } });
  assert.equal(creada.estado, 201);
  assert.equal(creada.datos.publicacion.republicarCadaDias, 14);
  assert.equal(creada.datos.publicacion.republicadaVeces, 0);
  const sin = await api("POST", "/api/refugio/publicaciones", { token: r.token, cuerpo: base });
  assert.equal(sin.datos.publicacion.republicarCadaDias, null);
  assert.equal(sin.datos.publicacion.proximaRepublicacion, null);

  // Editar: texto y periodicidad (personalizada); se conserva la foto; solo el dueño
  const id = creada.datos.publicacion.id;
  const editada = await api("PUT", `/api/refugio/publicaciones/${id}`, { token: r.token, cuerpo: { texto: "Texto nuevo de la publicación.", republicarCadaDias: 3 } });
  assert.equal(editada.estado, 200, editada.datos?.error);
  assert.equal(editada.datos.publicacion.texto, "Texto nuevo de la publicación.");
  assert.equal(editada.datos.publicacion.republicarCadaDias, 3);
  assert.equal(editada.datos.publicacion.foto, creada.datos.publicacion.foto);
  const desactivada = await api("PUT", `/api/refugio/publicaciones/${id}`, { token: r.token, cuerpo: { texto: "Texto nuevo de la publicación.", republicarCadaDias: null } });
  assert.equal(desactivada.datos.publicacion.republicarCadaDias, null);
  assert.equal((await api("PUT", `/api/refugio/publicaciones/${id}`, { token: otro.token, cuerpo: { texto: "Intento de editar ajena", republicarCadaDias: 7 } })).estado, 404);
  assert.equal((await api("PUT", `/api/refugio/publicaciones/${id}`, { token: r.token, cuerpo: { texto: "corto" } })).estado, 400);
  await api("DELETE", `/api/refugio/publicaciones/${id}`, { token: r.token });
  await api("DELETE", `/api/refugio/publicaciones/${sin.datos.publicacion.id}`, { token: r.token });
});

/* ---------- Apelación de un refugio rechazado ---------- */
test("apelación: el rechazado corrige, reemplaza lo señalado y vuelve a pendiente; el admin puede volver a rechazar", async () => {
  const rosa = await entrar("rechazado@huellapp.mx", "refugio");
  const aprobado = await entrar("refugio@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const admin = await entrar("admin@huellapp.mx", "admin");

  // Precarga: datos y documentos; el comprobante de domicilio viene señalado como erróneo
  const actual = await api("GET", "/api/auth/apelacion", { token: rosa.token });
  assert.equal(actual.estado, 200, actual.datos?.error);
  assert.equal(actual.datos.refugio.nombre, "Hogar Peludo");
  assert.ok(actual.datos.refugio.motivoRechazo.length > 0);
  assert.deepEqual(actual.datos.refugio.documentos.filter((d) => d.conError).map((d) => d.tipo), ["domicilio"]);
  assert.equal((await api("GET", "/api/auth/apelacion")).estado, 401);
  assert.equal((await api("GET", "/api/auth/apelacion", { token: ana.token })).estado, 403);
  const noRechazado = await api("GET", "/api/auth/apelacion", { token: aprobado.token });
  assert.equal(noRechazado.estado, 409);
  assert.equal(noRechazado.datos.codigo, "no-rechazado");

  const datos = { nombreRefugio: "Hogar Peludo", responsable: "Rosa Camacho", telefono: "55 1111 2222", direccion: "Calle Luna 12, Col. Centro", horario: "10:00 - 16:00" };
  // Sin reemplazar el documento señalado, con archivo falso o con datos inválidos: no se acepta
  const sinReemplazo = await api("POST", "/api/auth/apelacion", { token: rosa.token, cuerpo: { ...datos, documentos: [] } });
  assert.equal(sinReemplazo.estado, 400);
  assert.match(sinReemplazo.datos.error, /comprobante de domicilio/);
  const falso = `data:application/pdf;base64,${Buffer.from("no soy un pdf").toString("base64")}`;
  assert.equal((await api("POST", "/api/auth/apelacion", { token: rosa.token, cuerpo: { ...datos, documentos: [{ tipo: "domicilio", nombre: "x.pdf", dataUrl: falso }] } })).estado, 400);
  assert.equal((await api("POST", "/api/auth/apelacion", { token: rosa.token, cuerpo: { ...datos, horario: "18:00 - 09:00", documentos: [{ tipo: "domicilio", nombre: "x.pdf", dataUrl: PDF }] } })).estado, 400);
  assert.equal((await api("GET", "/api/auth/yo", { token: rosa.token })).datos.refugio.estado, "rechazado", "nada cambió tras los intentos fallidos");

  // Apelación correcta: se reemplaza el documento, se actualizan datos y vuelve a "pendiente"
  const enviada = await api("POST", "/api/auth/apelacion", { token: rosa.token, cuerpo: { ...datos, documentos: [{ tipo: "domicilio", nombre: "recibo-luz-octubre.pdf", dataUrl: PDF }] } });
  assert.equal(enviada.estado, 200, enviada.datos?.error);
  const r = enviada.datos.refugio;
  assert.equal(r.estado, "pendiente");
  assert.equal(r.telefono, "55 1111 2222");
  assert.equal(r.horario, "10:00 - 16:00");
  assert.equal(r.motivoRechazo, "");
  assert.ok(r.motivoAnterior.length > 0, "se guarda el motivo del rechazo anterior");
  assert.equal(r.apelaciones, 1);
  assert.equal(r.documentos.length, 3, "reemplaza, no duplica");
  assert.equal(r.documentos.find((d) => d.tipo === "domicilio").nombre, "recibo-luz-octubre.pdf");
  assert.equal(r.documentos.some((d) => d.conError), false);
  assert.equal((await api("GET", "/api/auth/yo", { token: rosa.token })).datos.sesion.refugioEstado, "pendiente");
  assert.equal((await api("POST", "/api/auth/apelacion", { token: rosa.token, cuerpo: { ...datos, documentos: [] } })).estado, 409, "no se apela dos veces");

  // Vuelve a la bandeja del administrador, marcada como apelación
  const bandeja = (await api("GET", "/api/admin/refugios?estado=pendiente", { token: admin.token })).datos.refugios;
  const enBandeja = bandeja.find((x) => x.id === r.id);
  assert.ok(enBandeja, "aparece en la bandeja de solicitudes");
  assert.equal(enBandeja.apelaciones, 1);

  // El admin puede rechazar de nuevo señalando otro documento (solo de esta solicitud)
  const ajeno = (await api("GET", "/api/refugio/yo", { token: aprobado.token })).datos.refugio.documentos[0].id;
  assert.equal((await api("POST", `/api/admin/refugios/${r.id}/rechazar`, { token: admin.token, cuerpo: { motivo: "La identificación no es legible, súbela de nuevo.", documentosConError: [ajeno] } })).estado, 400);
  const identificacion = r.documentos.find((d) => d.tipo === "identificacion").id;
  const rechazo = await api("POST", `/api/admin/refugios/${r.id}/rechazar`, { token: admin.token, cuerpo: { motivo: "La identificación no es legible, súbela de nuevo.", documentosConError: [identificacion] } });
  assert.equal(rechazo.estado, 200, rechazo.datos?.error);
  const otraVez = (await api("GET", "/api/auth/apelacion", { token: rosa.token })).datos.refugio;
  assert.deepEqual(otraVez.documentos.filter((d) => d.conError).map((d) => d.tipo), ["identificacion"]);
  assert.equal(otraVez.apelaciones, 1);
});

/* ---------- Preguntas frecuentes del refugio ---------- */
test("preguntas frecuentes: el refugio las gestiona y los usuarios solo ven las activas", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const otro = await entrar("petcare@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const publicas = () => api("GET", `/api/refugios/${r.sesion.refugioId}/preguntas`, { token: ana.token });

  const demo = (await publicas()).datos.preguntas;
  assert.equal(demo.length, 6);
  assert.ok(demo[0].claves.length > 0, "las palabras clave llegan como lista");
  assert.equal((await api("GET", "/api/refugio/preguntas", { token: ana.token })).estado, 403);

  const creada = await api("POST", "/api/refugio/preguntas", { token: r.token, cuerpo: { pregunta: "¿Aceptan adopciones fuera de la ciudad?", respuesta: "Sí, siempre que puedas venir a recoger a la mascota.", claves: ["foraneo", "otra ciudad"] } });
  assert.equal(creada.estado, 201, creada.datos?.error);
  const id = creada.datos.pregunta.id;
  assert.deepEqual(creada.datos.pregunta.claves, ["foraneo", "otra ciudad"]);
  assert.equal((await api("POST", "/api/refugio/preguntas", { token: r.token, cuerpo: { pregunta: "¿?", respuesta: "corta" } })).estado, 400);
  assert.equal((await publicas()).datos.preguntas.length, 7);

  // Desactivada: deja de verse; solo el dueño la edita o borra
  const editada = await api("PUT", `/api/refugio/preguntas/${id}`, { token: r.token, cuerpo: { pregunta: "¿Aceptan adopciones foráneas?", respuesta: "Sí, siempre que puedas venir a recoger a la mascota.", claves: "foraneo, viaje", activa: false } });
  assert.equal(editada.datos.pregunta.activa, false);
  assert.deepEqual(editada.datos.pregunta.claves, ["foraneo", "viaje"]);
  assert.equal((await publicas()).datos.preguntas.length, 6);
  assert.equal((await api("PUT", `/api/refugio/preguntas/${id}`, { token: otro.token, cuerpo: { pregunta: "Pregunta ajena", respuesta: "Respuesta ajena larga" } })).estado, 404);
  assert.equal((await api("DELETE", `/api/refugio/preguntas/${id}`, { token: otro.token })).estado, 404);
  assert.equal((await api("DELETE", `/api/refugio/preguntas/${id}`, { token: r.token })).estado, 200);
  assert.equal((await api("GET", "/api/refugios/999999/preguntas", { token: ana.token })).estado, 404);
});

/* ---------- Solicitudes de adopción ---------- */
test("adopción: el usuario envía datos y documentos; solo el refugio que la recibe la revisa", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const otro = await entrar("petcare@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const disponibles = (await api("GET", `/api/refugios/${r.sesion.refugioId}/mascotas`, { token: ana.token })).datos.mascotas;
  const mascota = disponibles[0];

  const DATOS = {
    mascotaId: mascota.id, nombre: "Ana López", correo: "ana@huellapp.mx", telefono: "55 1234 0000", direccion: "Av. Siempre Viva 742, Col. Centro",
    ocupacion: "Diseñadora", tipoVivienda: "casa", viviendaPropia: "propia", otrasMascotas: "", aceptaTerminos: true,
    motivo: "Tengo patio grande y tiempo para paseos diarios; me encantaría darle un hogar.",
  };
  const DOCS = [
    { tipo: "identificacion", nombre: "ine.pdf", dataUrl: PDF },
    { tipo: "domicilio", nombre: "recibo.pdf", dataUrl: PDF },
    { tipo: "vivienda", nombre: "patio.png", dataUrl: PNG },
  ];
  const enviar = (cuerpo, token = ana.token) => api("POST", "/api/adopciones", { token, cuerpo });

  // Validaciones
  assert.equal((await enviar({ ...DATOS, documentos: DOCS.slice(1) })).estado, 400, "falta la identificación");
  assert.equal((await enviar({ ...DATOS, documentos: DOCS.slice(0, 2) })).estado, 400, "faltan fotos del espacio");
  assert.equal((await enviar({ ...DATOS, documentos: [...DOCS.slice(0, 2), { tipo: "vivienda", nombre: "patio.pdf", dataUrl: PDF }] })).estado, 400, "las fotos deben ser imágenes");
  assert.equal((await enviar({ ...DATOS, aceptaTerminos: false, documentos: DOCS })).estado, 400);
  assert.equal((await enviar({ ...DATOS, motivo: "Porque sí", documentos: DOCS })).estado, 400);
  assert.equal((await enviar({ ...DATOS, documentos: DOCS }, r.token)).estado, 403, "un refugio no adopta");

  // Envío correcto y duplicado
  const enviada = await enviar({ ...DATOS, documentos: DOCS });
  assert.equal(enviada.estado, 201, enviada.datos?.error);
  assert.equal(enviada.datos.solicitud.estado, "pendiente");
  assert.equal(enviada.datos.solicitud.mascotaNombre, mascota.nombre);
  assert.equal("documentos" in enviada.datos.solicitud, false, "el usuario no recibe de vuelta los documentos");
  assert.equal((await enviar({ ...DATOS, documentos: DOCS })).estado, 409, "no se repite mientras está abierta");
  const mias = (await api("GET", "/api/adopciones", { token: ana.token })).datos.solicitudes;
  assert.ok(mias.some((s) => s.id === enviada.datos.solicitud.id));

  // El refugio la recibe con datos y documentos; otro refugio no
  const recibidas = (await api("GET", "/api/refugio/adopciones", { token: r.token })).datos.solicitudes;
  const sol = recibidas.find((s) => s.id === enviada.datos.solicitud.id);
  assert.equal(sol.nombre, "Ana López");
  assert.deepEqual(sol.documentos.map((d) => d.tipo), ["identificacion", "domicilio", "vivienda"]);
  assert.equal((await api("GET", "/api/refugio/adopciones", { token: otro.token })).datos.solicitudes.some((s) => s.id === sol.id), false);
  const archivo = `/api/refugio/adopciones/${sol.id}/documentos/${sol.documentos[2].id}/archivo`;
  const descarga = await api("GET", archivo, { token: r.token });
  assert.equal(descarga.estado, 200);
  assert.equal(descarga.respuesta.headers.get("content-type"), "image/png");
  assert.equal((await api("GET", archivo, { token: otro.token })).estado, 404);

  // Cambiar estado: rechazar exige nota; el usuario ve el resultado
  const ruta = `/api/refugio/adopciones/${sol.id}`;
  assert.equal((await api("PATCH", ruta, { token: r.token, cuerpo: { estado: "rechazada" } })).estado, 400);
  assert.equal((await api("PATCH", ruta, { token: r.token, cuerpo: { estado: "adoptada" } })).estado, 400);
  assert.equal((await api("PATCH", ruta, { token: otro.token, cuerpo: { estado: "aprobada" } })).estado, 404);
  const aprobada = await api("PATCH", ruta, { token: r.token, cuerpo: { estado: "aprobada", nota: "Te llamaremos para agendar la entrega." } });
  assert.equal(aprobada.datos.solicitud.estado, "aprobada");
  const vista = (await api("GET", "/api/adopciones", { token: ana.token })).datos.solicitudes.find((s) => s.id === sol.id);
  assert.equal(vista.estado, "aprobada");
  assert.equal(vista.notaRefugio, "Te llamaremos para agendar la entrega.");

  // Una mascota que no está disponible no recibe solicitudes
  const enProceso = (await api("GET", "/api/refugio/mascotas", { token: r.token })).datos.mascotas.find((m) => m.estatus === "en proceso");
  assert.equal((await enviar({ ...DATOS, mascotaId: enProceso.id, documentos: DOCS })).estado, 409);
});

/* ==========================================================================
 * Sprint 3 y 4 — funciones con IA. Usan la API real de Gemini si hay clave
 * (GEMINI_API_KEY): por eso solo se revisa la FORMA de la respuesta, nunca el
 * texto exacto. Sin clave o sin cuota responden con reglas y también pasan.
 * ========================================================================== */

test("KIRO (HU-7): el visitante no recibe reportes; con sesión sí, sin datos privados", async () => {
  const invitado = await api("POST", "/api/kiro", { cuerpo: { mensaje: "¿Han reportado algún perro perdido?" } });
  assert.equal(invitado.estado, 200, invitado.datos?.error);
  assert.equal(typeof invitado.datos.respuesta, "string");
  assert.deepEqual(invitado.datos.reportes, [], "sin sesión no se comparten reportes");
  assert.equal(/\(id\s*=\s*\d+\)/i.test(invitado.datos.respuesta), false, "no se ven ids internos");

  const { token } = await entrar("ana@huellapp.mx", "usuario");
  const conSesion = await api("POST", "/api/kiro", { token, cuerpo: { mensaje: "¿Han reportado algún perro perdido o encontrado?" } });
  assert.equal(conSesion.estado, 200, conSesion.datos?.error);
  assert.ok(Array.isArray(conSesion.datos.reportes));
  for (const r of conSesion.datos.reportes) {
    assert.ok(["perdida", "encontrada"].includes(r.tipo));
    for (const privado of ["senaSecreta", "sena_secreta", "latitud", "longitud", "usuarioId", "correo", "telefono"]) {
      assert.equal(privado in r, false, `la tarjeta del reporte no trae ${privado}`);
    }
  }
  assert.equal((await api("POST", "/api/kiro", { cuerpo: { mensaje: "" } })).estado, 400);
});

test("resumen con IA de una solicitud (HU-22): solo su refugio; se guarda y se reutiliza", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const otro = await entrar("petcare@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const sol = (await api("GET", "/api/refugio/adopciones", { token: r.token })).datos.solicitudes[0];
  assert.ok(sol, "la prueba de adopción dejó una solicitud");
  const ruta = `/api/refugio/adopciones/${sol.id}/resumen`;

  const primero = await api("POST", ruta, { token: r.token, cuerpo: {} });
  assert.equal(primero.estado, 200, primero.datos?.error);
  const resumen = primero.datos.resumen;
  assert.equal(typeof resumen.sintesis, "string");
  for (const lista of ["aFavor", "atencion", "preguntas"]) assert.ok(Array.isArray(resumen[lista]) && resumen[lista].length <= 4);
  assert.equal(JSON.stringify(resumen).includes("ana@huellapp.mx"), false, "el resumen no repite el correo");
  if (resumen.iaUsada) {
    // El de IA se guarda: la segunda vez llega el mismo (misma fecha) y aparece en la lista
    const segundo = await api("POST", ruta, { token: r.token, cuerpo: {} });
    assert.equal(segundo.datos.resumen.fecha, resumen.fecha);
    const enLista = (await api("GET", "/api/refugio/adopciones", { token: r.token })).datos.solicitudes.find((s) => s.id === sol.id);
    assert.equal(enLista.resumenIa.sintesis, resumen.sintesis);
  }
  assert.equal((await api("POST", ruta, { token: otro.token, cuerpo: {} })).estado, 404, "otro refugio no la ve");
  assert.equal((await api("POST", ruta, { token: ana.token, cuerpo: {} })).estado, 403, "un usuario no pide resúmenes");
});

test("guía de cuidado (HU-23): solo con la adopción aprobada y solo para quien adoptó", async () => {
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const laura = await entrar("laura.mendez@ejemplo.mx", "usuario");
  const mias = (await api("GET", "/api/adopciones", { token: ana.token })).datos.solicitudes;
  const aprobada = mias.find((s) => s.estado === "aprobada");
  assert.ok(aprobada, "la prueba de adopción dejó una aprobada");

  const guia = await api("GET", `/api/adopciones/${aprobada.id}/cuidados`, { token: ana.token });
  assert.equal(guia.estado, 200, guia.datos?.error);
  assert.ok(["cachorro", "adulto", "senior"].includes(guia.datos.guia.etapa));
  assert.equal(guia.datos.guia.secciones.length, 5);
  for (const s of guia.datos.guia.secciones) assert.ok(s.titulo && s.puntos.length > 0);

  const consejos = await api("POST", `/api/adopciones/${aprobada.id}/cuidados`, { token: ana.token, cuerpo: {} });
  assert.equal(consejos.estado, 200);
  assert.ok(consejos.datos.consejos === null || (Array.isArray(consejos.datos.consejos) && consejos.datos.consejos.length <= 5));

  assert.equal((await api("GET", `/api/adopciones/${aprobada.id}/cuidados`, { token: laura.token })).estado, 404, "no es suya");
  const abierta = mias.find((s) => s.estado !== "aprobada");
  if (abierta) assert.equal((await api("GET", `/api/adopciones/${abierta.id}/cuidados`, { token: ana.token })).estado, 409);
});

test("borrador de descripción con IA (HU-17): para refugios, sin guardar nada", async () => {
  const r = await entrar("refugio@huellapp.mx", "refugio");
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const antes = (await api("GET", "/api/refugio/mascotas", { token: r.token })).datos.mascotas.length;

  const ok = await api("POST", "/api/refugio/mascotas/borrador", {
    token: r.token,
    cuerpo: { nombre: "Chispa", especie: "perro", tamano: "mediano", notas: "muy juguetona, se lleva bien con niños", foto: PNG },
  });
  assert.equal(ok.estado, 200, ok.datos?.error);
  assert.ok(ok.datos.descripcion.length >= 10 && ok.datos.descripcion.length <= 400);
  assert.equal(typeof ok.datos.iaUsada, "boolean");
  assert.equal((await api("GET", "/api/refugio/mascotas", { token: r.token })).datos.mascotas.length, antes, "no se creó ninguna mascota");

  assert.equal((await api("POST", "/api/refugio/mascotas/borrador", { token: r.token, cuerpo: { nombre: "X" } })).estado, 400);
  assert.equal((await api("POST", "/api/refugio/mascotas/borrador", { token: ana.token, cuerpo: { especie: "perro" } })).estado, 403);
});

test("moderación (HU-18): lo marcado se oculta a los demás; el admin aprueba o quita", async () => {
  const ana = await entrar("ana@huellapp.mx", "usuario");
  const laura = await entrar("laura.mendez@ejemplo.mx", "usuario");
  const admin = await entrar("admin@huellapp.mx", "admin");

  // La lista de palabras marca al instante (sin esperar a la IA)
  const venta = await api("POST", "/api/foro", { token: ana.token, cuerpo: { texto: "Vendo cachorros husky $2500, informes por inbox" } });
  assert.equal(venta.estado, 201, venta.datos?.error);
  const id = venta.datos.publicacion.id;
  assert.equal(venta.datos.publicacion.enRevision, true);
  const ve = async (token) => (await api("GET", "/api/foro?categoria=comunidad", { token })).datos.publicaciones.some((p) => p.id === id);
  assert.equal(await ve(ana.token), true, "su autora la ve");
  assert.equal(await ve(laura.token), false, "los demás no");
  assert.equal(await ve(undefined), false, "el visitante tampoco");

  // Un comentario ofensivo también queda en revisión
  const publica = (await api("GET", "/api/foro?categoria=comunidad", { token: laura.token })).datos.publicaciones[0];
  const comentario = await api("POST", `/api/foro/${publica.id}/comentarios`, { token: laura.token, cuerpo: { texto: "qué estúpida idea" } });
  assert.equal(comentario.estado, 201);
  assert.equal(comentario.datos.comentarios.at(-1).enRevision, true);

  // Bandeja del administrador
  assert.equal((await api("GET", "/api/admin/moderacion", { token: ana.token })).estado, 403);
  const bandeja = (await api("GET", "/api/admin/moderacion", { token: admin.token })).datos.elementos;
  assert.ok(bandeja.some((e) => e.tipo === "publicacion" && e.id === id && e.fuente === "palabras"));
  assert.ok(bandeja.some((e) => e.tipo === "comentario"));
  assert.ok((await api("GET", "/api/admin/resumen", { token: admin.token })).datos.moderacion >= 2);

  assert.equal((await api("POST", `/api/admin/moderacion/publicacion/${id}`, { token: admin.token, cuerpo: { accion: "aprobar" } })).estado, 200);
  assert.equal(await ve(laura.token), true, "aprobada: ya la ven todos");
  assert.equal((await api("POST", `/api/admin/moderacion/publicacion/${id}`, { token: admin.token, cuerpo: { accion: "quitar" } })).estado, 200);
  assert.equal(await ve(ana.token), false, "quitada: ni su autora la ve");
  assert.equal((await api("POST", `/api/admin/moderacion/publicacion/${id}`, { token: admin.token, cuerpo: { accion: "borrar" } })).estado, 400);

  // Un texto normal no se marca
  const normal = await api("POST", "/api/foro", { token: ana.token, cuerpo: { texto: "¿A qué edad conviene esterilizar a una perrita?" } });
  assert.equal(normal.datos.publicacion.enRevision, false);
});
