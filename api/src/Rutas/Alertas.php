<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Serializadores, Solicitud, Validar};

/**
 * Alertas públicas de mascotas perdidas y encontradas (se ven SIN cuenta):
 *   GET /api/alertas/{id}  una alerta del foro, para la página que se comparte y el cartel con QR
 *   GET /api/alertas       alertas activas con ubicación APROXIMADA, para el mapa del Inicio
 *
 * Nunca se publica: la seña secreta, el punto exacto del mapa, ni el correo o teléfono de nadie.
 * Para contactar, la persona entra a HuellApp (foro y coincidencias).
 */
final class Alertas
{
    /** El punto del mapa se redondea a una cuadrícula de ~300 m: se ve la zona, no la casa. */
    private const PASO_GRADOS = 0.003;

    public static function registrar(Enrutador $r): void
    {
        $r->get('/alertas', [self::class, 'listar']);
        $r->get('/alertas/{id}', [self::class, 'ver']);
    }

    /** Primer nombre del autor (la alerta pública no muestra el nombre completo). */
    private static function primerNombre(string $nombre): string
    {
        return explode(' ', trim($nombre))[0] ?: 'Alguien';
    }

    /** Redondea una coordenada a la cuadrícula (centro de la celda). */
    private static function aproximar(string|float|int|null $valor): ?float
    {
        if ($valor === null) {
            return null;
        }
        return round((floor((float) $valor / self::PASO_GRADOS) + 0.5) * self::PASO_GRADOS, 5);
    }

    public static function ver(Solicitud $s): array
    {
        $id = Validar::entero($s->parametro('id'), 'La alerta', 1, PHP_INT_MAX);
        $f = Base::uno(
            "SELECT p.id, p.texto, p.foto, p.foto_alt, p.creado_en, u.nombre AS autor,
                    r.tipo, r.estado, r.nombre, r.especie, r.color, r.tamano, r.collar, r.zona, r.descripcion,
                    r.fecha_evento, r.situacion, r.reunido_en, r.creado_en AS reporte_creado
               FROM publicaciones_foro p JOIN usuarios u ON u.id = p.usuario_id
               LEFT JOIN reportes r ON r.id = p.reporte_id
              WHERE p.id = ? AND p.moderacion = 'visible'",
            [$id],
        );
        if ($f === null) {
            throw new ErrorHttp(404, 'Esta alerta ya no está disponible.');
        }
        $esAlerta = $f['tipo'] !== null;
        return ['alerta' => [
            'id' => (string) $f['id'],
            'esAlerta' => $esAlerta,
            // perdida | encontrada (null = publicación normal de la comunidad)
            'tipo' => $f['tipo'],
            'estado' => $f['estado'] ?? 'activo',
            'nombre' => $f['nombre'], 'especie' => $f['especie'], 'color' => $f['color'], 'tamano' => $f['tamano'],
            'collar' => $f['collar'], 'zona' => $f['zona'], 'descripcion' => $f['descripcion'], 'situacion' => $f['situacion'],
            'fechaEvento' => Serializadores::fecha($f['fecha_evento'] ?? $f['reporte_creado'] ?? null),
            'reunidoEn' => Serializadores::fecha($f['reunido_en'] ?? null),
            'texto' => $f['texto'], 'foto' => $f['foto'],
            'fotoAlt' => $f['foto'] !== '' ? ($f['foto_alt'] ?: 'Foto de la mascota') : '',
            'publicadoPor' => self::primerNombre((string) $f['autor']),
            'fecha' => Serializadores::fecha($f['creado_en']),
        ]];
    }

    /** Alertas activas con punto en el mapa (aproximado). ?tipo=perdida|encontrada filtra. */
    public static function listar(Solicitud $s): array
    {
        $tipo = ($s->query['tipo'] ?? '') === '' ? null : Validar::enumerado($s->query['tipo'], 'El tipo', ['perdida', 'encontrada']);
        $filas = Base::todos(
            "SELECT p.id, r.tipo, r.nombre, r.especie, r.zona, r.foto, r.latitud, r.longitud, r.creado_en
               FROM reportes r JOIN publicaciones_foro p ON p.reporte_id = r.id
              WHERE r.estado = 'activo' AND p.moderacion = 'visible'
                AND r.latitud IS NOT NULL AND r.longitud IS NOT NULL" . ($tipo ? ' AND r.tipo = ?' : '') . "
              ORDER BY r.creado_en DESC FETCH FIRST 200 ROWS ONLY",
            $tipo ? [$tipo] : [],
        );
        return ['alertas' => array_map(static fn (array $f): array => [
            'id' => (string) $f['id'], 'tipo' => $f['tipo'], 'nombre' => $f['nombre'], 'especie' => $f['especie'],
            'zona' => $f['zona'], 'foto' => $f['foto'], 'fecha' => Serializadores::fecha($f['creado_en']),
            'latitud' => self::aproximar($f['latitud']), 'longitud' => self::aproximar($f['longitud']),
        ], $filas)];
    }
}
