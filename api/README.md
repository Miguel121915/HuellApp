# HuellApp — API (PHP + Oracle)

Servidor en **PHP puro** que guarda todo en **Oracle** (Autonomous Database en el OCI de la escuela). Lo usan el sitio web y la app Flutter: los dos leen y escriben los **mismos datos**.

```
App móvil (Flutter) ──┐
                      ├──►  Servidor PHP (php artisan serve)  ──►  Oracle en OCI: esquema HUELLAPP_DEV
Sitio web ────────────┘                                       └──►  storage/uploads/       (fotos y documentos)
```

> **Sobre `artisan`:** el archivo `artisan` de esta carpeta es un script propio y sencillo con comandos parecidos a los de Laravel (`serve`, `migrate`, `db:seed`). **No es Laravel** (no hay Composer ni dependencias que instalar). Si algún día migran a Laravel, la API y la estructura de las tablas se pueden trasladar casi tal cual.
>
> **Node.js no es necesario** para usar el sitio ni el servidor. Solo lo usa `php artisan test` (las pruebas automáticas).

## 1. Requisitos

- **XAMPP** (solo su PHP **8.1 o superior**; el MySQL de XAMPP ya no se usa).
- **Oracle Instant Client**, el **wallet** de la base y las extensiones `oci8` y `pdo_oci` activas: sigue la *Guía de Oracle Cloud (OCI)* del equipo. Compruébalo con `php -m | findstr /i oci`.
- Nada más: sin Composer, sin `npm install`.

## 2. Primera vez, paso a paso (Windows)

1. Copia `.env.example` como `.env` en esta carpeta y llena `DB_TNS`, `DB_USER` y `DB_PASS` con los datos de Oracle que te pasó el equipo.
2. **Que la terminal reconozca `php`** (solo una vez). Comprueba con `php -v`. Si dice que no se reconoce:
   - Busca "Variables de entorno" en Windows → *Variables de entorno…* → en *Path* (usuario) → *Nuevo* → escribe `C:\xampp\php` → Aceptar.
   - **Cierra y vuelve a abrir** VS Code o la terminal. (Alternativa sin tocar nada: escribir la ruta completa, `C:\xampp\php\php.exe artisan serve`).
3. Abre una terminal **en esta carpeta (`api/`)** y ejecuta:

```bash
php artisan serve
```

La primera vez crea las tablas en tu esquema de Oracle y carga los datos de demostración.

4. Abre **http://localhost:3000** (el servidor también muestra el sitio web de la carpeta `../sitio-web`).
5. Para ver los datos: en la consola de OCI → tu Autonomous Database → **Database actions** → **SQL**, entrando con tu usuario (por ejemplo `HUELLAPP_DEV`).

**Cuentas demo** (contraseña de todas: `Demo1234`): `ana@huellapp.mx` (usuario), `refugio@huellapp.mx` (refugio verificado), `pendiente@huellapp.mx`, `rechazado@huellapp.mx` y `admin@huellapp.mx`.

> Deja la terminal abierta mientras uses el sitio; se apaga con `Ctrl + C`. Si el sitio muestra una franja roja "No hay conexión con el servidor", falta ejecutar `php artisan serve`.

### ¿Y si uso Live Server para el sitio?
También funciona: el servidor acepta peticiones desde `localhost` y `127.0.0.1` con cualquier puerto. Mantén `php artisan serve` encendido en el puerto 3000 (si usas otro, cambia `PUERTO_API` en `web/assets/js/core/config.js`).

## 3. Comandos

| Comando | Qué hace |
|---|---|
| `php artisan serve` | Enciende el servidor (`--port=3001` para otro puerto). Si falta la base o las tablas, las crea |
| `php artisan migrate` | Crea la base de datos y las tablas que falten (es seguro repetirlo). Con `--seed` carga la demostración |
| `php artisan migrate:fresh --seed` | **Borra todo** y recrea las tablas con los datos de demostración (pide confirmación; `--si` la omite) |
| `php artisan db:seed` | Carga la demostración en una base vacía (`--force` para cargarla aunque ya haya datos) |
| `php artisan refugios` | Lista los refugios y su estado |
| `php artisan refugios aprobar correo@refugio.com` | Aprueba una solicitud (también: `suspender`, `reactivar`) |
| `php artisan refugios rechazar correo@refugio.com "Motivo"` | Rechaza una solicitud (el motivo es obligatorio) |
| `php artisan publicaciones:republicar` | Republica ya las publicaciones a las que les toca (opcional: el servidor lo hace solo al mostrarlas) |
| `php artisan test` | Pruebas automáticas (usan un esquema aparte, `DB_TEST_USER`, que se borra en cada corrida; necesitan Node.js) |

Lo normal es revisar los refugios desde las pantallas del administrador del sitio; `refugios` es una alternativa desde la terminal (también puedes editar `refugios.estado` desde Database actions → SQL).

## 4. Tablas

| Tabla | Para qué sirve |
|---|---|
| `usuarios` | Cuentas de los tres roles. `password_hash` guarda la contraseña **cifrada**: no se puede leer ni editar a mano (para entrar con otra contraseña, regístrate desde el sitio) |
| `refugios` | Datos del refugio, ligado a la cuenta de su responsable. `estado`: pendiente · aprobado · rechazado · suspendido. `apelaciones`, `motivo_anterior` y `apelado_en`: cuántas veces reenvió la solicitud tras un rechazo, con qué motivo lo habían rechazado y cuándo |
| `documentos_refugio` | Acta, comprobante de domicilio, identificación, permiso. `verificado` es la casilla del checklist del administrador; `con_error`, el documento que el administrador señaló al rechazar (el refugio debe reemplazarlo para apelar) |
| `mascotas` | Inventario de cada refugio (`estatus`: disponible · en proceso · adoptado) |
| `documentos_mascota` | Documentos especiales de cada mascota (vacunación, esterilización, desparasitación, pedigree, expediente médico, otro). Los sube el refugio; `verificado` es la casilla de revisión del administrador. Archivos privados en `storage/uploads/documentos` |
| `publicaciones_refugio` | Publicaciones del refugio; si se borra la mascota, se borran solas (`ON DELETE CASCADE`). `republicar_cada_dias` (vacío = no se republica), `publicado_en` (fecha que ven los usuarios y que ordena la lista) y `republicada_veces` |
| `publicaciones_foro`, `comentarios_foro`, `likes_foro` | El foro y los "me gusta" (un usuario, un like por publicación) |
| `reportes` | Reportes de mascotas perdidas o encontradas |
| `coincidencias`, `coincidencias_descartadas` | Parejas (pérdida, hallazgo) con porcentaje de similitud, y las que el usuario declinó |
| `intentos_login` | Intentos fallidos de inicio de sesión (para bloquear a quien adivine contraseñas) |
| `preguntas_refugio` | Preguntas frecuentes de cada refugio con su respuesta y palabras clave (`claves`, separadas por comas). Las usa el asistente KIRO del formulario de adopción; `activa = 0` las oculta |
| `solicitudes_adopcion`, `documentos_adopcion` | Solicitudes de adopción (datos del solicitante y de su hogar; `estado`: pendiente · en revision · aprobada · rechazada, con `nota_refugio`) y sus documentos privados (identificación, comprobante de domicilio, fotos del espacio, otro) |

Puedes editar casi todo directamente desde Database actions → SQL (mascotas, estados de refugios, textos); recuerda que en Oracle hay que hacer `COMMIT` después de un `UPDATE` hecho a mano. El esquema completo, comentado, está en `database/esquema.sql`.

## 5. Configuración de Oracle

Todo se configura en `.env` (copia de `.env.example`): `DB_TNS` (servicio del `tnsnames.ora` del wallet, por ejemplo `huellapp_tp`), `DB_USER`, `DB_PASS` y, si no creaste la variable de entorno de Windows, `TNS_ADMIN` con la carpeta del wallet. Ese archivo **nunca** se sube al repositorio.

### Inicio de sesión con Google y verificación en dos pasos

**Verificación en dos pasos (Google Authenticator).** No necesita configuración. Cada cuenta la activa si quiere: en el sitio, botón **🔒 Seguridad** del encabezado; en la app, **Seguridad** en el menú de la cuenta. Se escanea el QR con Google Authenticator y se confirma con un código. Desde entonces, después de la contraseña (o de Google) se pide el código de 6 dígitos. El secreto se guarda cifrado con una clave que sale de `JWT_SECRET`: **si cambias `JWT_SECRET`, las cuentas con dos pasos tendrán que volver a activarla** (un administrador la quita con `UPDATE usuarios SET totp_activo = 0, totp_secreto = NULL WHERE correo = '...'`).

**«Continuar con Google».** El botón solo aparece si `GOOGLE_CLIENT_ID` está en el `.env`. Para obtenerlo (una sola vez, la cuenta de Google del equipo):

1. Entra a <https://console.cloud.google.com/>, crea un proyecto «HuellApp» y en **APIs y servicios → Pantalla de consentimiento de OAuth** elige *Externo*, llena el nombre y el correo de soporte y agrega como *usuarios de prueba* los correos del equipo.
2. **Credenciales → Crear credenciales → ID de cliente de OAuth → Aplicación web.** En *Orígenes de JavaScript autorizados* agrega `http://localhost:3000`, `http://127.0.0.1:3000`, `http://localhost:8080` y `http://127.0.0.1:8080` (sitio web y app de la demo). Copia el ID.
3. En `api/.env`: `GOOGLE_CLIENT_ID=<ese id>.apps.googleusercontent.com` y reinicia `php artisan serve`.
4. (Solo para el APK de Android) Crea otro ID de cliente tipo **Android** con el paquete `com.example.huellapp` y la huella SHA-1 de tu llave (`cd android` y `gradlew signingReport`). No hace falta copiarlo a ningún lado: la app usa el ID **web** que le da la API.

### IA de Gemini en los reportes (HU-5 y HU-8)

Antes la pantalla Reportar de la app usaba el servidor Node de `backend/` con MySQL. Ahora **todo pasa por esta API** con Oracle: el servidor Node ya no hace falta.

Al crear un reporte (`POST /reportes`, desde la app o el sitio):

1. Gemini mira la foto y detecta especie, raza, color, tamaño y señas (se guarda en `reportes.analisis_ia`).
2. Se buscan coincidencias entre los reportes contrarios de otras personas: primero por texto y zona (`Similitud.php`, con los rasgos de la IA) y, a los 5 más parecidos, **Gemini les compara las fotos**. El porcentaje final es 75 % foto y 25 % texto; se guardan las que pasan de 40 %. `coincidencias.por_ia = 1` indica que se compararon fotos.
3. La alerta se publica en el foro («🔎 SE BUSCA…» / «🐾 ENCONTRÉ…»): aparece en el muro de la app y en el foro del sitio.

Configuración: `GEMINI_API_KEY` en `api/.env` (clave en <https://aistudio.google.com/apikey>). **Sin clave todo sigue funcionando**: no se analiza la foto y las coincidencias se calculan solo por texto y zona. Si Gemini falla o tarda, igual se guarda el reporte. Un reporte con IA tarda de 5 a 20 segundos.

## 6. Quién puede hacer qué (seguridad)

Los permisos se validan **en el servidor** (las guardias de ruta del sitio solo mejoran la experiencia):

- Sin sesión válida (token) → `401`. Rol equivocado → `403`.
- Un refugio **solo ve y modifica sus propios datos**: su id sale de la sesión, nunca de lo que envía el navegador.
- Un refugio no aprobado (pendiente, rechazado, suspendido) no puede usar su panel → `403` con `codigo: "refugio-no-aprobado"`.
- Los usuarios solo ven refugios **aprobados** y mascotas **disponibles**; correo y documentos nunca son públicos.
- Los documentos de los refugios **no están en una carpeta pública**: solo un administrador con sesión puede descargarlos. Los de cada mascota, igual: solo el refugio dueño y el administrador. Los de una solicitud de adopción solo los ve el refugio que la recibe.
- Consultas preparadas (sin inyección SQL), contraseñas con `password_hash`, mensaje de error idéntico exista o no el correo y bloqueo tras 8 intentos fallidos en 10 minutos.
- Todo lo que llega se vuelve a validar (longitudes, valores permitidos); las imágenes y PDF se comprueban por su contenido real, no solo por la extensión.

## 7. Endpoints (para conectar Flutter u otros clientes)

Todas las rutas empiezan con `/api` y responden JSON; los errores son `{ "error": "mensaje" }`. Después de iniciar sesión, envía `Authorization: Bearer <token>` en cada petición.

| Método y ruta | Rol | Descripción |
|---|---|---|
| `POST /auth/login` | — | `{correo, password, rol}` → `{token, sesion}`, o `{requiere2fa: true, desafio}` si la cuenta tiene verificación en dos pasos |
| `GET /auth/config` | — | `{googleClientId}` (vacío = no hay botón de Google) |
| `POST /auth/google` | — | «Continuar con Google»: `{idToken, rol}` → igual que `/auth/login`. Si no existe la cuenta se crea una de **usuario** (los refugios se registran con su formulario y luego pueden entrar con Google) |
| `POST /auth/2fa/verificar` | — | Segundo paso: `{desafio, codigo}` → `{token, sesion}`. El desafío dura 5 minutos (`401` con `codigo: "desafio-vencido"`); código incorrecto → `400`; 5 fallos en 10 minutos → `429` |
| `GET /auth/2fa` · `POST /auth/2fa/preparar` | todos | ¿Está activa? `{activo}` / secreto nuevo `{secreto, enlace}` (`enlace` = `otpauth://…` para el QR) |
| `POST /auth/2fa/activar` · `POST /auth/2fa/desactivar` | todos | `{codigo}` de Google Authenticator para confirmar |
| `POST /auth/registro-usuario` | — | Alta de usuario |
| `POST /auth/registro-refugio` | — | Alta de refugio con `documentos: [{tipo, nombre, dataUrl}]`. Opcionales (app móvil): `latitud`, `longitud`, `municipio`, `codigoPostal`, `rfc`, `tipoOrganizacion`, `anioFundacion`, `whatsapp`, `redes[]`, `necesidades[]`, `tienePerros`, `tieneGatos` (también en `PUT /refugio/perfil`) |
| `GET /auth/yo` | todos | Sesión actualizada (y estado del refugio) |
| `GET /auth/apelacion` · `POST /auth/apelacion` | refugio **rechazado** | Datos y documentos actuales (con `conError`) / reenviar `{nombreRefugio, responsable, telefono, direccion, horario, documentos}`: `documentos` trae solo los archivos nuevos y cada uno reemplaza al de su tipo; los señalados con error deben reemplazarse. La solicitud vuelve a `pendiente`. Si no está rechazada → `409` con `codigo: "no-rechazado"` |
| `GET /foro` · `POST /foro` | usuario | Listar / publicar `{texto, foto?}` |
| `POST /foro/:id/comentarios` · `PUT /foro/:id/like` | usuario | Comentar / `{activo: true\|false}` |
| `GET /foro` | todos, **también sin sesión** (visitante) | Publicaciones del foro (publicar, comentar y like sí piden cuenta) |
| `GET /refugios` · `GET /refugios/:id` | todos, **también sin sesión** (visitante) | Refugios aprobados, con ubicación y datos de contacto. `GET /refugios?mascotas=1` trae cada refugio con sus mascotas disponibles en una sola petición (lo usan Inicio y el catálogo) |
| `GET /refugios/:id/mascotas` · `/publicaciones` · `/preguntas` | todos (mascotas y publicaciones también sin sesión) | Mascotas disponibles / publicaciones / preguntas frecuentes activas. Mascotas acepta filtros opcionales `?q=` (nombre o raza) `&especie=` (perro o gato) `&tamano=` (pequeño, mediano o grande) `&edad=` (cachorro, joven, adulto o senior); `GET /refugios?mascotas=1` acepta los mismos |
| `GET /adopciones` · `POST /adopciones` | usuario | Mis solicitudes de adopción / enviar una `{mascotaId, nombre, correo, telefono, direccion, ocupacion?, tipoVivienda, viviendaPropia, otrasMascotas?, motivo, aceptaTerminos, documentos}`: identificación y comprobante (uno de cada uno), de 1 a 3 fotos `vivienda` (solo imágenes) y un `otro` opcional. Solo mascotas disponibles; una solicitud abierta por mascota |
| `GET·POST /refugio/preguntas` · `PUT·DELETE /refugio/preguntas/:id` | refugio aprobado | Preguntas frecuentes `{pregunta, respuesta, claves[], activa}` (máx. 50) |
| `GET /refugio/adopciones` · `PATCH /refugio/adopciones/:id` · `GET …/:id/documentos/:doc/archivo` | refugio aprobado | Solicitudes recibidas / responder `{estado, nota}` (rechazar exige nota) / ver un documento |
| `POST /reportes` | usuario | `{tipo, descripcion, zona, foto, especie?, nombre?}` → `{reporte, coincidenciasNuevas, iaUsada, analisisIA}`. Analiza la foto con IA, calcula coincidencias y publica la alerta en el foro |
| `GET /coincidencias` · `/coincidencias/resumen` | usuario | Mis coincidencias / contadores. Las ven **las dos personas**: `lado` es `"perdida"` (yo la perdí) o `"encontrada"` (yo la encontré); `miReporte` es el propio y `otroReporte` el de la otra persona con su `contacto {nombre, telefono, correo}` (`telefono` es `""` si no lo dio). `hallazgo` se conserva por compatibilidad (siempre el reporte de la mascota encontrada) |
| `POST /coincidencias/:id/descartar` · `/coincidencias/restaurar` | usuario | Declinar / restaurar (cada persona descarta por su lado) |
| `POST /enlaces` | con sesión | `{ruta}` de un documento propio (`/refugio/adopciones/:id/documentos/:doc/archivo` o `/refugio/mascotas/:id/documentos/:doc/archivo`) → `{url}` firmada, válida 5 minutos, para abrirlo fuera de la app (navegador o visor de PDF). Al abrirla se revisan los mismos permisos |
| `GET /favoritos` · `POST /favoritos` · `DELETE /favoritos/:mascotaId` | usuario | HU-12: mis favoritos (mascota + `refugioNombre`, `refugioMunicipio`, `guardado`) / guardar `{mascotaId}` (repetir no falla; máx. 50) / quitar |
| `GET /mensajes` · `POST /mensajes` | usuario | HU-13: mis mensajes con la respuesta del refugio / escribir `{mascotaId?, refugioId?, mensaje, telefono?}` (con `mascotaId` el refugio sale de la mascota; máx. 10 por hora) |
| `GET /refugio/mensajes` · `PATCH /refugio/mensajes/:id` | refugio aprobado | HU-13: mensajes recibidos (nuevos primero) / `{}` = marcar leído, `{respuesta}` = responder |
| `GET /refugios/:id/requisitos` | todos, **también sin sesión** | HU-16: requisitos de adopción del refugio (obligatorios primero) |
| `GET·POST /refugio/requisitos` · `PUT·DELETE /refugio/requisitos/:id` | refugio aprobado | HU-16: requisitos `{texto, detalle?, obligatorio}` (máx. 20) |
| `GET /refugio/yo` · `PUT /refugio/perfil` · `GET /refugio/resumen` | refugio aprobado | Perfil y panel |
| `GET·POST /refugio/mascotas` · `PUT·DELETE /refugio/mascotas/:id` · `PATCH …/estatus` | refugio aprobado | Inventario (CRUD) |
| `GET·POST /refugio/mascotas/:id/documentos` · `GET …/documentos/:doc/archivo` · `DELETE …/documentos/:doc` | refugio aprobado | Documentos de la mascota `{tipo, nombre, dataUrl}` (PDF/JPG/PNG, máx. 5 MB, 10 por mascota) |
| `GET·POST /refugio/publicaciones` · `PUT·DELETE /refugio/publicaciones/:id` | refugio aprobado | Publicaciones `{mascotaId, texto, foto?, republicarCadaDias?}` (1–90 días o `null`); al editar, la mascota no cambia |
| `GET /admin/resumen` · `GET /admin/refugios?estado=` · `GET /admin/refugios/:id` | admin | Solicitudes y refugios |
| `POST /admin/refugios/:id/aprobar` · `/rechazar {motivo, documentosConError?}` · `/suspender` · `/reactivar` | admin | Cambiar el estado (rechazar exige motivo; `documentosConError` son los ids de los documentos que el refugio deberá reemplazar al apelar) |
| `PATCH /admin/documentos/:id` · `GET /admin/documentos/:id/archivo` | admin | Checklist / ver el documento |
| `GET /admin/refugios/:id/mascotas` · `GET /admin/mascotas/:id` | admin | Todas las mascotas de un refugio (con conteo de documentos) / una mascota con sus documentos |
| `PATCH /admin/documentos-mascota/:id` · `GET /admin/documentos-mascota/:id/archivo` | admin | Marcar como revisado / ver un documento de mascota |

**Republicación automática:** no necesita tarea programada. Antes de listar publicaciones, el servidor pone con fecha de ahora las que tienen periodicidad y ya cumplieron el plazo (si pasaron varios periodos sin visitas, cuenta como una sola republicación). Las de mascotas adoptadas no se republican.

**Fotos:** se envían como *data URL* (`data:image/jpeg;base64,...`) dentro del JSON, máximo 3 MB; el servidor las guarda y devuelve rutas como `/uploads/imagenes/<id>.jpg`.

**Desde Flutter:** usa el paquete `http` o `dio` contra `http://10.0.2.2:3000/api` en el emulador de Android, `http://localhost:3000/api` en el simulador de iOS, o `http://<IP-de-tu-PC>:3000/api` en un teléfono real conectado a la misma red Wi-Fi (arranca con `php artisan serve --host=0.0.0.0` y permite el puerto en el firewall de Windows).

## 8. Problemas comunes

| Mensaje | Qué hacer |
|---|---|
| `php no se reconoce como un comando` | Agrega `C:\xampp\php` al Path (paso 2) y reabre la terminal, o usa `C:\xampp\php\php.exe artisan serve` |
| `No se pudo conectar con Oracle en OCI` | Revisa tu internet y que la base esté *Available* en la consola de OCI (si estuvo 7 días sin uso, presiona **Start**) |
| `Oracle rechazó el usuario o la contraseña` | Revisa `DB_USER` y `DB_PASS` en `.env` (sección 5) |
| `Oracle no encontró el servicio` | Revisa `DB_TNS` y que `TNS_ADMIN` apunte a la carpeta del wallet |
| `Falta la extension pdo_oci` | En `C:\xampp\php\php.ini` agrega `extension=pdo_oci` y `extension=oci8_19` (sin comentarios a la derecha) |
| `Failed to listen … Address already in use` | El puerto 3000 está ocupado: `php artisan serve --port=3001` y cambia `PUERTO_API` en `config.js` |
| Franja roja "No hay conexión con el servidor" en el sitio | El servidor está apagado: ejecuta `php artisan serve` |

## 9. Notas y límites

- **Velocidad con Oracle en la nube:** la API reutiliza la conexión entre peticiones (`DB_PERSISTENTE=1`, el valor por defecto) y manda los ajustes de sesión en un solo viaje. Cada respuesta trae la cabecera `Server-Timing: api;dur=…` con los milisegundos que tardó la API (en el navegador: herramientas → Red → Tiempos; o `curl -i`). Si alguna vez la conexión persistente diera problemas, pon `DB_PERSISTENTE=0` en el `.env`.

- **Coincidencias:** la similitud se calcula comparando las palabras de las descripciones y la zona (`src/Similitud.php`). **No reconoce imágenes**; es una simulación para que la pantalla funcione.
- `php artisan serve` usa el servidor integrado de PHP: está pensado para **desarrollo local** y atiende una petición a la vez (suficiente para probar, no para publicar).
- Al borrar una mascota o publicación, su archivo de foto queda en `storage/uploads/imagenes`; `migrate:fresh` limpia todo.
- Antes de publicar en internet: define `JWT_SECRET` en `.env`, usa HTTPS y un servidor web de verdad (Apache o Nginx; `public/.htaccess` ya está preparado), y usa el esquema `HUELLAPP_DEMO` (o uno de producción), nunca `ADMIN`.
