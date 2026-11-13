# Fotos para evaluar las coincidencias por foto

Aquí van fotos **reales** para medir qué tan bien la IA reconoce a la misma mascota en fotos distintas.

1. Una carpeta por mascota, con un nombre sin espacios: `fotos/firulais/`, `fotos/michi/`…
2. **Mínimo 2 fotos distintas** de cada mascota (otro día, otra pose, otra luz), en JPG o PNG, de menos de 4 MB.
3. **Mínimo 2 mascotas**; lo ideal son 8 a 10, con algunas parecidas entre sí (dos perros cafés, dos gatos grises).
4. Solo fotos de mascotas del equipo o de conocidos que den permiso. Que no salgan caras de personas ni direcciones.
5. Corre `php artisan ia:evaluar fotos` dentro de `api/`.

Las fotos **no se suben a GitHub** (ver `.gitignore`); el resultado sí, en `evaluacion/resultados/`.
