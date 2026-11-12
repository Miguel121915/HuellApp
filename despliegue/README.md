# Despliegue de HuellApp en OCI (HU-25)

Hoy la API y el sitio corren en una laptop (`iniciar-demo.bat`). Esta guía los publica en una **máquina virtual de Oracle Cloud (OCI)**, la misma nube donde ya vive la base de datos, para que cualquiera los abra desde internet.

```
Internet ──► nginx (puerto 80/443) ──┬──► /app/  → app Flutter compilada (build/web)
                                     └──► todo lo demás → php artisan serve (127.0.0.1:3000)
                                                              └──► Oracle Autonomous Database (wallet)
```

| Archivo | Para qué |
|---|---|
| `instalar.sh` | Instala todo en la máquina virtual: PHP 8.3, Oracle Instant Client, `pdo_oci`, nginx y el servicio |
| `huellapp-api.service` | Servicio de systemd: mantiene la API encendida y la reinicia si se cae |
| `nginx-huellapp.conf` | nginx: recibe a internet y reparte entre el sitio/API y la app |
| `compilar-app-produccion.bat` | Compila la app Flutter apuntando al servidor publicado |

## 1. Crear la máquina virtual (consola de OCI)

1. **Compute → Instances → Create instance.**
   - Imagen: **Ubuntu 22.04** (o 24.04).
   - Forma: la gratuita **VM.Standard.A1.Flex** (Ampere, 1 OCPU y 6 GB bastan) o **VM.Standard.E2.1.Micro**.
   - Red: la VCN por defecto con **IP pública**.
   - Llaves SSH: descarga la llave privada (o sube la tuya). **Guárdala bien.**
2. **Abre los puertos 80 y 443**: en la instancia → *Subnet* → *Security List* → *Add Ingress Rules*: origen `0.0.0.0/0`, TCP, puertos `80` y otra regla para `443`.
3. Anota la **IP pública** de la instancia.

## 2. Subir el proyecto y el wallet

Desde tu PC (PowerShell), con la llave SSH:

```bash
ssh -i C:\ruta\llave.key ubuntu@IP_PUBLICA
```

Ya dentro de la máquina virtual:

```bash
git clone -b integracion/web-api-oracle https://github.com/Miguel121915/HuellApp.git ~/huellapp
```

Copia el wallet desde tu PC (otra terminal de PowerShell) y descomprímelo en la máquina:

```bash
scp -i C:\ruta\llave.key C:\Users\TU_USUARIO\Downloads\Wallet_HUELLAPP.zip ubuntu@IP_PUBLICA:~
```

```bash
sudo mkdir -p /opt/huellapp/wallet && sudo unzip -o ~/Wallet_HUELLAPP.zip -d /opt/huellapp/wallet
```

```bash
sudo sed -i 's#DIRECTORY="[^"]*"#DIRECTORY="/opt/huellapp/wallet"#' /opt/huellapp/wallet/sqlnet.ora
```

## 3. Instalar

```bash
cd ~/huellapp && sudo bash despliegue/instalar.sh IP_PUBLICA
```

Tarda unos 10 minutos (compila `pdo_oci`). Copia el repositorio a `/opt/huellapp`, instala nginx y el servicio `huellapp-api`.

## 4. Crear `api/.env` en el servidor

```bash
sudo -u huellapp cp /opt/huellapp/api/.env.example /opt/huellapp/api/.env
```

```bash
sudo -u huellapp nano /opt/huellapp/api/.env
```

Llena como mínimo:

```
DB_TNS=huellapp_tp
DB_USER=HUELLAPP_DEV
DB_PASS=la_contraseña
TNS_ADMIN=/opt/huellapp/wallet
APP_HOST=127.0.0.1
JWT_SECRET=una-clave-larga-y-aleatoria
GEMINI_API_KEY=...
```

- **`JWT_SECRET`**: en un servidor público **no** dejes la de desarrollo. Ojo: también cifra los secretos de Google Authenticator; si cambia, quien ya lo tenía activado debe configurarlo de nuevo.
- **`GOOGLE_CLIENT_ID`**: agrega en Google Cloud el origen `https://TU_DOMINIO` al ID de cliente web. Google **no** acepta `http://IP` (salvo localhost): el botón de Google necesita dominio con HTTPS.

Protege el archivo y enciende la API:

```bash
sudo chmod 600 /opt/huellapp/api/.env && sudo systemctl restart huellapp-api && sudo systemctl status huellapp-api
```

Abre `http://IP_PUBLICA`: debe salir el sitio web. Errores: `sudo journalctl -u huellapp-api -f`.

## 5. Publicar la app Flutter

En tu PC, desde la carpeta del proyecto:

```bash
despliegue\compilar-app-produccion.bat http://IP_PUBLICA
```

```bash
scp -i C:\ruta\llave.key -r build\web\* ubuntu@IP_PUBLICA:/tmp/appweb/
```

Y en la máquina virtual:

```bash
sudo rm -rf /opt/huellapp/build/web && sudo mv /tmp/appweb /opt/huellapp/build/web && sudo chown -R huellapp:huellapp /opt/huellapp/build
```

La app queda en `http://IP_PUBLICA/app/`. Para el **APK de Android** usa la misma dirección: `flutter build apk --release --dart-define=API_URL=https://TU_DOMINIO/api`.

## 6. HTTPS (recomendado, necesita un dominio)

Apunta un dominio (registro A) a la IP pública y luego:

```bash
sudo apt-get install -y certbot python3-certbot-nginx && sudo certbot --nginx -d TU_DOMINIO
```

Certbot configura HTTPS en nginx y lo renueva solo. Después compila la app con `https://TU_DOMINIO`.

## 7. Actualizar después de un `git pull`

```bash
cd ~/huellapp && git pull && sudo rsync -a --exclude api/.env --exclude wallet --exclude api/storage --exclude build ./ /opt/huellapp/ && sudo chown -R huellapp:huellapp /opt/huellapp && sudo systemctl restart huellapp-api
```

Las tablas y columnas nuevas se crean solas al reiniciar (el servicio corre `php artisan serve`, que ejecuta las migraciones).

## Notas

- **Fotos y documentos** se guardan en `/opt/huellapp/api/storage/uploads` de la máquina virtual (no en la base). Respáldalos si la recreas.
- **Rendimiento**: el servicio usa el servidor integrado de PHP con 6 *workers* (`PHP_CLI_SERVER_WORKERS`), suficiente para la demo y un grupo de prueba. Para mucho tráfico convendría php-fpm.
- **Seguridad**: `api/.env` y el wallet quedan con permisos solo para el usuario `huellapp`; la API escucha solo en `127.0.0.1` y nginx es la única puerta a internet.
