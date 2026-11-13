# Referencia de la API de HuellApp (HU-27)

La API en PHP (`api/`) es la única puerta a la base de datos: la usan el sitio web y la app Flutter.
La tabla de rutas de abajo se **genera desde el código** (`Aplicacion::rutas()`), así que coincide con lo que hay.

## Lo básico

| Tema | Cómo funciona |
| --- | --- |
| Dirección | Local: `http://127.0.0.1:3000/api`. Publicada: `https://TU_DOMINIO/api` (ver `despliegue/README.md`). |
| Formato | JSON de ida y de vuelta (`Content-Type: application/json`). Archivos (fotos, PDF) se mandan como *data URL* en base64. |
| Sesión | `POST /api/auth/login` devuelve un `token` (JWT firmado con `JWT_SECRET`). Se manda en cada petición: `Authorization: Bearer <token>`. |
| Verificación en dos pasos | Admin y refugio: el login devuelve `requiere2fa` o `requiereConfigurar2fa` con un `desafio`; con el código de Google Authenticator se obtiene el token (`/api/auth/2fa/...`). |
| Errores | Código HTTP + `{"error": "mensaje en español para la persona"}`. 400 datos inválidos · 401 sin sesión · 403 sin permiso · 404 no existe (o no es tuyo) · 409 conflicto · 429 demasiados intentos. |
| Privacidad | Lo ajeno responde **404** (no se confirma que exista). La seña secreta de un reporte, los documentos y los datos de contacto solo los ve a quien le toca. |
| Fechas | ISO 8601 en UTC, por ejemplo `2026-11-12T03:31:21.826Z`. |
| CORS | Se permite `localhost`/`127.0.0.1` con cualquier puerto y los orígenes de `ORIGENES_PERMITIDOS` en el `.env`. |

## Funciones con IA (Gemini)

Todas siguen funcionando sin IA (sin clave, sin cuota o si falla): responden con reglas sencillas y lo indican con `iaUsada: false`.
Más detalle en [`docs/ia.md`](ia.md).

| Ruta | Para qué |
| --- | --- |
| `POST /api/kiro` | KIRO, el asistente: recomienda mascotas reales y, con sesión, busca en los reportes (HU-7). |
| `POST /api/reportes` | Analiza la foto del reporte y busca coincidencias en segundo plano (HU-5, HU-8). |
| `POST /api/refugio/adopciones/{id}/resumen` | Resumen de una solicitud de adopción para el refugio (HU-22). Se guarda. |
| `GET/POST /api/adopciones/{id}/cuidados` | Guía de cuidado después de adoptar + consejos con IA (HU-23). |
| `POST /api/refugio/mascotas/borrador` | Borrador de la descripción de una mascota (HU-17). No guarda nada. |
| `POST /api/foro`, `POST /api/foro/{id}/comentarios` | Moderación automática: palabras al instante e IA en segundo plano (HU-18). |

## Comandos útiles (`php artisan …` dentro de `api/`)

| Comando | Para qué |
| --- | --- |
| `serve` | Enciende la API y el sitio en http://127.0.0.1:3000 (corre las migraciones). |
| `migrate` | Crea las tablas y columnas que falten (no borra nada). |
| `test` | Pruebas automáticas en un esquema aparte (`DB_TEST_USER`). |
| `2fa:reiniciar correo` | Quita la verificación en dos pasos de una cuenta. |
| `refugios [aprobar\|rechazar\|suspender\|reactivar] correo` | Revisar refugios desde la terminal. |
| `ia:procesar [id]` / `moderacion:revisar tipo id` | Los lanza la API sola en segundo plano. |

## Rutas por módulo

### Aplicacion

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/salud` | público | `(función)` |
| `POST` | `/api/enlaces` | sesión | `(función)` |

### Auth

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/auth/config` | público | `config` |
| `POST` | `/api/auth/login` | público | `login` |
| `POST` | `/api/auth/google` | público | `loginGoogle` |
| `POST` | `/api/auth/2fa/verificar` | público | `verificar2fa` |
| `POST` | `/api/auth/2fa/configurar/preparar` | público | `configurarPreparar` |
| `POST` | `/api/auth/2fa/configurar/activar` | público | `configurarActivar` |
| `GET` | `/api/auth/2fa` | sesión | `estado2fa` |
| `POST` | `/api/auth/2fa/preparar` | sesión | `preparar2fa` |
| `POST` | `/api/auth/2fa/activar` | sesión | `activar2fa` |
| `POST` | `/api/auth/2fa/desactivar` | sesión | `desactivar2fa` |
| `POST` | `/api/auth/registro-usuario` | público | `registroUsuario` |
| `POST` | `/api/auth/registro-refugio` | público | `registroRefugio` |
| `GET` | `/api/auth/yo` | sesión | `yo` |
| `GET` | `/api/auth/apelacion` | rol: refugio | `verApelacion` |
| `POST` | `/api/auth/apelacion` | rol: refugio | `apelar` |

### Foro

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/foro` | público (sesión opcional) | `listar` |
| `POST` | `/api/foro` | rol: usuario | `crear` |
| `POST` | `/api/foro/{id}/comentarios` | rol: usuario | `comentar` |
| `PUT` | `/api/foro/{id}/like` | rol: usuario | `like` |

### Refugios

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/refugios` | público | `listar` |
| `GET` | `/api/refugios/{id}` | público | `ver` |
| `GET` | `/api/refugios/{id}/mascotas` | público | `mascotas` |
| `GET` | `/api/refugios/{id}/publicaciones` | público | `publicaciones` |

### Refugio

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/refugio/yo` | rol: refugio, refugio aprobado | `yo` |
| `PUT` | `/api/refugio/perfil` | rol: refugio, refugio aprobado | `perfil` |
| `GET` | `/api/refugio/resumen` | rol: refugio, refugio aprobado | `resumen` |
| `GET` | `/api/refugio/mascotas` | rol: refugio, refugio aprobado | `listarMascotas` |
| `POST` | `/api/refugio/mascotas` | rol: refugio, refugio aprobado | `crearMascota` |
| `POST` | `/api/refugio/mascotas/borrador` | rol: refugio, refugio aprobado | `borradorDescripcion` |
| `PUT` | `/api/refugio/mascotas/{id}` | rol: refugio, refugio aprobado | `editarMascota` |
| `PATCH` | `/api/refugio/mascotas/{id}/estatus` | rol: refugio, refugio aprobado | `cambiarEstatus` |
| `GET` | `/api/refugio/mascotas/{id}/publicaciones/conteo` | rol: refugio, refugio aprobado | `contarPublicaciones` |
| `DELETE` | `/api/refugio/mascotas/{id}` | rol: refugio, refugio aprobado | `eliminarMascota` |
| `GET` | `/api/refugio/mascotas/{id}/documentos` | rol: refugio, refugio aprobado | `listarDocumentos` |
| `POST` | `/api/refugio/mascotas/{id}/documentos` | rol: refugio, refugio aprobado | `subirDocumento` |
| `GET` | `/api/refugio/mascotas/{id}/documentos/{doc}/archivo` | rol: refugio, refugio aprobado | `archivoDocumento` |
| `DELETE` | `/api/refugio/mascotas/{id}/documentos/{doc}` | rol: refugio, refugio aprobado | `eliminarDocumento` |
| `GET` | `/api/refugio/publicaciones` | rol: refugio, refugio aprobado | `listarPublicaciones` |
| `POST` | `/api/refugio/publicaciones` | rol: refugio, refugio aprobado | `crearPublicacion` |
| `PUT` | `/api/refugio/publicaciones/{id}` | rol: refugio, refugio aprobado | `editarPublicacion` |
| `DELETE` | `/api/refugio/publicaciones/{id}` | rol: refugio, refugio aprobado | `eliminarPublicacion` |

### Admin

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/admin/resumen` | rol: admin | `resumen` |
| `GET` | `/api/admin/estadisticas` | rol: admin | `estadisticas` |
| `GET` | `/api/admin/refugios` | rol: admin | `listar` |
| `GET` | `/api/admin/refugios/{id}` | rol: admin | `ver` |
| `POST` | `/api/admin/refugios/{id}/aprobar` | rol: admin | `aprobar` |
| `POST` | `/api/admin/refugios/{id}/rechazar` | rol: admin | `rechazar` |
| `POST` | `/api/admin/refugios/{id}/suspender` | rol: admin | `suspender` |
| `POST` | `/api/admin/refugios/{id}/reactivar` | rol: admin | `reactivar` |
| `PATCH` | `/api/admin/documentos/{id}` | rol: admin | `marcarDocumento` |
| `GET` | `/api/admin/documentos/{id}/archivo` | rol: admin | `archivo` |
| `GET` | `/api/admin/refugios/{id}/mascotas` | rol: admin | `mascotasDeRefugio` |
| `GET` | `/api/admin/mascotas/{id}` | rol: admin | `verMascota` |
| `PATCH` | `/api/admin/documentos-mascota/{id}` | rol: admin | `marcarDocumentoMascota` |
| `GET` | `/api/admin/documentos-mascota/{id}/archivo` | rol: admin | `archivoMascota` |
| `GET` | `/api/admin/moderacion` | rol: admin | `bandejaModeracion` |
| `POST` | `/api/admin/moderacion/{tipo}/{id}` | rol: admin | `decidirModeracion` |

### Reportes

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `POST` | `/api/reportes` | rol: usuario | `crear` |
| `POST` | `/api/reportes/{id}/reunido` | rol: usuario | `reunido` |
| `POST` | `/api/coincidencias/{id}/sena` | rol: usuario | `responderSena` |
| `GET` | `/api/coincidencias` | rol: usuario | `listar` |
| `GET` | `/api/coincidencias/resumen` | rol: usuario | `resumen` |
| `POST` | `/api/coincidencias/restaurar` | rol: usuario | `restaurar` |
| `POST` | `/api/coincidencias/{id}/descartar` | rol: usuario | `descartar` |

### Adopciones

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/refugios/{id}/preguntas` | sesión | `preguntasPublicas` |
| `GET` | `/api/adopciones` | rol: usuario | `misSolicitudes` |
| `POST` | `/api/adopciones` | rol: usuario | `solicitar` |
| `GET` | `/api/adopciones/{id}/cuidados` | rol: usuario | `guiaCuidados` |
| `POST` | `/api/adopciones/{id}/cuidados` | rol: usuario | `personalizarCuidados` |
| `GET` | `/api/refugio/preguntas` | rol: refugio, refugio aprobado | `listarPreguntas` |
| `POST` | `/api/refugio/preguntas` | rol: refugio, refugio aprobado | `crearPregunta` |
| `PUT` | `/api/refugio/preguntas/{id}` | rol: refugio, refugio aprobado | `editarPregunta` |
| `DELETE` | `/api/refugio/preguntas/{id}` | rol: refugio, refugio aprobado | `eliminarPregunta` |
| `GET` | `/api/refugio/adopciones` | rol: refugio, refugio aprobado | `recibidas` |
| `PATCH` | `/api/refugio/adopciones/{id}` | rol: refugio, refugio aprobado | `cambiarEstado` |
| `POST` | `/api/refugio/adopciones/{id}/resumen` | rol: refugio, refugio aprobado | `resumen` |
| `GET` | `/api/refugio/adopciones/{id}/documentos/{doc}/archivo` | rol: refugio, refugio aprobado | `archivo` |

### Favoritos

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/favoritos` | rol: usuario | `listar` |
| `POST` | `/api/favoritos` | rol: usuario | `agregar` |
| `DELETE` | `/api/favoritos/{id}` | rol: usuario | `quitar` |

### Mensajes

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/mensajes` | rol: usuario | `misMensajes` |
| `POST` | `/api/mensajes` | rol: usuario | `enviar` |
| `GET` | `/api/refugio/mensajes` | rol: refugio, refugio aprobado | `recibidos` |
| `PATCH` | `/api/refugio/mensajes/{id}` | rol: refugio, refugio aprobado | `responder` |

### Requisitos

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/refugios/{id}/requisitos` | público | `publicos` |
| `GET` | `/api/refugio/requisitos` | rol: refugio, refugio aprobado | `listar` |
| `POST` | `/api/refugio/requisitos` | rol: refugio, refugio aprobado | `crear` |
| `PUT` | `/api/refugio/requisitos/{id}` | rol: refugio, refugio aprobado | `editar` |
| `DELETE` | `/api/refugio/requisitos/{id}` | rol: refugio, refugio aprobado | `eliminar` |

### Kiro

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `POST` | `/api/kiro` | público (sesión opcional) | `preguntar` |

### Avisos

| Método | Ruta | Quién puede | Función |
| --- | --- | --- | --- |
| `GET` | `/api/avisos` | sesión | `listar` |
| `POST` | `/api/avisos/leidos` | sesión | `marcarLeidos` |

Total: 94 rutas
