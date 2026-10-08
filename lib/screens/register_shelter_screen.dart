import 'package:flutter/material.dart';

class RegisterShelterScreen extends StatefulWidget {
  const RegisterShelterScreen({super.key});

  @override
  State<RegisterShelterScreen> createState() => _RegisterShelterScreenState();
}

class _RegisterShelterScreenState extends State<RegisterShelterScreen> {
  // Paleta del diseño
  static const Color _accent = Color(0xFFC2571A);
  static const Color _background = Color(0xFFFFF7F0);
  static const Color _textColor = Color(0xFF2B2A33);
  static const Color _mutedColor = Color(0xFF5C5963);

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
  String? _selectedFileName;
  bool _documentError = false;

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
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'HuellApp',
          style: TextStyle(
            color: _accent,
            fontWeight: FontWeight.w800,
            fontSize: 26,
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
                            onPressed: _siguiente,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentStep == _totalSteps - 1
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
            backgroundColor: const Color(0xFFFFE3C7),
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
          validator: _required,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _orgType,
          decoration: _inputDecoration('Tipo de Organización', Icons.business),
          items: [
            'Asociación Civil',
            'Fundación',
            'Refugio Independiente',
            'Albergue Municipal',
            'Otro',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _orgType = val!),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _rfcController,
          'RFC o Número de Registro (Opcional)',
          Icons.badge,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _foundationYearController,
          'Año de Fundación',
          Icons.calendar_today,
          keyboardType: TextInputType.number,
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
          validator: _required,
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
          'Teléfono / WhatsApp',
          Icons.phone,
          keyboardType: TextInputType.phone,
          validator: _required,
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

  // Etapa 3: Ubicación
  Widget _stepLocation() {
    return Column(
      children: [
        _buildTextField(
          _addressController,
          'Dirección completa (Calle, #, Colonia)',
          Icons.location_on,
          validator: _required,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _municipalityController,
          'Municipio / Alcaldía y Estado',
          Icons.map,
          validator: _required,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _zipCodeController,
          'Código Postal',
          Icons.markunread_mailbox,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _scheduleController,
          'Horario de atención o visitas',
          Icons.access_time,
        ),
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
          'Teléfono / Correo de contacto público',
          Icons.contact_mail,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _socialsController,
          'Facebook, Instagram o Sitio Web',
          Icons.share,
          maxLines: 2,
        ),
      ],
    );
  }

  // Etapa 6: Documento que avale el refugio
  Widget _stepDocument() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _documentError ? Colors.red : _accent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Documento obligatorio (PDF, JPG o PNG, máx. 5 MB)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Simulación de selección de archivo.
                  // Para el real, usa el paquete file_picker.
                  setState(() {
                    _selectedFileName = 'documento_refugio_aval.pdf';
                    _documentError = false;
                  });
                },
                icon: const Icon(Icons.upload_file),
                label: Text(_selectedFileName ?? 'Subir Documento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_documentError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'El comprobante es obligatorio',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Ejemplos aceptados:\n'
          '• Acta constitutiva (A.C. / Fundación)\n'
          '• Constancia de Situación Fiscal (SAT)\n'
          '• Permiso municipal o carta de autoridad local o de una asociación '
          'de protección animal\n'
          '• Si no tienes documentos oficiales: fotos del refugio y '
          'comprobante de domicilio.',
          style: TextStyle(fontSize: 12, height: 1.5, color: _mutedColor),
        ),
      ],
    );
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
        borderSide: const BorderSide(color: Color(0xFFCFC6BC), width: 1.5),
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

    // El comprobante es obligatorio en la etapa 6
    if (_currentStep == 5 && _selectedFileName == null) {
      setState(() => _documentError = true);
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
    } else {
      _enviarSolicitud();
    }
  }

  void _enviarSolicitud() {
    if (!_acceptTerms || !_acceptPrivacy || !_declareTruth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar las casillas para continuar'),
        ),
      );
      return;
    }

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
          'Revisaremos la documentación de tu refugio y te notificaremos por correo electrónico.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cierra modal
              Navigator.pop(context); // Vuelve al Login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
