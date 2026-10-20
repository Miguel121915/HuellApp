import 'dart:convert';

import 'package:http/http.dart' as http;

/// Servicio para conectar la app Flutter con el Backend Node.js y Gemini IA.
class ServiciosIA {
  // IP local de tu PC para el dispositivo físico en la red Wi-Fi
  final String urlBackend = 'http://192.168.0.104:3000/api/analizar-mascota';

  /// Envía la descripción recibida en el reporte al backend en Node.js
  /// y devuelve un Map con los datos estructurados por Gemini.
  Future<Map<String, dynamic>?> analizarMascotaConIA(String descripcion) async {
    try {
      final respuesta = await http.post(
        Uri.parse(urlBackend),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'promptTexto': descripcion}),
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);

        if (datos['exito'] == true) {
          // Devuelve el objeto JSON estructurado (razaEstimada, colorPrincipal, tamano, senasParticulares, resumenAlerta)
          return datos['analisisIA'] as Map<String, dynamic>;
        }
      } else {
        print('❌ Error en el servidor: ${respuesta.statusCode}');
      }
      return null;
    } catch (e) {
      print(
        '❌ Excepción al conectar con el backend (Verifica tu red o Firewall): $e',
      );
      return null;
    }
  }
}
