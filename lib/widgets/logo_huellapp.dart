import 'package:flutter/material.dart';

/// Logo de HuellApp (perro y gato + «HuellApp» + huella) para las barras de arriba.
/// Va sobre una franja blanca: la parte «App» del logo es turquesa y no se leería sobre la barra turquesa.
/// El original está en public/Logo HuellApp.png; esta copia está recortada y reducida.
class LogoHuellApp extends StatelessWidget {
  const LogoHuellApp({super.key, this.alto = 44});

  /// Alto del logo (sin contar la franja blanca).
  final double alto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Image.asset(
          'assets/img/logo_huellapp.png',
          height: alto,
          fit: BoxFit.contain,
          semanticLabel: 'HuellApp',
        ),
      );
}
