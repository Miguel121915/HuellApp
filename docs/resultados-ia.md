# Resultados de la evaluación de la IA (lista de cotejo 20–23 y 32)

Evaluación hecha el **13 de noviembre de 2026** con el modelo **`gemini-3.5-flash`** (capa gratuita).
Resultados completos, caso por caso: [`api/evaluacion/resultados/ultima.json`](../api/evaluacion/resultados/ultima.json).

## Cómo se hizo

- **Datos etiquetados a mano** por el equipo, todos **inventados** (no hay datos de personas reales):
  - [`moderacion.json`](../api/evaluacion/moderacion.json): 40 textos de foro (20 apropiados, 20 inapropiados).
  - [`kiro.json`](../api/evaluacion/kiro.json): 14 preguntas a KIRO con lo que se espera de cada respuesta.
  - [`coincidencias-texto.json`](../api/evaluacion/coincidencias-texto.json): 20 pares de reportes (10 de la misma mascota, 10 distintas).
- A propósito se incluyeron **casos difíciles**: groserías disfrazadas («p3nd3ja»), venta sin la palabra «vendo»
  («se los dejo en 1500»), palabras que parecen groserías pero no lo son («perra» como mascota) y la misma
  mascota descrita con otras palabras.
- **Repetible:** `php artisan ia:evaluar` (dentro de `api/`) reinicia el esquema de pruebas `HUELLAPP_TEST` con los
  datos demo, corre todo y guarda el resultado. No toca la base del equipo. Gasta unas 55 consultas de Gemini.
- **Método de referencia (base):** en cada función se compara la IA contra el método **sin IA** que la app usa como
  respaldo (lista de palabras, comparación de texto). Así se ve cuánto aporta la IA.
- **Métricas:** para clasificar (moderación, coincidencias) se usa la matriz de confusión, donde *positivo* =
  «inapropiado» o «es la misma mascota»:
  - **Exactitud** = aciertos / total.
  - **Precisión** = de lo que marcó como positivo, cuánto sí lo era (evita falsas alarmas).
  - **Recall (sensibilidad)** = de los positivos reales, cuántos encontró (evita que se escapen).
  - **F1** = equilibrio entre precisión y recall.

## 1. Moderación del foro (HU-18)

| Método | VP | FP | FN | VN | Exactitud | Precisión | Recall | F1 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Solo lista de palabras (base) | 7 | 0 | 13 | 20 | 67.5 % | 100 % | **35.0 %** | 51.9 % |
| Solo IA (Gemini)¹ | 19 | 0 | 0 | 20 | **100 %** | 100 % | **100 %** | 100 % |
| **Palabras + IA (lo que hace la app)** | 20 | 0 | 0 | 20 | **100 %** | **100 %** | **100 %** | **100 %** |

¹ En 1 de los 40 textos Gemini no respondió (red); se calcula sobre 39. Ese texto lo atrapó la lista de palabras.

**Qué detectó cada método, por tipo de contenido inapropiado:**

| Tipo | Casos | Palabras | IA |
| --- | --: | --: | --: |
| Insulto directo | 5 | 5 | 5 |
| Venta con «vendo» / «venta» | 2 | 2 | 2 |
| Venta disfrazada («se los dejo en 1500», «cooperación») | 3 | 0 | 3 |
| Amenaza | 1 | 0 | 1 |
| Maltrato animal | 2 | 0 | 2 |
| Insulto disfrazado («p3nd3ja») | 1 | 0 | 1 |
| Acoso | 2 | 0 | 2 |
| Estafa | 1 | 0 | 1 |
| Discriminación | 1 | 0 | 1 |
| Contenido sexual | 1 | 0 | 1 |
| Datos personales de otra persona | 1 | 0 | 1 |

**Tiempo de la IA por texto:** mediana 3.4 s, promedio 6.1 s, máximo 19.6 s. Por eso la revisión con IA corre
**en segundo plano** y no hace esperar a quien publica.

**Interpretación.** La lista de palabras nunca se equivocó al marcar (precisión 100 %, ninguna falsa alarma con
«perra» ni con preguntar un precio), pero solo encontró **1 de cada 3** textos inapropiados: no entiende amenazas,
maltrato, acoso ni ventas disfrazadas. La IA los entendió todos y tampoco marcó textos normales. Combinadas,
la palabra actúa al instante y la IA cubre lo que la palabra no ve. **Cumple el objetivo de HU-18.**

## 2. KIRO, el asistente (HU-7)

Cada respuesta se revisa con reglas automáticas: ¿recomienda la especie y el tamaño pedidos?, ¿solo mascotas
disponibles?, ¿encuentra los reportes correctos?, ¿protege la privacidad?, ¿no muestra ids ni Markdown?, ¿el
texto nombra a las mascotas de las tarjetas?

| Tipo de pregunta | Casos | Cumplen todo |
| --- | --: | --: |
| Recomendación (especie / tamaño / niños) | 4 | 3² |
| Recomendación muy general | 1 | 1 |
| Sin opciones («quiero un conejo») | 1 | 1 |
| Proceso de adopción | 1 | 1 |
| Salud (debe mandar al veterinario) | 1 | 1 |
| Pregunta ajena (fútbol) | 1 | 1 |
| Búsqueda en reportes | 2 | 2 |
| Reporte que no existe | 1 | 1 |
| Privacidad: visitante no ve reportes | 1 | 1 |
| Privacidad: pedir teléfono de quien reportó | 1 | 1 |
| **Total** | **14** | **13 (92.9 %)** |

- **Verificaciones individuales:** 70 de 71 (98.6 %).
- **Recomendaciones:** el 100 % de las mascotas recomendadas eran de la especie y el tamaño pedidos y estaban
  disponibles (ninguna inventada).
- **Privacidad:** 2 de 2. Al visitante no le mostró reportes y ante el pedido de teléfono y dirección respondió
  que no comparte datos personales.
- **Tiempo:** mediana 3.6 s, promedio 4.3 s, máximo 8.5 s. 13 de 14 respuestas fueron con IA.

² El caso que no cumplió: Gemini no respondió (saturación o red, incluso tras un reintento) y KIRO usó su
**respaldo sin IA**. Aun así recomendó correctamente 3 perros pequeños, pero con un texto genérico que no los
nombra. Muestra que el respaldo evita una pantalla vacía.

Durante la evaluación se ajustaron 2 reglas que estaban mal planteadas (no la IA): ante «recomiéndame una
mascota», KIRO pregunta por el hogar antes de recomendar, lo cual es válido; y los reportes demo no traen la
especie llenada (es un campo opcional).

## 3. Coincidencias por texto (método base, sin IA)

Comparación de palabras de la descripción (70 %) y de la zona (30 %), `api/src/Similitud.php`. La app usa
umbral **40**.

| Umbral | VP | FP | FN | VN | Exactitud | Precisión | Recall | F1 |
| --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 30 | 10 | 9 | 0 | 1 | 55 % | 52.6 % | 100 % | 69.0 % |
| **40 (app)** | 10 | 8 | 0 | 2 | **60 %** | **55.6 %** | **100 %** | 71.4 % |
| 50 | 9 | 6 | 1 | 4 | 65 % | 60.0 % | 90 % | 72.0 % |
| 60 | 7 | 5 | 3 | 5 | 60 % | 58.3 % | 70 % | 63.6 % |

Puntaje promedio: **62.7** en pares de la misma mascota y **52.3** en mascotas distintas: casi no las separa.

**Interpretación.** El texto encuentra todas las parejas reales (recall 100 %), pero da **8 falsas alarmas de 10**:
confunde un **gato** gris con un **perro** gris, o la misma descripción en **otra ciudad**, porque solo cuenta
palabras en común y no entiende que «gato» y «perro» se excluyen. Subir el umbral no lo arregla (pierde parejas
reales). Esto **justifica usar la IA con fotos** para las coincidencias (HU-8): la foto distingue especie, colores
y manchas.

## 4. Coincidencias por foto (IA) — pendiente

La comparación con fotos necesita **fotos reales** etiquetadas (varias por mascota), y el proyecto solo tiene
dibujos SVG de demostración. El experimento está listo en `php artisan ia:evaluar fotos`: basta con poner fotos de
mascotas del equipo en `api/evaluacion/fotos/<mascota>/` (instrucciones en `LEEME.md` de esa carpeta).

## Limitaciones de esta evaluación

- **Muestras pequeñas** (40, 14 y 20 casos): los porcentajes son orientativos, no estadísticamente concluyentes.
- **Datos inventados por el equipo:** reflejan los casos que imaginamos, no la variedad del uso real.
- **La IA no es determinista:** en otra corrida algún resultado puede cambiar; por eso todo se puede repetir.
- **Dependencia de internet y de la cuota gratuita:** un corte o la saturación hace que se use el respaldo sin IA.
- Las reglas de KIRO revisan la forma y los datos de la respuesta, no qué tan amable o útil le parece a una persona.
