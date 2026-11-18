import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/compartir.dart';
import '../core/tipografia.dart';

/// «Alertas cerca de ti» del Inicio: mascotas perdidas (rojo) y encontradas (verde) en el mapa.
/// Datos de GET /api/alertas, que ya vienen con la ubicación APROXIMADA (~300 m): por eso cada
/// punto lleva un círculo tenue alrededor (se ve la zona, no la casa de quien reportó).
class MapaAlertas extends StatefulWidget {
  const MapaAlertas({super.key});

  static const Color rojo = Color(0xFFB42318);
  static const Color verde = Color(0xFF1B4F4A);

  @override
  State<MapaAlertas> createState() => _MapaAlertasState();
}

class _MapaAlertasState extends State<MapaAlertas> {
  List<Map<String, dynamic>>? _alertas;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await ApiClient.instancia.get('/alertas');
      final lista = (r['alertas'] as List? ?? []).cast<Map<String, dynamic>>()
          .where((a) => a['latitud'] is num && a['longitud'] is num)
          .toList();
      if (mounted) setState(() => _alertas = lista);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.sinConexion ? 'Sin conexión: no pudimos cargar las alertas.' : 'No pudimos cargar las alertas.');
    }
  }

  static LatLng _punto(Map<String, dynamic> a) => LatLng((a['latitud'] as num).toDouble(), (a['longitud'] as num).toDouble());
  static Color _color(Map<String, dynamic> a) => a['tipo'] == 'perdida' ? MapaAlertas.rojo : MapaAlertas.verde;
  static String _nombre(Map<String, dynamic> a) =>
      (a['nombre'] as String?) ?? const {'perro': 'Perro', 'gato': 'Gato'}[a['especie']] ?? 'Mascota';

  void _abrir(Map<String, dynamic> a) {
    final perdida = a['tipo'] == 'perdida';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: _color(a), borderRadius: BorderRadius.circular(20)),
                child: Text(perdida ? 'SE BUSCA' : 'BUSCA A SU FAMILIA',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              const SizedBox(height: 8),
              Text(_nombre(a), style: const TextStyle(fontFamily: Tipografia.fuenteTitulos, fontSize: 24, fontWeight: FontWeight.w600, color: Tipografia.aquaFuerte)),
              if (a['zona'] != null) Text('📍 ${a['zona']}', style: const TextStyle(fontSize: 14.5, color: Tipografia.tintaSuave)),
              const SizedBox(height: 4),
              const Text('La ubicación es aproximada para cuidar la privacidad de quien reportó.',
                  style: TextStyle(fontSize: 12.5, color: Tipografia.tintaTenue)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(hoja);
                        final url = await Compartir.enlaceAlerta(a['id'] as String);
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ver alerta'),
                      style: ElevatedButton.styleFrom(backgroundColor: Tipografia.aquaFuerte, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(hoja);
                        Compartir.mostrar(context, a['id'] as String);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String texto) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12.5, color: Tipografia.tintaSuave)),
      ]);

  Widget _mapa(List<Map<String, dynamic>> alertas) {
    final puntos = alertas.map(_punto).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 230,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(19.4326, -99.1332), // CDMX, si no hay alertas
            initialZoom: 11,
            maxZoom: 16, // más cerca no tiene sentido: la ubicación es aproximada
            initialCameraFit: puntos.isEmpty ? null : CameraFit.coordinates(coordinates: puntos, padding: const EdgeInsets.all(36), maxZoom: 14),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.huellapp',
            ),
            CircleLayer(circles: [
              for (final a in alertas)
                CircleMarker(point: _punto(a), radius: 220, useRadiusInMeter: true, color: _color(a).withValues(alpha: 0.12), borderColor: _color(a).withValues(alpha: 0.35), borderStrokeWidth: 1),
            ]),
            MarkerLayer(markers: [
              for (final a in alertas)
                Marker(
                  point: _punto(a),
                  width: 30,
                  height: 30,
                  child: Semantics(
                    button: true,
                    label: '${a['tipo'] == 'perdida' ? 'Se busca' : 'Busca a su familia'}: ${_nombre(a)}',
                    child: GestureDetector(
                      onTap: () => _abrir(a),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _color(a),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertas = _alertas;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x141B4943), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AYUDA EN TU ZONA', style: Tipografia.sobretitulo),
          const SizedBox(height: 2),
          const Text('Alertas cerca de ti',
              style: TextStyle(fontFamily: Tipografia.fuenteTitulos, fontSize: 21, fontWeight: FontWeight.w600, color: Tipografia.aquaFuerte)),
          const SizedBox(height: 6),
          Wrap(spacing: 14, children: [_leyenda(MapaAlertas.rojo, 'Se busca'), _leyenda(MapaAlertas.verde, 'Busca a su familia')]),
          const SizedBox(height: 10),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Tipografia.tintaSuave))
          else if (alertas == null)
            const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()))
          else ...[
            _mapa(alertas),
            const SizedBox(height: 8),
            Text(
              alertas.isEmpty
                  ? 'Por ahora no hay alertas activas con ubicación. ¡Buena señal! 🐾'
                  : '${alertas.length} ${alertas.length == 1 ? 'alerta activa' : 'alertas activas'}. Toca un punto para ver la alerta.',
              style: const TextStyle(fontSize: 12.5, color: Tipografia.tintaTenue),
            ),
          ],
        ],
      ),
    );
  }
}
