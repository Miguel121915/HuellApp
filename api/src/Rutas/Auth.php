<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, Enrutador, ErrorHttp, Google, RefugioExtra, Serializadores, Sesion, Solicitud, Totp, Validar};

/** Rutas de autenticación: inicio de sesión, registros y datos de la sesión actual. */
final class Auth
{
    private const MAX_FALLOS = 8;
    private const MAX_FALLOS_CODIGO = 5; // códigos de 6 dígitos equivocados por cuenta cada 10 minutos
    private const VENTANA_SEGUNDOS = 600;
    private const TIPOS_DOCUMENTO = ['acta', 'domicilio', 'identificacion', 'permiso'];
    private const TIPOS_OBLIGATORIOS = ['acta', 'domicilio', 'identificacion'];

    public static function registrar(Enrutador $r): void
    {
        $r->get('/auth/config', [self::class, 'config']);
        $r->post('/auth/login', [self::class, 'login']);
        $r->post('/auth/google', [self::class, 'loginGoogle']);
        $r->post('/auth/2fa/verificar', [self::class, 'verificar2fa']);
        $sesion = [[Sesion::class, 'requiereSesion']];
        $r->get('/auth/2fa', [self::class, 'estado2fa'], $sesion);
        $r->post('/auth/2fa/preparar', [self::class, 'preparar2fa'], $sesion);
        $r->post('/auth/2fa/activar', [self::class, 'activar2fa'], $sesion);
        $r->post('/auth/2fa/desactivar', [self::class, 'desactivar2fa'], $sesion);
        $r->post('/auth/registro-usuario', [self::class, 'registroUsuario']);
        $r->post('/auth/registro-refugio', [self::class, 'registroRefugio']);
        $r->get('/auth/yo', [self::class, 'yo'], [[Sesion::class, 'requiereSesion']]);

        // Un refugio rechazado corrige sus datos/documentos y reenvía la solicitud
        $refugio = [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('refugio')];
        $r->get('/auth/apelacion', [self::class, 'verApelacion'], $refugio);
        $r->post('/auth/apelacion', [self::class, 'apelar'], $refugio);
    }

    /* ---------- Protección contra adivinar contraseñas (se guarda en la BD) ---------- */

    private static function revisarLimite(string $clave, int $maximo = self::MAX_FALLOS): void
    {
        $f = Base::uno('SELECT cuenta, desde FROM intentos_login WHERE clave = ?', [$clave]);
        if ($f && (new \DateTimeImmutable($f['desde'], new \DateTimeZone('UTC')))->getTimestamp() < time() - self::VENTANA_SEGUNDOS) {
            Base::ejecutar('DELETE FROM intentos_login WHERE clave = ?', [$clave]);
            $f = null;
        }
        if ($f && (int) $f['cuenta'] >= $maximo) {
            throw new ErrorHttp(429, 'Demasiados intentos fallidos. Espera unos minutos e inténtalo de nuevo.');
        }
    }

    private static function anotarFallo(string $clave): void
    {
        Base::ejecutar(
            'MERGE INTO intentos_login t USING (SELECT ? AS clave, ? AS desde FROM dual) n ON (t.clave = n.clave)
              WHEN MATCHED THEN UPDATE SET t.cuenta = t.cuenta + 1
              WHEN NOT MATCHED THEN INSERT (clave, cuenta, desde) VALUES (n.clave, 1, TO_TIMESTAMP(n.desde, \'YYYY-MM-DD HH24:MI:SS.FF3\'))',
            [$clave, Base::ahora()],
        );
    }

    /** Lo que el sitio guarda como "sesión" (nunca incluye la contraseña). */
    private static function construirSesion(array $u): array
    {
        $refugio = $u['rol'] === 'refugio' ? Base::uno('SELECT id, estado FROM refugios WHERE usuario_id = ?', [$u['id']]) : null;
        return [
            'id' => (string) $u['id'], 'nombre' => $u['nombre'], 'correo' => $u['correo'], 'rol' => $u['rol'],
            'refugioId' => $refugio ? (string) $refugio['id'] : null, 'refugioEstado' => $refugio['estado'] ?? null,
        ];
    }

    /* ---------- POST /api/auth/login ---------- */
    public static function login(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $correo = $b['correo'] ?? null;
        $password = $b['password'] ?? null;
        if (!is_string($correo) || !is_string($password)) {
            throw new ErrorHttp(400, 'Escribe tu correo y tu contraseña.');
        }
        $clave = substr($s->ip() . '|' . strtolower(trim($correo)), 0, 190);
        self::revisarLimite($clave);

        $usuario = Base::uno('SELECT * FROM usuarios WHERE correo = ?', [strtolower(trim($correo))]); // en Oracle la comparación distingue mayúsculas
        // Se verifica contra un hash falso si el correo no existe: el tiempo de respuesta no delata qué correos hay
        $valida = password_verify($password, $usuario['password_hash'] ?? '$2y$10$usesomesillystringforsaltuQ9vYd0u5nQ8K8h3m6mZ2o1Zr7h6Wa');
        if ($usuario === null || !$valida) {
            self::anotarFallo($clave);
            throw new ErrorHttp(401, 'Correo o contraseña incorrectos. Revisa tus datos e inténtalo de nuevo.');
        }
        $rol = $b['rol'] ?? null;
        if ($rol && $usuario['rol'] !== $rol) {
            throw new ErrorHttp(403, 'Esta cuenta no pertenece al rol seleccionado. Cambia la pestaña de rol arriba.');
        }
        Base::ejecutar('DELETE FROM intentos_login WHERE clave = ?', [$clave]);
        return self::entregar($usuario);
    }

    /**
     * Paso final de cualquier inicio de sesión: si la cuenta tiene la verificación en dos pasos
     * activa, devuelve un desafío (falta el código de Google Authenticator); si no, la sesión.
     */
    private static function entregar(array $usuario): array
    {
        if ((int) ($usuario['totp_activo'] ?? 0) === 1) {
            return ['ok' => true, 'requiere2fa' => true, 'desafio' => Sesion::crearDesafio((int) $usuario['id'])];
        }
        return ['ok' => true, 'token' => Sesion::crearToken($usuario), 'sesion' => self::construirSesion($usuario)];
    }

    /* ---------- GET /api/auth/config — lo que el login necesita saber antes de mostrarse ---------- */
    public static function config(Solicitud $s): array
    {
        return ['googleClientId' => Google::clientIdWeb()];
    }

    /* ---------- POST /api/auth/google — «Continuar con Google» ---------- */
    // Cuerpo: { idToken, rol? }. Si no hay cuenta con ese correo se crea una de usuario
    // (los refugios se registran con su formulario y documentos, y después pueden entrar con Google).
    public static function loginGoogle(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $idToken = $b['idToken'] ?? null;
        if (!is_string($idToken) || $idToken === '') {
            throw new ErrorHttp(400, 'Falta la respuesta de Google. Inténtalo de nuevo.');
        }
        $rol = in_array($b['rol'] ?? null, ['usuario', 'refugio', 'admin'], true) ? $b['rol'] : null;
        $google = Google::verificar($idToken);

        $usuario = Base::uno('SELECT * FROM usuarios WHERE google_sub = ?', [$google['sub']])
            ?? Base::uno('SELECT * FROM usuarios WHERE correo = ?', [$google['correo']]);

        if ($usuario === null) {
            if ($rol !== null && $rol !== 'usuario') {
                throw new ErrorHttp(404, $rol === 'refugio'
                    ? 'No hay un refugio registrado con ese correo de Google. Registra tu refugio primero.'
                    : 'No hay una cuenta de administrador con ese correo de Google.');
            }
            Base::insertarSiNoExiste( // si dos pestañas lo intentan a la vez, el correo único evita duplicados
                "INSERT INTO usuarios (nombre, correo, password_hash, rol, google_sub, creado_en) VALUES (?, ?, ?, 'usuario', ?, ?)",
                // Contraseña aleatoria que nadie conoce: la cuenta entra con Google
                [$google['nombre'], $google['correo'], password_hash(bin2hex(random_bytes(24)), PASSWORD_DEFAULT), $google['sub'], Base::ahora()],
            );
            $usuario = Base::uno('SELECT * FROM usuarios WHERE correo = ?', [$google['correo']]);
        } elseif (($usuario['google_sub'] ?? '') === '') {
            // Cuenta creada con correo y contraseña: Google confirmó que ese correo es suyo, se vincula
            Base::ejecutar('UPDATE usuarios SET google_sub = ? WHERE id = ?', [$google['sub'], $usuario['id']]);
        } elseif ($usuario['google_sub'] !== $google['sub']) {
            throw new ErrorHttp(409, 'Ese correo ya está vinculado a otra cuenta de Google.');
        }

        if ($rol && $usuario['rol'] !== $rol) {
            throw new ErrorHttp(403, 'Esta cuenta no pertenece al rol seleccionado. Cambia la pestaña de rol arriba.');
        }
        return self::entregar($usuario);
    }

    /* ---------- Verificación en dos pasos (Google Authenticator) ---------- */

    /** Revisa el código contra el secreto guardado y lo marca como usado (no se puede repetir). */
    private static function comprobarCodigo(array $usuario, mixed $codigo): void
    {
        $clave = '2fa|' . $usuario['id'];
        self::revisarLimite($clave, self::MAX_FALLOS_CODIGO);
        $secreto = Sesion::descifrar((string) ($usuario['totp_secreto'] ?? ''));
        if ($secreto === null) {
            throw new ErrorHttp(409, 'No se pudo leer tu verificación en dos pasos. Vuelve a configurarla.');
        }
        $ultimo = $usuario['totp_ultimo_paso'] === null || $usuario['totp_ultimo_paso'] === '' ? null : (int) $usuario['totp_ultimo_paso'];
        $paso = is_string($codigo) ? Totp::verificar($secreto, $codigo, $ultimo) : null;
        if ($paso === null) {
            self::anotarFallo($clave);
            throw new ErrorHttp(400, 'El código no es correcto o ya venció. Escribe el que muestra ahora Google Authenticator.');
        }
        // Solo gana una petición con el mismo código aunque lleguen dos a la vez
        $marcado = Base::ejecutar(
            'UPDATE usuarios SET totp_ultimo_paso = ? WHERE id = ? AND (totp_ultimo_paso IS NULL OR totp_ultimo_paso < ?)',
            [$paso, $usuario['id'], $paso],
        );
        if ($marcado === 0) {
            throw new ErrorHttp(400, 'Ese código ya se usó. Espera el siguiente en Google Authenticator.');
        }
        Base::ejecutar('DELETE FROM intentos_login WHERE clave = ?', [$clave]);
    }

    // POST /api/auth/2fa/verificar — { desafio, codigo } → sesión
    public static function verificar2fa(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $id = is_string($b['desafio'] ?? null) ? Sesion::verificarDesafio($b['desafio']) : null;
        if (!$id) {
            throw new ErrorHttp(401, 'Pasaron más de 5 minutos. Vuelve a iniciar sesión.', ['codigo' => 'desafio-vencido']);
        }
        $usuario = Base::uno('SELECT * FROM usuarios WHERE id = ?', [$id]);
        if ($usuario === null || (int) $usuario['totp_activo'] !== 1) {
            throw new ErrorHttp(401, 'Vuelve a iniciar sesión.', ['codigo' => 'desafio-vencido']);
        }
        self::comprobarCodigo($usuario, $b['codigo'] ?? null);
        return ['ok' => true, 'token' => Sesion::crearToken($usuario), 'sesion' => self::construirSesion($usuario)];
    }

    private static function datos2fa(Solicitud $s): array
    {
        return Base::uno('SELECT id, correo, totp_secreto, totp_activo, totp_ultimo_paso FROM usuarios WHERE id = ?', [$s->usuario['id']]);
    }

    // GET /api/auth/2fa — ¿la cuenta tiene activa la verificación en dos pasos?
    public static function estado2fa(Solicitud $s): array
    {
        return ['activo' => (int) self::datos2fa($s)['totp_activo'] === 1];
    }

    // POST /api/auth/2fa/preparar — secreto nuevo (aún sin activar) para escanear en Google Authenticator
    public static function preparar2fa(Solicitud $s): array
    {
        $u = self::datos2fa($s);
        if ((int) $u['totp_activo'] === 1) {
            throw new ErrorHttp(409, 'La verificación en dos pasos ya está activa. Desactívala primero para cambiar de teléfono.');
        }
        $secreto = Totp::nuevoSecreto();
        Base::ejecutar('UPDATE usuarios SET totp_secreto = ?, totp_ultimo_paso = NULL WHERE id = ?', [Sesion::cifrar($secreto), $u['id']]);
        return ['secreto' => $secreto, 'enlace' => Totp::enlace($secreto, $u['correo'])];
    }

    // POST /api/auth/2fa/activar — { codigo }: confirma que el teléfono quedó bien configurado
    public static function activar2fa(Solicitud $s): array
    {
        $u = self::datos2fa($s);
        if ((int) $u['totp_activo'] === 1) {
            return ['ok' => true, 'activo' => true];
        }
        if (($u['totp_secreto'] ?? '') === '') {
            throw new ErrorHttp(409, 'Primero genera el código QR.');
        }
        self::comprobarCodigo($u, $s->cuerpo()['codigo'] ?? null);
        Base::ejecutar('UPDATE usuarios SET totp_activo = 1 WHERE id = ?', [$u['id']]);
        return ['ok' => true, 'activo' => true];
    }

    // POST /api/auth/2fa/desactivar — { codigo }: pide un código vigente para que nadie la quite con una sesión robada
    public static function desactivar2fa(Solicitud $s): array
    {
        $u = self::datos2fa($s);
        if ((int) $u['totp_activo'] !== 1) {
            return ['ok' => true, 'activo' => false];
        }
        self::comprobarCodigo($u, $s->cuerpo()['codigo'] ?? null);
        Base::ejecutar('UPDATE usuarios SET totp_activo = 0, totp_secreto = NULL, totp_ultimo_paso = NULL WHERE id = ?', [$u['id']]);
        return ['ok' => true, 'activo' => false];
    }

    /* ---------- POST /api/auth/registro-usuario ---------- */
    public static function registroUsuario(Solicitud $s): \HuellApp\Respuesta
    {
        $b = $s->cuerpo();
        $nombre = Validar::texto($b['nombre'] ?? null, 'El nombre', min: 3, max: 80);
        $correo = Validar::correo($b['correo'] ?? null);
        $telefono = Validar::telefono($b['telefono'] ?? null, opcional: true);
        $password = Validar::password($b['password'] ?? null);

        if (Base::uno('SELECT 1 FROM usuarios WHERE correo = ?', [$correo])) {
            throw new ErrorHttp(409, 'Ya existe una cuenta con ese correo. Inicia sesión o usa otro correo.');
        }
        Base::insertar(
            "INSERT INTO usuarios (nombre, correo, telefono, password_hash, rol, creado_en) VALUES (?, ?, ?, ?, 'usuario', ?)",
            [$nombre, $correo, $telefono ?: null, password_hash($password, PASSWORD_DEFAULT), Base::ahora()],
        );
        return \HuellApp\Respuesta::json(['ok' => true], 201);
    }

    /* ---------- Validaciones comunes del registro y la apelación ---------- */

    /** Datos del refugio que se capturan en el formulario de registro (y se corrigen al apelar). */
    private static function leerDatosRefugio(array $b): array
    {
        return [
            'nombre' => Validar::texto($b['nombreRefugio'] ?? null, 'El nombre del refugio', min: 3, max: 100),
            'responsable' => Validar::texto($b['responsable'] ?? null, 'El responsable', min: 3, max: 80),
            'telefono' => Validar::telefono($b['telefono'] ?? null),
            'direccion' => Validar::texto($b['direccion'] ?? null, 'La dirección', min: 8, max: 160),
            'horario' => Validar::horario($b['horario'] ?? null),
        ];
    }

    /** Lista de documentos enviados: máximo uno por tipo y solo tipos conocidos. Devuelve [documentos, tipos]. */
    private static function leerDocumentos(array $b): array
    {
        $documentos = is_array($b['documentos'] ?? null) ? array_values($b['documentos']) : [];
        if (count($documentos) > count(self::TIPOS_DOCUMENTO)) {
            throw new ErrorHttp(400, 'Enviaste demasiados documentos.');
        }
        $tipos = array_map(static fn ($d) => is_array($d) ? ($d['tipo'] ?? null) : null, $documentos);
        if (count(array_unique($tipos)) !== count($tipos) || array_diff($tipos, self::TIPOS_DOCUMENTO)) {
            throw new ErrorHttp(400, 'Los documentos enviados no son válidos.');
        }
        return [$documentos, $tipos];
    }

    private static function revisarObligatorios(array $tipos): void
    {
        if (array_diff(self::TIPOS_OBLIGATORIOS, $tipos)) {
            throw new ErrorHttp(400, 'Faltan documentos obligatorios (acta constitutiva, comprobante de domicilio e identificación).');
        }
    }

    /**
     * Guarda los archivos en disco. Si alguno falla, borra los que ya se guardaron.
     * @return list<array{tipo:string, nombre:string, archivo:string, mime:string, tamano:int}>
     */
    private static function guardarArchivos(array $documentos): array
    {
        $guardados = [];
        try {
            foreach ($documentos as $d) {
                $nombreArchivo = Validar::texto($d['nombre'] ?? null, 'El nombre del documento', max: 120);
                $guardados[] = ['tipo' => $d['tipo'], 'nombre' => $nombreArchivo]
                    + Archivos::guardarDocumento($d['dataUrl'] ?? null, "El documento «{$nombreArchivo}»");
            }
        } catch (\Throwable $e) {
            Archivos::borrarDocumentos(array_column($guardados, 'archivo'));
            throw $e;
        }
        return $guardados;
    }

    /* ---------- POST /api/auth/registro-refugio ---------- */
    public static function registroRefugio(Solicitud $s): \HuellApp\Respuesta
    {
        $b = $s->cuerpo();
        ['nombre' => $nombreRefugio, 'responsable' => $responsable, 'telefono' => $telefono, 'direccion' => $direccion, 'horario' => $horario] = self::leerDatosRefugio($b);
        $correo = Validar::correo($b['correo'] ?? null);
        $password = Validar::password($b['password'] ?? null);

        $extras = RefugioExtra::leer($b); // ubicación, WhatsApp, redes… (los manda la app móvil)
        [$documentos, $tipos] = self::leerDocumentos($b);
        self::revisarObligatorios($tipos);
        if (Base::uno('SELECT 1 FROM usuarios WHERE correo = ?', [$correo])) {
            throw new ErrorHttp(409, 'Ya existe una cuenta con ese correo. Inicia sesión o usa otro correo.');
        }

        $hash = password_hash($password, PASSWORD_DEFAULT);
        // 1) Se guardan los archivos; si algo falla después, se borran para no dejar basura
        $guardados = self::guardarArchivos($documentos);
        try {
            // 2) Se crean cuenta, refugio y documentos en una sola transacción
            Base::transaccion(static function () use ($responsable, $correo, $telefono, $hash, $nombreRefugio, $direccion, $horario, $guardados, $extras): void {
                $idUsuario = Base::insertar(
                    "INSERT INTO usuarios (nombre, correo, telefono, password_hash, rol, creado_en) VALUES (?, ?, ?, ?, 'refugio', ?)",
                    [$responsable, $correo, $telefono, $hash, Base::ahora()],
                );
                $idRefugio = Base::insertar(
                    'INSERT INTO refugios (usuario_id, nombre, responsable, telefono, direccion, horario, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [$idUsuario, $nombreRefugio, $responsable, $telefono, $direccion, $horario, Base::ahora()],
                );
                RefugioExtra::guardar($idRefugio, $extras);
                foreach ($guardados as $g) {
                    Base::insertar(
                        'INSERT INTO documentos_refugio (refugio_id, tipo, nombre, archivo, mime, tamano) VALUES (?, ?, ?, ?, ?, ?)',
                        [$idRefugio, $g['tipo'], $g['nombre'], $g['archivo'], $g['mime'], $g['tamano']],
                    );
                }
            });
        } catch (\Throwable $e) {
            Archivos::borrarDocumentos(array_column($guardados, 'archivo'));
            throw $e;
        }
        return \HuellApp\Respuesta::json(['ok' => true], 201);
    }

    /* ---------- Apelación de un refugio rechazado ---------- */

    /** El refugio de la sesión, solo si está rechazado (es el único estado desde el que se apela). */
    private static function refugioRechazado(Solicitud $s): array
    {
        $refugio = Base::uno('SELECT r.*, u.correo FROM refugios r JOIN usuarios u ON u.id = r.usuario_id WHERE r.usuario_id = ?', [$s->usuario['id']]);
        if ($refugio === null) {
            throw new ErrorHttp(404, 'No encontramos tu refugio.');
        }
        if ($refugio['estado'] !== 'rechazado') {
            throw new ErrorHttp(409, 'Solo se puede apelar una solicitud rechazada.', ['codigo' => 'no-rechazado', 'estado' => $refugio['estado']]);
        }
        return $refugio;
    }

    private static function documentosDe(int $refugioId): array
    {
        return Base::todos('SELECT * FROM documentos_refugio WHERE refugio_id = ? ORDER BY id', [$refugioId]);
    }

    // GET /api/auth/apelacion — datos y documentos actuales para precargar el formulario
    public static function verApelacion(Solicitud $s): array
    {
        $refugio = self::refugioRechazado($s);
        return ['refugio' => Serializadores::refugioCompleto($refugio, self::documentosDe((int) $refugio['id']))];
    }

    /**
     * POST /api/auth/apelacion — Reenvía la solicitud corregida.
     * `documentos` trae SOLO los archivos nuevos (uno por tipo): reemplazan al anterior de ese tipo.
     * Los documentos señalados como erróneos deben reemplazarse. La solicitud vuelve a "pendiente".
     */
    public static function apelar(Solicitud $s): array
    {
        $refugio = self::refugioRechazado($s);
        $b = $s->cuerpo();
        $datos = self::leerDatosRefugio($b);
        [$nuevos, $tiposNuevos] = self::leerDocumentos($b);

        $actuales = self::documentosDe((int) $refugio['id']);
        $porReemplazar = array_values(array_unique(array_column(array_filter($actuales, static fn ($d) => (bool) $d['con_error']), 'tipo')));
        if ($faltan = array_diff($porReemplazar, $tiposNuevos)) {
            $nombres = ['acta' => 'acta constitutiva', 'domicilio' => 'comprobante de domicilio', 'identificacion' => 'identificación', 'permiso' => 'permiso de refugio'];
            throw new ErrorHttp(400, 'Sube un archivo nuevo para: ' . implode(', ', array_map(static fn ($t) => $nombres[$t], $faltan)) . '.');
        }
        self::revisarObligatorios(array_unique([...array_column($actuales, 'tipo'), ...$tiposNuevos]));

        $guardados = self::guardarArchivos($nuevos);
        $reemplazados = array_values(array_filter($actuales, static fn ($d) => in_array($d['tipo'], $tiposNuevos, true)));
        try {
            Base::transaccion(static function () use ($refugio, $datos, $guardados, $reemplazados, $s): void {
                $cambio = Base::ejecutar(
                    "UPDATE refugios SET nombre = ?, responsable = ?, telefono = ?, direccion = ?, horario = ?,
                            estado = 'pendiente', motivo_anterior = motivo_rechazo, motivo_rechazo = '',
                            apelaciones = apelaciones + 1, apelado_en = ?, revisado_por = NULL, revisado_en = NULL
                      WHERE id = ? AND estado = 'rechazado'",
                    [$datos['nombre'], $datos['responsable'], $datos['telefono'], $datos['direccion'], $datos['horario'], Base::ahora(), $refugio['id']],
                );
                if ($cambio === 0) { // otra petición ya la reenvió o el administrador la cambió mientras tanto
                    throw new ErrorHttp(409, 'Tu solicitud ya no está rechazada. Actualiza la página.', ['codigo' => 'no-rechazado']);
                }
                Base::ejecutar('UPDATE usuarios SET nombre = ?, telefono = ? WHERE id = ?', [$datos['responsable'], $datos['telefono'], $s->usuario['id']]);
                foreach ($reemplazados as $d) {
                    Base::ejecutar('DELETE FROM documentos_refugio WHERE id = ?', [$d['id']]);
                }
                foreach ($guardados as $g) {
                    Base::insertar(
                        'INSERT INTO documentos_refugio (refugio_id, tipo, nombre, archivo, mime, tamano, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
                        [$refugio['id'], $g['tipo'], $g['nombre'], $g['archivo'], $g['mime'], $g['tamano'], Base::ahora()],
                    );
                }
                Base::ejecutar('UPDATE documentos_refugio SET con_error = 0 WHERE refugio_id = ?', [$refugio['id']]);
            });
        } catch (\Throwable $e) {
            Archivos::borrarDocumentos(array_column($guardados, 'archivo'));
            throw $e;
        }
        Archivos::borrarDocumentos(array_column($reemplazados, 'archivo')); // los archivos viejos ya no se usan

        $fila = Base::uno('SELECT r.*, u.correo FROM refugios r JOIN usuarios u ON u.id = r.usuario_id WHERE r.id = ?', [$refugio['id']]);
        return ['ok' => true, 'refugio' => Serializadores::refugioCompleto($fila, self::documentosDe((int) $fila['id']))];
    }

    /* ---------- GET /api/auth/yo ---------- */
    // Devuelve la sesión actualizada (el estado del refugio puede haber cambiado desde que inició sesión)
    public static function yo(Solicitud $s): array
    {
        $sesion = self::construirSesion($s->usuario);
        $refugio = $sesion['refugioId'] ? Base::uno('SELECT nombre, estado, motivo_rechazo, apelaciones FROM refugios WHERE id = ?', [(int) $sesion['refugioId']]) : null;
        return [
            'sesion' => $sesion,
            'refugio' => $refugio ? [
                'nombre' => $refugio['nombre'], 'estado' => $refugio['estado'], 'motivoRechazo' => $refugio['motivo_rechazo'],
                'apelaciones' => (int) $refugio['apelaciones'],
            ] : null,
        ];
    }
}
