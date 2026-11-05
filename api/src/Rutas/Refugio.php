<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Archivos, Base, DocumentosMascota, Enrutador, ErrorHttp, Republicacion, Respuesta, Serializadores, Sesion, Solicitud, Validar};

/**
 * Panel del refugio: perfil, inventario de mascotas y publicaciones.
 * Solo para refugios APROBADOS. Cada refugio solo puede tocar SUS datos: el id del refugio sale
 * de la sesión, nunca del cliente.
 */
final class Refugio
{
    private const FOTO_POR_DEFECTO = 'assets/img/mascotas/sin-foto.svg';
    private const ESTATUS = ['disponible', 'en proceso', 'adoptado'];

    private const SELECT_PUBLICACIONES = 'SELECT p.*, r.nombre AS refugio_nombre, m.nombre AS mascota_nombre, m.estatus AS mascota_estatus
        FROM publicaciones_refugio p JOIN refugios r ON r.id = p.refugio_id JOIN mascotas m ON m.id = p.mascota_id';

    public static function registrar(Enrutador $r): void
    {
        $guardias = [[Sesion::class, 'requiereSesion'], Sesion::requiereRol('refugio'), [Sesion::class, 'requiereRefugioAprobado']];
        $r->grupo('/refugio', $guardias, static function (Enrutador $r): void {
            $r->get('/yo', [self::class, 'yo']);
            $r->put('/perfil', [self::class, 'perfil']);
            $r->get('/resumen', [self::class, 'resumen']);

            $r->get('/mascotas', [self::class, 'listarMascotas']);
            $r->post('/mascotas', [self::class, 'crearMascota']);
            $r->put('/mascotas/{id}', [self::class, 'editarMascota']);
            $r->patch('/mascotas/{id}/estatus', [self::class, 'cambiarEstatus']);
            $r->get('/mascotas/{id}/publicaciones/conteo', [self::class, 'contarPublicaciones']);
            $r->delete('/mascotas/{id}', [self::class, 'eliminarMascota']);

            // Documentos especiales de la mascota (vacunas, esterilización, pedigree...)
            $r->get('/mascotas/{id}/documentos', [self::class, 'listarDocumentos']);
            $r->post('/mascotas/{id}/documentos', [self::class, 'subirDocumento']);
            $r->get('/mascotas/{id}/documentos/{doc}/archivo', [self::class, 'archivoDocumento']);
            $r->delete('/mascotas/{id}/documentos/{doc}', [self::class, 'eliminarDocumento']);

            $r->get('/publicaciones', [self::class, 'listarPublicaciones']);
            $r->post('/publicaciones', [self::class, 'crearPublicacion']);
            $r->put('/publicaciones/{id}', [self::class, 'editarPublicacion']);
            $r->delete('/publicaciones/{id}', [self::class, 'eliminarPublicacion']);
        });
    }

    /* ---------- Perfil ---------- */

    private static function documentos(int $refugioId): array
    {
        return Base::todos('SELECT * FROM documentos_refugio WHERE refugio_id = ? ORDER BY id', [$refugioId]);
    }

    public static function yo(Solicitud $s): array
    {
        return ['refugio' => Serializadores::refugioCompleto($s->refugio, self::documentos((int) $s->refugio['id']))];
    }

    // Solo se editan datos de contacto; nombre, responsable y correo requieren nueva verificación
    public static function perfil(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $telefono = Validar::telefono($b['telefono'] ?? null);
        $direccion = Validar::texto($b['direccion'] ?? null, 'La dirección', min: 5, max: 160);
        $horario = Validar::horario($b['horario'] ?? null);
        $descripcion = Validar::texto($b['descripcion'] ?? null, 'La descripción', max: 400, opcional: true);
        $extras = \HuellApp\RefugioExtra::leer($b); // solo los campos que vengan (la app móvil manda ubicación, WhatsApp…)
        Base::ejecutar('UPDATE refugios SET telefono = ?, direccion = ?, horario = ?, descripcion = ? WHERE id = ?', [$telefono, $direccion, $horario, $descripcion, $s->refugio['id']]);
        \HuellApp\RefugioExtra::guardar((int) $s->refugio['id'], $extras);
        $fila = Base::uno('SELECT r.*, u.correo FROM refugios r JOIN usuarios u ON u.id = r.usuario_id WHERE r.id = ?', [$s->refugio['id']]);
        return ['ok' => true, 'refugio' => Serializadores::refugioCompleto($fila, self::documentos((int) $fila['id']))];
    }

    /* ---------- Resumen del panel ---------- */

    public static function resumen(Solicitud $s): array
    {
        $id = $s->refugio['id'];
        $cuenta = static fn (string $estatus): int => (int) Base::valor('SELECT COUNT(*) FROM mascotas WHERE refugio_id = ? AND estatus = ?', [$id, $estatus]);
        return [
            'total' => (int) Base::valor('SELECT COUNT(*) FROM mascotas WHERE refugio_id = ?', [$id]),
            'disponibles' => $cuenta('disponible'), 'enProceso' => $cuenta('en proceso'), 'adoptadas' => $cuenta('adoptado'),
            'publicaciones' => (int) Base::valor('SELECT COUNT(*) FROM publicaciones_refugio WHERE refugio_id = ?', [$id]),
            'mensajesNuevos' => (int) Base::valor("SELECT COUNT(*) FROM mensajes_refugio WHERE refugio_id = ? AND estado = 'nuevo'", [$id]),
            'requisitos' => (int) Base::valor('SELECT COUNT(*) FROM requisitos_refugio WHERE refugio_id = ?', [$id]),
            'recientes' => array_map([Serializadores::class, 'mascota'], Base::todos('SELECT * FROM mascotas WHERE refugio_id = ? ORDER BY id DESC FETCH FIRST 4 ROWS ONLY', [$id])),
        ];
    }

    /* ---------- Inventario de mascotas (CRUD) ---------- */

    private static function leerMascota(array $b): array
    {
        return [
            'nombre' => Validar::texto($b['nombre'] ?? null, 'El nombre', min: 2, max: 40),
            'especie' => Validar::enumerado($b['especie'] ?? null, 'La especie', ['perro', 'gato']),
            'raza' => Validar::texto($b['raza'] ?? null, 'La raza', max: 60),
            'edad_meses' => Validar::entero($b['edadMeses'] ?? null, 'La edad', 1, 360),
            'sexo' => Validar::enumerado($b['sexo'] ?? null, 'El sexo', ['macho', 'hembra']),
            'tamano' => Validar::enumerado($b['tamano'] ?? null, 'El tamaño', ['pequeño', 'mediano', 'grande']),
            'salud' => Validar::texto($b['salud'] ?? null, 'El estado de salud', max: 120),
            'descripcion' => Validar::texto($b['descripcion'] ?? null, 'La descripción', min: 10, max: 400),
            'estatus' => Validar::enumerado($b['estatus'] ?? 'disponible', 'El estatus', self::ESTATUS),
            'foto' => Archivos::resolverFoto($b['foto'] ?? null, 'La foto') ?: self::FOTO_POR_DEFECTO,
        ];
    }

    /** Busca una mascota del refugio de la sesión (si es de otro refugio, responde 404). */
    private static function mascotaPropia(Solicitud $s): array
    {
        $m = Base::uno('SELECT * FROM mascotas WHERE id = ? AND refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($m === null) {
            throw new ErrorHttp(404, 'Esa mascota ya no existe.');
        }
        return $m;
    }

    private static function mascotaPorId(int $id): array
    {
        return Serializadores::mascota(Base::uno('SELECT * FROM mascotas WHERE id = ?', [$id]));
    }

    public static function listarMascotas(Solicitud $s): array
    {
        return ['mascotas' => DocumentosMascota::mascotasConConteo(Base::todos('SELECT * FROM mascotas WHERE refugio_id = ? ORDER BY id DESC', [$s->refugio['id']]))];
    }

    public static function crearMascota(Solicitud $s): Respuesta
    {
        $m = self::leerMascota($s->cuerpo());
        $id = Base::insertar(
            'INSERT INTO mascotas (refugio_id, nombre, especie, raza, edad_meses, sexo, tamano, salud, descripcion, foto, estatus, creado_en, actualizado_en)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [$s->refugio['id'], $m['nombre'], $m['especie'], $m['raza'], $m['edad_meses'], $m['sexo'], $m['tamano'], $m['salud'], $m['descripcion'], $m['foto'], $m['estatus'], Base::ahora(), Base::ahora()],
        );
        return Respuesta::json(['ok' => true, 'mascota' => self::mascotaPorId($id)], 201);
    }

    public static function editarMascota(Solicitud $s): array
    {
        $actual = self::mascotaPropia($s);
        $m = self::leerMascota($s->cuerpo());
        Base::ejecutar(
            'UPDATE mascotas SET nombre = ?, especie = ?, raza = ?, edad_meses = ?, sexo = ?, tamano = ?, salud = ?, descripcion = ?, foto = ?, estatus = ?, actualizado_en = ? WHERE id = ?',
            [$m['nombre'], $m['especie'], $m['raza'], $m['edad_meses'], $m['sexo'], $m['tamano'], $m['salud'], $m['descripcion'], $m['foto'], $m['estatus'], Base::ahora(), $actual['id']],
        );
        return ['ok' => true, 'mascota' => self::mascotaPorId((int) $actual['id'])];
    }

    public static function cambiarEstatus(Solicitud $s): array
    {
        $actual = self::mascotaPropia($s);
        $estatus = Validar::enumerado($s->cuerpo()['estatus'] ?? null, 'El estatus', self::ESTATUS);
        Base::ejecutar('UPDATE mascotas SET estatus = ?, actualizado_en = ? WHERE id = ?', [$estatus, Base::ahora(), $actual['id']]);
        return ['ok' => true, 'mascota' => self::mascotaPorId((int) $actual['id'])];
    }

    // Cuántas publicaciones se borrarían junto con la mascota (para el aviso de confirmación)
    public static function contarPublicaciones(Solicitud $s): array
    {
        $m = self::mascotaPropia($s);
        return ['total' => (int) Base::valor('SELECT COUNT(*) FROM publicaciones_refugio WHERE mascota_id = ?', [$m['id']])];
    }

    // Las publicaciones de la mascota se borran solas (ON DELETE CASCADE en la tabla)
    public static function eliminarMascota(Solicitud $s): array
    {
        $m = self::mascotaPropia($s);
        $publicaciones = (int) Base::valor('SELECT COUNT(*) FROM publicaciones_refugio WHERE mascota_id = ?', [$m['id']]);
        // Las filas se borran solas (CASCADE); los archivos del disco no
        DocumentosMascota::borrarArchivosDeMascota((int) $m['id']);
        Archivos::borrarDocumentos(Adopciones::archivosDeMascota((int) $m['id']));
        Base::ejecutar('DELETE FROM mascotas WHERE id = ?', [$m['id']]);
        return ['ok' => true, 'publicacionesEliminadas' => $publicaciones];
    }

    /* ---------- Documentos de la mascota ---------- */

    private static function documentoPropio(Solicitud $s, array $mascota): array
    {
        $d = Base::uno('SELECT * FROM documentos_mascota WHERE id = ? AND mascota_id = ?', [Validar::idDeRuta($s->parametro('doc')), $mascota['id']]);
        if ($d === null) {
            throw new ErrorHttp(404, 'Ese documento ya no existe.');
        }
        return $d;
    }

    public static function listarDocumentos(Solicitud $s): array
    {
        $m = self::mascotaPropia($s);
        return ['documentos' => array_map([Serializadores::class, 'documentoMascota'], DocumentosMascota::deMascota((int) $m['id']))];
    }

    public static function subirDocumento(Solicitud $s): Respuesta
    {
        $m = self::mascotaPropia($s);
        $fila = DocumentosMascota::subir($m, $s->cuerpo());
        return Respuesta::json(['ok' => true, 'documento' => Serializadores::documentoMascota($fila)], 201);
    }

    public static function archivoDocumento(Solicitud $s): Respuesta
    {
        return DocumentosMascota::servir(self::documentoPropio($s, self::mascotaPropia($s)));
    }

    public static function eliminarDocumento(Solicitud $s): array
    {
        $d = self::documentoPropio($s, self::mascotaPropia($s));
        Base::ejecutar('DELETE FROM documentos_mascota WHERE id = ?', [$d['id']]);
        Archivos::borrarDocumentos([$d['archivo']]);
        return ['ok' => true];
    }

    /* ---------- Publicaciones del refugio ---------- */

    private static function conMascota(array $f): array
    {
        return Serializadores::publicacionRefugio($f) + Serializadores::republicacion($f)
            + ['mascotaNombre' => $f['mascota_nombre'], 'mascotaEstatus' => $f['mascota_estatus']];
    }

    private static function publicacionPorId(int $id): array
    {
        return self::conMascota(Base::uno(self::SELECT_PUBLICACIONES . ' WHERE p.id = ?', [$id]));
    }

    public static function listarPublicaciones(Solicitud $s): array
    {
        Republicacion::aplicar((int) $s->refugio['id']);
        return ['publicaciones' => array_map([self::class, 'conMascota'],
            Base::todos(self::SELECT_PUBLICACIONES . ' WHERE p.refugio_id = ? ORDER BY p.publicado_en DESC, p.id DESC', [$s->refugio['id']]))];
    }

    public static function crearPublicacion(Solicitud $s): Respuesta
    {
        $b = $s->cuerpo();
        $mascotaId = $b['mascotaId'] ?? null;
        $mascota = is_scalar($mascotaId) && ctype_digit((string) $mascotaId)
            ? Base::uno('SELECT * FROM mascotas WHERE id = ? AND refugio_id = ?', [(int) $mascotaId, $s->refugio['id']])
            : null;
        if ($mascota === null) {
            throw new ErrorHttp(400, 'Selecciona una mascota de tu inventario.');
        }
        if ($mascota['estatus'] === 'adoptado') {
            throw new ErrorHttp(400, 'Esa mascota ya fue adoptada; no se puede publicar.');
        }
        $texto = Validar::texto($b['texto'] ?? null, 'El texto', min: 10, max: 500);
        $cadaDias = Republicacion::leerPeriodicidad($b['republicarCadaDias'] ?? null);
        $foto = Archivos::resolverFoto($b['foto'] ?? null, 'La foto') ?: $mascota['foto']; // sin foto propia, se usa la de la mascota
        $ahora = Base::ahora();
        $id = Base::insertar(
            'INSERT INTO publicaciones_refugio (refugio_id, mascota_id, texto, foto, foto_alt, creado_en, republicar_cada_dias, publicado_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [$s->refugio['id'], $mascota['id'], $texto, $foto, "Foto de {$mascota['nombre']}", $ahora, $cadaDias, $ahora],
        );
        return Respuesta::json(['ok' => true, 'publicacion' => self::publicacionPorId($id)], 201);
    }

    // Se editan el texto, la foto y la republicación; la mascota no cambia (para eso se crea otra publicación)
    public static function editarPublicacion(Solicitud $s): array
    {
        $actual = Base::uno(self::SELECT_PUBLICACIONES . ' WHERE p.id = ? AND p.refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($actual === null) {
            throw new ErrorHttp(404, 'Esa publicación ya no existe.');
        }
        $b = $s->cuerpo();
        $texto = Validar::texto($b['texto'] ?? null, 'El texto', min: 10, max: 500);
        $cadaDias = Republicacion::leerPeriodicidad($b['republicarCadaDias'] ?? null);
        // Sin foto nueva se conserva la actual
        $foto = array_key_exists('foto', $b) && $b['foto'] !== '' ? Archivos::resolverFoto($b['foto'], 'La foto') : $actual['foto'];
        Base::ejecutar(
            'UPDATE publicaciones_refugio SET texto = ?, foto = ?, republicar_cada_dias = ? WHERE id = ?',
            [$texto, $foto, $cadaDias, $actual['id']],
        );
        return ['ok' => true, 'publicacion' => self::publicacionPorId((int) $actual['id'])];
    }

    public static function eliminarPublicacion(Solicitud $s): array
    {
        $n = Base::ejecutar('DELETE FROM publicaciones_refugio WHERE id = ? AND refugio_id = ?', [Validar::idDeRuta($s->parametro('id')), $s->refugio['id']]);
        if ($n === 0) {
            throw new ErrorHttp(404, 'Esa publicación ya no existe.');
        }
        return ['ok' => true];
    }
}
