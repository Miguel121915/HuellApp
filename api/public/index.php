<?php
/**
 * public/index.php — Punto de entrada del servidor (lo usa "php artisan serve").
 *
 *   /api/...               → la API
 *   /uploads/imagenes/...  → fotos subidas
 *   cualquier otra ruta    → el sitio web (HTML/CSS/JS de la carpeta web/), que sirve el propio PHP
 */
declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use HuellApp\{Aplicacion, Archivos};

$ruta = rawurldecode(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/');

if ($ruta === '/api' || str_starts_with($ruta, '/api/')) {
    Aplicacion::manejar();
    return;
}
if (str_starts_with($ruta, '/uploads/imagenes/')) {
    Archivos::servirImagen(basename($ruta));
    return;
}
if (PHP_SAPI === 'cli-server') {
    return false; // el servidor integrado entrega el archivo estático pedido (carpeta web/)
}
http_response_code(404);
echo 'HuellApp API. Inicia el servidor con:  php artisan serve';
