import 'package:flutter/material.dart';

/// Marcador de un refugio en el mapa: un círculo turquesa con una huellita y
/// una punta que señala el lugar exacto. Seleccionado se ve más grande y en
/// rojo, para distinguirlo.
class MarcadorRefugio extends StatelessWidget {
  final bool seleccionado;

  const MarcadorRefugio({super.key, this.seleccionado = false});

  static const double ancho = 56;
  static const double alto = 66;

  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _seleccion = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final borde = seleccionado ? _seleccion : _accent;
    final fondo = seleccionado ? Colors.white : _turquoise;

    return Semantics(
      label: 'Refugio',
      child: Transform.scale(
        scale: seleccionado ? 1.15 : 1,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: ancho,
          height: alto,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Punta del marcador
              Positioned(
                bottom: 5,
                child: Transform.rotate(
                  angle: 0.785398, // 45 grados
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: borde,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Círculo con la huellita
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fondo,
                  shape: BoxShape.circle,
                  border: Border.all(color: borde, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.pets, size: 26, color: borde),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
