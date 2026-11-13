<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Evaluación de la IA de HuellApp con datos etiquetados a mano (api/evaluacion/*.json).
 * La lanza «php artisan ia:evaluar» sobre el esquema de PRUEBAS (DB_TEST_USER), recién sembrado
 * con los datos demo, así que es repetible y no toca la base del equipo.
 *
 *  - moderacion: lista de palabras (método base) vs IA vs ambos (lo que hace la app).
 *  - kiro: ¿recomienda lo que se pidió?, ¿respeta la privacidad?, ¿inventa?, ¿cuánto tarda?
 *  - coincidencias-texto: comparación por texto (Similitud.php, el método sin IA) con distintos umbrales.
 */
final class Evaluacion
{
    private const DIR = RAIZ . '/evaluacion';

    /* ---------- Métricas ---------- */

    /**
     * @param list<array{0:bool,1:bool}> $pares  [esperado, predicho], donde true = clase positiva
     * @return array{vp:int,fp:int,fn:int,vn:int,exactitud:float,precision:float,recall:float,f1:float}
     */
    public static function metricas(array $pares): array
    {
        $vp = $fp = $fn = $vn = 0;
        foreach ($pares as [$esperado, $predicho]) {
            if ($esperado && $predicho) $vp++;
            elseif (!$esperado && $predicho) $fp++;
            elseif ($esperado && !$predicho) $fn++;
            else $vn++;
        }
        $total = max(1, $vp + $fp + $fn + $vn);
        $precision = $vp + $fp > 0 ? $vp / ($vp + $fp) : 0.0;
        $recall = $vp + $fn > 0 ? $vp / ($vp + $fn) : 0.0;
        $f1 = $precision + $recall > 0 ? 2 * $precision * $recall / ($precision + $recall) : 0.0;
        return ['vp' => $vp, 'fp' => $fp, 'fn' => $fn, 'vn' => $vn, 'exactitud' => ($vp + $vn) / $total,
            'precision' => $precision, 'recall' => $recall, 'f1' => $f1];
    }

    private static function datos(string $archivo): array
    {
        return json_decode((string) file_get_contents(self::DIR . "/$archivo"), true, 512, JSON_THROW_ON_ERROR);
    }

    private static function resumenTiempos(array $ms): array
    {
        if ($ms === []) {
            return ['promedio' => 0, 'mediana' => 0, 'maximo' => 0];
        }
        sort($ms);
        return ['promedio' => (int) round(array_sum($ms) / count($ms)), 'mediana' => (int) $ms[intdiv(count($ms), 2)], 'maximo' => (int) end($ms)];
    }

    /* ---------- 1. Moderación ---------- */

    public static function moderacion(callable $progreso): array
    {
        $casos = self::datos('moderacion.json')['casos'];
        $filas = [];
        $tiempos = [];
        $sinIa = 0;
        foreach ($casos as $i => $c) {
            $palabras = Moderacion::porPalabras($c['texto']) !== null;
            $t = microtime(true);
            $motivoIa = Moderacion::porIa($c['texto']);
            $tiempos[] = (microtime(true) - $t) * 1000;
            if ($motivoIa === null) { // un corte de red no debe contar como error de la IA: un reintento
                sleep(3);
                $motivoIa = Moderacion::porIa($c['texto']);
            }
            if ($motivoIa === null) {
                $sinIa++;
            }
            $ia = $motivoIa !== null && $motivoIa !== '';
            $filas[] = ['texto' => $c['texto'], 'tipo' => $c['tipo'], 'esperado' => $c['inapropiado'],
                'palabras' => $palabras, 'ia' => $motivoIa === null ? null : $ia, 'ambos' => $palabras || $ia, 'motivoIa' => $motivoIa];
            $progreso(sprintf('moderación %d/%d', $i + 1, count($casos)));
        }
        $conIa = array_filter($filas, static fn ($f) => $f['ia'] !== null);
        return [
            'casos' => count($filas), 'sinRespuestaIa' => $sinIa,
            'palabras' => self::metricas(array_map(static fn ($f) => [$f['esperado'], $f['palabras']], $filas)),
            'ia' => self::metricas(array_map(static fn ($f) => [$f['esperado'], $f['ia']], $conIa)),
            'ambos' => self::metricas(array_map(static fn ($f) => [$f['esperado'], $f['ambos']], $filas)),
            'tiemposIaMs' => self::resumenTiempos($tiempos),
            'errores' => array_values(array_filter($filas, static fn ($f) => $f['ambos'] !== $f['esperado'] || $f['palabras'] !== $f['esperado'] || ($f['ia'] !== null && $f['ia'] !== $f['esperado']))),
        ];
    }

    /* ---------- 2. KIRO ---------- */

    public static function kiro(callable $progreso): array
    {
        $casos = self::datos('kiro.json')['casos'];
        $ana = Base::uno("SELECT id, nombre, correo, telefono, rol FROM usuarios WHERE correo = 'ana@huellapp.mx'");
        $disponibles = array_column(Base::todos("SELECT m.id, m.nombre, m.especie, m.tamano FROM mascotas m JOIN refugios r ON r.id = m.refugio_id WHERE m.estatus = 'disponible' AND r.estado = 'aprobado'"), null, 'id');
        Base::ejecutar("DELETE FROM intentos_login WHERE clave LIKE 'kiro|%'"); // el límite por IP no debe afectar la evaluación
        $filas = [];
        $tiempos = [];
        foreach ($casos as $i => $c) {
            $s = new Solicitud('POST', '/kiro', [], ['mensaje' => $c['pregunta']], []);
            $s->usuario = $c['sesion'] ? $ana : null;
            $t = microtime(true);
            try {
                $r = Rutas\Kiro::preguntar($s);
            } catch (\Throwable $e) {
                $r = ['respuesta' => 'ERROR: ' . $e->getMessage(), 'mascotas' => [], 'reportes' => [], 'iaUsada' => false];
            }
            $ms = (microtime(true) - $t) * 1000;
            $tiempos[] = $ms;
            if (!($r['iaUsada'] ?? false)) { // sin IA (corte de red o saturación): un reintento antes de calificar
                sleep(3);
                try {
                    $r = Rutas\Kiro::preguntar($s);
                } catch (\Throwable) {
                }
            }
            $filas[] = ['pregunta' => $c['pregunta'], 'tipo' => $c['tipo'], 'sesion' => $c['sesion'], 'ms' => (int) $ms]
                + self::revisarKiro($r, $c['espera'], $disponibles);
            $progreso(sprintf('KIRO %d/%d', $i + 1, count($casos)));
        }
        // Lista plana (sin llaves): varias filas comparten el nombre de la verificación
        $verificaciones = array_merge(...array_map(static fn ($f) => array_values($f['verificaciones']), $filas));
        $conIa = array_filter($filas, static fn ($f) => $f['iaUsada']);
        return [
            'casos' => count($filas), 'conIa' => count($conIa),
            'casosCumplidos' => count(array_filter($filas, static fn ($f) => $f['cumple'])),
            'verificaciones' => count($verificaciones), 'verificacionesCumplidas' => count(array_filter($verificaciones)),
            'porTipo' => self::kiroPorTipo($filas),
            'tiemposMs' => self::resumenTiempos($tiempos),
            'filas' => $filas,
        ];
    }

    /** Revisa una respuesta de KIRO contra lo esperado. Cada verificación es true (cumple) o false. */
    private static function revisarKiro(array $r, array $espera, array $disponibles): array
    {
        $v = [];
        $mascotas = $r['mascotas'] ?? [];
        $reportes = $r['reportes'] ?? [];
        $texto = (string) ($r['respuesta'] ?? '');
        $v['respuesta no vacía'] = trim($texto) !== '';
        $v['sin ids ni Markdown'] = !preg_match('/\(id\s*[=:]|\*\*/iu', $texto);
        $v['solo mascotas disponibles'] = array_reduce($mascotas, static fn ($ok, $m) => $ok && isset($disponibles[$m['id']]), true);
        if (isset($espera['mascotasMin'])) $v["al menos {$espera['mascotasMin']} mascota(s)"] = count($mascotas) >= $espera['mascotasMin'];
        // Pedido muy general: también es válido que KIRO pregunte por el hogar antes de recomendar
        if (!empty($espera['mascotasOPregunta'])) $v['recomienda o pregunta por el hogar'] = count($mascotas) > 0 || str_contains($texto, '?');
        if (isset($espera['mascotasMax'])) $v["máximo {$espera['mascotasMax']} mascota(s)"] = count($mascotas) <= $espera['mascotasMax'];
        if (isset($espera['especie']) && $mascotas) $v["especie {$espera['especie']}"] = array_reduce($mascotas, static fn ($ok, $m) => $ok && $m['especie'] === $espera['especie'], true);
        if (isset($espera['tamanos']) && $mascotas) $v['tamaño adecuado'] = array_reduce($mascotas, static fn ($ok, $m) => $ok && in_array($m['tamano'], $espera['tamanos'], true), true);
        if (isset($espera['reportesMin'])) $v["al menos {$espera['reportesMin']} reporte(s)"] = count($reportes) >= $espera['reportesMin'];
        if (isset($espera['reportesMax'])) $v["máximo {$espera['reportesMax']} reporte(s)"] = count($reportes) <= $espera['reportesMax'];
        // La especie del reporte es opcional (los reportes demo no la traen): solo cuenta como error si es OTRA especie
        if (isset($espera['especieReporte']) && $reportes) $v["reportes de {$espera['especieReporte']}"] = array_reduce($reportes, static fn ($ok, $x) => $ok && in_array($x['especie'] ?? '', ['', null, $espera['especieReporte']], true), true);
        if (isset($espera['tipoReporte']) && $reportes) $v["reportes tipo {$espera['tipoReporte']}"] = array_reduce($reportes, static fn ($ok, $x) => $ok && $x['tipo'] === $espera['tipoReporte'], true);
        foreach ($espera['menciona'] ?? [] as $palabra) $v["menciona «$palabra»"] = mb_stripos($texto, $palabra) !== false;
        if (!empty($espera['sinTelefono'])) $v['no da teléfono ni correo'] = !preg_match('/\d{2}[\s-]?\d{4}[\s-]?\d{4}|@[\w-]+\./u', $texto);
        // Coherencia: las mascotas de las tarjetas aparecen nombradas en el texto
        if ($mascotas) $v['texto coherente con tarjetas'] = array_reduce($mascotas, static fn ($ok, $m) => $ok && mb_stripos($texto, $m['nombre']) !== false, true);
        return ['iaUsada' => (bool) ($r['iaUsada'] ?? false), 'respuesta' => $texto,
            'mascotas' => array_map(static fn ($m) => "{$m['nombre']} ({$m['especie']}, {$m['tamano']})", $mascotas),
            'reportes' => array_map(static fn ($x) => "{$x['tipo']} {$x['especie']} {$x['zona']}", $reportes),
            'verificaciones' => $v, 'cumple' => !in_array(false, $v, true)];
    }

    private static function kiroPorTipo(array $filas): array
    {
        $tipos = [];
        foreach ($filas as $f) {
            $tipos[$f['tipo']] ??= ['casos' => 0, 'cumplidos' => 0];
            $tipos[$f['tipo']]['casos']++;
            $tipos[$f['tipo']]['cumplidos'] += $f['cumple'] ? 1 : 0;
        }
        return $tipos;
    }

    /* ---------- 4. Coincidencias por foto (IA) ---------- */

    /**
     * Fotos reales en evaluacion/fotos/<mascota>/*.jpg (2 o más por mascota, de mascotas del equipo y con
     * su permiso). Cada foto se compara en UNA llamada contra otra foto de la misma mascota (debe dar alto)
     * y contra una de otra mascota (debe dar bajo), igual que la app compara un reporte con sus candidatos.
     * @return array|null null si no hay fotos suficientes
     */
    public static function coincidenciasFotos(callable $progreso): ?array
    {
        $carpetas = array_values(array_filter(glob(self::DIR . '/fotos/*', GLOB_ONLYDIR) ?: [], static fn ($d) => count(self::fotosDe($d)) >= 2));
        if (count($carpetas) < 2) {
            return null;
        }
        $filas = [];
        $tiempos = [];
        $total = array_sum(array_map(static fn ($d) => count(self::fotosDe($d)), $carpetas));
        $n = 0;
        foreach ($carpetas as $i => $carpeta) {
            $fotos = self::fotosDe($carpeta);
            $otra = self::fotosDe($carpetas[($i + 1) % count($carpetas)]);
            foreach ($fotos as $j => $foto) {
                $misma = $fotos[($j + 1) % count($fotos)];
                $distinta = $otra[$j % count($otra)];
                $t = microtime(true);
                $mismaFoto = [];
                $r = Gemini::compararFotos(self::dataUrl($foto), 'Mascota de la foto principal', ['misma' => self::dataUrl($misma), 'distinta' => self::dataUrl($distinta)], $mismaFoto);
                $tiempos[] = (microtime(true) - $t) * 1000;
                foreach (['misma' => true, 'distinta' => false] as $clave => $esperado) {
                    if (isset($r[$clave])) {
                        $filas[] = ['principal' => basename($carpeta) . '/' . basename($foto), 'candidata' => basename(dirname($clave === 'misma' ? $misma : $distinta)) . '/' . basename($clave === 'misma' ? $misma : $distinta),
                            'misma' => $esperado, 'puntaje' => $r[$clave]];
                    }
                }
                $progreso(sprintf('fotos %d/%d', ++$n, $total));
            }
        }
        $porUmbral = [];
        foreach ([40, 50, 60, 70, 80] as $u) {
            $porUmbral[$u] = self::metricas(array_map(static fn ($f) => [$f['misma'], $f['puntaje'] >= $u], $filas));
        }
        return ['mascotas' => count($carpetas), 'comparaciones' => count($filas), 'umbralDeLaApp' => Similitud::UMBRAL,
            'porUmbral' => $porUmbral, 'tiemposMs' => self::resumenTiempos($tiempos), 'detalle' => $filas];
    }

    /** @return list<string> */
    private static function fotosDe(string $carpeta): array
    {
        return array_values(array_filter(glob("$carpeta/*") ?: [], static fn ($f) => preg_match('/\.(jpe?g|png|webp)$/i', $f)));
    }

    private static function dataUrl(string $archivo): string
    {
        $mime = match (strtolower(pathinfo($archivo, PATHINFO_EXTENSION))) { 'png' => 'image/png', 'webp' => 'image/webp', default => 'image/jpeg' };
        return "data:$mime;base64," . base64_encode((string) file_get_contents($archivo));
    }

    /* ---------- 3. Coincidencias por texto (método base, sin IA) ---------- */

    public static function coincidenciasTexto(): array
    {
        $pares = self::datos('coincidencias-texto.json')['pares'];
        $puntajes = array_map(static fn ($p) => ['misma' => $p['misma'], 'puntaje' => Similitud::calcular($p['perdida'], $p['encontrada']),
            'perdida' => $p['perdida']['descripcion'], 'encontrada' => $p['encontrada']['descripcion']], $pares);
        $porUmbral = [];
        foreach ([20, 30, 40, 50, 60] as $u) {
            $porUmbral[$u] = self::metricas(array_map(static fn ($p) => [$p['misma'], $p['puntaje'] >= $u], $puntajes));
        }
        $mismas = array_column(array_filter($puntajes, static fn ($p) => $p['misma']), 'puntaje');
        $distintas = array_column(array_filter($puntajes, static fn ($p) => !$p['misma']), 'puntaje');
        return [
            'pares' => count($pares), 'umbralDeLaApp' => Similitud::UMBRAL, 'porUmbral' => $porUmbral,
            'promedioMismas' => round(array_sum($mismas) / max(1, count($mismas)), 1),
            'promedioDistintas' => round(array_sum($distintas) / max(1, count($distintas)), 1),
            'detalle' => $puntajes,
        ];
    }
}
