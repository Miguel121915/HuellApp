import 'package:flutter/material.dart';

/// Logo de HuellApp (perro y gato + «HuellApp» + huella) para las barras de arriba.
/// Por defecto va sobre una franja blanca: la parte «App» del logo es turquesa y no se leería sobre
/// una barra de color. Con [conFondo] = false se dibuja solo (cuando ya está sobre un fondo blanco,
/// como el panel curvo de la barra principal).
/// El original está en public/Logo HuellApp.png; esta copia está recortada y reducida.
class LogoHuellApp extends StatelessWidget {
  const LogoHuellApp({super.key, this.alto = 44, this.conFondo = true});

  /// Alto del logo (sin contar la franja blanca).
  final double alto;
  final bool conFondo;

  @override
  Widget build(BuildContext context) {
    final imagen = Image.asset(
      'assets/img/logo_huellapp.png',
      height: alto,
      fit: BoxFit.contain,
      semanticLabel: 'HuellApp',
    );
    if (!conFondo) return imagen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: imagen,
    );
  }
}

/// Panel blanco con el logo que termina en curva hacia la derecha, como el encabezado del sitio web.
/// Usa el mismo alto que la barra de arriba ([alto] = toolbarHeight del AppBar).
class PanelLogoHuellApp extends StatelessWidget {
  const PanelLogoHuellApp({super.key, this.ancho = 196, this.alto = 70, this.altoLogo = 46});

  final double ancho;
  final double alto;
  final double altoLogo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: CustomPaint(
        painter: _PanelCurvo(),
        child: Padding(
          padding: EdgeInsets.only(left: 14, right: ancho * 0.2),
          child: Align(alignment: Alignment.centerLeft, child: LogoHuellApp(alto: altoLogo, conFondo: false)),
        ),
      ),
    );
  }
}

/// Blanco con borde menta: recto arriba y a la izquierda, curva que se abre hacia abajo a la derecha.
class _PanelCurvo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // El mismo trazo sirve para el borde menta y para el contorno del panel
    void trazarCurva(Path p) => p
      ..cubicTo(w * 0.76, 0, w * 0.81, h * 0.12, w * 0.84, h * 0.26)
      ..cubicTo(w * 0.89, h * 0.48, w * 0.91, h * 0.76, w * 0.945, h * 0.88)
      ..cubicTo(w * 0.965, h * 0.96, w * 0.98, h, w, h);
    final curva = Path()..moveTo(w * 0.68, 0);
    trazarCurva(curva);
    final panel = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.68, 0);
    trazarCurva(panel);
    panel
      ..lineTo(0, h)
      ..close();
    canvas.drawShadow(panel, const Color(0xFF000000), 3, false);
    canvas.drawPath(panel, Paint()..color = Colors.white);
    canvas.drawPath(curva, Paint()
      ..color = const Color(0xFFB9F2E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
