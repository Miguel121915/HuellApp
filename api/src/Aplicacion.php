<?php
declare(strict_types=1);

namespace HuellApp;

use HuellApp\Rutas\{Admin, Adopciones, Auth, Favoritos, Foro, Mensajes, Refugio, Refugios, Reportes, Requisitos};

/** Aplicacion — Atiende una petición /api: CORS, rutas y errores (siempre responde JSON). */
final class Aplicacion
{
    /** El sitio puede abrirse desde Live Server (localhost:5500), Flutter Web o el propio servidor. */
    private const ORIGEN_LOCAL = '#^https?://(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$#';

    private static function cors(): void
    {
        $origen = $_SERVER['HTTP_ORIGIN'] ?? '';
        $extras = array_filter(array_map('trim', explode(',', Config::obtener('ORIGENES_PERMITIDOS'))));
        if ($origen !== '' && (preg_match(self::ORIGEN_LOCAL, $origen) || in_array($origen, $extras, true))) {
            header("Access-Control-Allow-Origin: $origen");
            header('Vary: Origin');
            header('Access-Control-Allow-Headers: Content-Type, Authorization');
            header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
        }
    }

    private static function rutas(): Enrutador
    {
        $r = new Enrutador();
        $r->get('/salud', static fn (): array => ['ok' => true, 'servicio' => 'huellapp-api']);
        // Enlace de 5 minutos para abrir un documento privado fuera de la app (visor de PDF o navegador)
        $r->post('/enlaces', static function (Solicitud $s): array {
            $ruta = $s->cuerpo()['ruta'] ?? null;
            if (!is_string($ruta) || !preg_match(Sesion::PATRON_ARCHIVO, $ruta)) {
                throw new ErrorHttp(400, 'Ese archivo no se puede abrir con un enlace.');
            }
            return ['url' => "/api$ruta?" . Sesion::firmarEnlace($ruta, (int) $s->usuario['id'])];
        }, [[Sesion::class, 'requiereSesion']]);
        Auth::registrar($r);
        Foro::registrar($r);
        Refugios::registrar($r);
        Refugio::registrar($r);
        Admin::registrar($r);
        Reportes::registrar($r);
        Adopciones::registrar($r);
        Favoritos::registrar($r);
        Mensajes::registrar($r);
        Requisitos::registrar($r);
        return $r;
    }

    public static function manejar(): void
    {
        header('X-Content-Type-Options: nosniff');
        self::cors();
        if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { // petición previa (preflight) del navegador
            http_response_code(204);
            return;
        }

        try {
            $respuesta = self::rutas()->despachar(Solicitud::actual());
        } catch (ErrorHttp $e) {
            $respuesta = new Respuesta(['error' => $e->getMessage()] + $e->extra, $e->estado);
        } catch (\PDOException $e) {
            $traducido = Base::traducir($e);
            if ($traducido instanceof ErrorHttp) {
                $respuesta = new Respuesta(['error' => $traducido->getMessage()], $traducido->estado);
            } else {
                error_log('Error de base de datos: ' . $e->getMessage());
                $respuesta = new Respuesta(['error' => 'Ocurrió un error en el servidor. Inténtalo de nuevo.'], 500);
            }
        } catch (\Throwable $e) {
            error_log('Error inesperado: ' . $e);
            $respuesta = new Respuesta(['error' => 'Ocurrió un error en el servidor. Inténtalo de nuevo.'], 500);
        }
        $respuesta->enviar();
    }
}
