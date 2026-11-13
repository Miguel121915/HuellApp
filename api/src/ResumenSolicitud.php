<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * ResumenSolicitud — Resumen con IA de una solicitud de adopción para el refugio (HU-22):
 * una síntesis, puntos a favor, focos de atención y preguntas para la entrevista.
 *
 * Privacidad: a la IA NO se le mandan nombre, correo, teléfono ni dirección; solo lo que sirve para
 * valorar la adopción (vivienda, otras mascotas, ocupación, motivo y qué documentos subió).
 * Sin IA (sin clave, sin cuota o si falla) se arma un resumen con reglas sencillas: la pantalla nunca
 * se queda vacía. La decisión siempre es del refugio.
 */
final class ResumenSolicitud
{
    private const MAX_PUNTOS = 4;
    private const DOCUMENTOS = ['identificacion' => 'identificación', 'domicilio' => 'comprobante de domicilio', 'vivienda' => 'fotos de la vivienda'];

    /**
     * @param array $s  fila de solicitudes_adopcion (con mascota_nombre)
     * @return array{sintesis:string, aFavor:list<string>, atencion:list<string>, preguntas:list<string>, iaUsada:bool}
     */
    public static function generar(array $s): array
    {
        $mascota = Base::uno('SELECT nombre, especie, raza, edad_meses, sexo, tamano, salud, descripcion FROM mascotas WHERE id = ?', [$s['mascota_id']]) ?? [];
        $tipos = array_column(Base::todos('SELECT tipo FROM documentos_adopcion WHERE solicitud_id = ?', [$s['id']]), 'tipo');
        $requisitos = array_column(Base::todos(
            'SELECT texto FROM requisitos_refugio WHERE refugio_id = ? AND obligatorio = 1 ORDER BY id FETCH FIRST 10 ROWS ONLY',
            [$s['refugio_id']],
        ), 'texto');

        $ia = self::conIa($s, $mascota, $tipos, $requisitos);
        return $ia ?? self::sinIa($s, $mascota, $tipos);
    }

    private static function conIa(array $s, array $m, array $tipos, array $requisitos): ?array
    {
        if (!Gemini::disponible()) {
            return null;
        }
        $documentos = array_map(static fn ($t) => self::DOCUMENTOS[$t] ?? $t, array_values(array_unique($tipos)));
        $datos = implode("\n", [
            'MASCOTA: ' . implode(' | ', array_filter([
                $m['nombre'] ?? '', $m['especie'] ?? '', $m['raza'] ?? '', isset($m['edad_meses']) ? self::edad((int) $m['edad_meses']) : '',
                $m['sexo'] ?? '', 'tamaño ' . ($m['tamano'] ?? '?'), 'salud: ' . ($m['salud'] ?? 'sin dato'),
                mb_substr(preg_replace('/\s+/', ' ', (string) ($m['descripcion'] ?? '')), 0, 200),
            ])),
            'SOLICITANTE:',
            '- Vivienda: ' . $s['tipo_vivienda'] . ' (' . $s['vivienda_propia'] . ')',
            '- Otras mascotas: ' . (trim((string) $s['otras_mascotas']) ?: 'no indicó'),
            '- Ocupación: ' . (trim((string) $s['ocupacion']) ?: 'no indicó'),
            '- Motivo: «' . mb_substr(preg_replace('/\s+/', ' ', (string) $s['motivo']), 0, 800) . '»',
            '- Documentos subidos: ' . ($documentos ? implode(', ', $documentos) : 'ninguno'),
            'REQUISITOS OBLIGATORIOS DEL REFUGIO: ' . ($requisitos ? implode('; ', $requisitos) : 'no publicó'),
        ]);
        $instrucciones = <<<TXT
            Eres un asistente de HuellApp que ayuda a un refugio de mascotas en México a revisar solicitudes de
            adopción. Analiza la solicitud y resume, en español y con frases cortas, lo que el refugio debe saber.
            Sé justo y respetuoso: no juzgues por ocupación, tipo de vivienda o nivel económico por sí mismos; señala
            solo lo relevante para el bienestar de la mascota (espacio, tiempo, otras mascotas, si la vivienda es
            rentada, si faltan documentos o requisitos, si el motivo es vago o preocupante, como regalarla o
            usarla solo para cuidar la casa). Nunca inventes datos que no estén en la solicitud.
            No decides tú: el refugio decide.

            Responde SOLO con este JSON (máximo 4 elementos por lista, cada uno de máximo 20 palabras):
            {"sintesis": "1 o 2 frases", "aFavor": ["..."], "atencion": ["..."], "preguntas": ["preguntas para la entrevista"]}
            TXT;
        $r = Gemini::conversar($instrucciones, [['rol' => 'usuario', 'texto' => $datos]], 0.3);
        if (!is_array($r) || !is_string($r['sintesis'] ?? null) || trim($r['sintesis']) === '') {
            return null;
        }
        return [
            'sintesis' => mb_substr(self::limpio($r['sintesis']), 0, 300),
            'aFavor' => self::lista($r['aFavor'] ?? []),
            'atencion' => self::lista($r['atencion'] ?? []),
            'preguntas' => self::lista($r['preguntas'] ?? []),
            'iaUsada' => true,
        ];
    }

    /** Resumen con reglas sencillas (sin IA). */
    private static function sinIa(array $s, array $m, array $tipos): array
    {
        $aFavor = $atencion = $preguntas = [];
        $especie = ($m['especie'] ?? '') === 'gato' ? 'gato' : 'perro';
        $grande = ($m['tamano'] ?? '') === 'grande';

        $faltan = array_diff(['identificacion', 'domicilio', 'vivienda'], $tipos);
        if ($faltan === []) {
            $aFavor[] = 'Subió identificación, comprobante de domicilio y fotos de la vivienda.';
        } else {
            $atencion[] = 'Falta: ' . implode(', ', array_map(static fn ($t) => self::DOCUMENTOS[$t], $faltan)) . '.';
        }
        if ($s['vivienda_propia'] === 'propia') {
            $aFavor[] = 'La vivienda es propia.';
        } elseif ($s['vivienda_propia'] === 'rentada') {
            $atencion[] = 'Vivienda rentada: confirma que el contrato permite mascotas.';
            $preguntas[] = '¿Tu arrendador permite mascotas? ¿Lo tienes por escrito?';
        }
        if ($s['tipo_vivienda'] === 'casa') {
            $aFavor[] = 'Vive en casa.';
        } elseif ($s['tipo_vivienda'] === 'departamento' && $grande && $especie === 'perro') {
            $atencion[] = 'Departamento con un perro grande: revisa espacio y paseos diarios.';
            $preguntas[] = '¿Cuántos paseos al día podrías darle y de cuánto tiempo?';
        }
        if (self::tieneOtrasMascotas((string) $s['otras_mascotas'])) {
            $preguntas[] = '¿Cómo se llevan tus mascotas actuales con otros animales?';
        }
        $palabras = count(preg_split('/\s+/', trim((string) $s['motivo'])) ?: []);
        if ($palabras >= 25) {
            $aFavor[] = 'Explicó su motivo con detalle.';
        } else {
            $atencion[] = 'El motivo es breve: conviene platicarlo en la entrevista.';
        }
        $preguntas[] = '¿Quién cuidará a la mascota cuando no estés en casa?';

        return [
            'sintesis' => "Solicitud para adoptar a {$s['mascota_nombre']}. Resumen hecho con reglas básicas (sin IA): revisa los datos completos.",
            'aFavor' => array_slice($aFavor, 0, self::MAX_PUNTOS),
            'atencion' => array_slice($atencion, 0, self::MAX_PUNTOS),
            'preguntas' => array_slice($preguntas, 0, self::MAX_PUNTOS),
            'iaUsada' => false,
        ];
    }

    /** «Ninguna», «no», «no tengo»… cuentan como que no tiene otras mascotas. */
    private static function tieneOtrasMascotas(string $texto): bool
    {
        $t = mb_strtolower(trim($texto));
        return $t !== '' && !preg_match('/^(no|ningun[oa]s?|nada|n\/a|sin mascotas|no tengo\b.*)\.?$/u', $t);
    }

    /**
     * JSON para guardar en resumen_ia (VARCHAR2 de 2000): si no cabe, se recortan primero las preguntas
     * y luego los puntos, nunca la síntesis.
     */
    public static function aJson(array $resumen): string
    {
        foreach (['preguntas', 'aFavor', 'atencion'] as $lista) {
            while (mb_strlen(json_encode($resumen, JSON_UNESCAPED_UNICODE)) > 1990 && count($resumen[$lista]) > 1) {
                array_pop($resumen[$lista]);
            }
        }
        return json_encode($resumen, JSON_UNESCAPED_UNICODE);
    }

    /** @return list<string> */
    private static function lista(mixed $valor): array
    {
        $lista = array_filter(is_array($valor) ? $valor : [], static fn ($v) => is_string($v) && trim($v) !== '');
        return array_values(array_map(static fn (string $v) => mb_substr(self::limpio($v), 0, 180), array_slice($lista, 0, self::MAX_PUNTOS)));
    }

    /** Sin Markdown: la web y la app muestran texto plano. */
    private static function limpio(string $texto): string
    {
        $texto = preg_replace('/(\*\*|__)(.+?)\1/u', '$2', $texto) ?? $texto;
        return trim(preg_replace('/\s+/u', ' ', $texto) ?? $texto);
    }

    private static function edad(int $meses): string
    {
        return $meses < 12 ? "$meses meses" : intdiv($meses, 12) . ' año' . (intdiv($meses, 12) === 1 ? '' : 's');
    }
}
