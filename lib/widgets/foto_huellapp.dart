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
    // Siempre dentro de una caja del tamaño pedido y recortada: la foto se ajusta con [fit]
    // (por defecto cover = recorte centrado) y nunca estira ni deforma la tarjeta.
    if (url.toLowerCase().split('?').first.endsWith('.svg')) {
      return ClipRect(
        child: Container(
          width: width,
          height: height,
          color: const Color(0xFFF2FCFA),
          child: SvgPicture.network(
            url,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            placeholderBuilder: (_) => const Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        ),
      );
    }
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          alignment: Alignment.center,
          errorBuilder: (c, e, s) => _respaldo(c),
        ),
      ),
    );
  }
}
