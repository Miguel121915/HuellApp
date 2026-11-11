import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../data/refugios_data.dart';
import '../models/refugio.dart';
import 'usuario_service.dart';

/// Carga de la API los refugios aprobados y sus mascotas disponibles, y los deja en
/// [listaRefugios]. No necesita sesión: el visitante también puede ver el catálogo.
///
/// Uso en una pantalla:
///   initState:  CatalogoService.instancia.addListener(_alCambiar); CatalogoService.instancia.cargar();
///   dispose:    CatalogoService.instancia.removeListener(_alCambiar);
class CatalogoService extends ChangeNotifier {
  CatalogoService._();

  static final CatalogoService instancia = CatalogoService._();

  bool _cargando = false;
  bool _cargado = false;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;
  List<Refugio> get refugios => listaRefugios;

  /// Texto que se escribió en la búsqueda de Inicio; la pantalla de Refugios lo toma y lo limpia.
  String busquedaPendiente = '';

  void buscarDesdeInicio(String texto) {
    busquedaPendiente = texto.trim();
    notifyListeners();
  }

  /// Filtros del catálogo (HU-3) aplicados por la API: devuelve los ids de las mascotas
  /// disponibles del refugio que cumplen con ellos. Valores vacíos o "todas"/"todos" no filtran.
  /// [edad]: cachorro | joven | adulto | senior (los mismos rangos que el sitio web).
  Future<Set<String>> filtrarMascotas(
    String refugioId, {
    String texto = '',
    String especie = '',
    String edad = '',
    String tamano = '',
  }) async {
    final query = <String, String>{
      if (texto.trim().isNotEmpty) 'q': texto.trim(),
      if (especie.isNotEmpty && especie != 'todas') 'especie': especie,
      if (edad.isNotEmpty && edad != 'todas') 'edad': edad,
      if (tamano.isNotEmpty && tamano != 'todos') 'tamano': tamano,
    };
    final r = await ApiClient.instancia.get('/refugios/${Uri.encodeComponent(refugioId)}/mascotas', query: query);
    return {for (final m in (r['mascotas'] as List? ?? []).cast<Map<String, dynamic>>()) '${m['id']}'};
  }

  /// Descarga el catálogo. Si ya se cargó, no vuelve a pedirlo salvo con [forzar].
  Future<void> cargar({bool forzar = false}) async {
    if (_cargando || (_cargado && !forzar)) return;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final api = ApiClient.instancia;
      // Una sola petición: cada refugio viene con sus mascotas disponibles (?mascotas=1)
      final r = await api.get('/refugios?mascotas=1');
      final refugiosJson = (r['refugios'] as List? ?? []).cast<Map<String, dynamic>>();
      final mascotasPorRefugio = [
        for (final ref in refugiosJson)
          (ref['mascotas'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map((j) => MascotaRefugio.desdeApi(j, ApiConfig.urlArchivo))
              .toList(),
      ];

      final nuevos = [
        for (var i = 0; i < refugiosJson.length; i++) Refugio.desdeApi(refugiosJson[i], mascotasPorRefugio[i]),
      ];
      listaRefugios
        ..clear()
        ..addAll(nuevos);
      _cargado = true;
      // Corazones de favoritos (HU-12): los guardados en la API, iguales que en el sitio web
      FavoritosService.instancia.marcarCatalogo();
      FavoritosService.instancia.cargar();
    } on ApiException catch (e) {
      _error = e.mensaje;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
