import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Muestra una foto de la API. Igual que Image.network, pero también entiende las
/// ilustraciones .svg que usan las mascotas de demostración del sitio web.
class FotoHuellApp extends StatelessWidget {
  const FotoHuellApp(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  Widget _respaldo(BuildContext context) =>
      errorBuilder?.call(context, 'sin foto', null) ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFFD8EEE6),
        alignment: Alignment.center,
        child: const Icon(Icons.pets, color: Color(0xFF1B4943)),
      );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _respaldo(context);
    if (url.toLowerCase().split('?').first.endsWith('.svg')) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF2FCFA),
        child: SvgPicture.network(
          url,
          width: width,
          height: height,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }
    return Image.network(url, width: width, height: height, fit: fit, errorBuilder: (c, e, s) => _respaldo(c));
  }
}
