import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/requiere_sesion.dart';
import '../core/sesion_service.dart';
import '../data/refugios_data.dart';
import '../models/refugio.dart';

/// HU-12 Mascotas favoritas. Se guardan en la API (no se pierden al cerrar la app) y son las mismas
/// que en el sitio web. Las pantallas escuchan este servicio para pintar el corazón.
///
///   FavoritosService.instancia.addListener(_alCambiar);   // en initState
///   await FavoritosService.instancia.alternar(context, mascota);
class FavoritosService extends ChangeNotifier {
  FavoritosService._() {
    // Al iniciar o cerrar sesión se recargan (o se vacían) los favoritos
    SesionService.instancia.addListener(_sesionCambio);
  }

  static final FavoritosService instancia = FavoritosService._();

  final Set<String> _ids = {};
  List<Map<String, dynamic>> _lista = [];
  String? _usuarioCargado;

  Set<String> get ids => _ids;
  List<Map<String, dynamic>> get lista => _lista;
  bool esFavorito(String mascotaId) => _ids.contains(mascotaId);

  bool get _esUsuario => SesionService.instancia.actual?.rol == 'usuario';

  void _sesionCambio() {
    final actual = SesionService.instancia.actual?.correo;
    if (actual == _usuarioCargado) return;
    _ids.clear();
    _lista = [];
    _usuarioCargado = null;
    _marcarCatalogo();
    notifyListeners();
    if (_esUsuario) cargar();
  }

  /// Pide mis favoritos a la API. Un visitante o un refugio no tienen favoritos.
  Future<void> cargar() async {
    if (!_esUsuario) return;
    try {
      final r = await ApiClient.instancia.get('/favoritos');
      _lista = (r['favoritos'] as List? ?? []).cast<Map<String, dynamic>>();
      _ids
        ..clear()
        ..addAll(_lista.map((m) => '${m['id']}'));
      _usuarioCargado = SesionService.instancia.actual?.correo;
      _marcarCatalogo();
      notifyListeners();
    } on ApiException {
      // sin conexión: el corazón se queda como estaba
    }
  }

  /// Pone el corazón a las mascotas del catálogo (listaRefugios) que están en favoritos.
  void _marcarCatalogo() {
    for (final ref in listaRefugios) {
      for (final m in ref.mascotas) {
        m.esFavorito = _ids.contains(m.id);
      }
    }
  }

  /// Llamar después de recargar el catálogo.
  void marcarCatalogo() => _marcarCatalogo();

  /// Guarda o quita una mascota. Al visitante se le pide iniciar sesión. Devuelve el nuevo estado.
  Future<bool> alternar(BuildContext context, MascotaRefugio mascota) async {
    if (!await requiereSesion(context, 'guardar mascotas en favoritos')) return mascota.esFavorito;
    if (!_esUsuario) return mascota.esFavorito; // un refugio no guarda favoritos
    return establecer(context, mascota.id, !_ids.contains(mascota.id), nombre: mascota.nombre);
  }

  /// Guarda ([activo] = true) o quita una mascota por su id.
  Future<bool> establecer(BuildContext context, String mascotaId, bool activo, {String nombre = 'La mascota'}) async {
    final mensajero = ScaffoldMessenger.maybeOf(context);
    try {
      if (activo) {
        await ApiClient.instancia.post('/favoritos', {'mascotaId': mascotaId});
        _ids.add(mascotaId);
      } else {
        await ApiClient.instancia.delete('/favoritos/$mascotaId');
        _ids.remove(mascotaId);
        _lista = _lista.where((m) => '${m['id']}' != mascotaId).toList();
      }
      _marcarCatalogo();
      notifyListeners();
      mensajero?.showSnackBar(SnackBar(
        content: Text(activo ? '$nombre se guardó en tus favoritos' : '$nombre se quitó de tus favoritos'),
        duration: const Duration(seconds: 2),
      ));
      if (activo) cargar(); // trae los datos completos para la pantalla de favoritos
    } on ApiException catch (e) {
      mensajero?.showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
    }
    return _ids.contains(mascotaId);
  }
}

/// HU-13 y HU-16: escribirle a un refugio, ver mis mensajes y consultar los requisitos de adopción.
class ContactoService {
  ContactoService._();

  static final ContactoService instancia = ContactoService._();

  ApiClient get _api => ApiClient.instancia;

  /// Requisitos de adopción de un refugio (también para visitantes): [{id, texto, detalle, obligatorio}]
  Future<List<Map<String, dynamic>>> requisitos(String refugioId) async =>
      ((await _api.get('/refugios/$refugioId/requisitos'))['requisitos'] as List? ?? []).cast<Map<String, dynamic>>();

  /// Mis mensajes a refugios, con su respuesta.
  Future<List<Map<String, dynamic>>> misMensajes() async =>
      ((await _api.get('/mensajes'))['mensajes'] as List? ?? []).cast<Map<String, dynamic>>();

  /// Con [mascotaId] el mensaje va al refugio responsable de esa mascota; si no, a [refugioId].
  Future<void> enviar({String? refugioId, String? mascotaId, required String mensaje, String telefono = ''}) =>
      _api.post('/mensajes', {
        if (mascotaId != null) 'mascotaId': mascotaId else 'refugioId': refugioId,
        'mensaje': mensaje,
        'telefono': telefono,
      });

  static String urlFoto(String ruta) => ruta.isEmpty ? '' : ApiConfig.urlArchivo(ruta);
}
