import 'package:flutter/material.dart';

import 'main.dart';
import 'screens/app_shell.dart';
import 'screens/foro_screen.dart';
import 'screens/kiro_home_screen.dart';

/// Pantalla que se abre después del login.
/// '/' es la estructura principal (barras fijas + secciones).
class AppNavigation extends StatelessWidget {
  const AppNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HuellApp',
      // El mismo tema del login: colores de la marca y la escala de texto (Fredoka + Inter)
      theme: MyApp.tema(),
      initialRoute: '/',
      routes: {
        '/': (context) => const AppShell(),
        '/kiro': (context) => const KiroHomeScreen(),
        '/foro': (context) => const ForoScreen(),
      },
    );
  }
}
