import 'package:flutter/material.dart';

/// Insignia junto al nombre de un refugio:
///  - Refugio verificado (✔ azul): HuellApp revisó su acta o constancia fiscal, domicilio e identificación.
///  - Rescatista independiente (🏠 ámbar): sin acta; HuellApp revisó su identificación, domicilio y
///    fotos del lugar.
class InsigniaRefugio extends StatelessWidget {
  const InsigniaRefugio({super.key, required this.independiente, this.tamano = 20});

  final bool independiente;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: independiente
          ? 'Rescatista independiente: sin acta constitutiva. HuellApp revisó su identificación, su domicilio y fotos del lugar.'
          : 'Refugio verificado por HuellApp',
      child: Semantics(
        label: independiente ? 'Rescatista independiente' : 'Refugio verificado',
        child: Icon(
          independiente ? Icons.home_work : Icons.verified,
          color: independiente ? const Color(0xFFB7791F) : Colors.blue,
          size: tamano,
        ),
      ),
    );
  }
}
