#!/usr/bin/env bash
# =============================================================================
#  instalar.sh — Instala HuellApp en una máquina virtual de OCI (Ubuntu 22.04 o 24.04)
#
#  Uso (en la máquina virtual, después de copiar el repositorio y el wallet):
#     sudo bash despliegue/instalar.sh TU_DOMINIO_O_IP
#
#  Qué hace (se puede volver a ejecutar sin problema):
#   1. PHP 8.3 + Oracle Instant Client + extensión pdo_oci (compilada para esa versión de PHP)
#   2. Usuario «huellapp» y la carpeta /opt/huellapp (el repositorio)
#   3. Servicio huellapp-api (systemd) y nginx en el puerto 80
#   4. Abre los puertos 80 y 443 en el firewall de la máquina
#  NO crea api/.env ni copia el wallet: eso lo haces tú (ver despliegue/README.md).
# =============================================================================
set -euo pipefail

DOMINIO="${1:-}"
if [[ -z "$DOMINIO" ]]; then
  echo "Uso: sudo bash despliegue/instalar.sh TU_DOMINIO_O_IP" >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta con sudo." >&2
  exit 1
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO=/opt/huellapp
PHPV=8.3

echo "==> 1/6 Paquetes del sistema y PHP $PHPV"
apt-get update -y
apt-get install -y software-properties-common curl unzip git nginx libaio1 2>/dev/null || apt-get install -y software-properties-common curl unzip git nginx libaio1t64
add-apt-repository -y ppa:ondrej/php
apt-get update -y
apt-get install -y "php$PHPV-cli" "php$PHPV-dev" "php$PHPV-curl" "php$PHPV-mbstring" "php$PHPV-xml" build-essential

echo "==> 2/6 Oracle Instant Client (Basic + SDK)"
ARQ="$(uname -m)"
if [[ "$ARQ" == "aarch64" ]]; then SUFIJO="linux-arm64"; else SUFIJO="linuxx64"; fi
if ! ls -d /opt/oracle/instantclient_* >/dev/null 2>&1; then
  mkdir -p /opt/oracle && cd /opt/oracle
  curl -fL -o basic.zip "https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-$SUFIJO.zip"
  curl -fL -o sdk.zip   "https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-$SUFIJO.zip"
  unzip -oq basic.zip && unzip -oq sdk.zip && rm -f basic.zip sdk.zip
fi
IC="$(ls -d /opt/oracle/instantclient_* | sort | tail -n1)"
echo "$IC" > /etc/ld.so.conf.d/oracle-instantclient.conf
ldconfig
# Ubuntu 24.04 renombró libaio
if [[ ! -e /usr/lib/x86_64-linux-gnu/libaio.so.1 && -e /usr/lib/x86_64-linux-gnu/libaio.so.1t64 ]]; then
  ln -sf /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/x86_64-linux-gnu/libaio.so.1
fi
if [[ ! -e /usr/lib/aarch64-linux-gnu/libaio.so.1 && -e /usr/lib/aarch64-linux-gnu/libaio.so.1t64 ]]; then
  ln -sf /usr/lib/aarch64-linux-gnu/libaio.so.1t64 /usr/lib/aarch64-linux-gnu/libaio.so.1
fi

echo "==> 3/6 Extensión pdo_oci (se compila con el código de la misma versión de PHP)"
if ! php -m | grep -qi '^pdo_oci$'; then
  VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION.".".PHP_RELEASE_VERSION;')"
  cd /tmp && rm -rf "php-$VERSION"
  curl -fL -o php.tar.gz "https://www.php.net/distributions/php-$VERSION.tar.gz"
  tar xzf php.tar.gz && rm -f php.tar.gz
  cd "php-$VERSION/ext/pdo_oci"
  phpize
  ./configure --with-pdo-oci="instantclient,$IC"
  make -j"$(nproc)" && make install
  echo "extension=pdo_oci" > "/etc/php/$PHPV/mods-available/pdo_oci.ini"
  phpenmod -v "$PHPV" pdo_oci
fi
php -m | grep -qi '^pdo_oci$' && echo "    pdo_oci OK" || { echo "No se pudo activar pdo_oci" >&2; exit 1; }

echo "==> 4/6 Usuario y carpeta $DESTINO"
id huellapp >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin huellapp
if [[ "$REPO" != "$DESTINO" ]]; then
  mkdir -p "$DESTINO"
  cp -a "$REPO/." "$DESTINO/"
fi
mkdir -p "$DESTINO/wallet" "$DESTINO/api/storage/uploads/imagenes" "$DESTINO/api/storage/uploads/documentos" "$DESTINO/build/web"
chown -R huellapp:huellapp "$DESTINO"
chmod 700 "$DESTINO/wallet"
[[ -f "$DESTINO/api/.env" ]] && chmod 600 "$DESTINO/api/.env"

echo "==> 5/6 Servicio huellapp-api y nginx"
cp "$DESTINO/despliegue/huellapp-api.service" /etc/systemd/system/huellapp-api.service
sed "s/TU_DOMINIO/$DOMINIO/g" "$DESTINO/despliegue/nginx-huellapp.conf" > /etc/nginx/sites-available/huellapp
ln -sf /etc/nginx/sites-available/huellapp /etc/nginx/sites-enabled/huellapp
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl daemon-reload
systemctl enable --now nginx
systemctl reload nginx
if [[ -f "$DESTINO/api/.env" && -f "$DESTINO/wallet/cwallet.sso" ]]; then
  systemctl enable huellapp-api
  systemctl restart huellapp-api
else
  echo "    [Pendiente] Falta $DESTINO/api/.env o el wallet en $DESTINO/wallet: el servicio se encenderá cuando estén."
  systemctl enable huellapp-api
fi

echo "==> 6/6 Firewall de la máquina (puertos 80 y 443)"
# Las imágenes de Ubuntu de OCI traen reglas de iptables que bloquean todo menos SSH
if command -v iptables >/dev/null; then
  for P in 80 443; do
    iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null || iptables -I INPUT 6 -m state --state NEW -p tcp --dport "$P" -j ACCEPT
  done
  command -v netfilter-persistent >/dev/null && netfilter-persistent save || true
fi

echo
echo "Listo. Revisa:  sudo systemctl status huellapp-api   y abre  http://$DOMINIO"
echo "Recuerda abrir también los puertos 80/443 en la «Security List» de la VCN en la consola de OCI."
