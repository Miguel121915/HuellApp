# Inteligencia artificial en HuellApp (HU-27)

HuellApp usa **Google Gemini** (capa gratuita, sin facturación) desde la API PHP. Todo el código está en
[`api/src/Gemini.php`](../api/src/Gemini.php); la clave va solo en `api/.env` (`GEMINI_API_KEY`) y **nunca** se sube.

## Principios

1. **Nunca deja la pantalla vacía.** Si no hay clave, se acabó la cuota o Gemini falla, cada función responde
   con reglas sencillas y lo indica (`iaUsada: false`).
2. **La IA sugiere, la persona decide.** Los resúmenes, borradores y la moderación los revisa un humano.
3. **Privacidad.** A Gemini no se le mandan nombres, correos, teléfonos ni direcciones de las personas, ni la
   seña secreta de los reportes; solo lo necesario para la tarea.
4. **Cuidar la cuota.** Los resultados que se reutilizan se guardan en la base; hay límites por persona y lo
   pesado corre en segundo plano.

## Modelos y cuota

- Principal `gemini-3.5-flash`; respaldo `gemini-3.5-flash-lite` y `gemini-3.6-flash`. Cada modelo tiene su propia
  cuota gratuita: si uno está saturado (503) o sin cuota (429), se pasa al siguiente. Se cambian con
  `GEMINI_MODEL` y `GEMINI_MODELOS_RESPALDO`.
- `gemini-3.8-flash` y `gemini-flash-latest` **no** contestan en la capa gratuita (se quedan colgados): no usarlos.
- Tiempo máximo por modelo: 15 s en el chat de KIRO y 20–30 s en lo demás.
- La cuota gratuita es por minuto **y** por día. El día de la demo conviene una clave aparte que no se haya usado
  para pruebas.

## Funciones

| Función | Historia | Qué recibe la IA | Qué devuelve | Sin IA | Dónde se guarda |
| --- | --- | --- | --- | --- | --- |
| Análisis de la foto del reporte | HU-5 | Foto + descripción del reporte | Especie, raza, color, tamaño, señas | El reporte se guarda igual | `reportes.analisis_ia` |
| Coincidencias por foto | HU-8 | Foto del reporte + fotos de candidatos | % de parecido y si es la misma foto | Se compara el texto y la zona | `coincidencias` |
| KIRO, el asistente | HU-7 | Pregunta + historial, mascotas disponibles y, **con sesión**, reportes activos (sin autor, mapa ni seña) | Respuesta + ids de mascotas/reportes | Respuestas por palabras clave | — (límite: 30 preguntas / 10 min por IP) |
| Resumen de solicitud | HU-22 | Vivienda, otras mascotas, ocupación, motivo, documentos subidos y requisitos del refugio | Síntesis, a favor, para revisar, preguntas | Reglas (documentos, vivienda rentada…) | `solicitudes_adopcion.resumen_ia` |
| Guía de cuidado | HU-23 | Especie, raza, edad, tamaño, salud y tipo de hogar | 3–5 consejos para esa mascota | Guía base por especie y edad | `solicitudes_adopcion.guia_ia` |
| Borrador de descripción | HU-17 | Datos del formulario, notas del refugio y foto | Descripción (≤ 400 caracteres) | Plantilla para completar | No se guarda (límite: 20 / 10 min por refugio) |
| Moderación | HU-18 | Texto de la publicación o comentario | Apropiado o motivo | Solo la lista de palabras | `publicaciones_foro` / `comentarios_foro.moderacion*` |

## En segundo plano

Para no hacer esperar a la persona, la API lanza comandos de `php artisan` aparte (`api/src/Procesos.php`):

- `ia:procesar [id]` — análisis y coincidencias de un reporte (con reintentos si Gemini falla).
- `moderacion:revisar publicacion|comentario id` — revisión con IA de lo recién publicado.

## Cómo se evita que la IA invente

- Las instrucciones piden **solo JSON** y se validan: los ids que devuelve KIRO se cruzan con la base (solo
  mascotas y reportes que existen), las listas se recortan y se quitan el Markdown y los «(id=…)».
- En los borradores, el carácter de la mascota sale **solo** de las notas del refugio.
- En la moderación, «perra»/«perro» referidos a animales no cuentan como groserías, y preguntar un precio
  (consulta, vacunas) no se marca como venta.
