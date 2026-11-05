# HuellApp (frontend)

Plataforma para ayudar a mascotas perdidas y promover la adopción. Frontend en HTML5, CSS3 y JavaScript vanilla (módulos ES) que habla con la API del servidor local (`api/`).

> **Estado: las 4 fases están completas** — autenticación, **vista de Usuario**, **panel de Refugio** y **panel de Administrador**, conectados a la base de datos Oracle del proyecto (a través de la API).

> ⚠️ **Este sitio ya no funciona solo:** guarda y lee todo de un servidor local con base de datos. Antes de usarlo, enciende el servidor (carpeta `api/`, ver su `README.md`): `php artisan serve`. Luego abre **http://localhost:3000**.

## Cómo ejecutarlo

1. Enciende **el servidor** (carpeta `api/`): `php artisan serve`. Detalles en `api/README.md`.
2. Abre **http://localhost:3000**. El servidor ya muestra este sitio.

También puedes abrir el sitio con **Live Server** de VS Code (clic derecho sobre `index.html` → *Open with Live Server*), siempre con el servidor encendido en el puerto 3000. Los módulos ES **no funcionan abriendo el archivo con doble clic** (`file://`). La cámara de «Reportar» funciona en `localhost`/`127.0.0.1` y en `https://`.

## Cuentas demo (contraseña: `Demo1234`)

| Rol | Correo | Resultado |
|---|---|---|
| Usuario | ana@huellapp.mx | Vista de usuario |
| Refugio verificado | refugio@huellapp.mx | Panel del refugio |
| Refugio pendiente | pendiente@huellapp.mx | Mensaje "Pendiente de verificación" |
| Refugio rechazado | rechazado@huellapp.mx | Mensaje con el motivo del rechazo y botón **Solicitar apelación** |
| Administrador | admin@huellapp.mx | Vista de administrador |

En el login hay un desplegable "Cuentas de demostración" que rellena el formulario.

### Apelación de un refugio rechazado

1. En `pages/estado-refugio.html`, un refugio **rechazado** ve el botón **Solicitar apelación**, que abre `pages/registro-refugio.html?apelacion=1`.
2. En modo apelación el formulario precarga los datos y muestra el archivo actual de cada documento. Los que el administrador señaló como erróneos aparecen en rojo con un aviso y hay que reemplazarlos; los demás se conservan si no se elige otro archivo. El correo no se edita y no se pide contraseña.
3. Al reenviar, el servidor reemplaza los archivos, deja la solicitud en **pendiente** (vuelve a `admin/solicitudes.html`, marcada como «Apelación») y el sitio regresa a la pantalla de estado.

## Vista de usuario (Fase 2)

| Pantalla | Archivo | Qué hace |
|---|---|---|
| Inicio | `pages/usuario/inicio.html` | KIRO (gato-robot) con globo de diálogo, buscador de dudas y preguntas frecuentes (respuestas predefinidas). |
| Foro | `pages/usuario/foro.html` | Muro: crear publicación (texto + foto), feed por lotes con scroll infinito, «me gusta» en forma de huella (toggle) y comentarios (cada comentario es una "burbuja" con borde de acento y fondos alternados para distinguir las respuestas). Todo se guarda en la base de datos. |
| Refugios | `pages/usuario/refugios.html` | Refugios **verificados**; al entrar (`?id=1`) se ven sus mascotas disponibles con filtros de nombre, especie, edad y tamaño. Cada tarjeta tiene el botón **🐾 Adoptar**, que abre el formulario de solicitud (datos personales, hogar y documentos: identificación, comprobante de domicilio y 1 a 3 fotos del espacio). Dentro del formulario, el botón flotante **¿Dudas? Pregúntale a KIRO** abre un chat que responde al instante con las preguntas frecuentes del refugio. Tras enviar, el botón cambia a «Solicitud enviada». |
| Reportar | `pages/usuario/reportar.html` | Cámara con `getUserMedia`, captura en `<canvas>`, vista previa y formulario. Si se niega el permiso, se puede subir un archivo. |
| Coincidencias | `pages/usuario/coincidencias.html` | Posibles coincidencias con % de similitud; contactar (modal) o declinar. Un reporte nuevo se compara con los de otras personas y puede generar coincidencias. |

## Panel de refugio (Fase 3)

Entra con `refugio@huellapp.mx` / `Demo1234` (pestaña **Refugio** del login).

| Pantalla | Archivo | Qué hace |
|---|---|---|
| Panel | `pages/refugio/panel.html` | Contadores (registradas, disponibles, en proceso, adoptadas, publicaciones), accesos rápidos y últimas mascotas. |
| Inventario | `pages/refugio/inventario.html` | **CRUD completo**: tabla con búsqueda y filtros, alta/edición en un diálogo con validación, cambio rápido de estatus y eliminación con confirmación (borra también sus publicaciones y documentos). Botón **Documentos (n)** por mascota: adjuntar, ver y eliminar certificados de vacunación, esterilización, pedigree, etc. (PDF/JPG/PNG, máx. 5 MB), con el estado de revisión del administrador. |
| Publicaciones | `pages/refugio/publicaciones.html` | Elegir una mascota del inventario + texto + foto opcional + **republicación automática** (cada semana, cada 2 semanas, cada mes o cada N días). Se muestra en la página pública del refugio (vista de usuario). Las publicaciones se pueden **editar** (texto, foto y periodicidad) y la lista indica cuándo será la próxima republicación. |
| Adopciones | `pages/refugio/adopciones.html` | Solicitudes de adopción recibidas: contadores, filtro por estado y búsqueda. En el detalle, datos del solicitante y de su hogar, **visor** de sus documentos y la respuesta del refugio (nueva, en revisión, aprobada o rechazada, con nota para el solicitante; al rechazar es obligatoria). |
| Preguntas | `pages/refugio/preguntas.html` | Alta, edición, ocultar/mostrar y eliminación de **preguntas frecuentes** con su respuesta y palabras clave. Las usa KIRO en el formulario de adopción. Incluye un probador («Prueba a KIRO») y, si no hay ninguna, un botón para empezar con preguntas sugeridas. |
| Perfil | `pages/refugio/perfil.html` | Estado de verificación, datos fijos y documentos, y datos de contacto editables (teléfono, dirección, horario, descripción). |

Lo que el refugio cambia lo ven los usuarios: la mascota nueva aparece en su listado, las publicaciones en «Novedades del refugio» y los datos de contacto en su ficha. Las mascotas **adoptadas** dejan de mostrarse a los usuarios, y un refugio pendiente, rechazado o suspendido no puede entrar a estas páginas (ve su estado).

## Panel de administrador (Fase 4)

Entra con `admin@huellapp.mx` / `Demo1234` (pestaña **Administrador** del login).

| Pantalla | Archivo | Qué hace |
|---|---|---|
| Solicitudes | `pages/admin/solicitudes.html` | Contadores (pendientes, aprobados, rechazados, suspendidos) y la cola de refugios por revisar, las más antiguas primero. El menú muestra cuántas hay pendientes. |
| Revisar solicitud | `pages/admin/detalle-solicitud.html?id=…` | Datos del refugio, **checklist por documento** (se guarda en la base de datos), **visor** de cada archivo (PDF o imagen) y la decisión: **Aprobar** (solo con todos los documentos revisados) o **Rechazar** con motivo obligatorio, que el refugio verá al intentar entrar, y marcando (opcional) qué documentos tienen problemas. Si la solicitud es una apelación, muestra el motivo del rechazo anterior y marca los documentos nuevos. |
| Refugios | `pages/admin/refugios.html` | Lista con filtro por estado (verificados por defecto) y búsqueda. Permite **suspender** un refugio verificado (con motivo opcional) o **reactivar** uno suspendido. Un refugio suspendido pierde el acceso a su panel al instante. Botón **Mascotas** en verificados y suspendidos. |
| Mascotas del refugio | `pages/admin/mascotas-refugio.html?id=…` | Inventario completo del refugio (todos los estatus) con filtros, incluido «con documentos por revisar». Al elegir una mascota: sus datos, **checklist de sus documentos** y **visor**. |

Los documentos de los refugios son privados: el visor los descarga con la sesión del administrador y los muestra desde una dirección temporal del navegador; no existe una URL pública para verlos.

## Dónde se guardan los datos

Todo lo editable (usuarios, refugios, mascotas, publicaciones, foro, reportes, coincidencias) vive en la **base de datos Oracle** (esquema de `DB_USER`, ver `api/README.md`), y las fotos y documentos en `api/storage/uploads/`. El navegador solo recuerda en `localStorage` la **sesión** (`huellapp:sesion`: datos básicos y el token). Para empezar de cero: `php artisan migrate:fresh --seed` en `api/`.

Las fotos se reducen a 640 px en el navegador antes de enviarse (las de la cámara, a 1024 px). Los documentos de un refugio (PDF, JPG o PNG, máx. 5 MB) se guardan en una carpeta privada que solo el administrador puede consultar.

## Arquitectura

- `assets/js/core/` — `config` (dónde está el servidor), `api` (cliente HTTP: token, errores, sesión vencida, aviso de servidor apagado), `storage` (guarda la sesión), `auth` (sesión y registros), `router-guard` (guardias por rol, solo de experiencia), `utils`.
- `assets/js/core/servicios.js`, `servicios-refugio.js` y `servicios-admin.js` — capa de datos: una función `async` por operación, que llama a la API. Los módulos de página no saben nada de HTTP.
- `assets/js/components/` — navbar, like-huella, camara, chatbot-kiro, tarjeta-mascota, tarjeta-publicacion, visor-documento y asistente-adopcion (reutilizables).
- `assets/js/core/buscador-faq.js` — encuentra la pregunta frecuente que responde una duda escrita libremente (sin acentos ni mayúsculas, por raíces de palabras y con sinónimos como «INE» → identificación). Lo usan el asistente del formulario de adopción y el probador del refugio; funciona en el navegador, sin servicios externos.
- `assets/js/data/` — `cuentas-demo.js` (atajos del login), `mock-kiro.js` (preguntas del asistente de inicio) y `preguntas-adopcion.js` (respuestas generales que usa KIRO si ninguna pregunta del refugio responde la duda).
- `assets/js/modules/<seccion>/` — un módulo JS por página; carga solo lo que necesita.
- `assets/css/` — `base/` (tokens, reset, tipografía, layout), `components/` (reutilizables), `pages/` (uno por sección). Cada HTML enlaza solo los CSS que usa. Sin estilos inline.

La autorización real vive en el servidor (rol, estado del refugio y dueño de los datos se validan en cada petición); las guardias de ruta del navegador solo mejoran la experiencia.
