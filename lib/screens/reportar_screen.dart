import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:huellapp/core/api_client.dart';
import 'package:huellapp/core/api_config.dart';
import 'package:huellapp/core/requiere_sesion.dart';
import 'package:huellapp/screens/coincidencias_screen.dart';
import 'package:huellapp/screens/muro_huellapp_screen.dart';
import 'package:huellapp/services/comunidad_service.dart';
import 'package:huellapp/widgets/foto_huellapp.dart';
import 'package:huellapp/widgets/selector_ubicacion.dart';

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

  /// Primero se elige el camino: «Se me perdió» o «La encontré» (cada uno con su formulario).
  bool _eligio = false;

  // Datos de los formularios (iguales a los del sitio web)
  static const _colores = ['Negro', 'Blanco', 'Café', 'Gris', 'Dorado o amarillo', 'Naranja', 'Blanco y negro', 'Manchado o varios colores', 'Atigrado'];
  static const _tamanos = {'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'};
  static const _situaciones = {
    'conmigo': 'La tengo yo, está a salvo',
    'refugio': 'La llevé a un refugio o veterinaria',
    'vista': 'Solo la vi, no la pude resguardar',
  };
  String? _color;
  String? _tamano;
  String? _situacion;
  DateTime? _fecha;
  double? _latitud;
  double? _longitud;
  final TextEditingController _collarController = TextEditingController();
  // Seña secreta: solo «Se me perdió»; NUNCA se publica (sirve para verificar a quien diga que la encontró)
  final TextEditingController _senaController = TextEditingController();

  final TextEditingController _nombreMascotaController =
      TextEditingController();
  final TextEditingController _razaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  Uint8List? _imagenBytes;
  final ImagePicker _picker = ImagePicker();

  // 👈 NUEVO: Estado de carga nativo sin modales congelados
  bool _estaCargando = false;

  // Mensajes mientras se publica (la IA revisa la foto después, en segundo plano)
  static const _etapasAnalisis = [
    'Subiendo la foto…',
    'Publicando tu alerta en el muro…',
    'Buscando coincidencias por descripción y zona…',
  ];
  int _etapa = 0;
  Timer? _relojEtapas;

  void _iniciarAnalisis() {
    _relojEtapas?.cancel();
    setState(() {
      _estaCargando = true;
      _etapa = 0;
    });
    _relojEtapas = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && _etapa < _etapasAnalisis.length - 1) setState(() => _etapa++);
    });
  }

  void _terminarAnalisis() {
    _relojEtapas?.cancel();
    if (mounted) setState(() => _estaCargando = false);
  }

  _Paleta get _paleta =>
      _tipoReporte == 'Extraviada' ? _paletaBusca : _paletaEncontre;

  @override
  void dispose() {
    _relojEtapas?.cancel();
    _nombreMascotaController.dispose();
    _razaController.dispose();
    _ubicacionController.dispose();
    _collarController.dispose();
    _senaController.dispose();
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
    if (_tipoReporte != 'Extraviada' && _situacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cuéntanos dónde está ahora la mascota.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

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

    _iniciarAnalisis();

    // La API pide una sola descripción: se arma con la raza y las señas
    final raza = _razaController.text.trim();
    final senas = _descripcionController.text.trim();
    var descripcion = [
      if (raza.isNotEmpty) '$_tipoMascota $raza.',
      if (senas.isNotEmpty) senas,
    ].join(' ');
    if (descripcion.length < 15) descripcion = '$descripcion (sin más señas)';

    final tipo = _tipoReporte == 'Extraviada' ? 'perdida' : 'encontrada';
    Future<ResultadoReporte> enviar({String? fotoGuardada, bool confirmar = false}) =>
        ComunidadService.instancia.crearReporte(
          tipo: tipo,
          descripcion: descripcion.length > 600 ? descripcion.substring(0, 600) : descripcion,
          zona: _ubicacionController.text.trim(),
          foto: _imagenBytes!,
          especie: switch (_tipoMascota) { 'Perro' => 'perro', 'Gato' => 'gato', _ => 'otro' },
          nombre: tipo == 'perdida' ? _nombreMascotaController.text : '',
          color: _color,
          tamano: _tamano,
          collar: _collarController.text,
          fecha: _fecha,
          situacion: tipo == 'encontrada' ? _situacion : null,
          latitud: _latitud,
          longitud: _longitud,
          senaSecreta: tipo == 'perdida' ? _senaController.text : '',
          fotoGuardada: fotoGuardada,
          confirmarDuplicado: confirmar,
        );

    try {
      ResultadoReporte r;
      try {
        r = await enviar();
      } on ApiException catch (e) {
        // ¿Alguien ya reportó a esta mascota? La persona decide si es la misma o publica de todos modos
        if (e.codigo != 'posible-duplicado' || !mounted) rethrow;
        _terminarAnalisis();
        final duplicados = (e.datos['duplicados'] as List? ?? []).cast<Map<String, dynamic>>();
        final publicar = await _preguntarDuplicado(tipo, duplicados);
        if (!mounted) return;
        if (!publicar) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No publicamos tu reporte. Puedes comentar en la alerta que ya existe en el muro.'),
          ));
          return;
        }
        _iniciarAnalisis();
        r = await enviar(fotoGuardada: e.datos['foto'] as String?, confirmar: true);
      }
      if (!mounted) return;
      _terminarAnalisis();
      await _mostrarResultado(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      _terminarAnalisis();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
      );
    }
  }

  /// Reportes muy parecidos que ya existen (quizá de un familiar). true = publicar de todos modos.
  Future<bool> _preguntarDuplicado(String tipo, List<Map<String, dynamic>> duplicados) async {
    final publicar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Ya reportaron a esta mascota?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tipo == 'perdida'
                  ? 'Encontramos una alerta muy parecida (quizá la subió un familiar). Si es la misma mascota, '
                      'no hace falta otra: comenta en esa alerta del muro.'
                  : 'Alguien ya reportó haber encontrado a una mascota muy parecida. Si es la misma, comenta en esa alerta del muro.'),
              const SizedBox(height: 12),
              for (final d in duplicados)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((d['foto'] as String? ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FotoHuellApp(ApiConfig.urlArchivo(d['foto'] as String), width: 72, height: 72),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          (d['nombre'] as String?)?.isNotEmpty == true
                              ? '${d['nombre']}'
                              : (d['tipo'] == 'perdida' ? 'Mascota perdida' : 'Mascota encontrada'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${d['descripcion'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        Text('Zona: ${d['zona'] ?? ''} · Reportó ${d['autor'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Es otra, publicar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Es la misma, no publicar')),
        ],
      ),
    );
    return publicar ?? false;
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
                    ? 'Tu alerta ya está en el muro. Por la descripción hay ${r.coincidenciasNuevas == 1 ? '1 mascota parecida' : '${r.coincidenciasNuevas} mascotas parecidas'} en los reportes de la comunidad.'
                    : 'Tu alerta ya está en el muro. Te avisaremos en «Coincidencias» si aparece una mascota parecida.',
              ),
              if (r.iaPendiente) ...[
                const SizedBox(height: 12),
                const Text(
                  '🤖 La IA está revisando la foto y comparándola con otros reportes. '
                  'En uno o dos minutos verás el resultado en «Coincidencias».',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
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
    if (!_eligio) return _pantallaEleccion();

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: darkBorderColor),
                      const SizedBox(height: 16),
                      Text(
                        _etapasAnalisis[_etapa],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkBorderColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Solo unos segundos. La IA revisará la foto después.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
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

  /// Paso 0: dos caminos claros, cada uno con su propio formulario.
  Widget _pantallaEleccion() {
    Widget opcion(String valor, String emoji, String titulo, String texto, _Paleta color) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: color.suave,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                _tipoReporte = valor;
                _eligio = true;
              }),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.oscuro, width: 1.5),
                ),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color.oscuro)),
                      const SizedBox(height: 4),
                      Text(texto, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: color.oscuro),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximo),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),
                const Text('¿Qué pasó?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: darkBorderColor)),
                const SizedBox(height: 6),
                const Text('Elige una opción para llenar el formulario correcto.', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                opcion('Extraviada', '🔎', 'Se me perdió mi mascota', 'Publica una alerta para que la comunidad te ayude a buscarla.', _paletaBusca),
                opcion('Avistamiento', '🏠', 'Encontré una mascota', 'Ayúdale a volver con su familia.', _paletaEncontre),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha ?? ahora,
      firstDate: ahora.subtract(const Duration(days: 365)),
      lastDate: ahora,
      helpText: _tipoReporte == 'Extraviada' ? '¿Cuándo se perdió?' : '¿Cuándo la viste?',
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fecha ?? ahora));
    if (!mounted) return;
    var elegida = DateTime(dia.year, dia.month, dia.day, hora?.hour ?? 12, hora?.minute ?? 0);
    if (elegida.isAfter(ahora)) elegida = ahora; // no puede ser futura
    setState(() => _fecha = elegida);
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
        // Solo «Se me perdió» pide nombre (quien la encontró no lo sabe)
        if (_tipoReporte == 'Extraviada')
          TextFormField(
            controller: _nombreMascotaController,
            decoration: _inputDecoration('Nombre de tu mascota', Icons.pets),
          ),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _color,
              isExpanded: true,
              decoration: _inputDecoration('Color', Icons.palette_outlined),
              items: [for (final c in _colores) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _color = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _tamano,
              isExpanded: true,
              decoration: _inputDecoration('Tamaño', Icons.straighten),
              items: [for (final e in _tamanos.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _tamano = v),
            ),
          ),
        ]),
        TextFormField(
          controller: _collarController,
          decoration: _inputDecoration(
            _tipoReporte == 'Extraviada' ? 'Collar, placa o chip' : '¿Trae collar o placa? ¿Cómo es?',
            Icons.local_offer_outlined,
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
        if (_tipoReporte == 'Extraviada')
          TextFormField(
            controller: _senaController,
            maxLength: 200,
            decoration: _inputDecoration('🔒 Seña secreta (opcional, no se publica)', Icons.lock_outline).copyWith(
              helperText: 'Un detalle que no se vea en la foto. Si alguien dice que la encontró, '
                  'le pediremos describirlo antes de darle tus datos.',
              helperMaxLines: 3,
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
        // Punto en el mapa: las coincidencias se buscan por distancia real (opcional pero recomendado)
        SelectorUbicacion(
          latitud: _latitud,
          longitud: _longitud,
          titulo: _tipoReporte == 'Extraviada' ? 'Marca dónde se perdió (recomendado)' : 'Marca dónde la encontraste (recomendado)',
          descripcion: 'Toca el mapa para colocar el pin o usa tu ubicación actual. '
              'Así encontramos coincidencias cercanas.',
          onCambio: (punto) => setState(() {
            _latitud = punto?.latitude;
            _longitud = punto?.longitude;
          }),
        ),
        OutlinedButton.icon(
          onPressed: _elegirFecha,
          icon: const Icon(Icons.event),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
          label: Text(
            _fecha == null
                ? (_tipoReporte == 'Extraviada' ? '¿Cuándo se perdió? (opcional)' : '¿Cuándo la viste? (opcional)')
                : '${_tipoReporte == 'Extraviada' ? 'Se perdió' : 'La viste'}: '
                    '${_fecha!.day.toString().padLeft(2, '0')}/${_fecha!.month.toString().padLeft(2, '0')}/${_fecha!.year} '
                    '${_fecha!.hour.toString().padLeft(2, '0')}:${_fecha!.minute.toString().padLeft(2, '0')}',
          ),
        ),
        // Solo «La encontré»: dónde está ahora la mascota
        if (_tipoReporte != 'Extraviada') ...[
          const Text('¿Dónde está ahora la mascota?', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioGroup<String>(
            groupValue: _situacion,
            onChanged: (v) => setState(() => _situacion = v),
            child: Column(children: [
              for (final e in _situaciones.entries)
                RadioListTile<String>(value: e.key, title: Text(e.value), dense: true, contentPadding: EdgeInsets.zero),
            ]),
          ),
        ],
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
