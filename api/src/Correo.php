<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Correo — Envía correos con Gmail (Google) o con Brevo. Se usa el primero que esté configurado en api/.env:
 *
 * 1) GMAIL (Google, gratis, ~500 correos al día) con una «contraseña de aplicación»:
 *      GMAIL_USUARIO=tu-cuenta@gmail.com
 *      GMAIL_CONTRASENA_APP=abcd efgh ijkl mnop   (myaccount.google.com/apppasswords; requiere verificación en 2 pasos)
 *    Se conecta a smtp.gmail.com por el puerto 465 (SSL). Los correos salen desde GMAIL_USUARIO.
 *
 * 2) BREVO (https://www.brevo.com, gratis: 300 correos al día), por su API web (HTTPS):
 *      BREVO_API_KEY=...               clave de API de Brevo (SMTP & API → API Keys)
 *      CORREO_REMITENTE=...            correo verificado como remitente en Brevo
 *
 * En ambos casos CORREO_REMITENTE_NOMBRE (por defecto «HuellApp») es el nombre que ve quien recibe.
 *
 * Sin ninguno de los dos la API funciona en MODO DE PRUEBA: no envía nada y escribe el correo (con el
 * código) en la consola donde corre "php artisan serve". Así se puede probar todo sin cuentas.
 */
final class Correo
{
    private const URL = 'https://api.brevo.com/v3/smtp/email';
    private const GMAIL_SERVIDOR = 'ssl://smtp.gmail.com:465';

    public static function usaGmail(): bool
    {
        return Config::obtener('GMAIL_USUARIO') !== '' && Config::obtener('GMAIL_CONTRASENA_APP') !== '';
    }

    public static function modoPrueba(): bool
    {
        return !self::usaGmail() && (Config::obtener('BREVO_API_KEY') === '' || Config::obtener('CORREO_REMITENTE') === '');
    }

    /** Envía un correo. Devuelve false si Gmail o Brevo no lo aceptaron (se anota el motivo en la consola). */
    public static function enviar(string $para, string $nombre, string $asunto, string $texto, string $html): bool
    {
        if (self::modoPrueba()) {
            error_log("[CORREO DE PRUEBA] Para: $para · Asunto: $asunto\n" . $texto);
            return true;
        }
        if (self::usaGmail()) {
            return self::enviarGmail($para, $nombre, $asunto, $texto, $html);
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

    /**
     * Envía por el SMTP de Gmail (SSL, puerto 465) con la contraseña de aplicación. Sin librerías:
     * se habla el protocolo directamente. Nunca se anota la contraseña, solo la respuesta del servidor.
     */
    private static function enviarGmail(string $para, string $nombre, string $asunto, string $texto, string $html): bool
    {
        $usuario = trim(Config::obtener('GMAIL_USUARIO'));
        $clave = str_replace(' ', '', Config::obtener('GMAIL_CONTRASENA_APP')); // Google la muestra con espacios
        $limpiar = static fn (string $t): string => str_replace(["\r", "\n"], '', $t); // evita inyectar cabeceras
        $para = $limpiar($para);

        $socket = @stream_socket_client(self::GMAIL_SERVIDOR, $errno, $error, 10);
        if ($socket === false) {
            error_log("Gmail: no se pudo conectar con smtp.gmail.com ($errno $error). Revisa tu internet o que el puerto 465 no esté bloqueado.");
            return false;
        }
        stream_set_timeout($socket, 15);

        // Lee la respuesta (puede ser de varias líneas: «250-…» y la última «250 …») y revisa el código
        $responder = static function (int $esperado) use ($socket): string {
            $respuesta = '';
            while (($linea = fgets($socket, 1024)) !== false) {
                $respuesta .= $linea;
                if (strlen($linea) < 4 || $linea[3] === ' ') {
                    break;
                }
            }
            if ((int) substr($respuesta, 0, 3) !== $esperado) {
                throw new \RuntimeException(trim($respuesta) ?: 'sin respuesta del servidor');
            }
            return $respuesta;
        };
        $comando = static function (string $linea, int $esperado) use ($socket, $responder): string {
            fwrite($socket, $linea . "\r\n");
            return $responder($esperado);
        };

        $codificar = static fn (string $t): string => '=?UTF-8?B?' . base64_encode($t) . '?=';
        $remitente = Config::obtener('CORREO_REMITENTE_NOMBRE') ?: 'HuellApp';
        $limite = 'huellapp-' . bin2hex(random_bytes(12));
        $dominio = substr(strrchr($usuario, '@') ?: '@gmail.com', 1);
        $mensaje = implode("\r\n", [
            'From: ' . $codificar($limpiar($remitente)) . " <$usuario>",
            'To: ' . $codificar($limpiar($nombre)) . " <$para>",
            'Subject: ' . $codificar($limpiar($asunto)),
            'Date: ' . date('r'),
            'Message-ID: <' . bin2hex(random_bytes(16)) . "@$dominio>",
            'MIME-Version: 1.0',
            "Content-Type: multipart/alternative; boundary=\"$limite\"",
            '',
            "--$limite",
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: base64',
            '',
            rtrim(chunk_split(base64_encode($texto), 76, "\r\n")),
            "--$limite",
            'Content-Type: text/html; charset=UTF-8',
            'Content-Transfer-Encoding: base64',
            '',
            rtrim(chunk_split(base64_encode($html), 76, "\r\n")),
            "--$limite--",
        ]);
        // El cuerpo va en base64, así que ninguna línea empieza con «.» (no hace falta duplicar puntos)

        try {
            $responder(220);
            $comando('EHLO huellapp', 250);
            $comando('AUTH LOGIN', 334);
            $comando(base64_encode($usuario), 334);
            try {
                $comando(base64_encode($clave), 235);
            } catch (\RuntimeException $e) {
                throw new \RuntimeException('Google rechazó GMAIL_USUARIO o GMAIL_CONTRASENA_APP (usa una contraseña de aplicación, no la normal). ' . $e->getMessage());
            }
            $comando("MAIL FROM:<$usuario>", 250);
            $comando("RCPT TO:<$para>", 250);
            $comando('DATA', 354);
            $comando($mensaje . "\r\n.", 250);
            fwrite($socket, "QUIT\r\n"); // el correo ya fue aceptado: la respuesta al cierre no importa
            return true;
        } catch (\RuntimeException $e) {
            error_log('Gmail: no se pudo enviar el correo. ' . substr($e->getMessage(), 0, 300));
            return false;
        } finally {
            fclose($socket);
        }
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
