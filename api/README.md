# HuellApp — Servidor local (PHP + MySQL)

Servidor en **PHP puro** que guarda todo en **MySQL** (la base de datos de XAMPP, la que ves en **phpMyAdmin**). Lo usan el sitio web y, más adelante, la app Flutter: los dos leen y escriben los **mismos datos**.

```
App móvil (Flutter) ──┐
                      ├──►  Servidor PHP (php artisan serve)  ──►  MySQL: base "huellapp"  (phpMyAdmin)
Sitio web ────────────┘                                       └──►  storage/uploads/       (fotos y documentos)
```

> **Sobre `artisan`:** el archivo `artisan` de esta carpeta es un script propio y sencillo con comandos parecidos a los de Laravel (`serve`, `migrate`, `db:seed`). **No es Laravel** (no hay Composer ni dependencias que instalar). Si algún día migran a Laravel, la API y la estructura de las tablas se pueden trasladar casi tal cual.
>
> **Node.js no es necesario** para usar el sitio ni el servidor. Solo lo usa `php artisan test` (las pruebas automáticas).

## 1. Requisitos

- **XAMPP** con PHP **8.1 o superior** y MySQL (las versiones actuales de XAMPP ya lo cumplen).
- Nada más: sin Composer, sin `npm install`.

## 2. Primera vez, paso a paso (Windows)

1. Abre el **Panel de control de XAMPP** y presiona **Start** en **MySQL**. (Apache solo hace falta si quieres abrir phpMyAdmin, que también lo necesita.)
2. **Que la terminal reconozca `php`** (solo una vez). Comprueba con `php -v`. Si dice que no se reconoce:
   - Busca "Variables de entorno" en Windows → *Variables de entorno…* → en *Path* (usuario) → *Nuevo* → escribe `C:\xampp\php` → Aceptar.
   - **Cierra y vuelve a abrir** VS Code o la terminal. (Alternativa sin tocar nada: escribir la ruta completa, `C:\xampp\php\php.exe artisan serve`).
3. Abre una terminal **en esta carpeta (`api/`)** y ejecuta:

```bash
php artisan serve
```

La primera vez crea solo la base de datos `huellapp`, las tablas y los datos de demostración.

4. Abre **http://localhost:3000** (el servidor también muestra el sitio web de la carpeta `../sitio-web`).
5. Para ver los datos: **http://localhost/phpmyadmin** → base de datos **huellapp**.

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
| `php artisan test` | Pruebas automáticas (usan una base aparte, `huellapp_test`; necesitan Node.js) |

Lo normal es revisar los refugios desde las pantallas del administrador del sitio; `refugios` es una alternativa desde la terminal (también puedes editar `refugios.estado` en phpMyAdmin).

## 4. Ver y editar datos en phpMyAdmin

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

Puedes editar casi todo directamente en phpMyAdmin (mascotas, estados de refugios, textos); el sitio lo refleja al recargar. El esquema completo, comentado, está en `database/esquema.sql`.

## 5. Si tu MySQL tiene contraseña u otro puerto

XAMPP trae `root` sin contraseña y es lo que se usa por defecto. Si cambiaste algo, copia `.env.example` como `.env` (en esta carpeta) y ajusta `DB_USER`, `DB_PASS`, `DB_PORT`… No hace falta reiniciar nada más.

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
| `POST /auth/login` | — | `{correo, password, rol}` → `{token, sesion}` |
| `POST /auth/registro-usuario` | — | Alta de usuario |
| `POST /auth/registro-refugio` | — | Alta de refugio con `documentos: [{tipo, nombre, dataUrl}]` |
| `GET /auth/yo` | todos | Sesión actualizada (y estado del refugio) |
| `GET /auth/apelacion` · `POST /auth/apelacion` | refugio **rechazado** | Datos y documentos actuales (con `conError`) / reenviar `{nombreRefugio, responsable, telefono, direccion, horario, documentos}`: `documentos` trae solo los archivos nuevos y cada uno reemplaza al de su tipo; los señalados con error deben reemplazarse. La solicitud vuelve a `pendiente`. Si no está rechazada → `409` con `codigo: "no-rechazado"` |
| `GET /foro` · `POST /foro` | usuario | Listar / publicar `{texto, foto?}` |
| `POST /foro/:id/comentarios` · `PUT /foro/:id/like` | usuario | Comentar / `{activo: true\|false}` |
| `GET /refugios` · `GET /refugios/:id` | todos | Refugios aprobados |
| `GET /refugios/:id/mascotas` · `/publicaciones` · `/preguntas` | todos | Mascotas disponibles / publicaciones / preguntas frecuentes activas |
| `GET /adopciones` · `POST /adopciones` | usuario | Mis solicitudes de adopción / enviar una `{mascotaId, nombre, correo, telefono, direccion, ocupacion?, tipoVivienda, viviendaPropia, otrasMascotas?, motivo, aceptaTerminos, documentos}`: identificación y comprobante (uno de cada uno), de 1 a 3 fotos `vivienda` (solo imágenes) y un `otro` opcional. Solo mascotas disponibles; una solicitud abierta por mascota |
| `GET·POST /refugio/preguntas` · `PUT·DELETE /refugio/preguntas/:id` | refugio aprobado | Preguntas frecuentes `{pregunta, respuesta, claves[], activa}` (máx. 50) |
| `GET /refugio/adopciones` · `PATCH /refugio/adopciones/:id` · `GET …/:id/documentos/:doc/archivo` | refugio aprobado | Solicitudes recibidas / responder `{estado, nota}` (rechazar exige nota) / ver un documento |
| `POST /reportes` | usuario | `{tipo, descripcion, zona, foto}` → también calcula coincidencias |
| `GET /coincidencias` · `/coincidencias/resumen` | usuario | Mis coincidencias / contadores |
| `POST /coincidencias/:id/descartar` · `/coincidencias/restaurar` | usuario | Declinar / restaurar |
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
| `No se pudo conectar con MySQL` | Presiona **Start** en MySQL en el panel de XAMPP |
| `MySQL rechazó el usuario o la contraseña` | Revisa `DB_USER` y `DB_PASS` en `.env` (sección 5) |
| `Falta la extension pdo_mysql` | En XAMPP: abre `php.ini` (botón *Config* de Apache) y quita el `;` de `extension=pdo_mysql` |
| `Failed to listen … Address already in use` | El puerto 3000 está ocupado: `php artisan serve --port=3001` y cambia `PUERTO_API` en `config.js` |
| Franja roja "No hay conexión con el servidor" en el sitio | El servidor está apagado: ejecuta `php artisan serve` |

## 9. Notas y límites

- **Coincidencias:** la similitud se calcula comparando las palabras de las descripciones y la zona (`src/Similitud.php`). **No reconoce imágenes**; es una simulación para que la pantalla funcione.
- `php artisan serve` usa el servidor integrado de PHP: está pensado para **desarrollo local** y atiende una petición a la vez (suficiente para probar, no para publicar).
- Al borrar una mascota o publicación, su archivo de foto queda en `storage/uploads/imagenes`; `migrate:fresh` limpia todo.
- Antes de publicar en internet: define `JWT_SECRET` en `.env`, usa HTTPS y un servidor web de verdad (Apache o Nginx; `public/.htaccess` ya está preparado), y crea un usuario de MySQL propio con contraseña.
