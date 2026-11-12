import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// La cara de KIRO, el gato-robot asistente (la misma imagen que usa el sitio web).
class KiroAvatar extends StatelessWidget {
  const KiroAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/img/kiro.svg',
    width: size,
    height: size * 420 / 400, // proporción original del dibujo
    excludeFromSemantics: true,
  );
}
