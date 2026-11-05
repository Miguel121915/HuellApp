<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * ErrorHttp — Error controlado de la API. Se convierte en { "error": "mensaje" } con su código HTTP.
 * `extra` agrega campos a la respuesta (por ejemplo "codigo", para que el cliente reaccione).
 */
final class ErrorHttp extends \Exception
{
    /** @param array<string,mixed> $extra */
    public function __construct(public readonly int $estado, string $mensaje, public readonly array $extra = [])
    {
        parent::__construct($mensaje);
    }
}
