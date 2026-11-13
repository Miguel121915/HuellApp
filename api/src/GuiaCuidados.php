<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * GuiaCuidados — Orientación de cuidado después de adoptar (HU-23), según la especie y la etapa de
 * vida (cachorro, adulto o senior). La guía base es fija (funciona sin IA y al instante); con IA se
 * agregan consejos para ESA mascota y ESE hogar (raza, tamaño, salud, vivienda, otras mascotas),
 * que se guardan para no gastar cuota cada vez.
 * Son consejos generales: siempre se recomienda una consulta con el veterinario.
 */
final class GuiaCuidados
{
    /** Desde qué edad (meses) se considera senior. */
    private const SENIOR = ['perro' => 96, 'gato' => 120];
    private const ETAPAS = ['cachorro' => 'cachorro', 'adulto' => 'adulto', 'senior' => 'senior'];

    /** Etapa de vida según especie y edad en meses. */
    public static function etapa(string $especie, int $meses, string $tamano = ''): string
    {
        if ($meses < 12) {
            return 'cachorro';
        }
        $senior = self::SENIOR[$especie] ?? 96;
        if ($especie === 'perro' && $tamano === 'grande') {
            $senior = 84; // los perros grandes envejecen antes (~7 años)
        }
        return $meses >= $senior ? 'senior' : 'adulto';
    }

    /**
     * Guía base para una mascota.
     * @param array $m  fila de mascotas (especie, edad_meses, tamano, nombre)
     * @return array{especie:string, etapa:string, titulo:string, secciones:list<array{titulo:string, icono:string, puntos:list<string>}>}
     */
    public static function base(array $m): array
    {
        $especie = in_array($m['especie'] ?? '', ['perro', 'gato'], true) ? $m['especie'] : 'otro';
        $etapa = self::etapa($especie, (int) ($m['edad_meses'] ?? 0), (string) ($m['tamano'] ?? ''));
        $nombre = trim((string) ($m['nombre'] ?? '')) ?: 'tu mascota';
        $quien = match ($especie) {
            'perro' => ['cachorro' => 'cachorro', 'adulto' => 'perro adulto', 'senior' => 'perro senior'][$etapa],
            'gato' => ['cachorro' => 'gatito', 'adulto' => 'gato adulto', 'senior' => 'gato senior'][$etapa],
            default => 'mascota',
        };

        $secciones = [
            ['titulo' => 'Primeros días en casa', 'icono' => '🏠', 'puntos' => self::primerosDias($especie)],
            ['titulo' => 'Alimentación', 'icono' => '🍽️', 'puntos' => self::alimentacion($especie, $etapa)],
            ['titulo' => 'Salud y veterinario', 'icono' => '🩺', 'puntos' => self::salud($especie, $etapa)],
            ['titulo' => 'Ejercicio, juego y convivencia', 'icono' => '🎾', 'puntos' => self::actividad($especie, $etapa)],
            ['titulo' => 'Ve al veterinario si notas…', 'icono' => '🚨', 'puntos' => self::alertas($especie)],
        ];
        return ['especie' => $especie, 'etapa' => $etapa, 'titulo' => "Guía para cuidar a $nombre ($quien)", 'secciones' => $secciones];
    }

    /** @return list<string> */
    private static function primerosDias(string $e): array
    {
        $comun = [
            'Prepárale un lugar tranquilo con cama, agua y comida antes de que llegue.',
            'Los primeros días puede estar asustado o esconderse: dale tiempo, no lo obligues a convivir.',
            'Mantén la misma comida que le daba el refugio la primera semana y cámbiala poco a poco.',
        ];
        return match ($e) {
            'perro' => [...$comun, 'Ponle collar con placa (tu teléfono) desde el primer día y sácalo siempre con correa.', 'Establece horarios fijos de comida, paseo y descanso: le dan seguridad.'],
            'gato' => [...$comun, 'Ten el arenero limpio en un lugar tranquilo, lejos de su comida.', 'Revisa ventanas y balcones: pon mallas para evitar caídas o escapes.'],
            default => [...$comun, 'Pregúntale al refugio qué espacio, temperatura y cuidados especiales necesita.'],
        };
    }

    /** @return list<string> */
    private static function alimentacion(string $e, string $etapa): array
    {
        $puntos = match ($etapa) {
            'cachorro' => ['Dale alimento para cachorro (o gatito) de 3 a 4 veces al día, en porciones pequeñas.'],
            'senior' => ['Elige alimento para edad avanzada, más fácil de digerir; pregúntale al veterinario por las porciones.'],
            default => ['Dale alimento balanceado para adulto 2 veces al día, según su peso (viene en el empaque).'],
        };
        $puntos[] = 'Siempre agua limpia y fresca a su alcance.';
        $puntos[] = match ($e) {
            'perro' => 'Nunca le des chocolate, uvas o pasas, cebolla, ajo, huesos cocidos ni dulces con xilitol: son tóxicos.',
            'gato' => 'Nunca le des cebolla, ajo, chocolate, leche de vaca ni huesos; y ojo con plantas como los lirios: son tóxicos.',
            default => 'Pregunta al veterinario qué alimentos son seguros para su especie.',
        };
        return $puntos;
    }

    /** @return list<string> */
    private static function salud(string $e, string $etapa): array
    {
        $puntos = ['Llévalo al veterinario en la primera o segunda semana para una revisión general, aunque se vea sano.'];
        $puntos[] = match ($etapa) {
            'cachorro' => 'Completa su esquema de vacunas y desparasitaciones según el calendario de tu veterinario.',
            'senior' => 'Haz chequeos cada 6 meses: en la edad avanzada es más fácil detectar problemas a tiempo.',
            default => 'Mantén sus vacunas al día (incluida la antirrábica) con refuerzo anual.',
        };
        $puntos[] = 'Desparasítalo por dentro y por fuera (pulgas y garrapatas) según te indique el veterinario.';
        $puntos[] = 'Si aún no está esterilizado, platica con el veterinario sobre cuándo hacerlo: es más sano y evita camadas.';
        return $puntos;
    }

    /** @return list<string> */
    private static function actividad(string $e, string $etapa): array
    {
        return match ($e) {
            'perro' => [
                match ($etapa) {
                    'cachorro' => 'Paseos cortos y mucho juego; espera a completar vacunas antes de llevarlo a lugares con otros perros.',
                    'senior' => 'Paseos tranquilos y más cortos, varias veces al día; evita el calor fuerte.',
                    default => 'Al menos 2 paseos al día y juegos para que gaste energía.',
                },
                'Usa premios y paciencia para enseñarle: nunca castigos físicos.',
                'Preséntale a otras mascotas poco a poco y con supervisión.',
            ],
            'gato' => [
                'Dale un rascador y juguetes; juega con él 10 a 15 minutos dos veces al día.',
                'Los gatos necesitan lugares altos y escondites para sentirse seguros.',
                'Preséntale a otras mascotas poco a poco: primero por olor, luego viéndose, y al final juntos.',
            ],
            default => ['Pregúntale al refugio o al veterinario qué actividad y enriquecimiento necesita.'],
        };
    }

    /** @return list<string> */
    private static function alertas(string $e): array
    {
        return [
            'No come o no bebe por más de un día, o vomita o tiene diarrea varias veces.',
            'Está decaído, respira con dificultad o tiene dolor al tocarlo.',
            $e === 'gato' ? 'Va al arenero y no orina, o lo intenta muchas veces (es urgente en gatos).' : 'Tiene la panza hinchada y dura, o intenta vomitar sin lograrlo (es urgente).',
        ];
    }

    /* ---------- Consejos con IA para esta mascota y este hogar ---------- */

    /**
     * 3 a 5 consejos personalizados. null si no hay IA o falló (la guía base sigue funcionando).
     * A la IA no se le manda ningún dato personal del adoptante (nombre, contacto ni dirección).
     * @return list<string>|null
     */
    public static function personalizados(array $m, array $solicitud): ?array
    {
        if (!Gemini::disponible()) {
            return null;
        }
        $base = self::base($m);
        $datos = implode("\n", [
            'MASCOTA: ' . implode(' | ', array_filter([
                $m['especie'] ?? '', $m['raza'] ?? '', 'etapa: ' . $base['etapa'], (int) ($m['edad_meses'] ?? 0) . ' meses',
                $m['sexo'] ?? '', 'tamaño ' . ($m['tamano'] ?? '?'), 'salud: ' . ($m['salud'] ?? 'sin dato'),
                mb_substr(preg_replace('/\s+/', ' ', (string) ($m['descripcion'] ?? '')), 0, 200),
            ])),
            'HOGAR: vivienda ' . $solicitud['tipo_vivienda'] . ' (' . $solicitud['vivienda_propia'] . '); otras mascotas: '
                . (trim((string) $solicitud['otras_mascotas']) ?: 'no indicó'),
        ]);
        $instrucciones = <<<TXT
            Eres un asistente de HuellApp (México) que orienta a una familia que acaba de adoptar una mascota.
            Ya tienen una guía general (primeros días, alimentación, vacunas, desparasitación, ejercicio y señales
            de alerta). Da de 3 a 5 consejos EXTRA y concretos para ESTA mascota y ESTE hogar (raza, tamaño, edad,
            salud, descripción, tipo de vivienda y otras mascotas). No repitas lo general. Frases cortas (máximo
            25 palabras), en español de México, de tú. No diagnostiques ni recetes medicamentos: si algo es de
            salud, recomienda consultarlo con el veterinario. No inventes datos.
            Responde SOLO con este JSON: {"consejos": ["...", "..."]}
            TXT;
        $r = Gemini::conversar($instrucciones, [['rol' => 'usuario', 'texto' => $datos]], 0.4);
        $lista = is_array($r) && is_array($r['consejos'] ?? null) ? $r['consejos'] : [];
        $lista = array_values(array_map(
            static fn (string $t) => mb_substr(trim(preg_replace('/(\*\*|__)(.+?)\1/u', '$2', $t) ?? $t), 0, 220),
            array_filter($lista, static fn ($t) => is_string($t) && trim($t) !== ''),
        ));
        return $lista ? array_slice($lista, 0, 5) : null;
    }
}
