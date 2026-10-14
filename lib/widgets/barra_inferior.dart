import 'package:flutter/material.dart';

/// Barra de abajo de HuellApp (la original): Foro, Refugios, Inicio,
/// Reportar y Coincidencias. La controla la pantalla principal (AppShell).
class BarraInferiorHuellApp extends StatelessWidget {
  final int indiceActual;
  final ValueChanged<int> onCambio;

  const BarraInferiorHuellApp({
    super.key,
    required this.indiceActual,
    required this.onCambio,
  });

  static const Color primaryTurquoise = Color(0xFF75E6DA);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: indiceActual,
      onTap: onCambio,
      type: BottomNavigationBarType.fixed,
      backgroundColor: primaryTurquoise,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black,
      showUnselectedLabels: true,
      items: [
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
          label: 'Foro',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.maps_home_work_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
          label: 'Refugios',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: primaryTurquoise, width: 2),
            ),
            child: const Icon(
              Icons.other_houses_outlined,
              color: Colors.black,
              size: 32,
            ),
          ),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.videocam_outlined, color: Colors.black, size: 24),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(Icons.pets, color: Colors.red, size: 8),
                ),
              ],
            ),
          ),
          label: 'Reportar',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          label: 'Coincidencias',
        ),
      ],
    );
  }
}
