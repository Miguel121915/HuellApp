import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:huellapp/core/api_client.dart';
import 'package:huellapp/core/geocodificar.dart';
import 'package:huellapp/services/refugio_service.dart';
import 'package:huellapp/widgets/selector_ubicacion.dart';
import 'package:latlong2/latlong.dart';

class RegisterShelterScreen extends StatefulWidget {
  const RegisterShelterScreen({super.key});

  @override
  State<RegisterShelterScreen> createState() => _RegisterShelterScreenState();
}

class _RegisterShelterScreenState extends State<RegisterShelterScreen> {
  // Paleta turquesa de HuellApp
  static const Color _accent = Color(
    0xFF1B4F4A,
  ); // Verde oscuro: botones y enlaces
  static const Color _turquoise = Color(0xFF75E6DA); // Turquesa de la app
  static const Color _background = Color(0xFFE6F8F5); // Menta claro
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);
  static const Color _borderColor = Color(0xFF9ED9D1);

  static const int _totalSteps = 7;
  static const List<String> _stepTitles = [
    'Datos del refugio',
    'Datos del responsable',
    'Ubicación',
    'Información de animales',
    'Contacto y redes',
    'Comprobante de refugio',
    'Aceptación y envío',
  ];

  int _currentStep = 0;

  // Valida solo los campos de la etapa que se está mostrando
  final _formKey = GlobalKey<FormState>();

  // 1. Datos del refugio
  final _shelterNameController = TextEditingController();
  String _orgType = 'Refugio Independiente';
  final _rfcController = TextEditingController();
  final _foundationYearController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 2. Datos del responsable
  final _repNameController = TextEditingController();
  final _repRoleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // 3. Ubicación
  final _addressController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _scheduleController = TextEditingController();

  // 4. Información de los animales
  final _capacityController = TextEditingController();
  final _currentAnimalsController = TextEditingController();
  bool _attendsDogs = true;
  bool _attendsCats = true;
  bool _attendsOthers = false;
  bool _providesHealthCare = true; // Esterilización, vacunas, desparasitación

  // 5. Contacto y redes
  final _publicContactController = TextEditingController();
  final _socialsController = TextEditingController();

  // 6. Documento que avale
  // Documentos que pide la API (los mismos que en el sitio web)
  static const List<(String, String, bool)> _documentosFormal = [
    ('acta', 'Acta constitutiva o constancia fiscal', true),
    ('domicilio', 'Comprobante de domicilio', true),
    ('identificacion', 'Identificación del responsable', true),
    ('permiso', 'Permiso municipal o de refugio (opcional)', false),
  ];
  // Rescatista independiente (sin acta): en lugar del acta, fotos del lugar donde tiene a los animales
  static const List<(String, String, bool)> _documentosIndependiente = [
    ('identificacion', 'Identificación del responsable', true),
    ('domicilio', 'Comprobante de domicilio', true),
    ('lugar', 'Foto del lugar donde tienes a los animales', true),
    ('lugar2', 'Otra foto del lugar (opcional)', false),
  ];
  static const String _tipoIndependiente = 'Rescatista independiente';
  bool get _esIndependiente => _orgType == _tipoIndependiente;
  List<(String, String, bool)> get _tiposDocumento => _esIndependiente ? _documentosIndependiente : _documentosFormal;
  static const int _maxBytesDocumento = 5 * 1024 * 1024;
  final Map<String, ArchivoElegido> _documentos = {};
  bool _documentError = false;
  bool _enviando = false;

  // Ubicación en el mapa (para aparecer en "Refugios cerca de ti")
  double? _latitud;
  double? _longitud;
  bool _ubicacionError = false;
  // Dirección escrita ↔ mapa: aviso de lo que pasó y contador para descartar respuestas viejas
  String? _avisoUbicacion;
  int _consultaGeo = 0;
  bool get _hayUbicacion => _latitud != null && _longitud != null;

  // 7. Aceptación
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _declareTruth = false;

  @override
  void dispose() {
    _shelterNameController.dispose();
    _rfcController.dispose();
    _foundationYearController.dispose();
    _descriptionController.dispose();
    _repNameController.dispose();
    _repRoleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _municipalityController.dispose();
    _zipCodeController.dispose();
    _scheduleController.dispose();
    _capacityController.dispose();
    _currentAnimalsController.dispose();
    _publicContactController.dispose();
    _socialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si el teclado está abierto, se oculta el encabezado para dar espacio
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _turquoise,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'HuellApp',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 24,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Vuelve al Login
            child: const Text(
              'Inicia sesión',
              style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (!keyboardOpen) ...[
                    _buildAnimalsHeader(),
                    const SizedBox(height: 12),
                  ],
                  _buildProgress(),
                  const SizedBox(height: 12),

                  // Contenido de la etapa actual
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: _buildStepContent(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botones de navegación
                  Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _anterior,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accent,
                                side: const BorderSide(color: _accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Anterior'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _enviando ? null : _siguiente,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _turquoise,
                              foregroundColor: _textColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _enviando
                                  ? 'Enviando…'
                                  : _currentStep == _totalSteps - 1
                                      ? 'Enviar solicitud 🐾'
                                      : 'Siguiente',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Encabezado y progreso ----------

  /// Caritas de animales encimadas (perro, gato y cuyo).
  Widget _buildAnimalsHeader() {
    return SizedBox(
      width: 156,
      height: 64,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _animalAvatar('🐶', const Color(0xFFFFE3C7)),
          ),
          Positioned(
            left: 46,
            child: _animalAvatar('🐱', const Color(0xFFD8EEE6)),
          ),
          Positioned(
            left: 92,
            child: _animalAvatar('🐹', const Color(0xFFFFE4EA)),
          ),
        ],
      ),
    );
  }

  Widget _animalAvatar(String emoji, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso ${_currentStep + 1} de $_totalSteps',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _mutedColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _stepTitles[_currentStep],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            minHeight: 8,
            color: _accent,
            backgroundColor: const Color(0xFFCDEFEA),
          ),
        ),
      ],
    );
  }

  // ---------- Contenido de cada etapa ----------

  Widget _buildStepContent() {
    Widget content;
    switch (_currentStep) {
      case 0:
        content = _stepShelter();
        break;
      case 1:
        content = _stepRepresentative();
        break;
      case 2:
        content = _stepLocation();
        break;
      case 3:
        content = _stepAnimals();
        break;
      case 4:
        content = _stepContact();
        break;
      case 5:
        content = _stepDocument();
        break;
      default:
        content = _stepAcceptance();
    }
    // La key evita reutilizar el estado de los campos de otra etapa
    return KeyedSubtree(key: ValueKey(_currentStep), child: content);
  }

  // Etapa 1: Datos del refugio
  Widget _stepShelter() {
    return Column(
      children: [
        _buildTextField(
          _shelterNameController,
          'Nombre del Refugio',
          Icons.store,
          validator: (v) => _minimo(v, 3),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _orgType,
          decoration: _inputDecoration('Tipo de Organización', Icons.business),
          items: const [
            ('Asociación Civil', 'Asociación Civil'),
            ('Fundación', 'Fundación'),
            ('Refugio Independiente', 'Refugio Independiente'),
            ('Albergue Municipal', 'Albergue Municipal'),
            (_tipoIndependiente, 'Rescatista independiente (sin acta)'),
            ('Otro', 'Otro'),
          ].map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
          onChanged: (val) => setState(() {
            _orgType = val!;
            // Los documentos cambian según el tipo: se quitan los que ya no aplican
            final validos = _tiposDocumento.map((d) => d.$1).toSet();
            _documentos.removeWhere((tipo, _) => !validos.contains(tipo));
          }),
        ),
        if (_esIndependiente) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFDECB5), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              '🏠 Sin acta también puedes registrarte. En lugar del acta te pediremos tu identificación, '
              'un comprobante de domicilio, fotos del lugar donde tienes a los animales y al menos una red '
              'social o referencia de tu trabajo. Tu perfil mostrará la insignia «Rescatista independiente».',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: _textColor),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildTextField(
          _rfcController,
          'RFC (Opcional)',
          Icons.badge,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            return t.length < 12 || t.length > 13 ? 'El RFC tiene 12 o 13 caracteres' : null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _foundationYearController,
          'Año de Fundación (Opcional)',
          Icons.calendar_today,
          keyboardType: TextInputType.number,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final anio = int.tryParse(t);
            return anio == null || anio < 1900 || anio > DateTime.now().year ? 'Escribe un año válido' : null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _descriptionController,
          'Descripción breve y misión',
          Icons.description,
          maxLines: 3,
        ),
      ],
    );
  }

  // Etapa 2: Datos del responsable
  Widget _stepRepresentative() {
    return Column(
      children: [
        _buildTextField(
          _repNameController,
          'Nombre completo del representante',
          Icons.person,
          validator: (v) => _minimo(v, 3),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _repRoleController,
          'Cargo dentro del refugio',
          Icons.work,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _emailController,
          'Correo electrónico (Acceso)',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
            if (!v.contains('@') || !v.contains('.')) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _phoneController,
          'Teléfono del refugio',
          Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => _telefono(v, obligatorio: true),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _passwordController,
          'Contraseña',
          Icons.lock,
          isPassword: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Campo obligatorio';
            if (v.length < 8) return 'Mínimo 8 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _confirmPasswordController,
          'Confirmar contraseña',
          Icons.lock_outline,
          isPassword: _obscurePassword,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Campo obligatorio';
            if (v != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Marca en el mapa la dirección escrita (con municipio y CP si los hay).
  Future<void> _buscarDireccionEscrita() async {
    final calle = _addressController.text.trim();
    if (calle.length < 8) return;
    final id = ++_consultaGeo;
    setState(() => _avisoUbicacion = 'Buscando la dirección en el mapa…');
    final busqueda = [calle, _municipalityController.text.trim(), _zipCodeController.text.trim(), 'México']
        .where((t) => t.isNotEmpty)
        .join(', ');
    final punto = await Geocodificar.buscarDireccion(busqueda);
    if (!mounted || id != _consultaGeo) return;
    setState(() {
      if (punto == null) {
        _avisoUbicacion = 'No encontramos esa dirección en el mapa. Toca el lugar del refugio o usa tu ubicación actual.';
        return;
      }
      _latitud = punto.latitude;
      _longitud = punto.longitude;
      _ubicacionError = false;
      _avisoUbicacion = 'Marcamos la dirección en el mapa. Si no quedó exacta, toca el lugar correcto.';
    });
  }

  /// Al marcar con «Usar mi ubicación» o tocando el mapa: si no escribió dirección, se llena con la de ese punto.
  Future<void> _completarDireccion(LatLng punto) async {
    if (_addressController.text.trim().isNotEmpty) return;
    final id = ++_consultaGeo;
    setState(() => _avisoUbicacion = 'Buscando la dirección de ese punto…');
    final datos = await Geocodificar.direccionDe(punto);
    if (!mounted || id != _consultaGeo) return;
    setState(() {
      if (datos == null || datos.direccion.isEmpty) {
        _avisoUbicacion = null;
        return;
      }
      if (_addressController.text.trim().isEmpty) _addressController.text = datos.direccion;
      if (_municipalityController.text.trim().isEmpty) _municipalityController.text = datos.municipio;
      if (_zipCodeController.text.trim().isEmpty) _zipCodeController.text = datos.codigoPostal;
      _avisoUbicacion = 'Llenamos la dirección con la de ese punto: revísala y corrígela si hace falta.';
    });
  }

  /// Al salir de un campo de la dirección se busca en el mapa (no en cada tecla).
  Widget _alSalirBuscar(Widget campo) => Focus(
        skipTraversal: true,
        onFocusChange: (enfocado) {
          if (!enfocado) _buscarDireccionEscrita();
        },
        child: campo,
      );

  // Etapa 3: Ubicación
  Widget _stepLocation() {
    return Column(
      children: [
        // Basta con una: la dirección escrita (se marca sola en el mapa) o «Usar mi ubicación» (llena la dirección)
        _alSalirBuscar(_buildTextField(
          _addressController,
          'Dirección completa (Calle, #, Colonia)',
          Icons.location_on,
          validator: (v) => (v ?? '').trim().isEmpty && _hayUbicacion ? null : _minimo(v, 8),
        )),
        const SizedBox(height: 12),
        _alSalirBuscar(_buildTextField(
          _municipalityController,
          'Municipio / Alcaldía y Estado',
          Icons.map,
          validator: (v) => (v ?? '').trim().isEmpty && _hayUbicacion ? null : _required(v),
        )),
        const SizedBox(height: 12),
        _alSalirBuscar(_buildTextField(
          _zipCodeController,
          'Código Postal',
          Icons.markunread_mailbox,
          keyboardType: TextInputType.number,
          validator: (v) {
            final t = (v ?? '').trim();
            return t.isEmpty || RegExp(r'^\d{5}$').hasMatch(t) ? null : 'El código postal tiene 5 dígitos';
          },
        )),
        const SizedBox(height: 12),
        _buildTextField(
          _scheduleController,
          'Horario de atención (ej. 09:00 - 18:00)',
          Icons.access_time,
          validator: (v) {
            final m = RegExp(r'^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$').firstMatch((v ?? '').trim());
            if (m == null) return 'Escríbelo como 09:00 - 18:00';
            return '${m[3]}:${m[4]}'.compareTo('${m[1]}:${m[2]}') <= 0 ? 'La hora de cierre debe ser después de la de apertura' : null;
          },
        ),
        const SizedBox(height: 20),
        SelectorUbicacion(
          latitud: _latitud,
          longitud: _longitud,
          hayError: _ubicacionError,
          descripcion: 'Escribe la dirección arriba y se marca sola, o usa tu '
              'ubicación actual si estás en el refugio. También puedes tocar el mapa.',
          textoError: 'Falta la ubicación: escribe una dirección que aparezca en el '
              'mapa, usa tu ubicación actual o toca el mapa.',
          onCambio: (punto) {
            setState(() {
              _latitud = punto?.latitude;
              _longitud = punto?.longitude;
              _ubicacionError = false;
              _avisoUbicacion = null;
            });
            if (punto != null) _completarDireccion(punto);
          },
        ),
        if (_avisoUbicacion != null) ...[
          const SizedBox(height: 6),
          Text(
            _avisoUbicacion!,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1B4F4A), fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  // Etapa 4: Información de los animales
  Widget _stepAnimals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipos de animales que atienden:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text('Perros 🐶'),
          value: _attendsDogs,
          onChanged: (val) => setState(() => _attendsDogs = val!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text('Gatos 🐱'),
          value: _attendsCats,
          onChanged: (val) => setState(() => _attendsCats = val!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text('Otros (Cuyos, conejos, etc.) 🐹'),
          value: _attendsOthers,
          onChanged: (val) => setState(() => _attendsOthers = val!),
        ),
        const SizedBox(height: 8),
        _buildTextField(
          _capacityController,
          'Capacidad aproximada',
          Icons.roofing,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _currentAnimalsController,
          'Número actual de animales',
          Icons.pets,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '¿Se entregan esterilizados, vacunados y desparasitados?',
          ),
          value: _providesHealthCare,
          activeColor: _accent,
          onChanged: (val) => setState(() => _providesHealthCare = val),
        ),
      ],
    );
  }

  // Etapa 5: Contacto y redes
  Widget _stepContact() {
    return Column(
      children: [
        _buildTextField(
          _publicContactController,
          'WhatsApp (opcional)',
          Icons.chat,
          keyboardType: TextInputType.phone,
          validator: (v) => _telefono(v, obligatorio: false),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _socialsController,
          'Facebook, Instagram o sitio web (uno por línea)',
          Icons.share,
          maxLines: 3,
        ),
      ],
    );
  }

  // Etapa 6: Documentos que avalan el refugio (los revisa el administrador en el sitio web)
  Widget _stepDocument() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PDF, JPG o PNG, máximo 5 MB cada uno. Los tres primeros son obligatorios.',
          style: TextStyle(fontSize: 13, color: _mutedColor),
        ),
        const SizedBox(height: 12),
        for (final (tipo, etiqueta, obligatorio) in _tiposDocumento)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _documentError && obligatorio && !_documentos.containsKey(tipo) ? Colors.red : _borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _documentos.containsKey(tipo) ? Icons.check_circle : Icons.description_outlined,
                  color: _documentos.containsKey(tipo) ? Colors.green : _accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (_documentos[tipo] != null)
                        Text(
                          _documentos[tipo]!.nombre,
                          style: const TextStyle(fontSize: 12, color: _mutedColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _elegirDocumento(tipo),
                  child: Text(_documentos.containsKey(tipo) ? 'Cambiar' : 'Subir'),
                ),
              ],
            ),
          ),
        if (_documentError)
          const Padding(
            padding: EdgeInsets.only(top: 2, left: 4),
            child: Text(
              'Sube el acta, el comprobante de domicilio y la identificación',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _elegirDocumento(String tipo) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final archivo = resultado?.files.single;
    if (archivo == null || archivo.bytes == null || !mounted) return;
    if (archivo.size > _maxBytesDocumento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo pesa más de 5 MB. Elige uno más ligero.')),
      );
      return;
    }
    setState(() {
      _documentos[tipo] = ArchivoElegido(
        nombre: archivo.name,
        bytes: archivo.bytes!,
        mime: ArchivoElegido.mimeDe(archivo.name),
      );
      _documentError = false;
    });
  }

  // Etapa 7: Aceptación y envío
  Widget _stepAcceptance() {
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text('Acepto los términos y condiciones de HuellApp'),
          value: _acceptTerms,
          onChanged: (val) => setState(() => _acceptTerms = val!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text('Acepto el aviso de privacidad'),
          value: _acceptPrivacy,
          onChanged: (val) => setState(() => _acceptPrivacy = val!),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: _accent,
          title: const Text(
            'Declaro que toda la información proporcionada es verdadera',
          ),
          value: _declareTruth,
          onChanged: (val) => setState(() => _declareTruth = val!),
        ),
      ],
    );
  }

  // ---------- Campos ----------

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(label, icon, suffixIcon: suffixIcon),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _minimo(String? value, int minimo) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Campo obligatorio';
    return t.length < minimo ? 'Mínimo $minimo caracteres' : null;
  }

  String? _telefono(String? value, {required bool obligatorio}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'Campo obligatorio' : null;
    return RegExp(r'^[\d\s+()\-]{8,}$').hasMatch(t) ? null : 'Al menos 8 dígitos (números, espacios, + - y paréntesis)';
  }

  // ---------- Navegación entre etapas ----------

  void _anterior() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _siguiente() {
    FocusScope.of(context).unfocus();

    // Valida los campos de la etapa actual
    if (!_formKey.currentState!.validate()) return;

    // La ubicación en el mapa es obligatoria en la etapa 3
    if (_currentStep == 2 && (_latitud == null || _longitud == null)) {
      setState(() => _ubicacionError = true);
      return;
    }

    // Rescatista independiente: al menos una red social o referencia (etapa 5, contacto y redes)
    if (_currentStep == 4 && _esIndependiente && _socialsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Como rescatista independiente, agrega al menos una red social o referencia de tu trabajo de rescate.'),
      ));
      return;
    }

    // Los tres documentos obligatorios en la etapa 6
    if (_currentStep == 5 &&
        _tiposDocumento.any((d) => d.$3 && !_documentos.containsKey(d.$1))) {
      setState(() => _documentError = true);
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
    } else {
      _enviarSolicitud();
    }
  }

  Future<void> _enviarSolicitud() async {
    if (!_acceptTerms || !_acceptPrivacy || !_declareTruth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar las casillas para continuar'),
        ),
      );
      return;
    }
    if (_enviando) return;

    final redes = _socialsController.text
        .split(RegExp(r'[\n,]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(5)
        .toList();
    final datos = <String, dynamic>{
      'nombreRefugio': _shelterNameController.text.trim(),
      'responsable': _repNameController.text.trim(),
      'telefono': _phoneController.text.trim(),
      'direccion': _addressController.text.trim(),
      'horario': _scheduleController.text.trim(),
      'correo': _emailController.text.trim(),
      'password': _passwordController.text,
      // Datos extra que también guarda el sitio web
      'latitud': _latitud,
      'longitud': _longitud,
      'municipio': _municipalityController.text.trim(),
      'codigoPostal': _zipCodeController.text.trim(),
      'rfc': _rfcController.text.trim(),
      'tipoOrganizacion': _orgType,
      'anioFundacion': _foundationYearController.text.trim(),
      'whatsapp': _publicContactController.text.trim(),
      'redes': redes,
      'tienePerros': _attendsDogs,
      'tieneGatos': _attendsCats,
      'descripcion': _descriptionController.text.trim(),
      // Antes la app los pedía pero no se guardaban
      'cargoResponsable': _repRoleController.text.trim(),
      'capacidad': _capacityController.text.trim(),
      'animalesActuales': _currentAnimalsController.text.trim(),
      'entregaEsterilizados': _providesHealthCare ? 'si' : 'no',
    };

    setState(() => _enviando = true);
    try {
      await RefugioService.instancia.registrar(datos, _documentos);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _enviando = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
            SizedBox(height: 8),
            Text('¡Solicitud Enviada!', textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          'Un administrador revisará la documentación de tu refugio. Mientras tanto, al iniciar sesión verás el estado de tu solicitud.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cierra modal
              Navigator.pop(context); // Vuelve al Login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _turquoise,
              foregroundColor: _textColor,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
