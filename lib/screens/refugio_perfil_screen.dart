import 'package:flutter/material.dart';
import 'package:huellapp/models/refugio.dart';
import 'package:huellapp/widgets/mascota_perfil_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Perfil de un refugio: fotos, descripción, horario, contacto, redes,
/// necesidades de donación y sus mascotas. Los datos los captura el refugio
/// desde su panel.
class RefugioPerfilScreen extends StatefulWidget {
  final Refugio refugio;

  /// Distancia desde la persona al refugio (si se conoce su ubicación).
  final double? distanciaKm;

  const RefugioPerfilScreen({
    super.key,
    required this.refugio,
    this.distanciaKm,
  });

  @override
  State<RefugioPerfilScreen> createState() => _RefugioPerfilScreenState();
}

class _RefugioPerfilScreenState extends State<RefugioPerfilScreen> {
  // Paleta turquesa de HuellApp
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _background = Color(0xFFE6F8F5);
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);

  static const double _anchoMaximo = 720;

  int _fotoActual = 0;

  Refugio get _r => widget.refugio;

  List<String> get _fotos => _r.fotos.isNotEmpty ? _r.fotos : [_r.imagenUrl];

  bool get _tieneUbicacion => _r.latitud != null && _r.longitud != null;

  // ---------- Acciones ----------

  String _soloDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _abrirUrl(Uri uri) async {
    bool abierto = false;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      abierto = false;
    }
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  Future<void> _llamar() =>
      _abrirUrl(Uri(scheme: 'tel', path: _soloDigitos(_r.contacto)));

  Future<void> _escribirWhatsapp() {
    final numero = _r.whatsapp.isNotEmpty ? _r.whatsapp : _r.contacto;
    var digitos = _soloDigitos(numero);
    if (digitos.length == 10) digitos = '52$digitos'; // Lada de México
    return _abrirUrl(Uri.parse('https://wa.me/$digitos'));
  }

  Future<void> _abrirRuta() => _abrirUrl(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_r.latitud},${_r.longitud}',
    ),
  );

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
          'Perfil del refugio',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFotos(),
              const SizedBox(height: 16),
              _buildEncabezado(),
              _seccion(
                'Sobre el refugio',
                Text(_r.descripcion, style: _cuerpo),
              ),
              _seccion(
                'Horario de visitas',
                _filaIcono(Icons.schedule, _r.horario),
              ),
              _seccion('Contacto', _buildContacto()),
              if (_r.redes.isNotEmpty)
                _seccion(
                  'Redes sociales',
                  Column(
                    children: [
                      for (final red in _r.redes) _filaIcono(Icons.public, red),
                    ],
                  ),
                ),
              if (_r.necesidades.isNotEmpty)
                _seccion(
                  'Necesidades de donación',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in _r.necesidades)
                        Chip(
                          avatar: const Icon(
                            Icons.volunteer_activism,
                            size: 16,
                            color: _accent,
                          ),
                          label: Text(n, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white,
                        ),
                    ],
                  ),
                ),
              _seccion(
                'Mascotas en adopción (${_r.mascotas.length})',
                _buildMascotas(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _tieneUbicacion
          ? Material(
              color: Colors.white,
              elevation: 8,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _anchoMaximo),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _abrirRuta,
                          icon: const Icon(Icons.directions),
                          label: const Text(
                            'Cómo llegar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  static const TextStyle _cuerpo = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: _textColor,
  );

  // Galería de fotos con indicador
  Widget _buildFotos() {
    final fotos = _fotos;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: fotos.length,
              onPageChanged: (i) => setState(() => _fotoActual = i),
              itemBuilder: (context, i) => Image.network(
                fotos[i],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _turquoise.withValues(alpha: 0.4),
                  child: const Icon(Icons.pets, size: 60, color: _accent),
                ),
              ),
            ),
            if (fotos.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < fotos.length; i++)
                      Container(
                        width: i == _fotoActual ? 18 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _fotoActual
                              ? Colors.white
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Nombre, ubicación, distancia y etiquetas
  Widget _buildEncabezado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _r.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
              ),
              const Tooltip(
                message: 'Refugio verificado',
                child: Icon(Icons.verified, color: Colors.blue, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _filaIcono(
            Icons.location_on,
            widget.distanciaKm == null
                ? _r.ubicacion
                : '${_r.ubicacion} · a ${widget.distanciaKm!.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_r.tienePerros) _etiqueta('Perros'),
              if (_r.tieneGatos) _etiqueta('Gatos'),
              if (_r.necesitaDonaciones) _etiqueta('Recibe donaciones'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _turquoise),
    ),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _accent,
      ),
    ),
  );

  Widget _buildContacto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filaIcono(Icons.phone, _r.contacto),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _llamar,
                icon: const Icon(Icons.call),
                label: const Text('Llamar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent, width: 1.5),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _escribirWhatsapp,
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
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
          ],
        ),
      ],
    );
  }

  // Lista horizontal de mascotas; al tocar una se abre su perfil
  Widget _buildMascotas() {
    if (_r.mascotas.isEmpty) {
      return const Text(
        'Este refugio aún no ha publicado mascotas.',
        style: TextStyle(color: _mutedColor),
      );
    }
    return SizedBox(
      height: 226,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _r.mascotas.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _tarjetaMascota(_r.mascotas[index]),
      ),
    );
  }

  Widget _tarjetaMascota(MascotaRefugio m) {
    return SizedBox(
      width: 156,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => mostrarPerfilMascota(
            context,
            m,
            _r.nombre,
            onCambio: () => setState(() {}),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: Image.network(
                      m.imagenPrincipal,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.pets, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white,
                      child: Icon(
                        m.esFavorito ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: m.esFavorito ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.tipo} · ${m.edad}',
                      style: const TextStyle(fontSize: 12, color: _mutedColor),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ver perfil',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Piezas reutilizables ----------

  Widget _seccion(String titulo, Widget contenido) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 10),
            contenido,
          ],
        ),
      ),
    );
  }

  Widget _filaIcono(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: _mutedColor),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: _cuerpo)),
        ],
      ),
    );
  }
}
