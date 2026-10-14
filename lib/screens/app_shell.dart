import 'package:flutter/material.dart';
import 'package:huellapp/screens/coincidencias_screen.dart';
import 'package:huellapp/screens/inicio_screen.dart';
import 'package:huellapp/screens/login_screen.dart';
import 'package:huellapp/screens/muro_huellapp_screen.dart';
import 'package:huellapp/screens/refugios_screen.dart';
import 'package:huellapp/screens/reportar_screen.dart';
import 'package:huellapp/widgets/barra_inferior.dart';

/// Estructura principal de la app: la barra de arriba (HuellApp) y la de
/// abajo se quedan fijas, y solo cambia el contenido de en medio.
/// Índices: 0 Foro, 1 Refugios, 2 Inicio, 3 Reportar, 4 Coincidencias.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Color _turquoise = Color(0xFF75E6DA);

  int _indice = 2; // Empieza en Inicio

  void _irA(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _turquoise,
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: const Text(
          'HuellApp',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Iniciar sesión',
              icon: const Icon(Icons.pets, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ),
        ],
      ),
      // IndexedStack conserva lo que hiciste en cada sección al cambiar
      body: IndexedStack(
        index: _indice,
        children: [
          const MuroHuellAppScreen(),
          const RefugiosScreen(),
          InicioScreen(onIrA: _irA),
          const ReportarScreen(),
          const CoincidenciasScreen(),
        ],
      ),
      bottomNavigationBar: BarraInferiorHuellApp(
        indiceActual: _indice,
        onCambio: _irA,
      ),
    );
  }
}