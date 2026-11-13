<?php
declare(strict_types=1);

namespace HuellApp;

/**
 * Moderación de contenido (HU-18) para publicaciones y comentarios del foro.
 *
 *  1. Al publicar: revisión instantánea con una lista de palabras (insultos y venta de animales).
 *  2. En segundo plano (php artisan moderacion:revisar): la IA revisa el texto.
 * Lo que se marca queda «en revisión»: se oculta a los demás (su autor sí lo ve) hasta que el
 * administrador lo apruebe o lo quite desde su bandeja de Moderación.
 *
 * Columnas en publicaciones_foro y comentarios_foro: moderacion (visible | revision | quitado),
 * moderacion_motivo, moderacion_fuente (palabras | ia) y moderacion_en.
 */
final class Moderacion
{
    public const TABLAS = ['publicacion' => 'publicaciones_foro', 'comentario' => 'comentarios_foro'];

    /**
     * Raíces sin acentos y en minúsculas. Se buscan como palabra completa (o como inicio de palabra
     * cuando terminan en *). «perra» NO está: en HuellApp es una perrita.
     */
    private const OFENSIVAS = [
        'pendej*', 'put[oa]s?', 'putit[oa]s?', 'cabron*', 'chingad*', 'chingar*', 'chingue*', 'chinga', 'verga*',
        'mierda*', 'imbecil*', 'idiota*', 'estupid[oa]s?', 'culer[oa]s?', 'mamon*', 'joto*', 'maricon*', 'zorra*',
        'pinche', 'hdp', 'ptm', 'alv', 'nmms',
    ];
    /** Vender animales va contra el propósito de HuellApp (adopción responsable). */
    // «precio» no: preguntar el precio de una consulta o vacuna es normal; la IA revisa los casos dudosos
    private const VENTA = ['vendo', 'se vende*', 'en venta', 'a la venta', '\$\s?\d+'];

    /**
     * Revisión instantánea. Devuelve el motivo si algo coincide, o null si pasa.
     */
    public static function porPalabras(string $texto): ?string
    {
        $t = self::normalizar($texto);
        $encontradas = array_values(array_filter(self::OFENSIVAS, static fn ($p) => preg_match(self::patron($p), $t)));
        if ($encontradas !== []) {
            return 'Lenguaje ofensivo detectado automáticamente.';
        }
        foreach (self::VENTA as $p) {
            if (preg_match(self::patron($p), $t)) {
                return 'Posible venta de animales (HuellApp es solo para adopción).';
            }
        }
        return null;
    }

    /**
     * Revisión con IA. Devuelve el motivo si es inapropiado, '' si es apropiado o null si no hay IA.
     */
    public static function porIa(string $texto): ?string
    {
        if (!Gemini::disponible()) {
            return null;
        }
        $instrucciones = <<<TXT
            Eres moderador de HuellApp, una comunidad mexicana de adopción de mascotas y búsqueda de mascotas perdidas.
            Decide si el texto que te mandan es apropiado para publicarse. Es INAPROPIADO si tiene: insultos o
            groserías dirigidas a alguien, acoso o amenazas, discriminación, maltrato animal o incitación a él,
            venta o compra de animales, contenido sexual, estafas o spam, o datos personales sensibles de otra
            persona. Es APROPIADO hablar de mascotas perdidas, adopción, cuidados, dudas, historias o quejas
            respetuosas; también palabras como «perra» o «perro» referidas a animales.
            Responde SOLO con este JSON: {"apropiado": true|false, "motivo": "frase corta en español si no es apropiado"}
            TXT;
        $r = Gemini::conversar($instrucciones, [['rol' => 'usuario', 'texto' => mb_substr($texto, 0, 600)]], 0.0);
        if (!is_array($r) || !is_bool($r['apropiado'] ?? null)) {
            return null;
        }
        if ($r['apropiado']) {
            return '';
        }
        $motivo = is_string($r['motivo'] ?? null) ? trim($r['motivo']) : '';
        return mb_substr($motivo !== '' ? $motivo : 'La IA lo marcó como posible contenido inapropiado.', 0, 280);
    }

    /** Marca un elemento «en revisión» (si sigue visible: no pisa lo que el admin ya decidió). */
    public static function marcar(string $tipo, int $id, string $motivo, string $fuente): void
    {
        Base::ejecutar(
            'UPDATE ' . self::TABLAS[$tipo] . " SET moderacion = 'revision', moderacion_motivo = ?, moderacion_fuente = ?, moderacion_en = TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS.FF3')
              WHERE id = ? AND moderacion = 'visible'",
            [mb_substr($motivo, 0, 290), $fuente, Base::ahora(), $id],
        );
    }

    /**
     * Revisa con IA un elemento recién publicado (lo lanza la API en segundo plano).
     * @return string resumen para la terminal
     */
    public static function revisarConIa(string $tipo, int $id): string
    {
        $fila = Base::uno('SELECT texto, moderacion FROM ' . self::TABLAS[$tipo] . ' WHERE id = ?', [$id]);
        if ($fila === null) {
            return 'ya no existe';
        }
        if ($fila['moderacion'] !== 'visible') {
            return "ya estaba {$fila['moderacion']}";
        }
        $motivo = self::porIa((string) $fila['texto']);
        if ($motivo === null) {
            return 'sin IA: se queda visible';
        }
        if ($motivo === '') {
            return 'apropiado';
        }
        self::marcar($tipo, $id, $motivo, 'ia');
        return "en revisión: $motivo";
    }

    private static function normalizar(string $texto): string
    {
        $t = mb_strtolower($texto);
        $t = strtr($t, ['á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n']);
        return preg_replace('/\s+/u', ' ', $t) ?? $t;
    }

    private static function patron(string $raiz): string
    {
        $cuerpo = str_ends_with($raiz, '*') ? substr($raiz, 0, -1) . '\w*' : $raiz;
        return '/(?<![\w])' . $cuerpo . '(?![\w])/u';
    }
}
