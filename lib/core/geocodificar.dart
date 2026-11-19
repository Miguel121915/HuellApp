import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Dirección ↔ punto en el mapa con Nominatim (el buscador gratuito de
/// OpenStreetMap, el mismo proyecto de los mapas). Sin cuenta ni llave.
/// Sus reglas piden pocas consultas: solo se busca cuando la persona termina
/// de escribir la dirección o usa su ubicación, nunca en cada tecla.
class Geocodificar {
  static const _servidor = 'nominatim.openstreetmap.org';

  static Future<dynamic> _consultar(String ruta, Map<String, String> parametros) async {
    final uri = Uri.https(_servidor, '/$ruta', {
      'format': 'jsonv2',
      'accept-language': 'es',
      ...parametros,
    });
    // Nominatim pide que las apps se identifiquen (en el navegador no se puede cambiar el User-Agent)
    final cabeceras = {
      'Accept': 'application/json',
      if (!kIsWeb) 'User-Agent': 'HuellApp/1.0 (proyecto escolar)',
    };
    final r = await http.get(uri, headers: cabeceras).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Nominatim respondió ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// Busca una dirección escrita (en México). Devuelve null si no se encontró o no hay internet.
  static Future<LatLng?> buscarDireccion(String texto) async {
    try {
      final lista = await _consultar('search', {'q': texto, 'countrycodes': 'mx', 'limit': '1'});
      if (lista is! List || lista.isEmpty) return null;
      final lat = double.tryParse('${lista.first['lat']}');
      final lon = double.tryParse('${lista.first['lon']}');
      return lat == null || lon == null ? null : LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  /// Lo contrario: la dirección de un punto. Null si no se pudo.
  static Future<({String direccion, String municipio, String codigoPostal})?> direccionDe(LatLng punto) async {
    try {
      final r = await _consultar('reverse', {
        'lat': '${punto.latitude}',
        'lon': '${punto.longitude}',
        'zoom': '18',
        'addressdetails': '1',
      });
      final a = r is Map ? r['address'] : null;
      if (a is! Map) return null;
      String campo(List<String> claves) =>
          claves.map((c) => a[c]).firstWhere((v) => v is String && v.isNotEmpty, orElse: () => '') as String;
      final calle = [campo(['road', 'pedestrian', 'footway']), campo(['house_number'])].where((t) => t.isNotEmpty).join(' ');
      final colonia = campo(['neighbourhood', 'suburb', 'quarter', 'hamlet']);
      final municipio = campo(['city', 'town', 'village', 'municipality', 'county']);
      final estado = campo(['state']);
      final cp = campo(['postcode']);
      return (
        direccion: [calle, colonia].where((t) => t.isNotEmpty).join(', '),
        municipio: [municipio, estado].where((t) => t.isNotEmpty).join(', '),
        codigoPostal: RegExp(r'^\d{5}$').hasMatch(cp) ? cp : '',
      );
    } catch (_) {
      return null;
    }
  }
}
