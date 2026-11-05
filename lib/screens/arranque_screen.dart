import 'package:flutter/material.dart';

import '../core/destino.dart';
import '../core/sesion_service.dart';
import 'login_screen.dart';

/// Primera pantalla: recupera la sesión guardada en el teléfono.
/// Con sesión válida entra directo a la app; si no, muestra el inicio de sesión.
class ArranqueScreen extends StatefulWidget {
  const ArranqueScreen({super.key});

  @override
  State<ArranqueScreen> createState() => _ArranqueScreenState();
}

class _ArranqueScreenState extends State<ArranqueScreen> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    final sesion = SesionService.instancia;
    final valida = await sesion.cargar();
    if (!mounted) return;

    // Con sesión: cada rol a su pantalla (usuario → app, refugio → panel o estado). Sin sesión: login.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => valida ? destinoDeSesion(sesion.actual) : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE6F8F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 56, color: Color(0xFF1B4F4A)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF1B4F4A)),
          ],
        ),
      ),
    );
  }
}
