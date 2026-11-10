import 'package:flutter/material.dart';

import 'muro_huellapp_screen.dart';

/// Ruta '/foro': el foro de la comunidad es el mismo muro (publicaciones y alertas de la API PHP).
/// Antes leía del servidor Node (backend/); se dejó este nombre para no romper la ruta.
class ForoScreen extends StatelessWidget {
  const ForoScreen({super.key});

  @override
  Widget build(BuildContext context) => const MuroHuellAppScreen();
}
