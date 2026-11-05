<?php
/**
 * bootstrap.php — Arranque común del servidor y de los comandos de artisan:
 * carga automática de clases, configuración y ajustes de PHP.
 */
declare(strict_types=1);

define('RAIZ', dirname(__DIR__));

// Carga automática: HuellApp\Rutas\Auth  →  src/Rutas/Auth.php
spl_autoload_register(static function (string $clase): void {
    $prefijo = 'HuellApp\\';
    if (strncmp($clase, $prefijo, strlen($prefijo)) !== 0) {
        return;
    }
    $archivo = RAIZ . '/src/' . str_replace('\\', '/', substr($clase, strlen($prefijo))) . '.php';
    if (is_file($archivo)) {
        require $archivo;
    }
});

// Los errores de PHP no deben ensuciar las respuestas JSON: se registran en la terminal
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('memory_limit', '512M'); // el alta de refugio recibe documentos en base64 (hasta 4 × 5 MB)
date_default_timezone_set('UTC');

HuellApp\Config::cargar();
