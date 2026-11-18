<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Correo — Envía correos con Brevo (https://www.brevo.com, plan gratuito: 300 correos al día).
 *
 * Configuración en api/.env:
 *   BREVO_API_KEY=...               clave de API de Brevo (SMTP & API → API Keys)
 *   CORREO_REMITENTE=...            correo verificado como remitente en Brevo
 *   CORREO_REMITENTE_NOMBRE=HuellApp
 *
 * Sin BREVO_API_KEY la API funciona en MODO DE PRUEBA: no envía nada y escribe el correo (con el
 * código) en la consola donde corre "php artisan serve". Así se puede probar todo sin cuenta de Brevo.
 *
 * Se usa la API web de Brevo (HTTPS) y no SMTP: no necesita librerías y funciona aunque la nube
 * bloquee los puertos de correo.
 */
final class Correo
{
    private const URL = 'https://api.brevo.com/v3/smtp/email';

    public static function modoPrueba(): bool
    {
        return Config::obtener('BREVO_API_KEY') === '' || Config::obtener('CORREO_REMITENTE') === '';
    }

    /** Envía un correo. Devuelve false si Brevo no lo aceptó (se anota el motivo en la consola). */
    public static function enviar(string $para, string $nombre, string $asunto, string $texto, string $html): bool
    {
        if (self::modoPrueba()) {
            error_log("[CORREO DE PRUEBA] Para: $para · Asunto: $asunto\n" . $texto);
            return true;
        }
        $cuerpo = json_encode([
            'sender' => ['name' => Config::obtener('CORREO_REMITENTE_NOMBRE') ?: 'HuellApp', 'email' => Config::obtener('CORREO_REMITENTE')],
            'to' => [['email' => $para, 'name' => $nombre]],
            'subject' => $asunto,
            'textContent' => $texto,
            'htmlContent' => $html,
        ], JSON_UNESCAPED_UNICODE);
        $cabeceras = ['Content-Type: application/json', 'Accept: application/json', 'api-key: ' . Config::obtener('BREVO_API_KEY')];

        if (function_exists('curl_init')) {
            $c = curl_init(self::URL);
            curl_setopt_array($c, [
                CURLOPT_POST => true, CURLOPT_POSTFIELDS => $cuerpo, CURLOPT_HTTPHEADER => $cabeceras,
                CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10, CURLOPT_CONNECTTIMEOUT => 5,
            ]);
            $respuesta = curl_exec($c);
            $estado = (int) curl_getinfo($c, CURLINFO_HTTP_CODE);
            curl_close($c);
        } else {
            $contexto = stream_context_create(['http' => [
                'method' => 'POST', 'header' => implode("\r\n", $cabeceras), 'content' => $cuerpo,
                'timeout' => 10, 'ignore_errors' => true,
            ]]);
            $respuesta = @file_get_contents(self::URL, false, $contexto);
            $estado = preg_match('#^HTTP/\S+ (\d{3})#', $http_response_header[0] ?? '', $m) ? (int) $m[1] : 0;
        }
        if ($estado < 200 || $estado >= 300) {
            // Nunca se anota la clave: solo el estado y el mensaje de Brevo
            error_log("Brevo: no se pudo enviar el correo ($estado) " . (is_string($respuesta) ? substr($respuesta, 0, 300) : ''));
            return false;
        }
        return true;
    }

    /** Correo con un código de 6 dígitos (confirmar correo o recuperar contraseña). */
    public static function enviarCodigo(string $para, string $nombre, string $codigo, string $proposito): bool
    {
        $esRecuperar = $proposito === 'recuperar';
        $asunto = $esRecuperar ? "Tu código para recuperar tu contraseña: $codigo" : "Tu código de HuellApp: $codigo";
        $intro = $esRecuperar
            ? 'Recibimos una solicitud para cambiar la contraseña de tu cuenta de HuellApp.'
            : '¡Gracias por unirte a HuellApp! Confirma tu correo para activar tu cuenta.';
        $cierre = $esRecuperar
            ? 'Si no pediste cambiar tu contraseña, ignora este correo: tu cuenta sigue igual.'
            : 'Si no creaste una cuenta en HuellApp, ignora este correo.';
        $primerNombre = explode(' ', trim($nombre))[0] ?: 'hola';

        $texto = "Hola, $primerNombre.\n\n$intro\n\nTu código es: $codigo\n\nVence en 15 minutos.\n\n$cierre\n\n— El equipo de HuellApp";
        $e = static fn (string $t): string => htmlspecialchars($t, ENT_QUOTES, 'UTF-8');
        $html = '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;color:#14312e">'
            . '<h2 style="color:#1b4f4a;margin:0 0 12px">HuellApp 🐾</h2>'
            . '<p>Hola, ' . $e($primerNombre) . '.</p><p>' . $e($intro) . '</p>'
            . '<p style="margin:24px 0 8px">Tu código es:</p>'
            . '<p style="font-size:34px;font-weight:bold;letter-spacing:8px;background:#e6f8f5;color:#1b4f4a;'
            . 'padding:14px 18px;border-radius:12px;text-align:center;margin:0">' . $e($codigo) . '</p>'
            . '<p style="color:#3f5f5b">Vence en 15 minutos.</p>'
            . '<p style="color:#3f5f5b;font-size:13px">' . $e($cierre) . '</p></div>';
        return self::enviar($para, $nombre, $asunto, $texto, $html);
    }
}
