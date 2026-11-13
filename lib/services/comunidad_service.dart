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
    // Si la API avisó «posible-duplicado» y la persona decide publicar de todos modos:
    // se reenvía la ruta de la foto que ya quedó guardada y confirmarDuplicado.
    String? fotoGuardada,
    bool confirmarDuplicado = false,
    // Formularios «Se me perdió» / «La encontré»
    String? color,
    String? tamano,
    String collar = '',
    DateTime? fecha,
    String? situacion,
    double? latitud,
    double? longitud,
    String senaSecreta = '',
  }) async {
    final r = await _api.post('/reportes', {
      'tipo': tipo,
      'descripcion': descripcion,
      'zona': zona,
      'foto': fotoGuardada ?? dataUrl(foto),
      'especie': ?especie,
      if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
      'color': ?color,
      'tamano': ?tamano,
      if (collar.trim().isNotEmpty) 'collar': collar.trim(),
      if (fecha != null) 'fecha': fecha.toUtc().toIso8601String(),
      'situacion': ?situacion,
      'latitud': ?latitud,
      'longitud': ?longitud,
      if (senaSecreta.trim().isNotEmpty) 'senaSecreta': senaSecreta.trim(),
      if (confirmarDuplicado) 'confirmarDuplicado': true,
    }, const Duration(seconds: 180)); // la IA analiza y compara fotos: puede tardar (con reintentos)
    return ResultadoReporte(
      coincidenciasNuevas: (r['coincidenciasNuevas'] as num?)?.toInt() ?? 0,
      iaUsada: r['iaUsada'] == true,
      iaPendiente: r['iaPendiente'] == true,
      analisis: (r['analisisIA'] as Map?)?.cast<String, dynamic>(),
    );
  }

  /* ---------- Coincidencias ---------- */

  Future<List<Map<String, dynamic>>> coincidencias() async => (await coincidenciasConEstado()).coincidencias;

  /// Coincidencias más lo que la IA sigue haciendo en segundo plano (ver [EstadoCoincidencias]).
  Future<EstadoCoincidencias> coincidenciasConEstado() async {
    final r = await _api.get('/coincidencias');
    return EstadoCoincidencias(
      coincidencias: (r['coincidencias'] as List? ?? []).cast<Map<String, dynamic>>(),
      analizando: (r['analizando'] as num?)?.toInt() ?? 0,
      duplicados: (r['duplicados'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }

  Future<Map<String, int>> resumenCoincidencias() async {
    final r = await _api.get('/coincidencias/resumen');
    return {
      'pendientes': (r['pendientes'] as num?)?.toInt() ?? 0,
      'descartadas': (r['descartadas'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> descartarCoincidencia(String id) => _api.post('/coincidencias/$id/descartar');

  /// Quien encontró la mascota describe la seña secreta que pidió el dueño (después ve su contacto).
  Future<void> responderSena(String id, String respuesta) =>
      _api.post('/coincidencias/$id/sena', {'respuesta': respuesta.trim()});

  Future<void> restaurarCoincidencias() => _api.post('/coincidencias/restaurar');

  /* ---------- Foro / muro ---------- */

  /// Publicaciones del muro. [categoria]: busca | familia | reunidos | comunidad (vacía = todas).
  Future<List<PublicacionForo>> publicaciones({String categoria = ''}) async {
    final r = await _api.get('/foro', query: {'limite': '60', if (categoria.isNotEmpty) 'categoria': categoria});
    return (r['publicaciones'] as List? ?? [])
        .map((p) => PublicacionForo.desdeApi(p as Map<String, dynamic>))
        .toList();
  }

  /// «¡Ya apareció!»: quien publicó la alerta la cierra y pasa a «Reunidos».
  Future<void> marcarReunido(String reporteId) => _api.post('/reportes/$reporteId/reunido');

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

/// Lo que devuelve GET /coincidencias.
class EstadoCoincidencias {
  const EstadoCoincidencias({required this.coincidencias, this.analizando = 0, this.duplicados = const []});

  final List<Map<String, dynamic>> coincidencias;

  /// Reportes míos que la IA todavía está revisando (en segundo plano).
  final int analizando;

  /// Mis reportes que la IA cree que son la misma mascota que otra alerta: {miReporte, otro}.
  final List<Map<String, dynamic>> duplicados;
}

class ResultadoReporte {
  const ResultadoReporte({required this.coincidenciasNuevas, required this.iaUsada, this.analisis, this.iaPendiente = false});

  final int coincidenciasNuevas;
  final bool iaUsada;

  /// La IA revisa la foto en segundo plano: el resultado llega después a «Coincidencias».
  final bool iaPendiente;

  /// {especie, raza, color, tamano, senas, resumen} que detectó la IA (null si no hubo IA).
  final Map<String, dynamic>? analisis;
}

class ComentarioForo {
  const ComentarioForo({required this.autor, required this.texto, this.enRevision = false});

  final String autor;
  final String texto;

  /// HU-18: el sistema lo marcó; solo lo ve su autor hasta que el administrador lo revise.
  final bool enRevision;

  factory ComentarioForo.desdeApi(Map<String, dynamic> j) => ComentarioForo(
    autor: j['autor'] as String? ?? '',
    texto: j['texto'] as String? ?? '',
    enRevision: j['enRevision'] == true,
  );
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
    this.categoria = 'comunidad',
    this.reporteId,
    this.esMiAlerta = false,
    this.enRevision = false,
  });

  /// HU-18: el sistema la marcó; solo la ve su autor hasta que el administrador la revise.
  final bool enRevision;

  final String id;
  final String autor;

  /// Pestaña del muro: busca | familia | reunidos | comunidad (la manda la API).
  String categoria;

  /// Reporte al que pertenece la alerta (null = publicación de la comunidad).
  final String? reporteId;

  /// La alerta es de quien consulta: puede marcar «¡Ya apareció!».
  final bool esMiAlerta;
  final DateTime? fecha;
  final String texto;
  final String fotoUrl;

  /// "Me gusta" de las demás personas (la API no cuenta el propio).
  final int otrosLikes;
  bool leGusta;
  List<ComentarioForo> comentarios;

  int get meGusta => otrosLikes + (leGusta ? 1 : 0);

  bool get esAlertaPerdida => categoria == 'busca';
  bool get esAlertaEncontrada => categoria == 'familia';
  bool get esReunido => categoria == 'reunidos';

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
      categoria: j['categoria'] as String? ?? 'comunidad',
      reporteId: j['reporteId'] as String?,
      esMiAlerta: j['esMiAlerta'] == true,
      enRevision: j['enRevision'] == true,
    );
  }
}
