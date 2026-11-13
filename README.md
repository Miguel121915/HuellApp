# HuellApp

Plataforma de adopción de mascotas y reunificación de mascotas perdidas. Tiene dos clientes que comparten una sola API y una sola base de datos:

```
App móvil (Flutter) ──┐                          ┌──► Base de datos Oracle Autonomous (OCI)
                      ├──► API PHP (api/) ───────┤
Sitio web (HTML/JS) ──┘                          └──► Google Gemini (IA, capa gratuita)
```

## Qué hace

| Para quién | Funciones |
| --- | --- |
| Visitante | Ver refugios y mascotas en adopción; KIRO, el asistente |
| Usuario | Reportar mascotas perdidas/encontradas con foto y mapa; coincidencias con IA y seña secreta; foro por pestañas; favoritos y comparación; solicitud de adopción con documentos; guía de cuidado al adoptar; mensajes; avisos; KIRO busca mascotas y reportes |
| Refugio | Registro con verificación; inventario con borrador de descripción con IA; publicaciones con republicación; solicitudes de adopción con resumen con IA; requisitos, preguntas frecuentes y mensajes |
| Administrador | Revisión de refugios y documentos; estadísticas; moderación del foro |
| Seguridad | Sesión con JWT, verificación en dos pasos (Google Authenticator) para refugio y admin, bloqueo por intentos, documentos privados |

## Documentación

| Documento | Contenido |
| --- | --- |
| [docs/manual-usuario.md](docs/manual-usuario.md) | Cómo se usa, por rol, y preguntas frecuentes |
| [docs/api.md](docs/api.md) | Referencia de la API: las 94 rutas, quién puede usarlas, errores y sesión |
| [docs/base-de-datos.md](docs/base-de-datos.md) | Diagrama y tablas de Oracle |
| [docs/ia.md](docs/ia.md) | Qué hace la IA, qué datos recibe y qué pasa sin cuota |
| [docs/pruebas-manuales.md](docs/pruebas-manuales.md) | Lista de pruebas por rol para antes de la entrega |
| [api/README.md](api/README.md) | Instalar y correr la API, comandos de `php artisan` y pruebas automáticas |
| [despliegue/README.md](despliegue/README.md) | Publicar en una máquina virtual de OCI |

## Estructura del repositorio

| Carpeta | Qué es | Cómo se ejecuta |
| --- | --- | --- |
| raíz (`lib/`, `android/`, `ios/`, `pubspec.yaml`…) | App móvil en Flutter | `flutter pub get` y `flutter run` desde la raíz |
| `api/` | API en PHP (sin frameworks) que usan la app y el sitio | `php artisan serve` dentro de `api/` (ver `api/README.md`) |
| `sitio-web/` | Sitio web en HTML, CSS y JavaScript | Lo muestra la API en http://localhost:3000 (ver `sitio-web/README.md`) |
| `backend/` | **Ya no se usa.** Era el servidor Node/Express de Reportar con Gemini y MySQL; la IA ahora está en `api/` (ver `api/README.md`) | Se puede borrar cuando el equipo lo confirme |
| `despliegue/` | Publicar la API, el sitio y la app en una máquina virtual de OCI (HU-25) | Ver `despliegue/README.md` |
| `database/` | Esquemas de base de datos | — |

Cada parte se ejecuta por separado: cambiar el sitio web no afecta a la app y viceversa. Lo único que comparten es la API; si cambias una ruta o un campo de la API, avisa al equipo.


## Presentar en vivo (demo)

1. **Una sola vez** (y cada vez que cambie la app, después de `git pull`): doble clic en `compilar-app.bat`. Compila la app para el navegador en `build/web` (tarda unos minutos).
2. **Para presentar:** doble clic en `iniciar-demo.bat`. Abre dos ventanas negras (API y app), espera a que la conexión con Oracle esté lista y abre en el navegador:
   - Sitio web: http://127.0.0.1:3000
   - App móvil: http://127.0.0.1:8080
3. **Para apagar:** cierra las dos ventanas negras.

Necesita internet (la base está en la nube de OCI), PHP en el PATH y, para compilar, Flutter. Si después de recompilar la app se ve la versión vieja, recarga con Ctrl + F5.

## Secretos

Ningún archivo `.env`, wallet de Oracle ni contraseña se sube al repositorio. Cada carpeta tiene un `.env.example`: cópialo como `.env` y llena tus valores.
