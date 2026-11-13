# Pruebas manuales de HuellApp (HU-26)

Recorridos completos por rol para revisar **antes de la entrega del 20 de noviembre**. Repártanse los bloques,
marquen cada casilla y anoten en «Resultado» lo que falle (con captura si se puede).

- **Dónde:** de preferencia en el servidor publicado (HU-25). Si aún no está, en local: web en http://127.0.0.1:3000 y
  app en http://localhost:8090 (`flutter run -d web-server --web-port 8090`) o en un celular Android.
- **Datos:** usen datos **inventados pero realistas** (nombres, colonias de CDMX, teléfonos 55 xxxx xxxx). No usen datos reales.
- **Cuentas demo** (contraseña `Demo1234`): `ana@huellapp.mx` (usuario), `refugio@huellapp.mx` (refugio),
  `admin@huellapp.mx` (administrador). El refugio y el admin piden verificación en dos pasos.
- **Pruebas automáticas de la API:** `php artisan test` en `api/` (necesita `DB_TEST_USER` en el `.env`; ver `api/README.md`).

| Quién | Web | App | Fecha | Resultado / notas |
| --- | :-: | :-: | --- | --- |
| | ☐ | ☐ | | |

---

## 1. Visitante (sin cuenta)

- [ ] Entrar como visitante: solo puede ver **Refugios** y sus mascotas en adopción.
- [ ] Las demás secciones aparecen con candado y, al tocarlas, piden iniciar sesión o registrarse.
- [ ] La burbuja de **KIRO** responde dudas de adopción; si pregunta por mascotas perdidas, le pide iniciar sesión.

## 2. Usuario (`ana@huellapp.mx` o una cuenta nueva)

**Cuenta**
- [ ] Registrarse con datos inventados; un correo repetido marca error.
- [ ] Iniciar sesión; contraseña incorrecta varias veces → pide captcha o bloquea un rato.
- [ ] Menú de cuenta (la inicial arriba a la derecha): Mis solicitudes, Seguridad y Cerrar sesión.

**Reportar y coincidencias**
- [ ] «Se me perdió» con foto, zona en el mapa, color, tamaño y seña secreta → aparece en el foro (pestaña «Se buscan»).
- [ ] «La encontré» con una foto parecida desde otra cuenta → al rato llega una coincidencia (campana y número rojo).
- [ ] En Coincidencias: responder la seña secreta, ver contacto, declinar y restaurar.
- [ ] «¡Ya apareció!» mueve la alerta a «Reunidos».

**Foro**
- [ ] Publicar con y sin foto, comentar y dar «me gusta».
- [ ] **Moderación (HU-18):** publicar «Vendo cachorros $2500» → se ve con el aviso «🕒 En revisión»; desde otra cuenta **no** se ve.
- [ ] Comentar con una grosería → queda «En revisión» y no le llega aviso al autor de la publicación.

**Adopción**
- [ ] Refugios: mapa, «Cerca de mí», perfil del refugio, requisitos y preguntas frecuentes.
- [ ] Favoritos: guardar 2 o 3 mascotas y compararlas.
- [ ] Solicitar adopción con identificación, comprobante y fotos del espacio; el asistente del formulario contesta dudas.
- [ ] Mis solicitudes: ver el estado y la nota del refugio.
- [ ] **Guía de cuidado (HU-23):** con la solicitud aprobada aparece «Ver guía de cuidado»: guía por especie/edad y consejos con IA.
- [ ] Mensajes: escribirle a un refugio.

**KIRO (HU-7)**
- [ ] «Vivo en un departamento pequeño, ¿qué perrito me recomiendas?» → recomienda mascotas reales con tarjeta.
- [ ] «¿Han reportado un perro café perdido en Del Valle?» → muestra reportes con tarjeta que abre el muro.
- [ ] Una pregunta ajena (fútbol) → regresa al tema con amabilidad. La respuesta no trae «(id=…)» ni asteriscos.
- [ ] La conversación sigue al cambiar de página (web).

## 3. Refugio (`refugio@huellapp.mx`)

- [ ] Primera vez: configurar la verificación en dos pasos con Google Authenticator; después pide el código.
- [ ] Código incorrecto → lo rechaza. (Para volver a empezar: `php artisan 2fa:reiniciar refugio@huellapp.mx`.)
- [ ] Panel: resumen de mascotas, publicaciones y mensajes.
- [ ] Inventario: agregar, editar, cambiar estatus y eliminar una mascota; subir documentos (vacunas).
- [ ] **Borrador con IA (HU-17):** escribir unas notas, tocar «✨ Sugerir con IA», revisar el texto y guardar.
- [ ] Publicaciones: publicar una mascota y programar la republicación.
- [ ] Adopciones: revisar una solicitud, ver documentos, aprobar / rechazar (exige nota) / en revisión.
- [ ] **Resumen con IA (HU-22):** «Generar resumen» muestra a favor, para revisar y preguntas; la segunda vez abre al instante.
- [ ] Requisitos y preguntas frecuentes: crear, editar y desactivar.
- [ ] Mensajes: responder.
- [ ] Un refugio **pendiente** o **rechazado** no entra al panel (ve su estado y puede corregir).

## 4. Administrador (`admin@huellapp.mx`)

- [ ] Verificación en dos pasos.
- [ ] Solicitudes de refugios: ver documentos, marcar con error, aprobar, rechazar con motivo, suspender y reactivar.
- [ ] Estadísticas (HU-20): cifras y gráficas.
- [ ] **Moderación (HU-18):** aparece lo marcado en las pruebas del usuario; «Aprobar» lo vuelve visible, «Quitar» lo oculta y avisa al autor; pestaña «Quitados» → «Restaurar».

## 5. Generales

- [ ] Campana de avisos: llegan avisos de coincidencias, respuestas del refugio y cambios de estado.
- [ ] Web en celular (375 px), tablet (768 px) y laptop (1280 px): la barra no se encima, la burbuja de KIRO no tapa botones.
- [ ] Sin internet / API apagada: la web y la app muestran un mensaje claro (no se quedan en blanco).
- [ ] Ninguna pantalla muestra datos de otra persona (contacto, seña secreta, documentos) a quien no le toca.
