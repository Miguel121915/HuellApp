<?php
declare(strict_types=1);

namespace HuellApp;

/** Respuesta — JSON (o un archivo) que se devuelve al cliente. */
final class Respuesta
{
    /** @param array<string,mixed> $datos @param array<string,string> $cabeceras */
    public function __construct(
        public readonly array $datos = [],
        public readonly int $estado = 200,
        public readonly array $cabeceras = [],
        public readonly ?string $archivo = null,
    ) {
    }

    public static function json(array $datos, int $estado = 200): self
    {
        return new self($datos, $estado);
    }

    /** Entrega un archivo del disco con las cabeceras indicadas. */
    public static function archivo(string $ruta, array $cabeceras): self
    {
        return new self([], 200, $cabeceras, $ruta);
    }

    public function enviar(): void
    {
        http_response_code($this->estado);
        foreach ($this->cabeceras as $nombre => $valor) {
            header("$nombre: $valor");
        }
        if ($this->archivo !== null) {
            readfile($this->archivo);
            return;
        }
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($this->datos, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE | JSON_PRESERVE_ZERO_FRACTION);
    }
}
