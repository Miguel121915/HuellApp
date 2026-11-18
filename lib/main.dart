import 'package:flutter/material.dart';

import 'screens/arranque_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Fuente de toda la app: Inter, incluida en assets/fonts (la misma del sitio web).
  static const String _fuente = 'Inter';

  /// Jerarquía de texto de toda la app.
  /// Títulos grandes y en negritas · subtítulos y etiquetas en semibold · cuerpo legible
  /// con buen interlineado. Solo tamaño, peso e interlineado: los colores no cambian.
  static TextTheme _textos(TextTheme base) {
    final t = base.apply(fontFamily: _fuente);
    return t.copyWith(
      // Títulos y encabezados
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineSmall: t.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: t.titleLarge?.copyWith(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.2),
      // Subtítulos
      titleMedium: t.titleMedium?.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      // Cuerpo: legible y con buen interlineado
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
      // Etiquetas (botones, chips, campos)
      labelLarge: t.labelLarge?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: t.labelSmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      useMaterial3: true,
      // Cualquier texto (también los que fijan su propio tamaño y grosor) usa Inter
      fontFamily: _fuente,
    );
    final textos = _textos(base.textTheme);
    return MaterialApp(
      title: 'HuellApp',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
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
      ),
      home: const ArranqueScreen(),
    );
  }
}
