import 'package:flutter/material.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  // Paleta compartida con el registro de refugio
  static const Color _accent = Color(0xFFC2571A);
  static const Color _background = Color(0xFFFFF7F0);
  static const Color _textColor = Color(0xFF2B2A33);
  static const Color _mutedColor = Color(0xFF5C5963);

  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAnimalsHeader(),
                      const SizedBox(height: 20),
                      const Text(
                        'Crea tu cuenta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Únete a HuellApp y ayuda a que más huellitas '
                        'encuentren un hogar 🐾',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _mutedColor,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Nombre de usuario
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          'Nombre de usuario',
                          Icons.person_outline,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Campo obligatorio';
                          }
                          if (v.trim().length < 3) {
                            return 'Mínimo 3 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Correo electrónico
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          'Correo electrónico',
                          Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Campo obligatorio';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          'Contraseña',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Campo obligatorio';
                          }
                          if (v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Términos y privacidad
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _accent,
                        title: const Text(
                          'Acepto los términos y condiciones y el aviso de privacidad',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _acceptTerms,
                        onChanged: (val) => setState(() {
                          _acceptTerms = val!;
                          _showTermsError = false;
                        }),
                      ),
                      if (_showTermsError)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            'Debes aceptar para continuar',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Botón Crear Cuenta
                      ElevatedButton(
                        onPressed: _crearCuenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Crear cuenta 🐾',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Caritas de animales encimadas (perro, gato y cuyo).
  Widget _buildAnimalsHeader() {
    return Center(
      child: SizedBox(
        width: 260,
        height: 96,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _animalAvatar('🐶', const Color(0xFFFFE3C7)),
            ),
            Positioned(
              left: 82,
              child: _animalAvatar('🐱', const Color(0xFFD8EEE6)),
            ),
            Positioned(
              left: 164,
              child: _animalAvatar('🐹', const Color(0xFFFFE4EA)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animalAvatar(String emoji, Color color) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 44)),
    );
  }

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

  void _crearCuenta() {
    final formOk = _formKey.currentState!.validate();

    if (!_acceptTerms) {
      setState(() => _showTermsError = true);
    }
    if (!formOk || !_acceptTerms) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Cuenta creada exitosamente!')),
    );
    Navigator.pop(context);
  }
}
