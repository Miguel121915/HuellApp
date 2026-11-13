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

    /**
     * Modelos a probar en orden. Cada modelo tiene su PROPIA cuota gratuita: si el principal está
     * saturado (503), sin cuota del día (429) o no responde, se pasa al siguiente.
     * Se cambian con GEMINI_MODEL (principal) y GEMINI_MODELOS_RESPALDO (separados por coma) en api/.env.
     * @return list<string>
     */
    private static function modelos(): array
    {
        // gemini-3.8-flash (y gemini-flash-latest) no contestan en la capa gratuita: se quedaban colgados
        // hasta el tiempo límite. gemini-3.5-flash responde en ~5 s; los respaldos, en 2 a 7 s.
        $principal = Config::obtener('GEMINI_MODEL') ?: 'gemini-3.5-flash';
        $respaldo = Config::obtener('GEMINI_MODELOS_RESPALDO') ?: 'gemini-3.5-flash-lite,gemini-3.6-flash';
        $lista = array_merge([$principal], array_map('trim', explode(',', $respaldo)));
        return array_values(array_unique(array_filter($lista, static fn ($m) => (bool) preg_match('/^[a-z0-9.\-]+$/', $m))));
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
     * @param array<string,bool> $mismaFoto  (salida) id => true si la candidata es la MISMA fotografía (misma toma),
     *                                       aunque esté recortada o comprimida: eso no prueba que sea el mismo animal hoy
     * @return array<int|string,int>|null  id => porcentaje 0-100 (solo los que se pudieron comparar), o null si no hay IA
     */
    public static function compararFotos(string $foto, string $descripcion, array $candidatos, array &$mismaFoto = []): ?array
    {
        $mismaFoto = [];
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
            (no solo de la misma raza). Indica también "mismaFoto": true si la candidata es LA MISMA
            FOTOGRAFÍA que la principal (la misma toma: mismo fondo, pose y luz, aunque esté recortada,
            comprimida, con otro tamaño, filtro o captura de pantalla); false si son fotos distintas,
            aunque sea el mismo animal. Responde SOLO con un arreglo JSON:
            [{"id": "<id de la candidata>", "similitud": 0-100, "mismaFoto": true|false, "motivo": "frase corta"}]
            TXT];
        $r = self::pedirJson($partes);
        if (!is_array($r)) {
            return null;
        }
        $mismaFoto = self::leerMismaFoto($r, $incluidos);
        $resultado = self::leerComparacion($r, $incluidos);
        if ($resultado === []) {
            // Antes esto se perdía sin aviso: queda en el log para poder revisarlo
            error_log('Gemini: la comparación de fotos no trajo similitudes reconocibles: ' . substr((string) json_encode($r, JSON_UNESCAPED_UNICODE), 0, 300));
        }
        return $resultado;
    }

    /**
     * Interpreta la respuesta de compararFotos aunque Gemini no use exactamente el formato pedido:
     *  - [{"id": "3", "similitud": 85}, ...]                 (el formato pedido)
     *  - {"resultados": [ ... ]} o cualquier otra clave que envuelva el arreglo
     *  - {"3": 85, "7": 40}                                  (id => porcentaje)
     *  - {"id": "3", "similitud": 85}                        (una sola candidata)
     * También acepta "id=3" o "CANDIDATA id=3", el porcentaje como texto ("85 %"), como fracción
     * (0.85) y otros nombres de campo (porcentaje, probabilidad, score).
     * @param list<string> $incluidos ids que sí se mandaron a comparar
     * @return array<string,int> id => porcentaje 0-100
     */
    public static function leerComparacion(array $r, array $incluidos): array
    {
        // Objeto que envuelve el arreglo: se toma el primer valor que sea una lista
        if (!array_is_list($r) && !isset($r['id'])) {
            foreach ($r as $valor) {
                if (is_array($valor) && array_is_list($valor)) {
                    $r = $valor;
                    break;
                }
            }
        }
        if (isset($r['id'])) {
            $r = [$r]; // una sola candidata
        }

        $resultado = [];
        foreach ($r as $clave => $fila) {
            if (is_array($fila)) {
                $id = self::idCandidata($fila['id'] ?? $fila['candidata'] ?? null);
                $valor = $fila['similitud'] ?? $fila['porcentaje'] ?? $fila['probabilidad'] ?? $fila['score'] ?? null;
            } else {
                $id = self::idCandidata($clave); // formato {"3": 85}
                $valor = $fila;
            }
            $porcentaje = self::porcentaje($valor);
            if ($id !== null && $porcentaje !== null && in_array($id, $incluidos, true)) {
                $resultado[$id] = $porcentaje;
            }
        }
        return $resultado;
    }

    /**
     * Candidatas que Gemini marcó como la MISMA fotografía ("mismaFoto": true).
     * @param list<string> $incluidos
     * @return array<string,bool> id => true
     */
    public static function leerMismaFoto(array $r, array $incluidos): array
    {
        if (!array_is_list($r) && !isset($r['id'])) {
            foreach ($r as $valor) {
                if (is_array($valor) && array_is_list($valor)) {
                    $r = $valor;
                    break;
                }
            }
        }
        if (isset($r['id'])) {
            $r = [$r];
        }
        $resultado = [];
        foreach ($r as $fila) {
            if (!is_array($fila)) {
                continue;
            }
            $id = self::idCandidata($fila['id'] ?? $fila['candidata'] ?? null);
            $valor = $fila['mismaFoto'] ?? $fila['misma_foto'] ?? false;
            $esMisma = $valor === true || (is_string($valor) && in_array(strtolower(trim($valor)), ['true', 'si', 'sí', 'yes'], true));
            if ($id !== null && $esMisma && in_array($id, $incluidos, true)) {
                $resultado[$id] = true;
            }
        }
        return $resultado;
    }

    private static function idCandidata(mixed $valor): ?string
    {
        if (is_int($valor)) {
            return (string) $valor;
        }
        return is_string($valor) && preg_match('/(\d+)\s*$/', $valor, $m) ? $m[1] : null;
    }

    private static function porcentaje(mixed $valor): ?int
    {
        if (is_string($valor)) {
            $valor = str_replace(',', '.', trim(str_replace('%', '', $valor)));
        }
        if (!is_numeric($valor)) {
            return null;
        }
        $numero = (float) $valor;
        if ($numero > 0 && $numero < 1) {
            $numero *= 100; // un porcentaje entero no cae entre 0 y 1: vino como fracción (0.85 = 85 %)
        }
        return max(0, min(100, (int) round($numero)));
    }

    /** Parte "inline_data" de una foto subida (/uploads/imagenes/...), o null si no existe. */
    /**
     * Imagen para Gemini desde una foto ya guardada (/uploads/imagenes/…) o recién elegida en el
     * formulario (data URL JPEG/PNG/WebP, aún sin guardar). null si no es una foto válida.
     */
    public static function imagenDeFoto(string $foto): ?array
    {
        if (preg_match('#^data:(image/(?:jpeg|png|webp));base64,([A-Za-z0-9+/=]+)$#', $foto, $m)) {
            $bytes = base64_decode($m[2], true);
            // Las fotos del formulario ya llegan reducidas; se rechaza lo que no sea una imagen real o pese demasiado
            if ($bytes === false || strlen($bytes) > 6 * 1024 * 1024 || @getimagesizefromstring($bytes) === false) {
                return null;
            }
            return ['inline_data' => ['mime_type' => $m[1], 'data' => $m[2]]];
        }
        return self::imagen($foto);
    }

    /**
     * Borrador de descripción de una mascota para su publicación (HU-17). Usa los datos del formulario
     * y, si hay, la foto. Devuelve el texto o null si no hay IA o falló.
     */
    public static function borradorDescripcion(string $datos, ?array $imagen, int $maximo): ?string
    {
        if (!self::disponible()) {
            return null;
        }
        $prompt = <<<TXT
            Eres el asistente de HuellApp, una plataforma de adopción de mascotas de refugios en México.
            Escribe un BORRADOR de la descripción de esta mascota para su ficha de adopción, que el refugio revisará.
            Datos que dio el refugio:
            $datos
            Reglas: en español de México con ortografía y acentos correctos, cálido y honesto, en 2 a 4 frases y máximo
            $maximo caracteres. Habla de su carácter, con quién podría convivir y qué hogar le conviene.
            El carácter, los gustos y la convivencia salen SOLO de las notas del refugio: no inventes que es tranquilo,
            juguetón, que le gusta correr, etc. Si no hay notas, describe solo lo que se ve en la foto (aspecto) y qué
            hogar le convendría por su tamaño y edad, e invita a conocerlo. Si algo no se sabe (por ejemplo, si convive
            con gatos), no lo afirmes. No repitas edad, raza ni salud tal cual (ya salen en la ficha).
            Sin emojis, sin hashtags, sin Markdown.
            Responde SOLO con este JSON: {"descripcion": "..."}
            TXT;
        $r = self::pedirJson(array_values(array_filter([$imagen, ['text' => $prompt]])), null, null, 0.6, 20);
        $texto = is_array($r) && is_string($r['descripcion'] ?? null) ? trim($r['descripcion']) : '';
        $texto = trim(preg_replace('/(\*\*|__)(.+?)\1/u', '$2', $texto) ?? $texto);
        if ($texto === '') {
            return null;
        }
        // Si se pasa del límite, se corta en el último punto que quepa
        if (mb_strlen($texto) > $maximo) {
            $corto = mb_substr($texto, 0, $maximo);
            $punto = mb_strrpos($corto, '.');
            $texto = $punto !== false && $punto > $maximo / 2 ? mb_substr($corto, 0, $punto + 1) : rtrim($corto) . '…';
        }
        return $texto;
    }

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

    /**
     * Conversación con instrucciones de sistema (KIRO, HU-7). $mensajes = [['rol' => 'usuario'|'kiro', 'texto' => '...'], ...]
     * en orden; el último debe ser del usuario. Devuelve el JSON que pidan las instrucciones, o null sin IA.
     */
    public static function conversar(string $instrucciones, array $mensajes, float $temperatura = 0.5): mixed
    {
        if (!self::disponible() || $mensajes === []) {
            return null;
        }
        $contents = array_map(static fn (array $m): array => [
            'role' => $m['rol'] === 'kiro' ? 'model' : 'user',
            'parts' => [['text' => $m['texto']]],
        ], $mensajes);
        // Es un chat: la persona está esperando. Si un modelo tarda más de 15 s se pasa al siguiente.
        return self::pedirJson([], $contents, $instrucciones, $temperatura, 15);
    }

    /**
     * Llama a Gemini pidiendo JSON. Reintenta si está saturado. Devuelve el JSON decodificado o null.
     * $limite = segundos máximos de espera por modelo (las fotos van en segundo plano y pueden esperar más).
     */
    private static function pedirJson(array $partes, ?array $contents = null, ?string $sistema = null, float $temperatura = 0.2, int $limite = 30): mixed
    {
        $cuerpo = json_encode([
            'contents' => $contents ?? [['role' => 'user', 'parts' => $partes]],
            'generationConfig' => ['responseMimeType' => 'application/json', 'temperature' => $temperatura],
        ] + ($sistema !== null ? ['systemInstruction' => ['parts' => [['text' => $sistema]]]] : []));
        // Un intento por modelo: si uno está saturado o sin cuota, el siguiente suele responder de inmediato
        foreach (self::modelos() as $i => $modelo) {
            [$estado, $respuesta] = self::post(sprintf(self::URL, $modelo), (string) $cuerpo, $limite);
            if ($estado === 200) {
                $datos = json_decode($respuesta, true);
                $texto = $datos['candidates'][0]['content']['parts'][0]['text'] ?? null;
                return is_string($texto) ? self::extraerJson($texto) : null;
            }
            error_log("Gemini ($modelo) respondió $estado: " . substr(preg_replace('/\s+/', ' ', $respuesta), 0, 200));
            if (!in_array($estado, [0, 404, 429, 500, 503], true)) {
                return null; // error de la petición (no del modelo): otro modelo fallaría igual
            }
            if ($i === 0 && $estado === 503) {
                usleep(1_000_000); // saturación momentánea: un respiro antes de cambiar de modelo
            }
        }
        return null;
    }

    /**
     * JSON de la respuesta del modelo. Si viene entre ``` o con una frase antes o después,
     * se toma el bloque que va del primer [ o { al último ] o }. null si no hay JSON.
     */
    public static function extraerJson(string $texto): mixed
    {
        $texto = trim(preg_replace('/^```(?:json)?|```$/m', '', $texto) ?? $texto);
        $json = json_decode($texto, true);
        if ($json !== null) {
            return $json;
        }
        $inicio = strcspn($texto, '[{');
        $fin = max((int) strrpos($texto, ']'), (int) strrpos($texto, '}'));
        if ($inicio < strlen($texto) && $fin > $inicio) {
            return json_decode(substr($texto, $inicio, $fin - $inicio + 1), true);
        }
        return null;
    }

    /** @return array{0:int,1:string} código HTTP (0 = sin conexión) y cuerpo */
    private static function post(string $url, string $cuerpo, int $limite = 30): array
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
            CURLOPT_TIMEOUT => $limite, // si no contesta a tiempo se pasa al siguiente modelo
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
