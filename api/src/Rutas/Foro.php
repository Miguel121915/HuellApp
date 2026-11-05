<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, Enrutador, ErrorHttp, Respuesta, Sesion, Solicitud, Validar};

/** Rutas del foro: publicaciones, comentarios y "me gusta" (huella). */
final class Foro
{
    public static function registrar(Enrutador $r): void
    {
        $sesion = [[Sesion::class, 'requiereSesion']];
        $soloUsuario = Sesion::requiereRol('usuario');
        $r->grupo('/foro', $sesion, static function (Enrutador $r) use ($soloUsuario): void {
            $r->get('', [self::class, 'listar'], [Sesion::requiereRol('usuario', 'admin')]);
            $r->post('', [self::class, 'crear'], [$soloUsuario]);
            $r->post('/{id}/comentarios', [self::class, 'comentar'], [$soloUsuario]);
            $r->put('/{id}/like', [self::class, 'like'], [$soloUsuario]);
        });
    }

    /**
     * Carga publicaciones con autor, comentarios y "me gusta".
     * `likes` NO cuenta el "me gusta" de quien consulta: el sitio lo suma en pantalla al activarlo.
     */
    private static function cargar(int $usuarioId, ?int $id = null, int $limite = 100): array
    {
        $limite = max(1, min(200, $limite)); // ya es entero validado; se escribe directo en FETCH FIRST
        $filas = Base::todos(
            "SELECT p.id, p.texto, p.foto, p.foto_alt, p.creado_en, u.nombre AS autor,
                    (SELECT COUNT(*) FROM likes_foro l WHERE l.publicacion_id = p.id) AS total_likes,
                    CASE WHEN EXISTS (SELECT 1 FROM likes_foro l WHERE l.publicacion_id = p.id AND l.usuario_id = ?) THEN 1 ELSE 0 END AS ya_dio
               FROM publicaciones_foro p JOIN usuarios u ON u.id = p.usuario_id
              " . ($id ? 'WHERE p.id = ?' : '') . "
              ORDER BY p.creado_en DESC, p.id DESC FETCH FIRST $limite ROWS ONLY",
            $id ? [$usuarioId, $id] : [$usuarioId],
        );
        if (!$filas) {
            return [];
        }
        $ids = array_column($filas, 'id');
        $comentarios = Base::todos(
            'SELECT c.publicacion_id, u.nombre AS autor, c.texto
               FROM comentarios_foro c JOIN usuarios u ON u.id = c.usuario_id
              WHERE c.publicacion_id IN (' . implode(',', array_fill(0, count($ids), '?')) . ') ORDER BY c.id',
            $ids,
        );
        return array_map(static function (array $f) use ($comentarios): array {
            return [
                'id' => (string) $f['id'], 'autor' => $f['autor'], 'fecha' => \HuellApp\Serializadores::fecha($f['creado_en']),
                'texto' => $f['texto'], 'foto' => $f['foto'],
                'fotoAlt' => $f['foto'] !== '' ? ($f['foto_alt'] ?: "Foto publicada por {$f['autor']}") : '',
                'likes' => (int) $f['total_likes'] - (int) $f['ya_dio'], 'yaDioLike' => (bool) $f['ya_dio'],
                'comentarios' => array_values(array_map(
                    static fn ($c) => ['autor' => $c['autor'], 'texto' => $c['texto']],
                    array_filter($comentarios, static fn ($c) => (int) $c['publicacion_id'] === (int) $f['id']),
                )),
            ];
        }, $filas);
    }

    private static function existe(string $idRuta): int
    {
        $id = Validar::idDeRuta($idRuta);
        if (!Base::uno('SELECT 1 FROM publicaciones_foro WHERE id = ?', [$id])) {
            throw new ErrorHttp(404, 'Esa publicación ya no existe.');
        }
        return $id;
    }

    public static function listar(Solicitud $s): array
    {
        $limite = Validar::entero($s->query['limite'] ?? 100, 'El límite', 1, 200);
        return ['publicaciones' => self::cargar((int) $s->usuario['id'], null, $limite)];
    }

    public static function crear(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $texto = Validar::texto($b['texto'] ?? null, 'El texto', min: 5, max: 600);
        $foto = Archivos::resolverFoto($b['foto'] ?? null, 'La foto');
        $id = Base::insertar(
            'INSERT INTO publicaciones_foro (usuario_id, texto, foto, foto_alt, creado_en) VALUES (?, ?, ?, ?, ?)',
            [$s->usuario['id'], $texto, $foto, $foto !== '' ? "Foto publicada por {$s->usuario['nombre']}" : '', Base::ahora()],
        );
        return Respuesta::json(['ok' => true, 'publicacion' => self::cargar((int) $s->usuario['id'], $id)[0]], 201);
    }

    public static function comentar(Solicitud $s): Respuesta
    {
        $id = self::existe($s->parametro('id'));
        $texto = Validar::texto($s->cuerpo()['texto'] ?? null, 'El comentario', min: 1, max: 300);
        Base::insertar('INSERT INTO comentarios_foro (publicacion_id, usuario_id, texto, creado_en) VALUES (?, ?, ?, ?)', [$id, $s->usuario['id'], $texto, Base::ahora()]);
        return Respuesta::json(['ok' => true, 'comentarios' => self::cargar((int) $s->usuario['id'], $id)[0]['comentarios']], 201);
    }

    // Fija (no alterna) el estado: así dos clics rápidos nunca se desincronizan
    public static function like(Solicitud $s): array
    {
        $id = self::existe($s->parametro('id'));
        $activo = Validar::booleano($s->cuerpo()['activo'] ?? null, '«activo»');
        if ($activo) {
            Base::insertarSiNoExiste('INSERT INTO likes_foro (publicacion_id, usuario_id) VALUES (?, ?)', [$id, $s->usuario['id']]);
        } else {
            Base::ejecutar('DELETE FROM likes_foro WHERE publicacion_id = ? AND usuario_id = ?', [$id, $s->usuario['id']]);
        }
        return ['ok' => true, 'activo' => $activo];
    }
}
