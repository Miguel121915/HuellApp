import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:huellapp/core/api_client.dart';
import 'package:huellapp/core/requiere_sesion.dart';
import 'package:huellapp/screens/coincidencias_screen.dart';
import 'package:huellapp/screens/muro_huellapp_screen.dart';
import 'package:huellapp/services/comunidad_service.dart';

/// Colores que cambian según el tipo de reporte
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
  String _tipoMascota = 'Perro';

  final TextEditingController _nombreMascotaController =
      TextEditingController();
  final TextEditingController _razaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  Uint8List? _imagenBytes;
  final ImagePicker _picker = ImagePicker();

  // 👈 NUEVO: Estado de carga nativo sin modales congelados
  bool _estaCargando = false;

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

  Future<void> _seleccionarImagen(ImageSource source) async {
    // Se reduce la foto: la API acepta hasta 3 MB y así la IA responde más rápido
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
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

  void _enviarReporte() async {
    if (!await requiereSesion(context, 'reportar una mascota')) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

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

    setState(() => _estaCargando = true);

    // La API pide una sola descripción: se arma con la raza y las señas
    final raza = _razaController.text.trim();
    final senas = _descripcionController.text.trim();
    var descripcion = [
      if (raza.isNotEmpty) '$_tipoMascota $raza.',
      if (senas.isNotEmpty) senas,
    ].join(' ');
    if (descripcion.length < 15) descripcion = '$descripcion (sin más señas)';

    try {
      final r = await ComunidadService.instancia.crearReporte(
        tipo: _tipoReporte == 'Extraviada' ? 'perdida' : 'encontrada',
        descripcion: descripcion.length > 600 ? descripcion.substring(0, 600) : descripcion,
        zona: _ubicacionController.text.trim(),
        foto: _imagenBytes!,
        especie: switch (_tipoMascota) { 'Perro' => 'perro', 'Gato' => 'gato', _ => 'otro' },
        nombre: _nombreMascotaController.text,
      );
      if (!mounted) return;
      setState(() => _estaCargando = false);
      await _mostrarResultado(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
      );
    }
  }

  /// Resultado del reporte: lo que vio la IA y cuántas coincidencias hubo.
  Future<void> _mostrarResultado(ResultadoReporte r) async {
    final a = r.analisis;
    final hay = r.coincidenciasNuevas > 0;
    String rasgo(String clave) => (a?[clave] as String? ?? '').trim();
    final rasgos = a == null
        ? <String>[]
        : [
            if (rasgo('raza').isNotEmpty) 'Raza: ${rasgo('raza')}',
            if (rasgo('color').isNotEmpty) 'Color: ${rasgo('color')}',
            if (rasgo('tamano').isNotEmpty) 'Tamaño: ${rasgo('tamano')}',
            if (rasgo('senas').isNotEmpty) 'Señas: ${rasgo('senas')}',
          ];

    final destino = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hay ? '¡Encontramos posibles coincidencias!' : '¡Alerta publicada!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hay
                    ? 'Hay ${r.coincidenciasNuevas == 1 ? '1 mascota parecida' : '${r.coincidenciasNuevas} mascotas parecidas'} en los reportes de la comunidad.'
                    : 'Tu alerta ya está en el muro. Te avisaremos en «Coincidencias» si aparece una mascota parecida.',
              ),
              if (rasgos.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Row(children: [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF5C4300)),
                  SizedBox(width: 6),
                  Text('Lo que detectó la IA', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                ...rasgos.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $t', style: const TextStyle(fontSize: 13)),
                    )),
              ] else if (!r.iaUsada) ...[
                const SizedBox(height: 10),
                const Text(
                  'La IA no estuvo disponible: comparamos por descripción y zona.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'muro'), child: const Text('Ver en el muro')),
          if (hay)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'coincidencias'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryTurquoise, foregroundColor: darkBorderColor),
              child: const Text('Ver coincidencias'),
            ),
        ],
      ),
    );
    if (!mounted) return;

    _formKey.currentState?.reset();
    _nombreMascotaController.clear();
    _razaController.clear();
    _descripcionController.clear();
    _ubicacionController.clear();
    setState(() => _imagenBytes = null);

    if (destino == 'coincidencias') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CoincidenciasScreen()));
    } else if (destino == 'muro') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MuroHuellAppScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paleta;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: Stack(
        children: [
          SingleChildScrollView(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: p.oscuro, width: 1.5),
                                ),
                              ),
                              onPressed: _estaCargando ? null : _enviarReporte,
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

          // 👈 NUEVO: Overlay de carga limpio centrado en pantalla
          if (_estaCargando)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: darkBorderColor),
                      SizedBox(height: 16),
                      Text(
                        'La IA está analizando la foto y buscando coincidencias…\nPuede tardar unos segundos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkBorderColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
                    children: const [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: darkBorderColor,
                      ),
                      SizedBox(height: 8),
                      Text(
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
