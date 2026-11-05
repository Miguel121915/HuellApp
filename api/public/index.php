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
// Fotos e ilustraciones: públicas y con CORS, porque la app Flutter en el navegador
// (otro puerto, por ejemplo localhost:52723) las descarga con fetch.
if (str_starts_with($ruta, '/uploads/imagenes/')) {
    header('Access-Control-Allow-Origin: *');
    Archivos::servirImagen(basename($ruta));
    return;
}
if (str_starts_with($ruta, '/assets/img/')) {
    $base = realpath(\HuellApp\Config::dirWeb() . '/assets/img');
    $archivo = realpath(\HuellApp\Config::dirWeb() . $ruta);
    $tipos = ['svg' => 'image/svg+xml', 'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'webp' => 'image/webp'];
    $extension = strtolower(pathinfo((string) $archivo, PATHINFO_EXTENSION));
    if ($base && $archivo && str_starts_with($archivo, $base . DIRECTORY_SEPARATOR) && is_file($archivo) && isset($tipos[$extension])) {
        header('Access-Control-Allow-Origin: *');
        header('Content-Type: ' . $tipos[$extension]);
        header('Cache-Control: public, max-age=3600');
        readfile($archivo);
        return;
    }
    http_response_code(404);
    return;
}
if (PHP_SAPI === 'cli-server') {
    return false; // el servidor integrado entrega el archivo estático pedido (carpeta web/)
}
http_response_code(404);
echo 'HuellApp API. Inicia el servidor con:  php artisan serve';
