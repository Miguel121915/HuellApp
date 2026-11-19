import 'package:flutter/material.dart';

import '../core/tipografia.dart';

/// Barra de abajo de HuellApp: Foro, Refugios, Inicio, Reportar y Coincidencias.
/// Mismos colores que el encabezado del sitio web: fondo verde turquesa, íconos y textos blancos,
/// y la sección activa en un cuadro blanco con el ícono y el texto en verde oscuro.
/// La controla la pantalla principal (AppShell).
class BarraInferiorHuellApp extends StatelessWidget {
  const BarraInferiorHuellApp({
    super.key,
    required this.indiceActual,
    required this.onCambio,
    this.coincidencias = 0,
  });

  final int indiceActual;
  final ValueChanged<int> onCambio;

  /// Coincidencias pendientes (burbuja roja; 0 = sin burbuja).
  final int coincidencias;

  /// Verde del encabezado del sitio web (arriba → abajo). Texto blanco con contraste AA.
  static const Color verdeArriba = Color(0xFF0D8274);
  static const Color verdeAbajo = Color(0xFF0B766A);
  static const LinearGradient degradado = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [verdeArriba, verdeAbajo],
  );

  static const _secciones = <(IconData, String)>[
    (Icons.forum_outlined, 'Foro'),
    (Icons.maps_home_work_outlined, 'Refugios'),
    (Icons.other_houses_outlined, 'Inicio'),
    (Icons.videocam_outlined, 'Reportar'),
    (Icons.join_inner, 'Coincidencias'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: degradado,
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(
            children: [
              for (var i = 0; i < _secciones.length; i++)
                Expanded(
                  child: _Seccion(
                    icono: _secciones[i].$1,
                    texto: _secciones[i].$2,
                    activa: i == indiceActual,
                    insignia: i == 4 ? coincidencias : 0,
                    alTocar: () => onCambio(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.icono, required this.texto, required this.activa, required this.insignia, required this.alTocar});

  final IconData icono;
  final String texto;
  final bool activa;
  final int insignia;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final color = activa ? Tipografia.aquaFuerte : Colors.white;
    return Semantics(
      button: true,
      selected: activa,
      label: insignia > 0 ? '$texto, $insignia pendientes' : texto,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: activa ? Colors.white : Colors.transparent,
          elevation: activa ? 3 : 0,
          shadowColor: const Color(0x55000000),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: alTocar,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white24,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: insignia > 0,
                    label: Text(insignia > 9 ? '9+' : '$insignia'),
                    backgroundColor: const Color(0xFFEC143C),
                    child: Icon(icono, color: color, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 11.5, fontWeight: activa ? FontWeight.w700 : FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
