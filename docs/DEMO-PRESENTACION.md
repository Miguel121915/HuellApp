# Presentar HuellApp en clase desde una computadora (enlace público + QR)

Con esto, **cualquier compañero abre HuellApp desde su celular** escaneando un QR, sin instalar nada.
La computadora que presenta corre la API y el sitio web, y un **túnel gratuito de Cloudflare** le da una
dirección pública `https://algo-al-azar.trycloudflare.com`. No hace falta cuenta en Cloudflare ni pagar.

> Esta computadora ya tiene PHP, el cliente de Oracle, el wallet y `api/.env` configurado.
> Si algo de eso falta, primero sigue `api/README.md`.

---

## 1. Traer la última versión (una sola vez, hoy)

En la carpeta del proyecto, en PowerShell:

```powershell
git checkout integracion/web-api-oracle
```

```powershell
git pull
```

```powershell
cd api; php artisan migrate; cd ..
```

`migrate` agrega a Oracle las tablas y columnas nuevas (códigos de correo, push, datos del refugio). Se puede
correr varias veces sin problema.

## 2. Revisar `api/.env` (sin compartir sus valores con nadie)

Abre `api\.env` con el Bloc de notas y revisa:

| Línea | Qué debe tener |
|---|---|
| `BREVO_API_KEY=` y `CORREO_REMITENTE=` | Si **tienen valor**, el código de verificación llega de verdad al correo (ver paso 3). |
| `SITIO_URL=` | **Vacío o sin poner.** Así los enlaces y QR usan la dirección del túnel. |
| `VERIFICAR_CORREO=0` | **Solo** si en el paso 3 el correo NO llega. Así la gente entra directo al registrarse. |
| `FIREBASE_CREDENCIALES=` | Opcional (notificaciones push). Ruta al JSON de Firebase, **fuera del proyecto**, p. ej. `C:/oracle/firebase/huellapp-firebase.json`. El JSON se pasa por USB, nunca por chat ni GitHub. |

Después de cambiar `.env` hay que cerrar y volver a abrir la ventana de la API.

## 3. Comprobar que llega el correo al registrarse

1. Doble clic en `iniciar-demo.bat` (la versión local) y espera a que abra `http://127.0.0.1:3000`.
2. **Crear cuenta** con un correo tuyo real.
3. Mira la ventana negra **«API y sitio web»**:
   - Si aparece `[CORREO DE PRUEBA] … Tu código es: 123456` → **Brevo no está configurado** (modo de prueba).
     Para la clase pon `VERIFICAR_CORREO=0` en `api/.env`.
   - Si no aparece eso y en 1–2 minutos te llega el correo de HuellApp (revisa **Spam**) → **funciona**.
     Escribe el código y listo; deja `VERIFICAR_CORREO` como está.
   - Si aparece un error de Brevo → revisa que el remitente esté verificado en Brevo
     (Senders) o usa `VERIFICAR_CORREO=0` para la clase.

Brevo gratis permite **300 correos al día**: alcanza de sobra para un grupo.

## 4. Descargar cloudflared (una sola vez, ~55 MB)

1. Entra a <https://github.com/cloudflare/cloudflared/releases/latest> (página oficial de Cloudflare).
2. Descarga **`cloudflared-windows-amd64.exe`**.
3. Crea la carpeta `C:\oracle\cloudflared` y guarda ahí el archivo con el nombre **`cloudflared.exe`**.

## 5. Conexión a internet

La red de la escuela bloquea el puerto de Oracle (1522). **Conecta la computadora al hotspot de un
celular.** Los compañeros pueden usar su propia red o datos: entran por el enlace público, no por la
computadora.

## 6. Encender la demo pública

Doble clic en **`iniciar-demo-publica.bat`** (en la raíz del proyecto). Hace todo solo:

1. Enciende la API y el sitio web (ventana **«API»**).
2. Abre el túnel (ventana **«Túnel»**).
3. Muestra la dirección pública y abre la **página del QR** (`/pages/qr.html`).

Proyecta esa página. Si al escanear sale «no se encuentra», espera 30 segundos y recarga: Cloudflare tarda
un poco en publicar la dirección nueva.

**No cierres las ventanas «API» y «Túnel»** mientras presentas. Para apagar, ciérralas.
La dirección **cambia cada vez** que abres el `.bat` (es normal; el QR se genera con la nueva).

## 7. Antes de la clase (lista)

- [ ] Haz una prueba completa **hoy**: `.bat` → escanea el QR con tu celular (con datos, no WiFi) → crea una cuenta.
- [ ] Laptop **conectada al cargador** y sin suspensión (Configuración → Sistema → Energía → «Nunca»).
- [ ] Hotspot del celular con saldo/datos suficientes.
- [ ] Enciende todo **15 minutos antes**.
- [ ] Ten a la mano una cuenta de administrador para mostrar la revisión de refugios.

Con 30–40 personas a la vez funciona bien. Si va lento, suele ser la señal del hotspot.

---

## Texto para pegarle a Claude en esa computadora

Copia todo lo de abajo y pégalo en Claude Code abierto en la carpeta del proyecto:

```text
Hola. Estoy en el proyecto HuellApp (Flutter en lib/, API PHP en api/, sitio web en sitio-web/, base
Oracle Autonomous). Mañana presento y necesito dejar lista la demo pública con túnel de Cloudflare que
explica docs/DEMO-PRESENTACION.md. Léelo primero y ayúdame paso a paso.

Reglas:
- Antes de hacer cambios dime qué entendiste y pregúntame.
- Trabajamos SOLO en la rama integracion/web-api-oracle. main es respaldo: no se toca.
- No hagas commit ni push sin que te lo pida.
- Nunca me pidas pegar contraseñas o llaves en el chat, ni las muestres: dime dónde guardarlas.
  Al revisar api/.env solo dime si cada clave tiene valor o está vacía, nunca el valor.
- Para pruebas usa datos inventados y realistas (excepto el correo de prueba del registro, que será el mío).
- No tenemos presupuesto para servicios de pago.

Lo que necesito:
1. Confirmar que estoy en integracion/web-api-oracle, hacer git pull y correr "php artisan migrate" en api/.
2. Revisar api/.env SIN mostrar valores: si BREVO_API_KEY y CORREO_REMITENTE tienen valor, si SITIO_URL
   está vacío, y si existe VERIFICAR_CORREO.
3. Verificar si el código por correo al registrarse funciona DE VERDAD: arranca la API (php artisan serve
   en api/), registra un usuario con el correo que yo te diga desde http://127.0.0.1:3000/pages/registro-usuario.html
   y revisa la consola de la API. Si sale "[CORREO DE PRUEBA]" es modo de prueba (Brevo sin configurar);
   si sale un error de Brevo, explícame la causa. Si no funciona, propón poner VERIFICAR_CORREO=0 en api/.env.
4. Ayudarme a dejar cloudflared.exe en C:\oracle\cloudflared y probar iniciar-demo-publica.bat
   (abre la página /pages/qr.html con la dirección pública). Comprobar que esa dirección abre desde fuera.
5. Si falla algo de Oracle, recuerda que la red de la escuela bloquea el puerto 1522: hay que usar hotspot.
```
