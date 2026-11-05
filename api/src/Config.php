<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Config — Lee la configuración. Orden de prioridad:
 * variable de entorno  >  archivo .env  >  valor por defecto (el de XAMPP).
 */
final class Config
{
    private const DEFECTOS = [
        'DB_HOST' => '127.0.0.1',
        'DB_PORT' => '3306',
        'DB_NAME' => 'huellapp',
        'DB_USER' => 'root',
        'DB_PASS' => '',
        'APP_HOST' => '127.0.0.1',
        'APP_PORT' => '3000',
        'JWT_SECRET' => 'huellapp-clave-solo-para-desarrollo-local',
        'WEB_DIR' => '',
        'ORIGENES_PERMITIDOS' => '',
    ];

    /** @var array<string,string> */
    private static array $archivo = [];

    public static function cargar(): void
    {
        self::$archivo = [];
        $ruta = RAIZ . '/.env';
        if (!is_file($ruta)) {
            return;
        }
        foreach (file($ruta, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $linea) {
            $linea = trim($linea);
            if ($linea === '' || $linea[0] === '#' || !str_contains($linea, '=')) {
                continue;
            }
            [$clave, $valor] = explode('=', $linea, 2);
            self::$archivo[trim($clave)] = trim(trim($valor), "\"'");
        }
    }

    public static function obtener(string $clave): string
    {
        $entorno = getenv($clave);
        if ($entorno !== false) {
            return $entorno;
        }
        return self::$archivo[$clave] ?? self::DEFECTOS[$clave] ?? '';
    }

    /** Carpeta del sitio web (HTML/CSS/JS). Por defecto: ../sitio-web respecto a api/. */
    public static function dirWeb(): string
    {
        $dir = self::obtener('WEB_DIR');
        $ruta = $dir !== '' ? $dir : RAIZ . '/../sitio-web';
        return realpath($ruta) ?: $ruta;
    }

    public static function dirUploads(): string
    {
        return RAIZ . '/storage/uploads';
    }
}
