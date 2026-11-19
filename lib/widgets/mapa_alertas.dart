import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  // Siluetas del marcador según la especie (viewBox 40×40): cabeza de gato, cabeza de perro o
  // huellita para otras mascotas. Las mismas que en sitio-web/assets/js/components/mapa-alertas.js.
  static const _siluetas = {
    'gato': '<path d="M7 4 L16.5 12.5 Q20 11.6 23.5 12.5 L33 4 Q35.5 13 34 19.5 Q37 25 34 30.5 Q29 37 20 37 Q11 37 6 30.5 Q3 25 6 19.5 Q4.5 13 7 4 Z"/>',
    'perro': '<path d="M12 9 Q4 6 2.5 15 Q1.5 24 6.5 27 Q9.5 28.5 10.5 24 Z"/><path d="M28 9 Q36 6 37.5 15 Q38.5 24 33.5 27 Q30.5 28.5 29.5 24 Z"/><ellipse cx="20" cy="22" rx="11.5" ry="13.5"/>',
    'otro': '<ellipse cx="20" cy="27" rx="9" ry="8"/><circle cx="9.5" cy="17.5" r="4"/><circle cx="16.5" cy="10.5" r="4"/><circle cx="23.5" cy="10.5" r="4"/><circle cx="30.5" cy="17.5" r="4"/>',
  };
  // Ojos y hocico en blanco; {c} es el color de la alerta (la nariz del perro)
  static const _caritas = {
    'gato': '<g fill="#fff"><ellipse cx="14" cy="22.5" rx="2.2" ry="2.8"/><ellipse cx="26" cy="22.5" rx="2.2" ry="2.8"/><path d="M17.8 28 H22.2 L20 30.6 Z"/></g>',
    'perro': '<g fill="#fff"><circle cx="15.5" cy="19.5" r="2.2"/><circle cx="24.5" cy="19.5" r="2.2"/><ellipse cx="20" cy="29" rx="6" ry="4.6"/></g><ellipse cx="20" cy="27.2" rx="2.6" ry="1.8" fill="{c}"/>',
    'otro': '',
  };

  /// SVG del marcador: la silueta de la especie, roja (se busca) o verde (busca a su familia).
  /// Primero la silueta en blanco y más gruesa (el borde), encima la de color y luego la carita.
  static String _iconoSvg(Map<String, dynamic> a) {
    final especie = _siluetas.containsKey(a['especie']) ? a['especie'] as String : 'otro';
    final silueta = _siluetas[especie]!;
    final c = '#${(_color(a).toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40">'
        '<g fill="#fff" stroke="#fff" stroke-width="5" stroke-linejoin="round">$silueta</g>'
        '<g fill="$c">$silueta</g>${_caritas[especie]!.replaceAll('{c}', c)}</svg>';
  }

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
                  width: 36,
                  height: 36,
                  child: Semantics(
                    button: true,
                    label: '${a['tipo'] == 'perdida' ? 'Se busca' : 'Busca a su familia'}: ${_nombre(a)}',
                    child: GestureDetector(
                      onTap: () => _abrir(a),
                      child: SvgPicture.string(_iconoSvg(a), width: 36, height: 36),
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
                  : '${alertas.length} ${alertas.length == 1 ? 'alerta activa' : 'alertas activas'}. Toca un ícono para ver la alerta.',
              style: const TextStyle(fontSize: 12.5, color: Tipografia.tintaTenue),
            ),
          ],
        ],
      ),
    );
  }
}
