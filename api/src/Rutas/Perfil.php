<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Serializadores, Sesion, Solicitud, Validar};

/**
 * Mi perfil (usuario): ver los datos de la cuenta y editar los que no la identifican.
 * El nombre y el correo NO se editan aquí (son los datos con los que se registró y se identifica);
 * sí el teléfono, la ciudad y los datos del hogar que también precargan la solicitud de adopción.
 */
final class Perfil
{
    private const VIVIENDAS = ['casa', 'departamento', 'otro'];

    public static function registrar(Enrutador $r): void
    {
        $r->grupo('/perfil', [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('usuario')], static function (Enrutador $r): void {
            $r->get('', [self::class, 'ver']);
            $r->put('', [self::class, 'actualizar']);
        });
    }

    /* ---------- GET /api/perfil ---------- */
    public static function ver(Solicitud $s): array
    {
        $id = (int) $s->usuario['id'];
        $u = Base::uno(
            'SELECT nombre, correo, telefono, ciudad, ocupacion, tipo_vivienda, otras_mascotas, sobre_mi,
                    creado_en, totp_activo, google_sub
               FROM usuarios WHERE id = ?',
            [$id],
        );
        if ($u === null) {
            throw new ErrorHttp(404, 'No encontramos tu cuenta.');
        }
        $contar = static fn (string $tabla): int => (int) Base::valor("SELECT COUNT(*) FROM $tabla WHERE usuario_id = ?", [$id]);
        return [
            'perfil' => self::serializar($u),
            'actividad' => [
                'reportes' => $contar('reportes'),
                'favoritos' => $contar('favoritos'),
                'solicitudes' => $contar('solicitudes_adopcion'),
                'publicaciones' => $contar('publicaciones_foro'),
            ],
        ];
    }

    /* ---------- PUT /api/perfil ---------- */
    public static function actualizar(Solicitud $s): array
    {
        $b = $s->cuerpo();
        // Campo del cuerpo => [columna, cómo se valida]. Solo se cambian los campos que vienen en el cuerpo.
        $campos = [
            'telefono' => ['telefono', static fn ($v) => Validar::telefono($v, opcional: true)],
            'ciudad' => ['ciudad', static fn ($v) => Validar::texto($v, 'La ciudad', min: 2, max: 80, opcional: true)],
            'ocupacion' => ['ocupacion', static fn ($v) => Validar::texto($v, 'La ocupación', min: 2, max: 100, opcional: true)],
            'tipoVivienda' => ['tipo_vivienda', static fn ($v) => $v === null || $v === '' ? '' : Validar::enumerado($v, 'El tipo de vivienda', self::VIVIENDAS)],
            'otrasMascotas' => ['otras_mascotas', static fn ($v) => Validar::texto($v, 'Tus otras mascotas', max: 200, opcional: true)],
            'sobreMi' => ['sobre_mi', static fn ($v) => Validar::texto($v, 'Sobre mí', max: 300, opcional: true)],
        ];
        $sets = [];
        $valores = [];
        foreach ($campos as $clave => [$columna, $validar]) {
            if (!array_key_exists($clave, $b)) {
                continue;
            }
            $valor = $validar($b[$clave]);
            $sets[] = "$columna = ?";
            $valores[] = $valor === '' ? null : $valor; // "" borra el dato (en Oracle '' ya es NULL)
        }
        if ($sets) {
            Base::ejecutar('UPDATE usuarios SET ' . implode(', ', $sets) . ' WHERE id = ?', [...$valores, $s->usuario['id']]);
        }
        return ['ok' => true] + self::ver($s);
    }

    private static function serializar(array $u): array
    {
        return [
            'nombre' => $u['nombre'],
            'correo' => $u['correo'],
            'telefono' => $u['telefono'] ?? '',
            'ciudad' => $u['ciudad'] ?? '',
            'ocupacion' => $u['ocupacion'] ?? '',
            'tipoVivienda' => $u['tipo_vivienda'] ?? '',
            'otrasMascotas' => $u['otras_mascotas'] ?? '',
            'sobreMi' => $u['sobre_mi'] ?? '',
            'miembroDesde' => Serializadores::fecha($u['creado_en']),
            'conGoogle' => !empty($u['google_sub']),
            'dosPasos' => (int) ($u['totp_activo'] ?? 0) === 1,
        ];
    }
}
