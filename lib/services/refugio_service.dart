import 'dart:convert';
import 'dart:typed_data';

import '../core/api_client.dart';
import '../core/api_config.dart';

/// Archivo elegido en el teléfono, listo para mandarse a la API como "data URL" (base64).
class ArchivoElegido {
  ArchivoElegido({required this.nombre, required this.bytes, required this.mime});

  final String nombre;
  final Uint8List bytes;
  final String mime;

  int get tamano => bytes.length;
  String get dataUrl => 'data:$mime;base64,${base64Encode(bytes)}';

  /// MIME a partir de la extensión (la API acepta PDF, JPG, PNG y, para fotos, WEBP).
  static String mimeDe(String nombre) {
    final ext = nombre.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

/// Mascota del inventario del refugio (tal como la devuelve /api/refugio/mascotas).
class MascotaInventario {
  MascotaInventario(this.datos);

  final Map<String, dynamic> datos;

  String get id => '${datos['id']}';
  String get nombre => datos['nombre'] as String? ?? '';
  String get especie => datos['especie'] as String? ?? 'perro';
  String get raza => datos['raza'] as String? ?? '';
  int get edadMeses => (datos['edadMeses'] as num?)?.toInt() ?? 1;
  String get sexo => datos['sexo'] as String? ?? 'macho';
  String get tamano => datos['tamano'] as String? ?? 'mediano';
  String get salud => datos['salud'] as String? ?? '';
  String get descripcion => datos['descripcion'] as String? ?? '';
  String get estatus => datos['estatus'] as String? ?? 'disponible';
  String get foto => datos['foto'] as String? ?? '';
  String get fotoUrl => ApiConfig.urlArchivo(foto);
}

/// Todo lo que hace la cuenta de un refugio contra la API: registro, estado, panel e inventario.
class RefugioService {
  RefugioService._();

  static final RefugioService instancia = RefugioService._();

  ApiClient get _api => ApiClient.instancia;

  /// Alta de refugio (queda "pendiente" hasta que el administrador lo apruebe en la web).
  /// [documentos]: tipo ('acta' | 'domicilio' | 'identificacion' | 'permiso') → archivo.
  Future<void> registrar(Map<String, dynamic> datos, Map<String, ArchivoElegido> documentos) async {
    await _api.post('/auth/registro-refugio', {
      ...datos,
      'documentos': [
        for (final d in documentos.entries) {'tipo': d.key, 'nombre': d.value.nombre, 'dataUrl': d.value.dataUrl},
      ],
    });
  }

  /// Estado actual del refugio de la sesión: {nombre, estado, motivoRechazo, apelaciones} o null.
  Future<Map<String, dynamic>?> estado() async {
    final r = await _api.get('/auth/yo');
    return r['refugio'] as Map<String, dynamic>?;
  }

  /// Datos completos del refugio (perfil): incluye ubicación, WhatsApp, redes, etc.
  Future<Map<String, dynamic>> miRefugio() async =>
      (await _api.get('/refugio/yo'))['refugio'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> actualizarPerfil(Map<String, dynamic> datos) async =>
      (await _api.put('/refugio/perfil', datos))['refugio'] as Map<String, dynamic>;

  /// {total, disponibles, enProceso, adoptadas, publicaciones, recientes: [mascotas]}
  Future<Map<String, dynamic>> resumen() => _api.get('/refugio/resumen');

  Future<List<MascotaInventario>> mascotas() async {
    final r = await _api.get('/refugio/mascotas');
    return (r['mascotas'] as List? ?? []).cast<Map<String, dynamic>>().map(MascotaInventario.new).toList();
  }

  /// Crea (sin [id]) o edita una mascota. [datos.foto] puede ser una data URL nueva o la ruta actual.
  Future<void> guardarMascota(Map<String, dynamic> datos, {String? id}) async {
    if (id == null) {
      await _api.post('/refugio/mascotas', datos);
    } else {
      await _api.put('/refugio/mascotas/$id', datos);
    }
  }

  Future<void> cambiarEstatus(String id, String estatus) =>
      _api.patch('/refugio/mascotas/$id/estatus', {'estatus': estatus});

  Future<void> eliminarMascota(String id) => _api.delete('/refugio/mascotas/$id');

  /* ---------- Publicaciones (las ven los usuarios en el perfil del refugio) ---------- */

  Future<List<Map<String, dynamic>>> publicaciones() async =>
      ((await _api.get('/refugio/publicaciones'))['publicaciones'] as List? ?? []).cast<Map<String, dynamic>>();

  /// Crea (sin [id], con mascotaId) o edita (con [id]: texto, foto y republicación).
  Future<void> guardarPublicacion(Map<String, dynamic> datos, {String? id}) async {
    if (id == null) {
      await _api.post('/refugio/publicaciones', datos);
    } else {
      await _api.put('/refugio/publicaciones/$id', datos);
    }
  }

  Future<void> eliminarPublicacion(String id) => _api.delete('/refugio/publicaciones/$id');

  /* ---------- Solicitudes de adopción recibidas ---------- */

  Future<List<Map<String, dynamic>>> adopciones() async =>
      ((await _api.get('/refugio/adopciones'))['solicitudes'] as List? ?? []).cast<Map<String, dynamic>>();

  /// [estado]: 'pendiente' | 'en revision' | 'aprobada' | 'rechazada' (rechazar exige [nota]).
  Future<void> cambiarEstadoAdopcion(String id, String estado, String nota) =>
      _api.patch('/refugio/adopciones/$id', {'estado': estado, 'nota': nota});

  /* ---------- Preguntas frecuentes (las usa el asistente de adopción) ---------- */

  Future<List<Map<String, dynamic>>> preguntas() async =>
      ((await _api.get('/refugio/preguntas'))['preguntas'] as List? ?? []).cast<Map<String, dynamic>>();

  Future<void> guardarPregunta(Map<String, dynamic> datos, {String? id}) async {
    if (id == null) {
      await _api.post('/refugio/preguntas', datos);
    } else {
      await _api.put('/refugio/preguntas/$id', datos);
    }
  }

  Future<void> eliminarPregunta(String id) => _api.delete('/refugio/preguntas/$id');
}

/// "2026-11-05T08:30:00.000Z" → "05/11/2026" (hora local).
String fechaCorta(String? iso) {
  final f = DateTime.tryParse(iso ?? '')?.toLocal();
  if (f == null) return '';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year}';
}
