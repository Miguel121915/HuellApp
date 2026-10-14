import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:huellapp/data/refugios_data.dart';
import 'package:huellapp/models/refugio.dart';
import 'package:huellapp/screens/refugio_perfil_screen.dart';
import 'package:huellapp/widgets/marcador_refugio.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mapa de refugios cercanos.
/// - Celular: el mapa arriba y la lista abajo.
/// - Web / pantalla ancha: la lista a la izquierda y el mapa a la derecha.
class RefugiosCercanosScreen extends StatefulWidget {
  const RefugiosCercanosScreen({super.key});

  @override
  State<RefugiosCercanosScreen> createState() => _RefugiosCercanosScreenState();
}

class _RefugiosCercanosScreenState extends State<RefugiosCercanosScreen> {
  // Paleta turquesa de HuellApp
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _background = Color(0xFFE6F8F5);
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);

  // A partir de este ancho se usa el diseño de dos columnas (web / tablet)
  static const double _anchoEscritorio = 800;

  final MapController _mapController = MapController();
  bool _mapaListo = false;
  LatLng? _centroPendiente;
  double _zoomPendiente = 12;
  bool _ajustarAlListo = false;

  LatLng? _miUbicacion;
  bool _cargando = true;
  String? _error;
  double? _radioKm = 25; // null = sin límite
  Refugio? _seleccionado;

  // Distancia en km de la persona a cada refugio (por id)
  final Map<String, double> _distancias = {};

  // Solo los refugios que ya tienen coordenadas
  List<Refugio> get _refugios => listaRefugios
      .where((r) => r.latitud != null && r.longitud != null)
      .toList();

  LatLng _punto(Refugio r) => LatLng(r.latitud!, r.longitud!);
  double? _distanciaDe(Refugio r) => _distancias[r.id];

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ---------- Mapa ----------

  /// Mueve el mapa. Si todavía no está listo, lo deja pendiente.
  void _centrar(LatLng punto, double zoom) {
    if (_mapaListo) {
      _mapController.move(punto, zoom);
    } else {
      _centroPendiente = punto;
      _zoomPendiente = zoom;
    }
  }

  /// Acerca o aleja el mapa para que se vean la persona y los refugios
  /// del radio elegido.
  void _ajustarVista() {
    final puntos = <LatLng>[
      if (_miUbicacion != null) _miUbicacion!,
      for (final r in _visibles) _punto(r),
    ];
    if (puntos.isEmpty) return;
    if (puntos.length == 1) {
      _centrar(puntos.first, 14);
      return;
    }
    if (!_mapaListo) {
      _ajustarAlListo = true;
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(puntos),
        padding: const EdgeInsets.all(56),
        maxZoom: 15,
      ),
    );
  }

  // ---------- Ubicación de la persona ----------

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        throw 'Activa la ubicación (GPS) de tu dispositivo.';
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        throw 'Necesitamos tu permiso para mostrar los refugios cercanos.';
      }
      if (permiso == LocationPermission.deniedForever) {
        throw 'El permiso de ubicación está bloqueado. '
            'Actívalo en los ajustes de la app o del navegador.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final miPunto = LatLng(pos.latitude, pos.longitude);
      for (final r in _refugios) {
        _distancias[r.id] =
            Geolocator.distanceBetween(
              miPunto.latitude,
              miPunto.longitude,
              r.latitud!,
              r.longitud!,
            ) /
            1000;
      }

      if (!mounted) return;
      setState(() {
        _miUbicacion = miPunto;
        _cargando = false;
      });
      _ajustarVista();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is String ? e : 'No pudimos obtener tu ubicación.';
        _cargando = false;
      });
      _ajustarVista();
    }
  }

  /// Refugios dentro del radio elegido, del más cercano al más lejano.
  List<Refugio> get _visibles {
    final lista = _refugios.where((r) {
      if (_miUbicacion == null || _radioKm == null) return true;
      return (_distanciaDe(r) ?? 0) <= _radioKm!;
    }).toList();

    if (_miUbicacion != null) {
      lista.sort(
        (a, b) => (_distanciaDe(a) ?? 0).compareTo(_distanciaDe(b) ?? 0),
      );
    }
    return lista;
  }

  String _textoDistancia(Refugio r) {
    final d = _distanciaDe(r);
    return d == null
        ? r.ubicacion
        : '${r.ubicacion} · a ${d.toStringAsFixed(1)} km';
  }

  // ---------- Acciones ----------

  void _seleccionar(Refugio r) {
    setState(() => _seleccionado = r);
    _centrar(_punto(r), 15);
    _mostrarDetalle(r);
  }

  Future<void> _abrirRuta(Refugio r) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${r.latitud},${r.longitud}',
    );
    bool abierto = false;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      abierto = false;
    }
    if (!abierto && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el mapa')));
    }
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _turquoise,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textColor),
        title: const Text(
          'Refugios cerca de ti',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final visibles = _visibles;

          if (constraints.maxWidth >= _anchoEscritorio) {
            // Web / pantalla ancha: lista a la izquierda, mapa a la derecha
            return Row(
              children: [
                SizedBox(width: 400, child: _buildPanel(visibles)),
                Expanded(child: _buildMapa(visibles)),
              ],
            );
          }

          // Celular: mapa arriba, lista abajo
          return Column(
            children: [
              Expanded(flex: 5, child: _buildMapa(visibles)),
              Expanded(flex: 5, child: _buildPanel(visibles)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapa(List<Refugio> visibles) {
    final refugios = _refugios;
    final centroInicial =
        _miUbicacion ??
        (refugios.isNotEmpty
            ? _punto(refugios.first)
            : const LatLng(19.4326, -99.1332)); // Respaldo: centro de CDMX

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centroInicial,
            initialZoom: 12,
            onMapReady: () {
              _mapaListo = true;
              final pendiente = _centroPendiente;
              if (pendiente != null) {
                _mapController.move(pendiente, _zoomPendiente);
                _centroPendiente = null;
              }
              if (_ajustarAlListo) {
                _ajustarAlListo = false;
                _ajustarVista();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // Cambiar por el applicationId real de la app
              userAgentPackageName: 'com.example.huellapp',
            ),
            MarkerLayer(
              markers: [
                for (final r in visibles)
                  Marker(
                    point: _punto(r),
                    width: MarcadorRefugio.ancho,
                    height: MarcadorRefugio.alto,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _seleccionar(r),
                      child: MarcadorRefugio(
                        seleccionado: _seleccionado?.id == r.id,
                      ),
                    ),
                  ),
                if (_miUbicacion != null)
                  Marker(
                    point: _miUbicacion!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
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
        if (_cargando)
          const Positioned(
            top: 12,
            left: 12,
            child: Chip(
              avatar: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Buscando tu ubicación...'),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 28,
          child: FloatingActionButton.small(
            tooltip: 'Ir a mi ubicación',
            backgroundColor: _turquoise,
            foregroundColor: _textColor,
            onPressed: () {
              final mia = _miUbicacion;
              if (mia != null) {
                _centrar(mia, 14);
              } else {
                _obtenerUbicacion();
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(List<Refugio> visibles) {
    return Container(
      color: _background,
      child: Column(
        children: [
          // Aviso si no hay ubicación
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_off, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: _obtenerUbicacion,
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(color: _accent),
                    ),
                  ),
                ],
              ),
            ),

          // Filtro por distancia
          if (_miUbicacion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final km in <double?>[5, 10, 25, null])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            km == null ? 'Todos' : '${km.toInt()} km',
                          ),
                          selected: _radioKm == km,
                          selectedColor: _turquoise,
                          onSelected: (_) {
                            setState(() => _radioKm = km);
                            _ajustarVista();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Lista
          Expanded(
            child: visibles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No hay refugios en este radio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _mutedColor),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _radioKm = null);
                              _ajustarVista();
                            },
                            child: const Text(
                              'Ver todos',
                              style: TextStyle(color: _accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: visibles.length,
                    itemBuilder: (context, index) =>
                        _buildTarjeta(visibles[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjeta(Refugio r) {
    final seleccionado = _seleccionado?.id == r.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: seleccionado ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: seleccionado ? _accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: () => _seleccionar(r),
        leading: const CircleAvatar(
          backgroundColor: _turquoise,
          foregroundColor: _textColor,
          child: Icon(Icons.pets),
        ),
        title: Text(
          r.nombre,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(_textoDistancia(r)),
        trailing: IconButton(
          tooltip: 'Cómo llegar',
          icon: const Icon(Icons.directions, color: _accent),
          onPressed: () => _abrirRuta(r),
        ),
      ),
    );
  }

  void _mostrarDetalle(Refugio r) {
    showModalBottomSheet(
      context: context,
      // En pantallas anchas la hoja no se estira a todo el ancho
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _textoDistancia(r),
              style: const TextStyle(color: _mutedColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: _mutedColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.horario,
                    style: const TextStyle(fontSize: 13, color: _mutedColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.pets, size: 18, color: _mutedColor),
                const SizedBox(width: 6),
                Text(
                  '${r.totalMascotas} mascotas',
                  style: const TextStyle(fontSize: 13, color: _mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder: (context) => RefugioPerfilScreen(
                        refugio: r,
                        distanciaKm: _distanciaDe(r),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text(
                  'Ver perfil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turquoise,
                  foregroundColor: _textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _abrirRuta(r);
                },
                icon: const Icon(Icons.directions),
                label: const Text(
                  'Cómo llegar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
