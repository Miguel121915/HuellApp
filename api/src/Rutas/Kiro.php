<?php
declare(strict_types=1);

namespace HuellApp\Rutas;

use HuellApp\{Base, Enrutador, ErrorHttp, Gemini, Serializadores, Sesion, Similitud, Solicitud, Validar};

/**
 * KIRO, el asistente de adopción (HU-7). Contesta dudas sobre HuellApp y recomienda mascotas REALES
 * que están disponibles en refugios aprobados.
 *
 * POST /api/kiro  { mensaje, historial?: [{rol: 'usuario'|'kiro', texto}] }
 *   → { respuesta, mascotas: [mascota + refugioNombre], enlace: 'refugios'|'reportar'|…|null, iaUsada }
 *
 * Con GEMINI_API_KEY responde la IA con la lista de mascotas disponibles como contexto (solo puede
 * recomendar esas). Sin IA, o si falla, responde con reglas sencillas y busca mascotas por palabras.
 */
final class Kiro
{
    private const MAX_MASCOTAS_CONTEXTO = 80;
    private const MAX_HISTORIAL = 8;
    private const MAX_PREGUNTAS = 30; // por persona (IP) cada 10 minutos: la cuota de Gemini es limitada
    private const VENTANA = 600;
    private const ENLACES = ['refugios', 'reportar', 'coincidencias', 'favoritos', 'foro', 'mensajes', 'solicitudes'];

    public static function registrar(Enrutador $r): void
    {
        $r->post('/kiro', [self::class, 'preguntar'], [[Sesion::class, 'sesionOpcional']]);
    }

    public static function preguntar(Solicitud $s): array
    {
        $b = $s->cuerpo();
        $mensaje = Validar::texto($b['mensaje'] ?? null, 'Tu pregunta', min: 2, max: 500);
        self::limitar($s);

        $historial = [];
        foreach (array_slice(is_array($b['historial'] ?? null) ? $b['historial'] : [], -self::MAX_HISTORIAL) as $m) {
            if (is_array($m) && in_array($m['rol'] ?? '', ['usuario', 'kiro'], true) && is_string($m['texto'] ?? null) && trim($m['texto']) !== '') {
                $historial[] = ['rol' => $m['rol'], 'texto' => mb_substr(trim($m['texto']), 0, 800)];
            }
        }
        // Gemini exige que la conversación empiece con el usuario
        while ($historial !== [] && $historial[0]['rol'] !== 'usuario') {
            array_shift($historial);
        }

        $mascotas = self::mascotasDisponibles();
        $porId = array_column($mascotas, null, 'id');

        $ia = Gemini::conversar(self::instrucciones($mascotas, $s->usuario), [...$historial, ['rol' => 'usuario', 'texto' => $mensaje]]);
        if (is_array($ia) && is_string($ia['respuesta'] ?? null) && trim($ia['respuesta']) !== '') {
            $ids = array_values(array_unique(array_filter(
                array_map('strval', is_array($ia['mascotas'] ?? null) ? $ia['mascotas'] : []),
                static fn ($id) => isset($porId[$id]), // solo mascotas que existen y están disponibles
            )));
            $enlace = in_array($ia['enlace'] ?? null, self::ENLACES, true) ? $ia['enlace'] : null;
            return [
                'respuesta' => mb_substr(trim($ia['respuesta']), 0, 1200),
                'mascotas' => array_map(static fn ($id) => self::tarjeta($porId[$id]), array_slice($ids, 0, 3)),
                'enlace' => $enlace,
                'iaUsada' => true,
            ];
        }
        return self::sinIa($mensaje, $mascotas) + ['iaUsada' => false];
    }

    /** Mismo límite que el inicio de sesión, con su propia clave en la tabla intentos_login. */
    private static function limitar(Solicitud $s): void
    {
        $clave = substr('kiro|' . $s->ip(), 0, 190);
        $f = Base::uno('SELECT cuenta, desde FROM intentos_login WHERE clave = ?', [$clave]);
        if ($f && (new \DateTimeImmutable($f['desde'], new \DateTimeZone('UTC')))->getTimestamp() < time() - self::VENTANA) {
            Base::ejecutar('DELETE FROM intentos_login WHERE clave = ?', [$clave]);
            $f = null;
        }
        if ($f && (int) $f['cuenta'] >= self::MAX_PREGUNTAS) {
            throw new ErrorHttp(429, 'KIRO necesita un respiro 🐾. Vuelve a preguntarme en unos minutos.');
        }
        Base::ejecutar(
            'MERGE INTO intentos_login t USING (SELECT ? AS clave, ? AS desde FROM dual) n ON (t.clave = n.clave)
              WHEN MATCHED THEN UPDATE SET t.cuenta = t.cuenta + 1
              WHEN NOT MATCHED THEN INSERT (clave, cuenta, desde) VALUES (n.clave, 1, TO_TIMESTAMP(n.desde, \'YYYY-MM-DD HH24:MI:SS.FF3\'))',
            [$clave, Base::ahora()],
        );
    }

    /** @return list<array> mascotas disponibles de refugios aprobados (con nombre y municipio del refugio) */
    private static function mascotasDisponibles(): array
    {
        return Base::todos(
            "SELECT m.*, r.nombre AS refugio_nombre, r.municipio AS refugio_municipio
               FROM mascotas m JOIN refugios r ON r.id = m.refugio_id
              WHERE m.estatus = 'disponible' AND r.estado = 'aprobado'
              ORDER BY m.creado_en DESC, m.id DESC FETCH FIRST " . self::MAX_MASCOTAS_CONTEXTO . ' ROWS ONLY',
        );
    }

    private static function tarjeta(array $m): array
    {
        return Serializadores::mascota($m) + ['refugioNombre' => $m['refugio_nombre'], 'refugioMunicipio' => $m['refugio_municipio'] ?? ''];
    }

    private static function edad(int $meses): string
    {
        return $meses < 12 ? "$meses meses" : intdiv($meses, 12) . ' año' . (intdiv($meses, 12) === 1 ? '' : 's');
    }

    private static function instrucciones(array $mascotas, ?array $usuario): string
    {
        $lista = implode("\n", array_map(static fn (array $m): string => sprintf(
            '- id=%s | %s | %s %s | %s | %s | %s | refugio: %s (%s) | %s',
            $m['id'], $m['nombre'], $m['especie'], $m['raza'], self::edad((int) $m['edad_meses']), $m['sexo'], $m['tamano'],
            $m['refugio_nombre'], $m['refugio_municipio'] ?: 'sin municipio', mb_substr(preg_replace('/\s+/', ' ', $m['descripcion']), 0, 140),
        ), $mascotas)) ?: '(por ahora no hay mascotas disponibles)';
        $quien = $usuario ? "La persona se llama {$usuario['nombre']} y tiene cuenta." : 'La persona es un visitante sin cuenta.';

        return <<<TXT
            Eres KIRO 🐾, el asistente amable de HuellApp, una plataforma mexicana para adoptar mascotas de refugios
            verificados y para reunir mascotas perdidas con sus familias. Hablas en español de México, de tú, con
            frases cortas y cálidas (máximo 90 palabras). $quien

            Lo que sabes de HuellApp:
            - Adoptar: en «Refugios» se ven las mascotas; se toca «Solicitar adopción», se llenan datos, motivo, se
              suben identificación, comprobante de domicilio y 1 a 3 fotos del espacio. El refugio la revisa y el
              estado se ve en «Mis solicitudes». Cada refugio publica sus requisitos de adopción.
            - Para adoptar, guardar favoritos, escribir a un refugio, reportar o usar el foro hay que iniciar sesión.
            - Reportar: mascota perdida o encontrada con foto y zona; la IA busca parecidas en «Coincidencias» y la
              alerta se publica en el foro.
            - Refugios cercanos: mapa en «Refugios».
            - Cuidados: puedes dar consejos generales de cuidado y adaptación de una mascota adoptada, pero ante
              síntomas de enfermedad recomienda ir al veterinario.

            Mascotas DISPONIBLES ahora (solo puedes recomendar estas, por su id; nunca inventes mascotas):
            $lista

            Si la persona busca una mascota, recomienda de 1 a 3 que encajen (espacio, tiempo, niños, otras mascotas,
            tamaño, edad) y explica en una línea por qué. Si no hay ninguna adecuada, dilo con honestidad.
            No pidas ni guardes datos personales. Si preguntan algo ajeno a mascotas o a HuellApp, redirige con amabilidad.

            Responde SOLO con este JSON:
            {"respuesta": "texto para la persona", "mascotas": ["id", ...], "enlace": "refugios|reportar|coincidencias|favoritos|foro|mensajes|solicitudes|null"}
            TXT;
    }

    /** Respuesta sin IA: reglas sencillas y búsqueda de mascotas por palabras. */
    private static function sinIa(string $mensaje, array $mascotas): array
    {
        $palabras = Similitud::palabras($mensaje);
        $tiene = static fn (string ...$claves): bool => (bool) array_filter($claves, static fn ($c) => isset($palabras[$c]));

        if ($tiene('reportar', 'reporto', 'reporte', 'perdida', 'perdido', 'perdi', 'perdio', 'escapo', 'extravio', 'encontre', 'extraviado', 'extraviada')) {
            return ['respuesta' => 'Si tu mascota se perdió o encontraste una, ve a «Reportar»: sube una foto y la zona. Buscaremos mascotas parecidas en «Coincidencias» y tu alerta saldrá en el foro.', 'mascotas' => [], 'enlace' => 'reportar'];
        }
        if ($tiene('requisitos', 'documentos', 'necesito', 'solicitud', 'solicitar', 'proceso')) {
            return ['respuesta' => 'Para adoptar elige una mascota en «Refugios» y toca «Solicitar adopción». Te pediremos tus datos, el motivo, una identificación, un comprobante de domicilio y fotos del espacio. Cada refugio publica sus requisitos en su perfil.', 'mascotas' => [], 'enlace' => 'refugios'];
        }
        if ($tiene('cercano', 'cercanos', 'cercana', 'mapa', 'ubicacion')) {
            return ['respuesta' => 'En «Refugios» tienes un mapa con todos los refugios verificados y el botón «Cerca de mí» para ver los más cercanos.', 'mascotas' => [], 'enlace' => 'refugios'];
        }

        // ¿Busca una mascota? Se filtra por especie y tamaño, y se ordena por palabras en común
        $especie = $tiene('perro', 'perrito', 'perros', 'cachorro') ? 'perro' : ($tiene('gato', 'gatito', 'gatos', 'michi') ? 'gato' : null);
        $tamano = $tiene('pequeno', 'chico', 'chiquito', 'departamento') ? 'pequeño' : ($tiene('grande') ? 'grande' : ($tiene('mediano') ? 'mediano' : null));
        $candidatas = array_filter($mascotas, static fn ($m) => (!$especie || $m['especie'] === $especie) && (!$tamano || $m['tamano'] === $tamano));
        if ($especie || $tamano || $tiene('adoptar', 'adopcion', 'mascota', 'recomienda', 'recomiendas')) {
            usort($candidatas, static fn ($a, $b) => count(array_intersect_key($palabras, Similitud::palabras("{$b['raza']} {$b['descripcion']}")))
                <=> count(array_intersect_key($palabras, Similitud::palabras("{$a['raza']} {$a['descripcion']}"))));
            $elegidas = array_slice(array_values($candidatas), 0, 3);
            return [
                'respuesta' => $elegidas
                    ? 'Estas mascotas están disponibles y podrían ser para ti. Toca una para conocerla y ver los requisitos de su refugio.'
                    : 'Por ahora no encontré mascotas disponibles con esas características, pero cada semana llegan nuevas. Revisa «Refugios».',
                'mascotas' => array_map([self::class, 'tarjeta'], $elegidas),
                'enlace' => 'refugios',
            ];
        }
        return ['respuesta' => 'Puedo ayudarte a encontrar una mascota para adoptar, explicarte el proceso de adopción, mostrarte refugios cercanos o cómo reportar una mascota perdida. ¿Qué te gustaría hacer?', 'mascotas' => [], 'enlace' => null];
    }
}
