import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'sesion_service.dart';

/// Para acciones que un visitante no puede hacer (reportar, adoptar, guardar favoritos, comentar…).
///
/// Uso:
///   if (!await requiereSesion(context, 'reportar una mascota')) return;
///
/// Devuelve true si hay sesión iniciada. Si no, muestra un aviso con la opción de iniciar sesión
/// y devuelve false (la acción no se hace).
Future<bool> requiereSesion(BuildContext context, String accion) async {
  if (SesionService.instancia.haySesion) return true;

  final irALogin = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Inicia sesión para continuar'),
      content: Text('Para $accion necesitas una cuenta de HuellApp. Es gratis y toma un minuto.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Ahora no'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF75E6DA),
            foregroundColor: const Color(0xFF14312E),
          ),
          child: const Text('Iniciar sesión'),
        ),
      ],
    ),
  );

  if (irALogin == true && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
  return SesionService.instancia.haySesion;
}
