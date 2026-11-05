/**
 * buscador-faq.js — Encuentra la pregunta frecuente que mejor responde a una duda escrita libremente.
 *
 * Sin servidor ni IA externa: compara las palabras de la duda con las de cada pregunta, sus
 * palabras clave y su respuesta. Tolera acentos, mayúsculas, plurales y variaciones
 * ("documentos" ≈ "documentación") recortando cada palabra a su raíz, y entiende algunos
 * sinónimos comunes ("INE" → identificación, "recibo de luz" → comprobante de domicilio).
 *
 * No toca el DOM: se puede usar desde cualquier pantalla (y probar con Node).
 */

const quitarAcentos = (t) => t.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");

/** Palabras que no aportan significado a la búsqueda. */
const VACIAS = new Set(("a al algo algun alguna como con cual cuales cuando cuanto de del donde el ella en es esa ese eso esta este esto ha hay la las le lo los mas me mi mis muy no o para pero por puedo puede que se si sin sobre son su sus te tengo tiene tu un una uno unos y ya yo quiero necesito debo hacer saber").split(" "));

/**
 * Raíz de una palabra (sus 4 primeras letras): une singular/plural y familias de palabras
 * ("adoptar"/"adopción" → "adop", "foto"/"fotos"/"fotografía" → "foto").
 */
const raiz = (palabra) => (palabra.length > 4 ? palabra.slice(0, 4) : palabra);

/** Sinónimos: si aparece la raíz de la izquierda, también se buscan las de la derecha. */
const SINONIMOS = {
  ine: ["iden", "docu"], cred: ["iden", "docu"], pasa: ["iden", "docu"], lice: ["iden"],
  reci: ["comp", "domi"], luz: ["comp", "domi"], agua: ["comp", "domi"], pred: ["comp", "domi"],
  dire: ["domi"], casa: ["vivi", "domi"], depa: ["vivi"], hoga: ["vivi"],
  imag: ["foto"], pape: ["docu", "requ"], requ: ["docu"], docu: ["requ"],
  cues: ["cost", "prec"], cost: ["prec", "paga"], prec: ["cost"], paga: ["cost"], grat: ["cost"],
  rent: ["arre"], arre: ["rent"],
  tard: ["tiem", "dias"], demo: ["tiem", "tard"], cuan: ["tiem", "cost"],
};

/** Texto → lista de raíces sin palabras vacías. */
export function raices(texto) {
  return quitarAcentos(texto)
    .split(/[^a-z0-9ñ]+/)
    .filter((p) => p.length > 1 && !VACIAS.has(p))
    .map(raiz);
}

function conSinonimos(lista) {
  const todas = new Set(lista);
  lista.forEach((r) => (SINONIMOS[r] || []).forEach((s) => todas.add(s)));
  return [...todas];
}

/**
 * Prepara las preguntas para buscar rápido.
 * @param {{pregunta:string, respuesta:string, claves?:string[]}[]} preguntas
 */
export function crearBuscador(preguntas) {
  const indice = preguntas.map((p) => ({
    item: p,
    pregunta: new Set(raices(p.pregunta)),
    claves: new Set((p.claves || []).flatMap(raices)),
    frases: (p.claves || []).map((c) => quitarAcentos(c).trim()).filter((c) => c.includes(" ")),
    respuesta: new Set(raices(p.respuesta)),
  }));

  /**
   * @returns {{item:object, puntaje:number}[]} de mejor a peor; solo las que superan el mínimo
   */
  function buscar(texto, { minimo = 1.5, maximo = 3 } = {}) {
    const consulta = raices(texto);
    if (consulta.length === 0) return [];
    const ampliada = conSinonimos(consulta);
    const normal = quitarAcentos(texto);

    return indice
      .map((e) => {
        let puntaje = 0;
        ampliada.forEach((r) => {
          const directa = consulta.includes(r) ? 1 : 0.6; // un sinónimo cuenta un poco menos
          if (e.claves.has(r)) puntaje += 2 * directa;
          else if (e.pregunta.has(r)) puntaje += 1.5 * directa;
          else if (e.respuesta.has(r)) puntaje += 0.4 * directa;
        });
        e.frases.forEach((f) => { if (normal.includes(f)) puntaje += 2; });
        // Preguntas cortas que coinciden casi completas ganan a las largas con una palabra suelta
        if (e.pregunta.size > 0) puntaje += [...e.pregunta].filter((r) => ampliada.includes(r)).length / e.pregunta.size;
        return { item: e.item, puntaje };
      })
      .filter((r) => r.puntaje >= minimo)
      .sort((a, b) => b.puntaje - a.puntaje)
      .slice(0, maximo);
  }

  return { buscar };
}
