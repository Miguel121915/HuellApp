<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Enrutador — Relaciona método + ruta con una función. Admite parámetros ({id}) y guardias
 * (funciones que se ejecutan antes y pueden lanzar ErrorHttp para negar el acceso).
 */
final class Enrutador
{
    /** @var list<array{string,string,callable,list<callable>}> */
    private array $rutas = [];
    private string $prefijo = '';
    /** @var list<callable> */
    private array $guardias = [];

    /** Agrupa rutas bajo un prefijo y unas guardias comunes. */
    public function grupo(string $prefijo, array $guardias, callable $definir): void
    {
        $anteriorPrefijo = $this->prefijo;
        $anterioresGuardias = $this->guardias;
        $this->prefijo .= $prefijo;
        $this->guardias = [...$this->guardias, ...$guardias];
        $definir($this);
        $this->prefijo = $anteriorPrefijo;
        $this->guardias = $anterioresGuardias;
    }

    public function agregar(string $metodo, string $ruta, callable $manejador, array $guardias = []): void
    {
        $patron = preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $this->prefijo . $ruta);
        $this->rutas[] = [$metodo, '#^' . $patron . '$#', $manejador, [...$this->guardias, ...$guardias]];
    }

    public function get(string $ruta, callable $m, array $g = []): void { $this->agregar('GET', $ruta, $m, $g); }
    public function post(string $ruta, callable $m, array $g = []): void { $this->agregar('POST', $ruta, $m, $g); }
    public function put(string $ruta, callable $m, array $g = []): void { $this->agregar('PUT', $ruta, $m, $g); }
    public function patch(string $ruta, callable $m, array $g = []): void { $this->agregar('PATCH', $ruta, $m, $g); }
    public function delete(string $ruta, callable $m, array $g = []): void { $this->agregar('DELETE', $ruta, $m, $g); }

    public function despachar(Solicitud $solicitud): Respuesta
    {
        foreach ($this->rutas as [$metodo, $patron, $manejador, $guardias]) {
            if ($metodo !== $solicitud->metodo || !preg_match($patron, $solicitud->ruta, $coincidencias)) {
                continue;
            }
            $solicitud->params = array_filter($coincidencias, 'is_string', ARRAY_FILTER_USE_KEY);
            foreach ($guardias as $guardia) {
                $guardia($solicitud);
            }
            $resultado = $manejador($solicitud);
            return $resultado instanceof Respuesta ? $resultado : Respuesta::json($resultado);
        }
        throw new ErrorHttp(404, 'Ruta no encontrada.');
    }
}
