<?php
declare(strict_types=1);

namespace HuellApp;

/** Solicitud — Lo que llegó del cliente: método, ruta, parámetros, cuerpo JSON y cabeceras. */
final class Solicitud
{
    /** @var array<string,string> parámetros de la ruta, ej. {id} */
    public array $params = [];
    /** Usuario autenticado (lo llena la guardia requiereSesion). */
    public ?array $usuario = null;
    /** Refugio del usuario (lo llena la guardia requiereRefugioAprobado). */
    public ?array $refugio = null;

    private const MAX_NORMAL = 8 * 1024 * 1024;       // 8 MB
    private const MAX_REGISTRO_REFUGIO = 30 * 1024 * 1024; // 4 documentos × 5 MB en base64

    /** @param array<string,mixed> $query @param array<string,mixed> $cuerpo */
    public function __construct(
        public readonly string $metodo,
        public readonly string $ruta,
        public readonly array $query,
        private readonly array $cuerpo,
        private readonly array $cabeceras,
    ) {
    }

    /** Construye la solicitud a partir de la petición HTTP actual. La ruta se entrega sin el prefijo /api. */
    public static function actual(): self
    {
        $ruta = rawurldecode(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/');
        $ruta = '/' . trim(substr($ruta, 4), '/'); // quita "/api"
        $cabeceras = [];
        foreach ($_SERVER as $clave => $valor) {
            if (str_starts_with($clave, 'HTTP_')) {
                $cabeceras[strtolower(str_replace('_', '-', substr($clave, 5)))] = (string) $valor;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $cabeceras['content-type'] = $_SERVER['CONTENT_TYPE'];
        }

        $limite = $ruta === '/auth/registro-refugio' ? self::MAX_REGISTRO_REFUGIO : self::MAX_NORMAL;
        if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > $limite) {
            throw new ErrorHttp(413, 'El archivo o los datos enviados son demasiado grandes.');
        }

        $cuerpo = [];
        $crudo = file_get_contents('php://input') ?: '';
        if ($crudo !== '') {
            $decodificado = json_decode($crudo, true);
            if (!is_array($decodificado)) {
                throw new ErrorHttp(400, 'Los datos enviados no tienen un formato válido.');
            }
            $cuerpo = $decodificado;
        }
        return new self($_SERVER['REQUEST_METHOD'] ?? 'GET', $ruta, $_GET, $cuerpo, $cabeceras);
    }

    /** Cuerpo JSON como arreglo (vacío si no hubo cuerpo). */
    public function cuerpo(): array
    {
        return $this->cuerpo;
    }

    public function cabecera(string $nombre): ?string
    {
        return $this->cabeceras[strtolower($nombre)] ?? null;
    }

    public function ip(): string
    {
        $remota = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
        // En el servidor publicado, nginx (en la misma máquina) reenvía la IP real en X-Real-IP.
        // Solo se le cree si la petición viene de la propia máquina: desde fuera no se puede falsificar.
        $real = $_SERVER['HTTP_X_REAL_IP'] ?? '';
        if (in_array($remota, ['127.0.0.1', '::1'], true) && filter_var($real, FILTER_VALIDATE_IP)) {
            return $real;
        }
        return $remota;
    }

    public function parametro(string $nombre): string
    {
        return $this->params[$nombre] ?? '';
    }
}
