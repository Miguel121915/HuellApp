import 'dart:convert';
import 'dart:typed_data';

import '../core/api_client.dart';
import '../core/api_config.dart';

/// Reportes de mascotas (HU-5), coincidencias (HU-8) y foro / muro de la comunidad,
/// todo contra la API PHP (antes Reportar y el foro usaban el servidor Node de backend/).
class ComunidadService {
  ComunidadService._();

  static final ComunidadService instancia = ComunidadService._();

  ApiClient get _api => ApiClient.instancia;

  /// Foto en el formato que acepta la API (data URL).
  static String dataUrl(Uint8List bytes) {
    final png = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return 'data:${png ? 'image/png' : 'image/jpeg'};base64,${base64Encode(bytes)}';
  }

  /* ---------- Reportes ---------- */

  /// Crea la alerta. [tipo] es 'perdida' o 'encontrada'; [especie] 'perro', 'gato' u 'otro'.
  /// La API analiza la foto con IA, busca coincidencias y publica la alerta en el muro.
  Future<ResultadoReporte> crearReporte({
    required String tipo,
    required String descripcion,
    required String zona,
    required Uint8List foto,
    String? especie,
    String nombre = '',
  }) async {
    final r = await _api.post('/reportes', {
      'tipo': tipo,
      'descripcion': descripcion,
      'zona': zona,
      'foto': dataUrl(foto),
      'especie': ?especie,
      if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    }, const Duration(seconds: 120)); // la IA analiza y compara fotos: puede tardar
    return ResultadoReporte(
      coincidenciasNuevas: (r['coincidenciasNuevas'] as num?)?.toInt() ?? 0,
      iaUsada: r['iaUsada'] == true,
      analisis: (r['analisisIA'] as Map?)?.cast<String, dynamic>(),
    );
  }

  /* ---------- Coincidencias ---------- */

  Future<List<Map<String, dynamic>>> coincidencias() async {
    final r = await _api.get('/coincidencias');
    return (r['coincidencias'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, int>> resumenCoincidencias() async {
    final r = await _api.get('/coincidencias/resumen');
    return {
      'pendientes': (r['pendientes'] as num?)?.toInt() ?? 0,
      'descartadas': (r['descartadas'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> descartarCoincidencia(String id) => _api.post('/coincidencias/$id/descartar');

  Future<void> restaurarCoincidencias() => _api.post('/coincidencias/restaurar');

  /* ---------- Foro / muro ---------- */

  Future<List<PublicacionForo>> publicaciones() async {
    final r = await _api.get('/foro', query: {'limite': '60'});
    return (r['publicaciones'] as List? ?? [])
        .map((p) => PublicacionForo.desdeApi(p as Map<String, dynamic>))
        .toList();
  }

  Future<PublicacionForo> publicar(String texto, {Uint8List? foto}) async {
    final r = await _api.post('/foro', {'texto': texto, if (foto != null) 'foto': dataUrl(foto)});
    return PublicacionForo.desdeApi(r['publicacion'] as Map<String, dynamic>);
  }

  Future<void> meGusta(String id, bool activo) => _api.put('/foro/$id/like', {'activo': activo});

  Future<List<ComentarioForo>> comentar(String id, String texto) async {
    final r = await _api.post('/foro/$id/comentarios', {'texto': texto});
    return (r['comentarios'] as List? ?? [])
        .map((c) => ComentarioForo.desdeApi(c as Map<String, dynamic>))
        .toList();
  }
}

class ResultadoReporte {
  const ResultadoReporte({required this.coincidenciasNuevas, required this.iaUsada, this.analisis});

  final int coincidenciasNuevas;
  final bool iaUsada;

  /// {especie, raza, color, tamano, senas, resumen} que detectó la IA (null si no hubo IA).
  final Map<String, dynamic>? analisis;
}

class ComentarioForo {
  const ComentarioForo({required this.autor, required this.texto});

  final String autor;
  final String texto;

  factory ComentarioForo.desdeApi(Map<String, dynamic> j) =>
      ComentarioForo(autor: j['autor'] as String? ?? '', texto: j['texto'] as String? ?? '');
}

class PublicacionForo {
  PublicacionForo({
    required this.id,
    required this.autor,
    required this.fecha,
    required this.texto,
    required this.fotoUrl,
    required this.otrosLikes,
    required this.leGusta,
    required this.comentarios,
  });

  final String id;
  final String autor;
  final DateTime? fecha;
  final String texto;
  final String fotoUrl;

  /// "Me gusta" de las demás personas (la API no cuenta el propio).
  final int otrosLikes;
  bool leGusta;
  List<ComentarioForo> comentarios;

  int get meGusta => otrosLikes + (leGusta ? 1 : 0);

  /// Las alertas de Reportar empiezan con 🔎 SE BUSCA o 🐾 ENCONTRÉ.
  bool get esAlertaPerdida => texto.startsWith('🔎');
  bool get esAlertaEncontrada => texto.startsWith('🐾 ENCONTRÉ');

  factory PublicacionForo.desdeApi(Map<String, dynamic> j) {
    final foto = j['foto'] as String? ?? '';
    return PublicacionForo(
      id: '${j['id']}',
      autor: j['autor'] as String? ?? '',
      fecha: DateTime.tryParse(j['fecha'] as String? ?? '')?.toLocal(),
      texto: j['texto'] as String? ?? '',
      fotoUrl: foto.isEmpty ? '' : ApiConfig.urlArchivo(foto),
      otrosLikes: (j['likes'] as num?)?.toInt() ?? 0,
      leGusta: j['yaDioLike'] == true,
      comentarios: (j['comentarios'] as List? ?? [])
          .map((c) => ComentarioForo.desdeApi(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
