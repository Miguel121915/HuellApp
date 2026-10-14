import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Colores que cambian según el tipo de reporte:
/// ámbar cuando se busca una mascota y verde cuando se encontró.
class _Paleta {
  final Color principal;
  final Color suave;
  final Color fondoBanner;
  final Color mancha;
  final Color oscuro;
  final String titulo;
  final String subtitulo;
  final String donde;
  final String zona;

  const _Paleta({
    required this.principal,
    required this.suave,
    required this.fondoBanner,
    required this.mancha,
    required this.oscuro,
    required this.titulo,
    required this.subtitulo,
    required this.donde,
    required this.zona,
  });
}

const _Paleta _paletaBusca = _Paleta(
  principal: Color(0xFFFFC83D),
  suave: Color(0xFFFFF1C7),
  fondoBanner: Color(0xFFFFE9A8),
  mancha: Color(0xFFFFD76A),
  oscuro: Color(0xFF4A3500),
  titulo: '¡Ayúdanos a encontrarlo!',
  subtitulo: 'Sube una foto y buscamos parecidos en los reportes activos.',
  donde: '¿Dónde fue?',
  zona: 'Zona o colonia del extravío',
);

const _Paleta _paletaEncontre = _Paleta(
  principal: Color(0xFF3DBE8B),
  suave: Color(0xFFD8F5E7),
  fondoBanner: Color(0xFFCDF3E1),
  mancha: Color(0xFFA9E6CB),
  oscuro: Color(0xFF0B3D2A),
  titulo: '¡Gracias por ayudar!',
  subtitulo:
      'Sube una foto y buscamos a su familia entre los reportes activos.',
  donde: '¿Dónde la viste?',
  zona: 'Zona o colonia del avistamiento',
);

class ReportarScreen extends StatefulWidget {
  const ReportarScreen({super.key});

  @override
  State<ReportarScreen> createState() => _ReportarScreenState();
}

class _ReportarScreenState extends State<ReportarScreen> {
  static const Color primaryTurquoise = Color(0xFF75E6DA);
  static const Color darkBorderColor = Color(0xFF1B4943);
  static const Color backgroundLight = Color(0xFFE8F9F8);
  static const double _anchoMaximo = 640;

  final _formKey = GlobalKey<FormState>();

  String _tipoReporte = 'Extraviada';

  // Tipo de mascota seleccionado (Perro, Gato u Otro)
  String _tipoMascota = 'Perro';

  final TextEditingController _nombreMascotaController =
      TextEditingController();
  final TextEditingController _razaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  // Guardamos los bytes de la imagen para compatibilidad total con Web y Móvil
  Uint8List? _imagenBytes;
  final ImagePicker _picker = ImagePicker();

  _Paleta get _paleta =>
      _tipoReporte == 'Extraviada' ? _paletaBusca : _paletaEncontre;

  @override
  void dispose() {
    _nombreMascotaController.dispose();
    _razaController.dispose();
    _ubicacionController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // Método universal compatible con Web y App nativa
  Future<void> _seleccionarImagen(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
      });
    }
  }

  void _elegirOrigenFoto() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar fotografía'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _enviarReporte() {
    if (_formKey.currentState!.validate()) {
      if (_imagenBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por favor, añade una foto de la mascota para el análisis de IA',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: darkBorderColor),
              SizedBox(height: 16),
              Text(
                'Analizando imagen con IA y generando alerta...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Reporte creado con éxito! Se han buscado coincidencias.',
            ),
            backgroundColor: darkBorderColor,
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _imagenBytes = null;
          _tipoMascota = 'Perro';
          _nombreMascotaController.clear();
          _razaController.clear();
          _ubicacionController.clear();
          _descripcionController.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paleta;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximo),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBanner(p),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFoto(p),
                        const SizedBox(height: 20),
                        _buildDatos(p),
                        const SizedBox(height: 20),
                        _buildLugar(p),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.principal,
                            foregroundColor: p.oscuro,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: p.oscuro, width: 1.5),
                            ),
                          ),
                          onPressed: _enviarReporte,
                          child: const Text(
                            'Generar Alerta y Buscar Coincidencias',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Banner superior dinámico con estilo de radar/mascota
  Widget _buildBanner(_Paleta p) {
    return Container(
      height: 226,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.fondoBanner,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: p.mancha,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: 190,
            height: 150,
            child: CustomPaint(painter: _RadarPainter()),
          ),
          Positioned(
            right: 38,
            top: 38,
            child: Text(
              _tipoMascota == 'Gato'
                  ? '🐱'
                  : (_tipoMascota == 'Perro' ? '🐶' : '🐾'),
              style: const TextStyle(fontSize: 76),
            ),
          ),
          Positioned(
            left: 20,
            top: 22,
            right: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.titulo,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    color: p.oscuro,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.subtitulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: p.oscuro,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _segmento(
                    'Extraviada',
                    'Se busca',
                    Icons.search,
                    _paletaBusca,
                  ),
                  _segmento(
                    'Avistamiento',
                    'La encontré',
                    Icons.pets,
                    _paletaEncontre,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmento(String valor, String texto, IconData icono, _Paleta color) {
    final activo = _tipoReporte == valor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: activo,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => _tipoReporte = valor),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: activo ? color.principal : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: activo
                  ? const [
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icono,
                  size: 20,
                  color: activo ? color.oscuro : darkBorderColor,
                ),
                const SizedBox(width: 8),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: activo ? color.oscuro : darkBorderColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Sección de la Tarjeta de Foto
  Widget _buildFoto(_Paleta p) {
    return _tarjeta(
      encabezado: _encabezado(
        p,
        Icons.add_a_photo_outlined,
        'Foto de la mascota',
        extra: _etiquetaIA(),
      ),
      hijos: [
        GestureDetector(
          onTap: _elegirOrigenFoto,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: darkBorderColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: _imagenBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_imagenBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: darkBorderColor,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toca aquí para subir foto de la mascota',
                        style: TextStyle(
                          color: darkBorderColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _consejo(p, 'De frente'),
            _consejo(p, 'Buena luz'),
            _consejo(p, 'Sin filtros'),
          ],
        ),
        const Text(
          'Sube una fotografía clara. Nuestra inteligencia artificial analizará los rasgos para buscar similitudes en reportes activos.',
          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _consejo(_Paleta p, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.suave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: darkBorderColor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _etiquetaIA() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9A8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: Color(0xFF5C4300)),
          SizedBox(width: 4),
          Text(
            'IA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5C4300),
            ),
          ),
        ],
      ),
    );
  }

  // Sección de Datos de la Mascota
  Widget _buildDatos(_Paleta p) {
    return _tarjeta(
      encabezado: _encabezado(p, Icons.pets, 'Sobre la mascota'),
      hijos: [
        Row(
          children: [
            _chipTipo(p, 'Perro', '🐶'),
            const SizedBox(width: 8),
            _chipTipo(p, 'Gato', '🐱'),
            const SizedBox(width: 8),
            _chipTipo(p, 'Otro', '🐾'),
          ],
        ),
        TextFormField(
          controller: _nombreMascotaController,
          decoration: _inputDecoration(
            'Nombre de la mascota (si lo sabes)',
            Icons.pets,
          ),
        ),
        TextFormField(
          controller: _razaController,
          decoration: _inputDecoration(
            'Raza o tipo estimado (ej. Labrador, Mestizo)',
            Icons.category_outlined,
          ),
          validator: (v) => v == null || v.isEmpty
              ? 'Indica una raza o tipo aproximado'
              : null,
        ),
        TextFormField(
          controller: _descripcionController,
          maxLines: 3,
          decoration: _inputDecoration(
            'Señas particulares (color de collar, manchas, cicatrices...)',
            Icons.description_outlined,
          ),
        ),
      ],
    );
  }

  Widget _chipTipo(_Paleta p, String valor, String emoji) {
    final activo = _tipoMascota == valor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: activo,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () => setState(() => _tipoMascota = valor),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: activo ? p.suave : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: activo ? darkBorderColor : const Color(0xFFCFEAE5),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: activo ? darkBorderColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Sección de Ubicación
  Widget _buildLugar(_Paleta p) {
    return _tarjeta(
      encabezado: _encabezado(p, Icons.location_on_outlined, p.donde),
      hijos: [
        TextFormField(
          controller: _ubicacionController,
          decoration: _inputDecoration(p.zona, Icons.location_on_outlined),
          validator: (v) =>
              v == null || v.isEmpty ? 'Indica la ubicación' : null,
        ),
      ],
    );
  }

  // Widgets auxiliares para mantener limpia y modular la interfaz
  Widget _tarjeta({required Widget encabezado, required List<Widget> hijos}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          encabezado,
          const SizedBox(height: 14),
          ...hijos
              .expand((child) => [child, const SizedBox(height: 14)])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _encabezado(
    _Paleta p,
    IconData icono,
    String titulo, {
    Widget? extra,
  }) {
    return Row(
      children: [
        Icon(icono, size: 22, color: darkBorderColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkBorderColor,
            ),
          ),
        ),
        if (extra != null) extra,
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
      prefixIcon: Icon(icon, color: darkBorderColor),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: darkBorderColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorderColor, width: 1.5),
      ),
    );
  }
}

// Pintor decorativo para los círculos de radar en el banner
class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width * 0.8, size.height * 0.5);
    canvas.drawCircle(center, 30, paint);
    canvas.drawCircle(center, 65, paint);
    canvas.drawCircle(center, 100, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
