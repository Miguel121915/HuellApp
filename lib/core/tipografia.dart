import 'package:flutter/material.dart';

/// Tipografía y tonos de texto de HuellApp (los mismos del sitio web: variables.css y tipografia.css).
///
/// Para que el texto no se vea "plano", cada nivel se distingue por tres cosas a la vez:
/// - **Fuente:** Fredoka (redondeada) en títulos, nombres de mascotas y números grandes;
///   Inter (muy legible) en el texto normal, botones y campos.
/// - **Tamaño:** escala con saltos que se notan (ver `MyApp._textos` en main.dart).
/// - **Tono:** el texto secundario va más suave ([tintaSuave]) y los detalles más tenues ([tintaTenue]).
class Tipografia {
  Tipografia._();

  static const String fuente = 'Inter';
  static const String fuenteTitulos = 'Fredoka';

  // Tonos de texto (contraste AA sobre blanco; tinta, tintaSuave y acento también sobre menta)
  static const Color tinta = Color(0xFF14312E); // texto principal
  static const Color tintaSuave = Color(0xFF3F5F5B); // lemas y descripciones
  static const Color tintaTenue = Color(0xFF5B7470); // fechas, edades y ayudas (solo sobre blanco)
  static const Color acento = Color(0xFF0F6E63); // sobretítulos y palabras destacadas
  static const Color aquaFuerte = Color(0xFF1B4F4A); // títulos y botones de la marca
  static const Color aqua = Color(0xFF75E6DA); // turquesa de la marca

  /// Etiqueta corta en mayúsculas encima de un título ("ADOPTA · REPORTA · COMPARTE").
  static const TextStyle sobretitulo = TextStyle(
    fontFamily: fuente,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: acento,
  );
}
