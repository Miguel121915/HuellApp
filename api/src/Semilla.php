<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Semilla — Datos de demostración (database/datos-demo.json).
 * Se cargan con "php artisan migrate --seed" o "php artisan db:seed".
 * Todas las cuentas demo usan la contraseña "Demo1234".
 */
final class Semilla
{
    private const PASSWORD_DEMO = 'Demo1234';

    private const TITULOS = [
        'acta' => 'Acta constitutiva', 'domicilio' => 'Comprobante de domicilio',
        'identificacion' => 'Identificacion del responsable', 'permiso' => 'Permiso de refugio',
        // Documentos de mascotas (sin acentos: el PDF de ejemplo usa una fuente básica)
        'vacunacion' => 'Certificado de vacunacion', 'esterilizacion' => 'Constancia de esterilizacion',
        'desparasitacion' => 'Registro de desparasitacion', 'pedigree' => 'Pedigree', 'medico' => 'Expediente medico', 'otro' => 'Documento',
    ];

    /** Fecha de hace N horas (puede ser fraccionaria). */
    private static function hace(float $horas): string
    {
        return Base::ahora((int) round($horas * 3600));
    }

    /**
     * Parte aleatoria del nombre de los archivos demo. La base de pruebas (huellapp_test) y la real
     * comparten la carpeta storage/uploads: con nombres fijos, una prueba que reemplaza o borra un
     * documento podría borrar el archivo que usa la base real.
     */
    private static function sufijo(): string
    {
        return bin2hex(random_bytes(4));
    }

    /** Un PDF mínimo y válido para que el visor de documentos del administrador tenga algo que mostrar. */
    private static function pdfDeEjemplo(string $titulo): string
    {
        $flujo = "BT /F1 22 Tf 60 720 Td ($titulo) Tj ET\nBT /F1 12 Tf 60 690 Td (Documento de demostracion de HuellApp) Tj ET";
        $objetos = [
            '<< /Type /Catalog /Pages 2 0 R >>',
            '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
            '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
            '<< /Length ' . strlen($flujo) . " >>\nstream\n$flujo\nendstream",
            '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        ];
        $pdf = "%PDF-1.4\n";
        $posiciones = [];
        foreach ($objetos as $i => $objeto) {
            $posiciones[] = strlen($pdf);
            $pdf .= ($i + 1) . " 0 obj\n$objeto\nendobj\n";
        }
        $inicio = strlen($pdf);
        $pdf .= "xref\n0 " . (count($objetos) + 1) . "\n0000000000 65535 f \n";
        foreach ($posiciones as $p) {
            $pdf .= str_pad((string) $p, 10, '0', STR_PAD_LEFT) . " 00000 n \n";
        }
        return $pdf . "trailer\n<< /Size " . (count($objetos) + 1) . " /Root 1 0 R >>\nstartxref\n$inicio\n%%EOF\n";
    }

    public static function sembrar(): void
    {
        $datos = json_decode((string) file_get_contents(RAIZ . '/database/datos-demo.json'), true, 512, JSON_THROW_ON_ERROR);
        $cuentas = [...$datos['usuarios'], ...array_map(static fn ($c) => $c + ['rol' => 'usuario'], $datos['comunidad'])];

        Base::transaccion(static function () use ($datos, $cuentas): void {
            $idUsuario = [];
            foreach ($cuentas as $i => $c) {
                $idUsuario[$c['correo']] = Base::insertar(
                    'INSERT INTO usuarios (nombre, correo, telefono, password_hash, rol, creado_en) VALUES (?, ?, ?, ?, ?, ?)',
                    [$c['nombre'], $c['correo'], $c['telefono'] ?? null, password_hash(self::PASSWORD_DEMO, PASSWORD_DEFAULT), $c['rol'], self::hace(500 - $i)],
                );
            }

            // Refugios y sus documentos (archivos PDF de ejemplo en storage/uploads/documentos)
            $idRefugio = [];
            foreach ($datos['refugios'] as $i => $r) {
                $id = Base::insertar(
                    'INSERT INTO refugios (usuario_id, nombre, responsable, telefono, direccion, horario, estado, motivo_rechazo, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    [$idUsuario[$r['correoDueno']], $r['nombre'], $r['responsable'], $r['telefono'], $r['direccion'], $r['horario'], $r['estado'], $r['motivoRechazo'], self::hace(400 - $i * 24)],
                );
                $idRefugio[$r['clave']] = $id;
                foreach ($r['documentos'] as $d) {
                    $contenido = self::pdfDeEjemplo(self::TITULOS[$d['tipo']]);
                    $archivo = "demo-$id-{$d['tipo']}-" . self::sufijo() . '.pdf';
                    file_put_contents(Archivos::dirDocumentos() . "/$archivo", $contenido);
                    Base::insertar(
                        "INSERT INTO documentos_refugio (refugio_id, tipo, nombre, archivo, mime, tamano, verificado, con_error) VALUES (?, ?, ?, ?, 'application/pdf', ?, ?, ?)",
                        [$id, $d['tipo'], $d['nombre'], $archivo, strlen($contenido), $r['estado'] === 'aprobado' || ($r['estado'] === 'rechazado' && empty($d['conError'])) ? 1 : 0, empty($d['conError']) ? 0 : 1],
                    );
                }
            }

            // Mascotas y publicaciones de los refugios
            $idMascota = [];
            foreach ($datos['mascotas'] as $m) {
                $idMascota[$m['clave']] = Base::insertar(
                    'INSERT INTO mascotas (refugio_id, nombre, especie, raza, edad_meses, sexo, tamano, salud, descripcion, foto, estatus) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    [$idRefugio[$m['refugio']], $m['nombre'], $m['especie'], $m['raza'], $m['edadMeses'], $m['sexo'], $m['tamano'], $m['salud'], $m['descripcion'], $m['foto'], $m['estatus']],
                );
            }
            foreach ($datos['publicacionesRefugio'] as $p) {
                $fecha = self::hace($p['horasAtras']);
                Base::insertar(
                    'INSERT INTO publicaciones_refugio (refugio_id, mascota_id, texto, foto, foto_alt, creado_en, republicar_cada_dias, publicado_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [$idRefugio[$p['refugio']], $idMascota[$p['mascota']], $p['texto'], $p['foto'], $p['fotoAlt'], $fecha, $p['republicarCadaDias'] ?? null, $fecha],
                );
            }

            // Preguntas frecuentes de los refugios (las usa el asistente del formulario de adopción)
            foreach ($datos['preguntasRefugio'] ?? [] as $p) {
                Base::insertar(
                    'INSERT INTO preguntas_refugio (refugio_id, pregunta, respuesta, claves) VALUES (?, ?, ?, ?)',
                    [$idRefugio[$p['refugio']], $p['pregunta'], $p['respuesta'], implode(', ', $p['claves'] ?? [])],
                );
            }

            // Documentos especiales de algunas mascotas (vacunas, esterilización, pedigree)
            foreach ($datos['documentosMascota'] ?? [] as $i => $d) {
                $mascotaId = $idMascota[$d['mascota']];
                $contenido = self::pdfDeEjemplo(self::TITULOS[$d['tipo']]);
                $archivo = "demo-mascota-$mascotaId-$i-" . self::sufijo() . '.pdf';
                file_put_contents(Archivos::dirDocumentos() . "/$archivo", $contenido);
                Base::insertar(
                    "INSERT INTO documentos_mascota (mascota_id, refugio_id, tipo, nombre, archivo, mime, tamano, verificado)
                     SELECT id, refugio_id, ?, ?, ?, 'application/pdf', ?, ? FROM mascotas WHERE id = ?",
                    [$d['tipo'], $d['nombre'], $archivo, strlen($contenido), $d['verificado'] ? 1 : 0, $mascotaId],
                );
            }

            // Foro: publicaciones, comentarios y "me gusta" (repartidos entre las cuentas, sin contar a Ana)
            $quienesDanLike = array_values(array_filter($idUsuario, static fn ($id, $correo) => $correo !== 'ana@huellapp.mx', ARRAY_FILTER_USE_BOTH));
            foreach (array_reverse($datos['foro']) as $p) {
                $id = Base::insertar(
                    'INSERT INTO publicaciones_foro (usuario_id, texto, foto, foto_alt, creado_en) VALUES (?, ?, ?, ?, ?)',
                    [$idUsuario[$p['autor']], $p['texto'], $p['foto'], $p['fotoAlt'], self::hace($p['horasAtras'])],
                );
                foreach ($p['comentarios'] as $i => $c) {
                    Base::insertar(
                        'INSERT INTO comentarios_foro (publicacion_id, usuario_id, texto, creado_en) VALUES (?, ?, ?, ?)',
                        [$id, $idUsuario[$c['autor']], $c['texto'], self::hace(max(0.2, $p['horasAtras'] - 1 - $i))],
                    );
                }
                foreach (array_slice($quienesDanLike, 0, $p['likes']) as $usuario) {
                    Base::ejecutar('INSERT IGNORE INTO likes_foro (publicacion_id, usuario_id) VALUES (?, ?)', [$id, $usuario]);
                }
            }

            // Reportes y coincidencias
            $idReporte = [];
            foreach ($datos['reportes'] as $r) {
                $idReporte[$r['clave']] = Base::insertar(
                    'INSERT INTO reportes (usuario_id, tipo, descripcion, zona, foto, foto_alt, creado_en) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [$idUsuario[$r['autor']], $r['tipo'], $r['descripcion'], $r['zona'], $r['foto'], $r['fotoAlt'], self::hace($r['horasAtras'])],
                );
            }
            foreach ($datos['coincidencias'] as $c) {
                Base::insertar(
                    'INSERT INTO coincidencias (reporte_perdido_id, reporte_encontrado_id, similitud) VALUES (?, ?, ?)',
                    [$idReporte[$c['perdido']], $idReporte[$c['encontrado']], $c['similitud']],
                );
            }
        });
    }
}
