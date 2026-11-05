import 'package:flutter/foundation.dart';

/// Dirección de la API PHP (carpeta api/ del repositorio).
///
/// Por defecto:
///  * Flutter web, Windows, iOS simulator: http://127.0.0.1:3000/api
///    (127.0.0.1 y no "localhost": php artisan serve solo escucha en IPv4)
///  * Emulador de Android: http://10.0.2.2:3000/api (así ve el emulador a tu PC)
///
/// En un celular real, enciende la API con  php artisan serve --host=0.0.0.0
/// y corre la app indicando la IP de tu PC en la red Wi-Fi:
///   flutter run --dart-define=API_URL=http://192.168.1.50:3000/api
class ApiConfig {
  ApiConfig._();

  static const String _desdeLineaDeComandos = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_desdeLineaDeComandos.isNotEmpty) return _desdeLineaDeComandos;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://127.0.0.1:3000/api';
  }

  /// Raíz del servidor (sin /api), para armar la URL de fotos como /uploads/imagenes/x.jpg.
  static String get servidor => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// Convierte una ruta de foto de la API en URL completa.
  static String urlArchivo(String ruta) {
    if (ruta.isEmpty || ruta.startsWith('http')) return ruta;
    return '$servidor/${ruta.startsWith('/') ? ruta.substring(1) : ruta}';
  }
}
