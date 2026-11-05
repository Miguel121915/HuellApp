import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Error que devuelve la API ({"error": "..."}) o un problema de conexión.
/// [mensaje] ya viene en español y se puede mostrar tal cual al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.estado = 0});

  final String mensaje;

  /// Código HTTP (0 = no hubo respuesta del servidor).
  final int estado;

  bool get sinConexion => estado == 0;
  bool get sesionVencida => estado == 401;

  @override
  String toString() => mensaje;
}

/// Cliente único para hablar con la API PHP. Agrega el token de sesión a cada petición.
class ApiClient {
  ApiClient._();

  static final ApiClient instancia = ApiClient._();

  static const Duration _espera = Duration(seconds: 25);

  /// Token JWT de la sesión actual (lo administra SesionService).
  String? token;

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String ruta, [Map<String, String>? query]) {
    final limpia = ruta.startsWith('/') ? ruta : '/$ruta';
    return Uri.parse('${ApiConfig.baseUrl}$limpia')
        .replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  Future<Map<String, dynamic>> get(String ruta, {Map<String, String>? query}) =>
      _enviar(() => http.get(_uri(ruta, query), headers: _cabeceras));

  Future<Map<String, dynamic>> post(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar(() => http.post(_uri(ruta), headers: _cabeceras, body: jsonEncode(cuerpo ?? {})));

  Future<Map<String, dynamic>> put(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar(() => http.put(_uri(ruta), headers: _cabeceras, body: jsonEncode(cuerpo ?? {})));

  Future<Map<String, dynamic>> patch(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar(() => http.patch(_uri(ruta), headers: _cabeceras, body: jsonEncode(cuerpo ?? {})));

  Future<Map<String, dynamic>> delete(String ruta) =>
      _enviar(() => http.delete(_uri(ruta), headers: _cabeceras));

  Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() peticion) async {
    final http.Response respuesta;
    try {
      respuesta = await peticion().timeout(_espera);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Inténtalo de nuevo.');
    } catch (_) {
      throw ApiException(
        'No hay conexión con el servidor de HuellApp. Revisa que esté encendido (php artisan serve) y tu conexión.',
      );
    }

    Map<String, dynamic> datos = {};
    if (respuesta.body.isNotEmpty) {
      try {
        final decodificado = jsonDecode(utf8.decode(respuesta.bodyBytes));
        if (decodificado is Map<String, dynamic>) datos = decodificado;
      } catch (_) {
        // respuesta que no es JSON: se trata abajo según el código HTTP
      }
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return datos;
    throw ApiException(
      (datos['error'] as String?) ?? 'Ocurrió un error en el servidor (${respuesta.statusCode}).',
      estado: respuesta.statusCode,
    );
  }
}
