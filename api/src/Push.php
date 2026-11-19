<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Push — Notificaciones push reales (HU-19) con Firebase Cloud Messaging (FCM, API HTTP v1).
 * Llegan aunque la página o la app estén cerradas.
 *
 * Configuración en api/.env:
 *   FIREBASE_CREDENCIALES=C:\oracle\firebase\huellapp-firebase.json   (cuenta de servicio, SECRETA)
 *
 * Cómo funciona, sin librerías:
 *  1. Con la llave privada de la cuenta de servicio se firma un JWT (RS256) y se cambia en Google por
 *     un token de acceso de 1 hora (se guarda en caché para no pedirlo en cada aviso).
 *  2. Cada aviso que se crea (Avisos::crear) se manda a todos los navegadores y celulares de esa cuenta.
 *  3. Si FCM responde que un token ya no existe (desinstaló la app, quitó el permiso), se borra.
 *
 * Nunca lanza errores: si Firebase falla, el aviso igual queda en la campana.
 */
final class Push
{
    private const ALCANCE = 'https://www.googleapis.com/auth/firebase.messaging';
    private static ?array $credenciales = null;

    public static function activo(): bool
    {
        return self::credenciales() !== null;
    }

    /** Lee el JSON de la cuenta de servicio (o null si no está configurado o no se puede leer). */
    private static function credenciales(): ?array
    {
        if (self::$credenciales !== null) {
            return self::$credenciales ?: null;
        }
        $ruta = Config::obtener('FIREBASE_CREDENCIALES');
        $datos = $ruta !== '' && is_file($ruta) ? json_decode((string) file_get_contents($ruta), true) : null;
        $valido = is_array($datos) && isset($datos['client_email'], $datos['private_key'], $datos['project_id']);
        if ($ruta !== '' && !$valido) {
            error_log('Push: FIREBASE_CREDENCIALES no apunta a un JSON válido de cuenta de servicio.');
        }
        self::$credenciales = $valido ? $datos : [];
        return $valido ? $datos : null;
    }

    private static function base64url(string $datos): string
    {
        return rtrim(strtr(base64_encode($datos), '+/', '-_'), '=');
    }

    /** Petición HTTPS con JSON o formulario. Devuelve [estado, cuerpo decodificado]. */
    private static function http(string $url, string $cuerpo, array $cabeceras): array
    {
        $c = curl_init($url);
        curl_setopt_array($c, [
            CURLOPT_POST => true, CURLOPT_POSTFIELDS => $cuerpo, CURLOPT_HTTPHEADER => $cabeceras,
            CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 8, CURLOPT_CONNECTTIMEOUT => 5,
        ]);
        $respuesta = curl_exec($c);
        $estado = (int) curl_getinfo($c, CURLINFO_HTTP_CODE);
        curl_close($c);
        return [$estado, is_string($respuesta) ? (json_decode($respuesta, true) ?? []) : []];
    }

    /** Token de acceso de Google (1 hora), guardado en un archivo temporal mientras sirve. */
    private static function tokenAcceso(array $cred): ?string
    {
        $cache = sys_get_temp_dir() . '/huellapp-fcm-' . md5($cred['client_email']) . '.json';
        $guardado = is_file($cache) ? json_decode((string) @file_get_contents($cache), true) : null;
        if (is_array($guardado) && ($guardado['vence'] ?? 0) > time() + 60) {
            return $guardado['token'];
        }
        $ahora = time();
        $cabecera = self::base64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $reclamos = self::base64url(json_encode([
            'iss' => $cred['client_email'], 'scope' => self::ALCANCE,
            'aud' => $cred['token_uri'] ?? 'https://oauth2.googleapis.com/token', 'iat' => $ahora, 'exp' => $ahora + 3600,
        ]));
        $firma = '';
        if (!openssl_sign("$cabecera.$reclamos", $firma, $cred['private_key'], OPENSSL_ALGO_SHA256)) {
            error_log('Push: no se pudo firmar con la llave de la cuenta de servicio.');
            return null;
        }
        [$estado, $r] = self::http(
            $cred['token_uri'] ?? 'https://oauth2.googleapis.com/token',
            http_build_query(['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => "$cabecera.$reclamos." . self::base64url($firma)]),
            ['Content-Type: application/x-www-form-urlencoded'],
        );
        if ($estado !== 200 || empty($r['access_token'])) {
            error_log("Push: Google no entregó el token de acceso ($estado) " . ($r['error_description'] ?? $r['error'] ?? ''));
            return null;
        }
        @file_put_contents($cache, json_encode(['token' => $r['access_token'], 'vence' => $ahora + (int) ($r['expires_in'] ?? 3600)]));
        return $r['access_token'];
    }

    /**
     * Manda un mensaje a un token. Devuelve 'ok', 'invalido' (hay que borrar el token) o 'error'.
     * `enlace`: página que abre la notificación en la web (relativa a la raíz del sitio).
     */
    public static function enviar(string $token, string $titulo, string $texto, string $seccion, string $enlace = ''): string
    {
        $cred = self::credenciales();
        $acceso = $cred ? self::tokenAcceso($cred) : null;
        if ($acceso === null) {
            return 'error';
        }
        $mensaje = [
            'token' => $token,
            'notification' => ['title' => $titulo, 'body' => $texto],
            'data' => ['seccion' => $seccion],
            'android' => ['priority' => 'high', 'notification' => ['color' => '#0D8274']],
            'webpush' => array_filter([
                'notification' => ['icon' => '/assets/img/favicon.svg'],
                'fcm_options' => $enlace !== '' ? ['link' => $enlace] : null,
            ]),
        ];
        [$estado, $r] = self::http(
            "https://fcm.googleapis.com/v1/projects/{$cred['project_id']}/messages:send",
            json_encode(['message' => $mensaje], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            ['Content-Type: application/json', "Authorization: Bearer $acceso"],
        );
        if ($estado === 200) {
            return 'ok';
        }
        $codigo = '';
        foreach ($r['error']['details'] ?? [] as $d) {
            $codigo = $d['errorCode'] ?? $codigo;
        }
        // El token ya no existe o no es de este proyecto: se borra para no intentarlo más
        if ($estado === 404 || in_array($codigo, ['UNREGISTERED', 'INVALID_ARGUMENT', 'SENDER_ID_MISMATCH'], true)) {
            return 'invalido';
        }
        error_log("Push: FCM respondió $estado " . ($r['error']['message'] ?? ''));
        return 'error';
    }

    /** Página del sitio que abre cada sección (las rutas de los refugios empiezan distinto). */
    private static function enlace(string $seccion): string
    {
        $base = rtrim(Config::obtener('SITIO_URL'), '/');
        $ruta = [
            'coincidencias' => 'pages/usuario/coincidencias.html', 'solicitudes' => 'pages/usuario/solicitudes.html',
            'mensajes' => 'pages/usuario/mensajes.html', 'foro' => 'pages/usuario/foro.html',
            'refugio-mensajes' => 'pages/refugio/mensajes.html', 'refugio-adopciones' => 'pages/refugio/adopciones.html',
            'estado-refugio' => 'pages/estado-refugio.html',
        ][$seccion] ?? 'pages/login.html';
        return $base !== '' ? "$base/$ruta" : "/$ruta";
    }

    /** Manda el aviso a todos los dispositivos de la cuenta. Nunca lanza errores. */
    public static function aUsuario(int $usuarioId, string $titulo, string $texto, string $seccion): void
    {
        if (!self::activo()) {
            return;
        }
        try {
            $tokens = Base::todos('SELECT id, token FROM dispositivos_push WHERE usuario_id = ?', [$usuarioId]);
            foreach ($tokens as $t) {
                if (self::enviar((string) $t['token'], $titulo, $texto, $seccion, self::enlace($seccion)) === 'invalido') {
                    Base::ejecutar('DELETE FROM dispositivos_push WHERE id = ?', [$t['id']]);
                }
            }
        } catch (\Throwable $e) {
            error_log('Push: ' . $e->getMessage());
        }
    }

    /* ---------- Rutas: registrar y quitar el token de este navegador o celular ---------- */

    public static function registrar(Enrutador $r): void
    {
        $r->get('/push/estado', [self::class, 'estado']);
        $sesion = [[Sesion::class, 'requiereSesion']];
        $r->post('/push/registrar', [self::class, 'guardarToken'], $sesion);
        $r->post('/push/quitar', [self::class, 'quitarToken'], $sesion);
    }

    /** ¿La API puede mandar push? (si no, la web y la app ni siquiera piden el permiso). */
    public static function estado(Solicitud $s): array
    {
        return ['disponible' => self::activo()];
    }

    private static function tokenDe(Solicitud $s): string
    {
        $token = $s->cuerpo()['token'] ?? null;
        if (!is_string($token) || strlen($token) < 20 || strlen($token) > 512 || !preg_match('/^[A-Za-z0-9_:\-\.]+$/', $token)) {
            throw new ErrorHttp(400, 'El identificador de notificaciones no es válido.');
        }
        return $token;
    }

    /* POST /api/push/registrar  { token, plataforma: web|android } */
    public static function guardarToken(Solicitud $s): array
    {
        $token = self::tokenDe($s);
        $plataforma = Validar::enumerado($s->cuerpo()['plataforma'] ?? null, 'La plataforma', ['web', 'android']);
        // Un token pertenece a un solo dispositivo: si otra cuenta inició sesión en él, pasa a esta
        Base::ejecutar(
            'MERGE INTO dispositivos_push d USING (SELECT ? AS token FROM dual) n ON (d.token = n.token)
              WHEN MATCHED THEN UPDATE SET d.usuario_id = ?, d.plataforma = ?, d.actualizado_en = SYS_EXTRACT_UTC(SYSTIMESTAMP)
              WHEN NOT MATCHED THEN INSERT (usuario_id, token, plataforma) VALUES (?, n.token, ?)',
            [$token, $s->usuario['id'], $plataforma, $s->usuario['id'], $plataforma],
        );
        return ['ok' => true];
    }

    /* POST /api/push/quitar  { token }  (al cerrar sesión o desactivar las notificaciones) */
    public static function quitarToken(Solicitud $s): array
    {
        Base::ejecutar('DELETE FROM dispositivos_push WHERE token = ? AND usuario_id = ?', [self::tokenDe($s), $s->usuario['id']]);
        return ['ok' => true];
    }
}
