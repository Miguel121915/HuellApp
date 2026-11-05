<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Respuesta, Sesion, Solicitud, Validar};

/**
 * HU-16 Requisitos de adopción: el refugio los define y los edita; cualquiera (también el visitante)
 * los consulta en el perfil del refugio y antes de solicitar una adopción o agendar la visita.
 */
final class Requisitos
{
    private const MAX_REQUISITOS = 20;

    public static function registrar(Enrutador $r): void
    {
        $r->get('/refugios/{id}/requisitos', [self::class, 'publicos']); // sin sesión

        $guardias = [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('refugio'), [Sesion::class, 'requiereRefugioAprobado']];
        $r->grupo('/refugio', $guardias, static function (Enrutador $r): void {
            $r->get('/requisitos', [self::class, 'listar']);
            $r->post('/requisitos', [self::class, 'crear']);
            $r->put('/requisitos/{id}', [self::class, 'editar']);
            $r->delete('/requisitos/{id}', [self::class, 'eliminar']);
        });
    }

    private static function requisito(array $f): array
    {
        return ['id' => (string) $f['id'], 'texto' => $f['texto'], 'detalle' => $f['detalle'] ?? '', 'obligatorio' => (bool) $f['obligatorio']];
    }

    private static function deRefugio(int $refugioId): array
    {
        // Primero los obligatorios, luego los recomendables, en el orden en que se agregaron
        return array_map([self::class, 'requisito'], Base::todos('SELECT * FROM requisitos_refugio WHERE refugio_id = ? ORDER BY obligatorio DESC, id', [$refugioId]));
    }

    public static function publicos(Solicitud $s): array
    {
        $refugio = Base::uno("SELECT id FROM refugios WHERE id = ? AND estado = 'aprobado'", [Validar::idDeRuta($s->parametro('id'))]);
        if ($refugio === null) {
            throw new ErrorHttp(404, 'Ese refugio no está disponible.');
        }
        return ['requisitos' => self::deRefugio((int) $refugio['id'])];
    }

    public static function listar(Solicitud $s): array
    {
        return ['requisitos' => self::deRefugio((int) $s->refugio['id'])];
    }

    private static function leer(array $b): array
    {
        return [
            'texto' => Validar::texto($b['texto'] ?? null, 'El requisito', min: 3, max: 150),
            'detalle' => Validar::texto($b['detalle'] ?? null, 'El detalle', max: 500, opcional: true),
            'obligatorio' => array_key_exists('obligatorio', $b) ? Validar::booleano($b['obligatorio'], '«obligatorio»') : true,
        ];
    }

    private static function propio(Solicitud $s): array
    {
        $f = Base::uno('SELECT * FROM requisitos_refugio WHERE id = ? AND refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($f === null) {
            throw new ErrorHttp(404, 'Ese requisito ya no existe.');
        }
        return $f;
    }

    public static function crear(Solicitud $s): Respuesta
    {
        if ((int) Base::valor('SELECT COUNT(*) FROM requisitos_refugio WHERE refugio_id = ?', [$s->refugio['id']]) >= self::MAX_REQUISITOS) {
            throw new ErrorHttp(400, 'Llegaste al máximo de ' . self::MAX_REQUISITOS . ' requisitos. Elimina alguno para agregar otro.');
        }
        $q = self::leer($s->cuerpo());
        $id = Base::insertar(
            'INSERT INTO requisitos_refugio (refugio_id, texto, detalle, obligatorio, creado_en, actualizado_en) VALUES (?, ?, ?, ?, ?, ?)',
            [$s->refugio['id'], $q['texto'], $q['detalle'], $q['obligatorio'] ? 1 : 0, Base::ahora(), Base::ahora()],
        );
        return Respuesta::json(['ok' => true, 'requisito' => self::requisito(Base::uno('SELECT * FROM requisitos_refugio WHERE id = ?', [$id]))], 201);
    }

    public static function editar(Solicitud $s): array
    {
        $actual = self::propio($s);
        $q = self::leer($s->cuerpo());
        Base::ejecutar(
            'UPDATE requisitos_refugio SET texto = ?, detalle = ?, obligatorio = ?, actualizado_en = ? WHERE id = ?',
            [$q['texto'], $q['detalle'], $q['obligatorio'] ? 1 : 0, Base::ahora(), $actual['id']],
        );
        return ['ok' => true, 'requisito' => self::requisito(Base::uno('SELECT * FROM requisitos_refugio WHERE id = ?', [$actual['id']]))];
    }

    public static function eliminar(Solicitud $s): array
    {
        Base::ejecutar('DELETE FROM requisitos_refugio WHERE id = ?', [self::propio($s)['id']]);
        return ['ok' => true];
    }
}
