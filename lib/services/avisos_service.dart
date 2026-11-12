import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/sesion_service.dart';

/// Un aviso para la cuenta (HU-19). [seccion] dice a dónde lleva:
/// coincidencias · solicitudes · mensajes · foro · refugio-mensajes · refugio-adopciones · estado-refugio
class Aviso {
  const Aviso({required this.id, required this.seccion, required this.titulo, required this.texto, required this.leido, this.fecha});

  final String id;
  final String seccion;
  final String titulo;
  final String texto;
  final bool leido;
  final DateTime? fecha;

  factory Aviso.desdeApi(Map<String, dynamic> j) => Aviso(
        id: '${j['id']}',
        seccion: j['seccion'] as String? ?? 'foro',
        titulo: j['titulo'] as String? ?? '',
        texto: j['texto'] as String? ?? '',
        leido: j['leido'] == true,
        fecha: DateTime.tryParse(j['fecha'] as String? ?? '')?.toLocal(),
      );
}

/// Avisos dentro de la app (HU-19). Revisa la API cada 30 s mientras haya sesión; la campana
/// escucha [noLeidos] y [nuevos] (los que llegaron desde la última revisión, para mostrar un aviso).
class AvisosService extends ChangeNotifier {
  AvisosService._() {
    SesionService.instancia.addListener(_alCambiarSesion);
    _alCambiarSesion();
  }

  static final AvisosService instancia = AvisosService._();

  List<Aviso> avisos = [];
  int noLeidos = 0;

  /// Avisos no leídos que llegaron en la última revisión (vacío en la primera).
  List<Aviso> nuevos = [];

  Timer? _reloj;
  int? _ultimoId;

  ApiClient get _api => ApiClient.instancia;

  void _alCambiarSesion() {
    _reloj?.cancel();
    avisos = [];
    noLeidos = 0;
    nuevos = [];
    _ultimoId = null;
    if (SesionService.instancia.haySesion) {
      actualizar();
      _reloj = Timer.periodic(const Duration(seconds: 30), (_) => actualizar());
    }
    notifyListeners();
  }

  Future<void> actualizar() async {
    if (!SesionService.instancia.haySesion) return;
    try {
      final r = await _api.get('/avisos');
      final lista = (r['avisos'] as List? ?? []).map((a) => Aviso.desdeApi(a as Map<String, dynamic>)).toList();
      final mayor = lista.fold<int>(0, (m, a) => (int.tryParse(a.id) ?? 0) > m ? int.parse(a.id) : m);
      nuevos = _ultimoId == null ? [] : lista.where((a) => !a.leido && (int.tryParse(a.id) ?? 0) > _ultimoId!).toList();
      _ultimoId = mayor > (_ultimoId ?? 0) ? mayor : (_ultimoId ?? 0);
      avisos = lista;
      noLeidos = (r['noLeidos'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } on ApiException {
      // sin conexión: se reintenta en 30 s
    }
  }

  Future<void> marcarLeido(Aviso aviso) async {
    if (aviso.leido) return;
    try {
      await _api.post('/avisos/leidos', {'ids': [aviso.id]});
    } on ApiException {
      return;
    }
    await actualizar();
  }

  Future<void> marcarTodos() async {
    try {
      await _api.post('/avisos/leidos', {});
    } on ApiException {
      return;
    }
    await actualizar();
  }
}
