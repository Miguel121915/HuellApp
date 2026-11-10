import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'boton_google_stub.dart' if (dart.library.js_interop) 'boton_google_web.dart' as plataforma;

/// Botón «Continuar con Google». En el navegador es el botón oficial que dibuja Google
/// (obligatorio en web); en Android es un botón propio que abre el selector de cuentas.
class BotonGoogle extends StatelessWidget {
  const BotonGoogle({super.key, required this.alPresionar, this.cargando = false});

  /// Solo se usa en Android (en web el token llega por GoogleLogin.instancia.idTokens).
  final VoidCallback alPresionar;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return Center(child: plataforma.botonGoogleWeb());
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: cargando ? null : alPresionar,
        icon: cargando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
        label: const Text('Continuar con Google', style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1F1F1F),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF747775)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
