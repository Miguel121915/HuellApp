<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Archivos — Guarda imágenes y documentos que llegan como data URL (base64).
 *
 * - Las IMÁGENES (mascotas, foro, reportes) van a storage/uploads/imagenes y son públicas.
 * - Los DOCUMENTOS de los refugios (acta, identificación...) van a storage/uploads/documentos y NO
 *   se sirven públicamente: solo un administrador puede verlos por una ruta protegida.
 * Se valida el tipo real revisando los primeros bytes del archivo, no solo lo que diga el cliente.
 */
final class Archivos
{
    private const MAX_IMAGEN = 3 * 1024 * 1024;    // 3 MB (el sitio ya las reduce antes de enviarlas)
    private const MAX_DOCUMENTO = 5 * 1024 * 1024; // 5 MB

    /** Fotos del sitio que se pueden usar sin subirlas (ilustraciones incluidas en assets/). */
    private const RUTA_ESTATICA = '#^assets/img/mascotas/[a-z0-9-]+\.svg$#';
    private const RUTA_SUBIDA = '#^/uploads/imagenes/[0-9a-f-]{36}\.(jpg|png|webp)$#';

    private const EXTENSIONES = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'application/pdf' => 'pdf'];
    private const TIPOS_POR_EXTENSION = ['jpg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp'];

    public static function dirImagenes(): string
    {
        return self::asegurar(Config::dirUploads() . '/imagenes');
    }

    public static function dirDocumentos(): string
    {
        return self::asegurar(Config::dirUploads() . '/documentos');
    }

    private static function asegurar(string $dir): string
    {
        if (!is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        return $dir;
    }

    /** ¿Los primeros bytes corresponden al formato indicado? */
    private static function firmaValida(string $mime, string $b): bool
    {
        return match ($mime) {
            'image/jpeg' => str_starts_with($b, "\xFF\xD8\xFF"),
            'image/png' => str_starts_with($b, "\x89PNG\r\n\x1A\n"),
            'image/webp' => substr($b, 0, 4) === 'RIFF' && substr($b, 8, 4) === 'WEBP',
            'application/pdf' => str_starts_with($b, '%PDF-'),
            default => false,
        };
    }

    /** Decodifica "data:<mime>;base64,<datos>" y comprueba tipo, tamaño y firma. */
    private static function decodificar(mixed $dataUrl, array $permitidos, int $maxBytes, string $nombre): array
    {
        // Sin expresiones regulares sobre el contenido: en archivos grandes podrían fallar
        if (!is_string($dataUrl) || !str_starts_with($dataUrl, 'data:') || ($corte = strpos($dataUrl, ';base64,')) === false) {
            throw new ErrorHttp(400, "$nombre: formato no permitido.");
        }
        $mime = substr($dataUrl, 5, $corte - 5);
        if (!in_array($mime, $permitidos, true)) {
            throw new ErrorHttp(400, "$nombre: formato no permitido.");
        }
        $datos = base64_decode(str_replace(["\r", "\n"], '', substr($dataUrl, $corte + 8)), true);
        if ($datos === false || $datos === '' || strlen($datos) > $maxBytes) {
            throw new ErrorHttp(400, "$nombre: el archivo está vacío o pesa más de " . intdiv($maxBytes, 1048576) . ' MB.');
        }
        if (!self::firmaValida($mime, $datos)) {
            throw new ErrorHttp(400, "$nombre: el contenido no corresponde a un archivo $mime.");
        }
        return [$mime, $datos];
    }

    private static function uuid(): string
    {
        $b = random_bytes(16);
        $b[6] = chr(ord($b[6]) & 0x0f | 0x40);
        $b[8] = chr(ord($b[8]) & 0x3f | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
    }

    /**
     * Resuelve el valor de una foto recibido del cliente y devuelve lo que se guarda en la BD:
     *  - ""  ................................ sin foto
     *  - data URL (jpeg/png/webp) ........... se guarda en disco → "/uploads/imagenes/<uuid>.jpg"
     *  - ruta de una ilustración del sitio .. se conserva
     *  - ruta de una foto ya subida ......... se conserva (si el archivo existe)
     */
    public static function resolverFoto(mixed $valor, string $nombre = 'La foto'): string
    {
        if ($valor === null || $valor === '') {
            return '';
        }
        if (!is_string($valor)) {
            throw new ErrorHttp(400, "$nombre no es válida.");
        }
        if (preg_match(self::RUTA_ESTATICA, $valor)) {
            return $valor;
        }
        if (preg_match(self::RUTA_SUBIDA, $valor)) {
            if (!is_file(self::dirImagenes() . '/' . basename($valor))) {
                throw new ErrorHttp(400, "$nombre ya no existe.");
            }
            return $valor;
        }
        [$mime, $datos] = self::decodificar($valor, ['image/jpeg', 'image/png', 'image/webp'], self::MAX_IMAGEN, $nombre);
        $archivo = self::uuid() . '.' . self::EXTENSIONES[$mime];
        file_put_contents(self::dirImagenes() . '/' . $archivo, $datos);
        return '/uploads/imagenes/' . $archivo;
    }

    /** Guarda un documento de refugio (PDF, JPG o PNG). Devuelve los datos para la tabla documentos_refugio. */
    public static function guardarDocumento(mixed $dataUrl, string $nombre): array
    {
        [$mime, $datos] = self::decodificar($dataUrl, ['application/pdf', 'image/jpeg', 'image/png'], self::MAX_DOCUMENTO, $nombre);
        $archivo = self::uuid() . '.' . self::EXTENSIONES[$mime];
        file_put_contents(self::dirDocumentos() . '/' . $archivo, $datos);
        return ['archivo' => $archivo, 'mime' => $mime, 'tamano' => strlen($datos)];
    }

    public static function rutaDocumento(string $archivo): string
    {
        return self::dirDocumentos() . '/' . basename($archivo); // basename evita rutas con ../
    }

    /** @param list<string> $archivos */
    public static function borrarDocumentos(array $archivos): void
    {
        foreach ($archivos as $archivo) {
            @unlink(self::rutaDocumento($archivo));
        }
    }

    /** Entrega una foto subida (pública). Lo llama public/index.php para /uploads/imagenes/<archivo>. */
    public static function servirImagen(string $archivo): void
    {
        $ruta = self::dirImagenes() . '/' . basename($archivo);
        $extension = strtolower(pathinfo($ruta, PATHINFO_EXTENSION));
        if (!isset(self::TIPOS_POR_EXTENSION[$extension]) || !is_file($ruta)) {
            http_response_code(404);
            return;
        }
        header('Content-Type: ' . self::TIPOS_POR_EXTENSION[$extension]);
        header('Cache-Control: public, max-age=604800');
        header('X-Content-Type-Options: nosniff');
        header('Content-Length: ' . filesize($ruta));
        readfile($ruta);
    }
}
