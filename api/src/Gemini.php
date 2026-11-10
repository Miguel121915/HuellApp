<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Gemini — Inteligencia artificial de Google para los reportes de mascotas (HU-5 y HU-8).
 * Reemplaza al servidor Node anterior (backend/server.js): ahora todo pasa por esta API.
 *
 *  - analizarMascota(): especie, raza, color, tamaño y señas a partir de la foto (y la descripción).
 *  - compararFotos():   qué tan probable es que la mascota de una foto sea la misma de otras fotos.
 *
 * Configuración en api/.env:  GEMINI_API_KEY=...  (y opcional GEMINI_MODEL).
 * Si no hay clave, no hay internet o Gemini falla, todo sigue funcionando sin IA: los reportes se
 * guardan y las coincidencias se calculan comparando el texto (Similitud.php).
 */
final class Gemini
{
    private const URL = 'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent';
    /** Gemini acepta hasta ~20 MB por petición (en base64); se deja margen. */
    private const MAX_BYTES_FOTOS = 12 * 1024 * 1024;

    public static function disponible(): bool
    {
        return Config::obtener('GEMINI_API_KEY') !== '';
    }

    private static function modelo(): string
    {
        $modelo = Config::obtener('GEMINI_MODEL');
        // Mismo modelo por defecto que usaba el servidor Node; se cambia con GEMINI_MODEL en api/.env
        return preg_match('/^[a-z0-9.\-]+$/', $modelo) ? $modelo : 'gemini-3.8-flash';
    }

    /**
     * Rasgos de la mascota de la foto. null si no hay IA o falló.
     * @return array{especie:string, raza:string, color:string, tamano:string, senas:string, resumen:string}|null
     */
    public static function analizarMascota(string $foto, string $descripcion): ?array
    {
        $imagen = self::imagen($foto);
        if (!self::disponible() || $imagen === null) {
            return null;
        }
        $prompt = <<<TXT
            Eres el asistente de HuellApp, una plataforma para encontrar mascotas perdidas en México.
            Mira la foto y la descripción que escribió la persona, y describe a la mascota en español.
            Descripción de la persona: «{$descripcion}»
            Responde SOLO con este JSON (textos cortos; si algo no se ve, escribe "No se distingue"):
            {"especie": "perro|gato|otro", "raza": "...", "color": "...", "tamano": "pequeño|mediano|grande",
             "senas": "collar, manchas, cicatrices u otras señas visibles", "resumen": "una frase para la alerta"}
            TXT;
        $r = self::pedirJson([$imagen, ['text' => $prompt]]);
        if (!is_array($r)) {
            return null;
        }
        $texto = static fn (string $clave, int $max): string => mb_substr(trim((string) ($r[$clave] ?? '')), 0, $max);
        $especie = strtolower($texto('especie', 10));
        return [
            'especie' => in_array($especie, ['perro', 'gato'], true) ? $especie : 'otro',
            'raza' => $texto('raza', 60), 'color' => $texto('color', 80), 'tamano' => $texto('tamano', 20),
            'senas' => $texto('senas', 200), 'resumen' => $texto('resumen', 200),
        ];
    }

    /**
     * Compara la foto de un reporte con las fotos de varios candidatos (una sola llamada a Gemini).
     * @param array<int|string,string> $candidatos  id => ruta de la foto
     * @return array<int|string,int>|null  id => porcentaje 0-100 (solo los que se pudieron comparar), o null si no hay IA
     */
    public static function compararFotos(string $foto, string $descripcion, array $candidatos): ?array
    {
        $principal = self::imagen($foto);
        if (!self::disponible() || $principal === null || $candidatos === []) {
            return null;
        }
        $partes = [['text' => 'FOTO PRINCIPAL (la mascota del reporte nuevo). Descripción: «' . $descripcion . '»'], $principal];
        $bytes = strlen($principal['inline_data']['data']);
        $incluidos = [];
        foreach ($candidatos as $id => $ruta) {
            $imagen = self::imagen($ruta);
            if ($imagen === null || $bytes + strlen($imagen['inline_data']['data']) > self::MAX_BYTES_FOTOS * 4 / 3) {
                continue;
            }
            $bytes += strlen($imagen['inline_data']['data']);
            $partes[] = ['text' => "CANDIDATA id=$id"];
            $partes[] = $imagen;
            $incluidos[] = (string) $id;
        }
        if ($incluidos === []) {
            return [];
        }
        $partes[] = ['text' => <<<TXT
            Compara la mascota de la FOTO PRINCIPAL con cada CANDIDATA. Fíjate en especie, raza, colores y
            su distribución, manchas, forma de orejas y cola, tamaño aparente y collar. Ignora el fondo, la luz
            y la pose. Para cada candidata da la probabilidad (0 a 100) de que sea EXACTAMENTE el mismo animal
            (no solo de la misma raza). Responde SOLO con un arreglo JSON:
            [{"id": "<id de la candidata>", "similitud": 0-100, "motivo": "frase corta"}]
            TXT];
        $r = self::pedirJson($partes);
        if (!is_array($r)) {
            return null;
        }
        $resultado = [];
        foreach ($r as $fila) {
            $id = is_array($fila) ? (string) ($fila['id'] ?? '') : '';
            if (in_array($id, $incluidos, true) && is_numeric($fila['similitud'] ?? null)) {
                $resultado[$id] = max(0, min(100, (int) round((float) $fila['similitud'])));
            }
        }
        return $resultado;
    }

    /** Parte "inline_data" de una foto subida (/uploads/imagenes/...), o null si no existe. */
    private static function imagen(string $foto): ?array
    {
        if (!str_starts_with($foto, '/uploads/imagenes/')) {
            return null;
        }
        $ruta = Archivos::dirImagenes() . '/' . basename($foto);
        $datos = is_file($ruta) ? @file_get_contents($ruta) : false;
        if ($datos === false || $datos === '') {
            return null;
        }
        $mime = match (strtolower(pathinfo($ruta, PATHINFO_EXTENSION))) {
            'png' => 'image/png', 'webp' => 'image/webp', default => 'image/jpeg',
        };
        return ['inline_data' => ['mime_type' => $mime, 'data' => base64_encode($datos)]];
    }

    /** Llama a Gemini pidiendo JSON. Reintenta si está saturado. Devuelve el JSON decodificado o null. */
    private static function pedirJson(array $partes): mixed
    {
        $cuerpo = json_encode([
            'contents' => [['role' => 'user', 'parts' => $partes]],
            'generationConfig' => ['responseMimeType' => 'application/json', 'temperature' => 0.2],
        ]);
        for ($intento = 1; $intento <= 3; $intento++) {
            [$estado, $respuesta] = self::post(sprintf(self::URL, self::modelo()), (string) $cuerpo);
            if ($estado === 200) {
                $datos = json_decode($respuesta, true);
                $texto = $datos['candidates'][0]['content']['parts'][0]['text'] ?? null;
                if (!is_string($texto)) {
                    break;
                }
                $texto = trim(preg_replace('/^```(?:json)?|```$/m', '', $texto) ?? $texto);
                $json = json_decode($texto, true);
                return $json ?? null;
            }
            if (!in_array($estado, [429, 500, 503], true) || $intento === 3) {
                error_log("Gemini respondió $estado: " . substr($respuesta, 0, 300));
                break;
            }
            usleep(1_500_000 * 2 ** ($intento - 1)); // 1.5 s, 3 s
        }
        return null;
    }

    /** @return array{0:int,1:string} código HTTP (0 = sin conexión) y cuerpo */
    private static function post(string $url, string $cuerpo): array
    {
        if (!function_exists('curl_init')) {
            error_log('Gemini: falta la extensión curl de PHP.');
            return [0, ''];
        }
        $c = curl_init($url);
        curl_setopt_array($c, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $cuerpo,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'x-goog-api-key: ' . Config::obtener('GEMINI_API_KEY')],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT => 45,
        ]);
        $respuesta = curl_exec($c);
        $estado = $respuesta === false ? 0 : (int) curl_getinfo($c, CURLINFO_RESPONSE_CODE);
        if ($respuesta === false) {
            error_log('Gemini: sin conexión (' . curl_error($c) . ')');
        }
        curl_close($c);
        return [$estado, (string) $respuesta];
    }
}
