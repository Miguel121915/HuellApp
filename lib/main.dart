import 'package:flutter/material.dart';

import 'core/push_service.dart';
import 'core/tipografia.dart';
import 'screens/arranque_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // HU-19: notificaciones push (solo Android; en web y en las pruebas no hace nada)
  await PushService.instancia.iniciar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Fuente del texto normal: Inter, incluida en assets/fonts (la misma del sitio web).
  static const String _fuente = Tipografia.fuente;

  /// Jerarquía de texto de toda la app (misma escala que el sitio web).
  /// Títulos en Fredoka (redondeada) · texto en Inter · cada nivel con un tamaño que se distingue
  /// del siguiente · detalles en un tono más suave. Ver lib/core/tipografia.dart.
  static TextTheme _textos(TextTheme base, {Color? detalles}) {
    final t = base.apply(fontFamily: _fuente);
    TextStyle? titulo(TextStyle? s, double tam, FontWeight peso) =>
        s?.copyWith(fontFamily: Tipografia.fuenteTitulos, fontSize: tam, fontWeight: peso, letterSpacing: 0, height: 1.15);
    return t.copyWith(
      // Títulos y encabezados (Fredoka)
      headlineLarge: titulo(t.headlineLarge, 32, FontWeight.w700),
      headlineMedium: titulo(t.headlineMedium, 28, FontWeight.w700),
      headlineSmall: titulo(t.headlineSmall, 25, FontWeight.w600),
      titleLarge: titulo(t.titleLarge, 21, FontWeight.w600),
      titleMedium: titulo(t.titleMedium, 18, FontWeight.w600),
      // Subtítulo pequeño en Inter negrita: se distingue del cuerpo por grosor y tamaño
      titleSmall: t.titleSmall?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
      // Cuerpo: legible y con buen interlineado; el pequeño, en tono suave (detalles)
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.4, color: detalles),
      // Etiquetas (botones, chips, campos)
      labelLarge: t.labelLarge?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: t.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
    );
  }

  /// Tema de HuellApp. Lo usan las dos MaterialApp: esta (login y arranque) y la de
  /// navigation.dart (todo lo que se abre después de iniciar sesión).
  static ThemeData tema() {
    final base = ThemeData(
      // Colores de la marca (verde oscuro y turquesa), no el naranja por defecto: así los botones,
      // interruptores y diálogos que no fijan su color propio también se ven de HuellApp.
      colorScheme: ColorScheme.fromSeed(
        seedColor: Tipografia.aquaFuerte,
        primary: Tipografia.aquaFuerte,
        onSurface: Tipografia.tinta,
        onSurfaceVariant: Tipografia.tintaSuave,
      ),
      useMaterial3: true,
      // Cualquier texto (también los que fijan su propio tamaño y grosor) usa Inter
      fontFamily: _fuente,
    );
    final textos = _textos(base.textTheme, detalles: base.colorScheme.onSurfaceVariant);
    return base.copyWith(
      textTheme: textos,
      primaryTextTheme: _textos(base.primaryTextTheme),
      // Los textos de cada pantalla que fijan su propio tamaño también usan Inter
      appBarTheme: base.appBarTheme.copyWith(titleTextStyle: textos.titleLarge),
      // Mismos colores que Material usa por defecto en cada caso; solo cambian tamaño y peso
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: textos.titleSmall?.copyWith(fontSize: 15.5, color: base.colorScheme.onSurface),
        subtitleTextStyle: textos.bodyMedium?.copyWith(fontSize: 13.5, color: base.colorScheme.onSurfaceVariant),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: textos.labelMedium?.copyWith(color: base.colorScheme.onSurfaceVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HuellApp',
      debugShowCheckedModeBanner: false,
      theme: tema(),
      home: const ArranqueScreen(),
    );
  }
}
