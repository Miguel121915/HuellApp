import '../core/api_client.dart';
import 'refugio_service.dart' show ArchivoElegido;

/// Solicitudes de adopción del usuario (HU-14). Misma API que el sitio web: POST/GET /api/adopciones.
class AdopcionService {
  AdopcionService._();

  static final AdopcionService instancia = AdopcionService._();

  ApiClient get _api => ApiClient.instancia;

  /// Envía la solicitud. [documentos]: identificación y comprobante (uno cada uno) y de 1 a 3
  /// fotos del espacio ('vivienda'). La API valida todo de nuevo.
  Future<Map<String, dynamic>> solicitar({
    required String mascotaId,
    required Map<String, dynamic> datos,
    required ArchivoElegido identificacion,
    required ArchivoElegido domicilio,
    required List<ArchivoElegido> vivienda,
  }) async {
    Map<String, String> doc(String tipo, ArchivoElegido a) => {'tipo': tipo, 'nombre': a.nombre, 'dataUrl': a.dataUrl};
    final r = await _api.post('/adopciones', {
      'mascotaId': mascotaId,
      ...datos,
      'aceptaTerminos': true,
      'documentos': [
        doc('identificacion', identificacion),
        doc('domicilio', domicilio),
        for (final f in vivienda) doc('vivienda', f),
      ],
    }, const Duration(seconds: 90)); // los documentos pueden pesar varios MB
    return (r['solicitud'] as Map).cast<String, dynamic>();
  }

  /// Mis solicitudes (las más recientes primero) con su estado.
  Future<List<Map<String, dynamic>>> misSolicitudes() async =>
      ((await _api.get('/adopciones'))['solicitudes'] as List? ?? []).cast<Map<String, dynamic>>();

  /// HU-23: guía de cuidado de una adopción aprobada: {titulo, etapa, secciones:[{titulo, icono, puntos}], consejos|null}.
  Future<Map<String, dynamic>> guiaCuidados(String solicitudId) async =>
      ((await _api.get('/adopciones/$solicitudId/cuidados'))['guia'] as Map).cast<String, dynamic>();

  /// HU-23: consejos con IA para esa mascota (la API los guarda). null si la IA no respondió.
  Future<List<String>?> personalizarCuidados(String solicitudId) async {
    final r = await _api.post('/adopciones/$solicitudId/cuidados', {}, const Duration(seconds: 60));
    return (r['consejos'] as List?)?.cast<String>();
  }
}
