import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Servicio para conectar la app Flutter con el Backend Node.js y Gemini IA.
class ServiciosIA {
  // IP de tu PC para dispositivos en la misma red Wi-Fi o localhost
  final String urlBackend = 'http://192.168.10.237:3000/api/analizar-mascota';

  /// Envía el reporte (texto + foto) a Node.js / Gemini
  Future<Map<String, dynamic>?> analizarMascotaConIA(
    String descripcion, {
    Uint8List? bytesImagen,
    String? tipoReporte,
    String? tipoMascota,
    String? nombreMascota,
    String? zonaUbicacion,
    int? usuarioId,
  }) async {
    try {
      final Map<String, dynamic> bodyData = {
        'promptTexto': descripcion,
        if (bytesImagen != null) 'imagenBase64': base64Encode(bytesImagen),
        if (tipoReporte != null) 'tipoReporte': tipoReporte,
        if (tipoMascota != null) 'tipoMascota': tipoMascota,
        if (nombreMascota != null && nombreMascota.isNotEmpty)
          'nombreMascota': nombreMascota,
        if (zonaUbicacion != null) 'zonaUbicacion': zonaUbicacion,
        if (usuarioId != null) 'usuarioId': usuarioId,
      };

      final respuesta = await http
          .post(
            Uri.parse(urlBackend),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyData),
          )
          .timeout(const Duration(seconds: 200));

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        if (datos['exito'] == true) {
          return datos as Map<String, dynamic>;
        }
      } else {
        print(
          '❌ Error servidor HTTP ${respuesta.statusCode}: ${respuesta.body}',
        );
      }
      return null;
    } on TimeoutException {
      print('⏰ Tiempo de espera agotado. El servidor tardó demasiado.');
      return null;
    } catch (e) {
      print('❌ Error de conexión: $e');
      return null;
    }
  }

  /// Obtiene las publicaciones del foro guardadas en MySQL
  Future<List<dynamic>> obtenerPublicacionesForo() async {
    try {
      final String urlForo = 'http://192.168.10.237:3000/api/foro';
      final respuesta = await http
          .get(Uri.parse(urlForo))
          .timeout(const Duration(seconds: 15));

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        if (datos['exito'] == true) {
          return datos['posts'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener publicaciones del foro: $e');
      return [];
    }
  }
}
