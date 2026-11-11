<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Lanza un comando de «php artisan» EN SEGUNDO PLANO: la petición responde de inmediato y el
 * comando sigue trabajando aparte (por ejemplo, la IA de los reportes). Funciona con el servidor
 * de «php artisan serve» en Windows, Linux y macOS.
 */
final class Procesos
{
    /** @param list<string> $argumentos  p. ej. ['ia:procesar', '41'] */
    public static function artisan(array $argumentos): void
    {
        $partes = array_map('escapeshellarg', [PHP_BINARY, RAIZ . DIRECTORY_SEPARATOR . 'artisan', ...$argumentos]);
        $comando = implode(' ', $partes);
        try {
            if (PHP_OS_FAMILY === 'Windows') {
                // «start /B» lo separa de esta petición; la salida se descarta
                $tuberia = popen('start "" /B ' . $comando . ' > NUL 2>&1', 'r');
                if ($tuberia !== false) {
                    pclose($tuberia);
                }
            } else {
                exec('nohup ' . $comando . ' > /dev/null 2>&1 &');
            }
        } catch (\Throwable $e) {
            // Si no se pudo lanzar, no pasa nada grave: el reporte queda pendiente y se reintenta después
            error_log('No se pudo lanzar en segundo plano (' . implode(' ', $argumentos) . '): ' . $e->getMessage());
        }
    }
}
