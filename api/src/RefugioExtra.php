<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * RefugioExtra — Datos del refugio que pide la app móvil además de los del sitio web:
 * ubicación en el mapa, municipio, CP, RFC, tipo de organización, año de fundación,
 * WhatsApp, redes sociales, necesidades, si recibe perros y/o gatos y la foto del refugio.
 *
 * Todos son OPCIONALES: el registro del sitio web sigue funcionando sin mandarlos.
 * En el JSON van con los nombres de la izquierda; en la tabla refugios, con los de la derecha.
 */
final class RefugioExtra
{
    private const COLUMNAS = [
        'latitud' => 'latitud', 'longitud' => 'longitud', 'municipio' => 'municipio', 'codigoPostal' => 'codigo_postal',
        'rfc' => 'rfc', 'tipoOrganizacion' => 'tipo_organizacion', 'anioFundacion' => 'anio_fundacion',
        'whatsapp' => 'whatsapp', 'redes' => 'redes', 'necesidades' => 'necesidades',
        'tienePerros' => 'tiene_perros', 'tieneGatos' => 'tiene_gatos',
        'descripcion' => 'descripcion', // la app la pide desde el registro; el sitio la edita en el perfil
        // Responsable y animales (registro web y app)
        'cargoResponsable' => 'cargo_responsable', 'capacidad' => 'capacidad', 'animalesActuales' => 'animales_actuales',
        'entregaEsterilizados' => 'entrega_esterilizados',
        'foto' => 'foto', // foto del refugio: data URL nueva, la ruta que ya tenía, o "" para quitarla
    ];

    /** Lee y valida los campos extra que vengan en el cuerpo. @return array<string,mixed> columna => valor */
    public static function leer(array $b): array
    {
        $valores = [];
        foreach (self::COLUMNAS as $campo => $columna) {
            if (!array_key_exists($campo, $b)) {
                continue;
            }
            $v = $b[$campo];
            $valores[$columna] = match ($campo) {
                'latitud' => self::coordenada($v, 'La latitud', 90),
                'longitud' => self::coordenada($v, 'La longitud', 180),
                'municipio' => Validar::texto($v, 'El municipio', max: 100, opcional: true),
                'codigoPostal' => self::codigoPostal($v),
                'rfc' => strtoupper(Validar::texto($v, 'El RFC', min: 12, max: 13, opcional: true)),
                'tipoOrganizacion' => Validar::texto($v, 'El tipo de organización', max: 60, opcional: true),
                'anioFundacion' => $v === null || $v === '' ? null : Validar::entero($v, 'El año de fundación', 1900, (int) date('Y')),
                'whatsapp' => Validar::telefono($v, opcional: true),
                'redes' => self::lista($v, 'Las redes sociales', 5, 80),
                'necesidades' => self::lista($v, 'Las necesidades', 10, 60),
                'tienePerros', 'tieneGatos' => Validar::booleano($v, $campo) ? 1 : 0,
                'descripcion' => Validar::texto($v, 'La descripción', max: 400, opcional: true),
                'cargoResponsable' => Validar::texto($v, 'El cargo del responsable', max: 80, opcional: true),
                'capacidad' => $v === null || $v === '' ? null : Validar::entero($v, 'La capacidad', 1, 100000),
                'animalesActuales' => $v === null || $v === '' ? null : Validar::entero($v, 'El número actual de animales', 0, 100000),
                'entregaEsterilizados' => $v === null || $v === '' ? null : Validar::enumerado($v, '«¿Se entregan esterilizados?»', ['si', 'algunos', 'no']),
                'foto' => Archivos::resolverFoto($v, 'La foto del refugio'),
            };
        }
        return $valores;
    }

    /** Tipo de organización de quien rescata sin acta constitutiva ni permiso. */
    public const TIPO_INDEPENDIENTE = 'Rescatista independiente';

    public static function esIndependiente(?string $tipo): bool
    {
        return $tipo !== null && strcasecmp(trim($tipo), self::TIPO_INDEPENDIENTE) === 0;
    }

    /** Guarda en el refugio los campos extra leídos con leer(). */
    public static function guardar(int $refugioId, array $valores): void
    {
        if (!$valores) {
            return;
        }
        $sets = implode(', ', array_map(static fn (string $c): string => "$c = ?", array_keys($valores)));
        Base::ejecutar("UPDATE refugios SET $sets WHERE id = ?", [...array_values($valores), $refugioId]);
    }

    /** Campos extra para el JSON público del refugio. */
    public static function serializar(array $r): array
    {
        $lat = $r['latitud'] ?? null;
        $lng = $r['longitud'] ?? null;
        return [
            'latitud' => $lat === null ? null : (float) $lat,
            'longitud' => $lng === null ? null : (float) $lng,
            'municipio' => $r['municipio'] ?? '',
            'codigoPostal' => $r['codigo_postal'] ?? '',
            'tipoOrganizacion' => $r['tipo_organizacion'] ?? '',
            'anioFundacion' => isset($r['anio_fundacion']) ? (int) $r['anio_fundacion'] : null,
            'whatsapp' => $r['whatsapp'] ?? '',
            'redes' => self::decodificar($r['redes'] ?? null),
            'necesidades' => self::decodificar($r['necesidades'] ?? null),
            'tienePerros' => (bool) ($r['tiene_perros'] ?? 1),
            'tieneGatos' => (bool) ($r['tiene_gatos'] ?? 1),
            // Rescatista independiente (sin acta): se registra con identificación, domicilio y fotos del lugar
            'independiente' => self::esIndependiente($r['tipo_organizacion'] ?? null),
            'cargoResponsable' => $r['cargo_responsable'] ?? '',
            'capacidad' => isset($r['capacidad']) ? (int) $r['capacidad'] : null,
            'animalesActuales' => isset($r['animales_actuales']) ? (int) $r['animales_actuales'] : null,
            'entregaEsterilizados' => $r['entrega_esterilizados'] ?? null,
            'foto' => $r['foto'] ?? '',
        ];
    }

    private static function coordenada(mixed $v, string $nombre, int $limite): ?float
    {
        if ($v === null || $v === '') {
            return null;
        }
        if (!is_numeric($v) || abs((float) $v) > $limite) {
            throw new ErrorHttp(400, "$nombre no es válida.");
        }
        return round((float) $v, 6);
    }

    private static function codigoPostal(mixed $v): string
    {
        $limpio = Validar::texto($v, 'El código postal', max: 5, opcional: true);
        if ($limpio !== '' && !preg_match('/^\d{5}$/', $limpio)) {
            throw new ErrorHttp(400, 'El código postal debe tener 5 dígitos.');
        }
        return $limpio;
    }

    /** Lista de textos cortos guardada como JSON en una columna VARCHAR2. */
    private static function lista(mixed $v, string $nombre, int $maxElementos, int $maxLargo): ?string
    {
        if ($v === null || $v === '' || $v === []) {
            return null;
        }
        if (!is_array($v) || count($v) > $maxElementos) {
            throw new ErrorHttp(400, "$nombre deben ser una lista de máximo $maxElementos elementos.");
        }
        $limpios = [];
        foreach ($v as $elemento) {
            $texto = Validar::texto($elemento, $nombre, max: $maxLargo, opcional: true);
            if ($texto !== '') {
                $limpios[] = $texto;
            }
        }
        return $limpios ? json_encode($limpios, JSON_UNESCAPED_UNICODE) : null;
    }

    private static function decodificar(?string $json): array
    {
        if ($json === null || $json === '') {
            return [];
        }
        $lista = json_decode($json, true);
        return is_array($lista) ? array_values(array_filter($lista, 'is_string')) : [];
    }
}
