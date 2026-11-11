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
        // Leer el foro es público (el visitante también lo ve); publicar, comentar y dar like piden cuenta
        $r->get('/foro', [self::class, 'listar'], [[Sesion::class, 'sesionOpcional']]);
        $r->grupo('/foro', $sesion, static function (Enrutador $r) use ($soloUsuario): void {
            $r->post('', [self::class, 'crear'], [$soloUsuario]);
            $r->post('/{id}/comentarios', [self::class, 'comentar'], [$soloUsuario]);
            $r->put('/{id}/like', [self::class, 'like'], [$soloUsuario]);
        });
    }

    /**
     * Carga publicaciones con autor, comentarios y "me gusta".
     * `likes` NO cuenta el "me gusta" de quien consulta: el sitio lo suma en pantalla al activarlo.
     */
    /**
     * Pestañas del muro. Cada alerta está ligada a su reporte (publicaciones_foro.reporte_id):
     *  - busca:     mascotas perdidas que siguen buscándose
     *  - familia:   mascotas que alguien halló y que buscan a su familia
     *  - reunidos:  alertas cerradas con «¡Ya apareció!» (finales felices)
     *  - comunidad: publicaciones normales (tips, historias, preguntas)
     */
    private const CATEGORIAS = [
        'busca' => "r.tipo = 'perdida' AND r.estado = 'activo'",
        'familia' => "r.tipo = 'encontrada' AND r.estado = 'activo'",
        'reunidos' => "r.estado = 'reunido'",
        'comunidad' => 'p.reporte_id IS NULL',
    ];

    private static function categoria(?string $tipo, ?string $estado): string
    {
        if ($tipo === null) {
            return 'comunidad';
        }
        return $estado === 'reunido' ? 'reunidos' : ($tipo === 'perdida' ? 'busca' : 'familia');
    }

    private static function cargar(int $usuarioId, ?int $id = null, int $limite = 100, ?string $categoria = null): array
    {
        $limite = max(1, min(200, $limite)); // ya es entero validado; se escribe directo en FETCH FIRST
        $donde = $id ? 'WHERE p.id = ?' : ($categoria ? 'WHERE ' . self::CATEGORIAS[$categoria] : '');
        $filas = Base::todos(
            "SELECT p.id, p.texto, p.foto, p.foto_alt, p.creado_en, p.reporte_id, u.nombre AS autor,
                    r.tipo AS reporte_tipo, r.estado AS reporte_estado, r.usuario_id AS reporte_usuario,
                    (SELECT COUNT(*) FROM likes_foro l WHERE l.publicacion_id = p.id) AS total_likes,
                    CASE WHEN EXISTS (SELECT 1 FROM likes_foro l WHERE l.publicacion_id = p.id AND l.usuario_id = ?) THEN 1 ELSE 0 END AS ya_dio
               FROM publicaciones_foro p JOIN usuarios u ON u.id = p.usuario_id
               LEFT JOIN reportes r ON r.id = p.reporte_id
              $donde
              ORDER BY " . ($categoria === 'reunidos' ? 'r.reunido_en DESC NULLS LAST, ' : '') . "p.creado_en DESC, p.id DESC FETCH FIRST $limite ROWS ONLY",
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
        return array_map(static function (array $f) use ($comentarios, $usuarioId): array {
            return [
                'id' => (string) $f['id'], 'autor' => $f['autor'], 'fecha' => \HuellApp\Serializadores::fecha($f['creado_en']),
                // Alerta de un reporte: pestaña y si es de quien consulta (para el botón «¡Ya apareció!»)
                'categoria' => self::categoria($f['reporte_tipo'] ?? null, $f['reporte_estado'] ?? null),
                'reporteId' => $f['reporte_id'] !== null ? (string) $f['reporte_id'] : null,
                'esMiAlerta' => $f['reporte_usuario'] !== null && (int) $f['reporte_usuario'] === $usuarioId,
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
        // ?categoria=busca|familia|reunidos|comunidad (sin categoría: todo, como antes)
        $categoria = ($s->query['categoria'] ?? '') === ''
            ? null
            : Validar::enumerado($s->query['categoria'], 'La pestaña', array_keys(self::CATEGORIAS));
        return ['publicaciones' => self::cargar((int) ($s->usuario['id'] ?? 0), null, $limite, $categoria)];
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
