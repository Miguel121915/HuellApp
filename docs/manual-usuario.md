# Manual de uso de HuellApp (HU-27)

HuellApp ayuda a **adoptar mascotas de refugios verificados** y a **reunir mascotas perdidas con sus familias**.
Funciona igual en la **app** (celular) y en el **sitio web**.

> Cuentas de demostración (contraseña `Demo1234`): `ana@huellapp.mx` (usuario), `refugio@huellapp.mx` (refugio)
> y `admin@huellapp.mx` (administrador).

---

## Si eres visitante (sin cuenta)

- Puedes ver los **refugios** y sus **mascotas en adopción**, y preguntarle a **KIRO** sobre adopción.
- Para reportar, comentar, guardar favoritos o adoptar, **crea una cuenta**: te la pide la misma app cuando lo intentas.

## Si eres usuario

### Adoptar
1. Entra a **Refugios**. Usa el mapa o **«Cerca de mí»** y abre un refugio.
2. Revisa sus **requisitos**. Toca ♡ para guardar mascotas en **Favoritos** y compararlas.
3. Toca **«Solicitar adopción»**, llena tus datos y el motivo, y sube **identificación**, **comprobante de domicilio**
   y de **1 a 3 fotos del espacio**. Si tienes dudas, el botón **«¿Dudas? Pregúntale a KIRO»** del formulario te ayuda.
4. Revisa el avance en **Mis solicitudes** (web: menú de tu cuenta, arriba a la derecha; app: menú de tu cuenta).
5. Cuando el refugio la **aprueba**, aparece **«Ver guía de cuidado»**: consejos de primeros días, alimentación,
   salud, ejercicio y señales de alerta, más consejos para tu nueva mascota.

### Si se perdió o encontraste una mascota
1. Entra a **Reportar** y elige **«Se me perdió»** o **«La encontré»**.
2. Sube una **foto**, marca la **zona** en el mapa y llena color, tamaño y collar. Si es tuya, agrega una
   **seña secreta** (un detalle que solo tú sabes): sirve para confirmar que quien la encontró habla de tu mascota.
3. Tu alerta sale en el **foro** y la IA busca mascotas parecidas. Cuando encuentra una, te llega un aviso 🔔.
4. En **Coincidencias** revisa cada una, responde la seña y ponte en contacto. Si no es, tócale **«No es mi mascota»**.
5. Cuando aparezca, toca **«¡Ya apareció!»**: tu alerta pasa a **Reunidos**.

### Foro
- Pestañas: **Se buscan**, **Buscan a su familia**, **Reunidos** y **Comunidad** (tips e historias).
- Puedes publicar con foto, comentar y dar «me gusta» con la huella.
- Si tu publicación dice **«🕒 En revisión»**, el sistema la marcó para que un administrador la revise; mientras,
  solo tú la ves. Evita groserías y no vendas animales: HuellApp es solo para adopción.

### KIRO, el asistente 🐾
- En la web es la burbuja de abajo a la derecha; en la app, el botón **«¿Te ayudo?»** del inicio.
- Pregúntale por ejemplo: *«Vivo en un departamento pequeño, ¿qué perrito me recomiendas?»* o
  *«¿Han reportado un gato gris perdido en la Roma?»*. Te muestra tarjetas de mascotas o reportes reales.
- Es una ayuda: ante síntomas de enfermedad, siempre ve al veterinario.

## Si eres refugio

1. **Regístrate** con los datos y documentos del refugio. Un administrador lo revisa; mientras, verás tu estado.
   Si te lo rechazan, puedes corregir lo señalado y volver a enviarlo.
2. La **primera vez** que entras configuras la **verificación en dos pasos**: escanea el QR con Google
   Authenticator y escribe el código. Después te pedirá el código cada vez.
3. **Inventario:** agrega tus mascotas con foto. En la descripción, escribe unas notas (carácter, con quién convive)
   y toca **«✨ Sugerir con IA»** para obtener un borrador; **revísalo** antes de guardar.
4. **Publicaciones:** publica tus mascotas y elige cada cuántos días se vuelven a mostrar arriba.
5. **Adopciones:** revisa cada solicitud y sus documentos. **«Generar resumen»** te da puntos a favor, lo que conviene
   revisar y preguntas para la entrevista. Responde con **aprobar**, **en revisión** o **rechazar** (con una nota).
6. **Requisitos**, **Preguntas frecuentes** y **Mensajes** completan tu perfil y la atención a las personas.

## Si eres administrador

1. Entra con la **verificación en dos pasos**.
2. **Solicitudes:** revisa los documentos de cada refugio nuevo; apruébalo o recházalo con motivo. También puedes
   suspender y reactivar.
3. **Estadísticas:** cifras de uso y actividad de las últimas semanas.
4. **Moderación:** lo que el sistema marcó (por palabras o con IA). **Aprobar** lo vuelve a mostrar; **Quitar** lo
   oculta y le avisa a su autor. En **Quitados** puedes restaurar si fue un error.

---

## Preguntas frecuentes

**No veo mi publicación en el foro.** Si dice «En revisión», el sistema la marcó y un administrador la revisará.

**El código de Google Authenticator dice que está mal.** Revisa que la hora del teléfono sea automática, que uses
la entrada más reciente de HuellApp en la app y que no se haya generado otro QR (por ejemplo, si alguien más entró
con la misma cuenta). Un administrador puede reiniciarla con `php artisan 2fa:reiniciar correo`.

**KIRO tarda o contesta algo muy general.** La IA es gratuita y a veces está saturada; en ese caso responde con
respuestas básicas. Inténtalo de nuevo en un momento.

**¿Mis datos los ve la IA?** No se le envían nombres, correos, teléfonos, direcciones ni la seña secreta. Más
detalle en [`docs/ia.md`](ia.md).

**¿Puedo vender o comprar mascotas?** No. HuellApp es solo para adopción responsable; esas publicaciones se quitan.
