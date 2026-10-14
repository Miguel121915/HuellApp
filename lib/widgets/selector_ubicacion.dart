import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:huellapp/widgets/marcador_refugio.dart';
import 'package:latlong2/latlong.dart';

/// Mapa pequeño para que el refugio marque dónde está.
/// Se puede tocar el mapa para colocar el pin o usar la ubicación actual.
/// Las coordenadas se guardan para que el refugio aparezca en
/// "Refugios cerca de ti".
class SelectorUbicacion extends StatefulWidget {
  final double? latitud;
  final double? longitud;
  final bool hayError;

  // Textos (por defecto son los del registro de refugio)
  final String titulo;
  final String descripcion;
  final String textoError;
  final ValueChanged<LatLng?> onCambio;

  const SelectorUbicacion({
    super.key,
    this.latitud,
    this.longitud,
    this.hayError = false,
    this.titulo = 'Ubicación en el mapa',
    this.descripcion =
        'Así las personas cercanas podrán encontrar tu refugio. Toca el '
        'mapa para colocar el pin o usa tu ubicación actual.',
    this.textoError =
        'La ubicación es obligatoria: marca tu refugio en el mapa.',
    required this.onCambio,
  });

  @override
  State<SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<SelectorUbicacion> {
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);

  // Centro por defecto mientras no hay pin (zona oriente del Valle de México)
  static const LatLng _centroPorDefecto = LatLng(19.3, -98.9);

  final MapController _mapController = MapController();
  LatLng? _punto;
  bool _buscando = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    if (widget.latitud != null && widget.longitud != null) {
      _punto = LatLng(widget.latitud!, widget.longitud!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _colocar(LatLng punto) {
    setState(() {
      _punto = punto;
      _mensaje = null;
    });
    widget.onCambio(punto);
  }

  void _quitar() {
    setState(() => _punto = null);
    widget.onCambio(null);
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _buscando = true;
      _mensaje = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Activa la ubicación (GPS) de tu dispositivo.';
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw 'No tenemos permiso de ubicación. Toca el mapa para marcar '
            'dónde está tu refugio.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final punto = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      _colocar(punto);
      _mapController.move(punto, 16);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _mensaje = e is String
            ? e
            : 'No pudimos obtener tu ubicación. Toca el mapa para marcarla.',
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinPin = _punto == null;
    final error = widget.hayError && sinPin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.descripcion,
          style: const TextStyle(fontSize: 12, height: 1.4, color: _mutedColor),
        ),
        const SizedBox(height: 10),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error ? Colors.red : const Color(0xFF9ED9D1),
              width: error ? 2 : 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _punto ?? _centroPorDefecto,
                initialZoom: _punto == null ? 10 : 16,
                onTap: (tapPosition, punto) => _colocar(punto),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Cambiar por el applicationId real de la app
                  userAgentPackageName: 'com.example.huellapp',
                ),
                if (_punto != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _punto!,
                        width: MarcadorRefugio.ancho,
                        height: MarcadorRefugio.alto,
                        alignment: Alignment.topCenter,
                        child: const MarcadorRefugio(),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _buscando ? null : _usarMiUbicacion,
                icon: _buscando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Usar mi ubicación actual'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turquoise,
                  foregroundColor: _textColor,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (!sinPin) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Quitar el pin',
                onPressed: _quitar,
                icon: const Icon(Icons.delete_outline, color: _accent),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (_mensaje != null)
          Text(
            _mensaje!,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          )
        else if (error)
          Text(
            widget.textoError,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          )
        else if (!sinPin)
          Text(
            'Ubicación marcada: ${_punto!.latitude.toStringAsFixed(5)}, '
            '${_punto!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, color: _mutedColor),
          ),
      ],
    );
  }
}
