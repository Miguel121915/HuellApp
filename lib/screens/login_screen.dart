import 'package:flutter/material.dart';

import '../navigation.dart';
import 'register_shelter_screen.dart';
import 'register_user_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Paleta turquesa de HuellApp (la de la pantalla de inicio)
  static const Color _accent = Color(
    0xFF1B4F4A,
  ); // Verde oscuro: botones y enlaces
  static const Color _turquoise = Color(0xFF75E6DA); // Turquesa de la app
  static const Color _background = Color(0xFFE6F8F5); // Menta claro
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);
  static const Color _borderColor = Color(0xFF9ED9D1);

  // Imagen de fondo guardada en el proyecto (funciona sin internet)
  static const String _backgroundImage = 'assets/images/fondo_login.jpg';

  final _formKey = GlobalKey<FormState>();

  // Los 3 roles de login: 'Usuario', 'Refugio', 'Admin'
  String _selectedRole = 'Usuario';

  final TextEditingController _userOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryEmailController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _userOrEmailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    super.dispose();
  }

  // ---------- Textos e íconos según el rol ----------

  String get _userFieldLabel {
    if (_selectedRole == 'Admin') return 'Usuario Admin';
    if (_selectedRole == 'Refugio') return 'Correo o usuario del refugio';
    return 'Nombre de usuario o correo';
  }

  IconData get _userFieldIcon {
    if (_selectedRole == 'Admin') return Icons.badge_outlined;
    if (_selectedRole == 'Refugio') return Icons.maps_home_work_outlined;
    return Icons.person_outline;
  }

  // ---------- Acciones ----------

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: reemplazar por la validación real con el servidor
    // (usuario, contraseña y rol seleccionado).
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isLoading = false);
    _entrar();
  }

  void _entrar() {
    // TODO: cuando existan los paneles, enviar a cada rol a su pantalla:
    //   'Usuario' -> AppNavigation()
    //   'Refugio' -> panel del refugio
    //   'Admin'   -> panel del administrador
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AppNavigation()),
    );
  }

  void _olvideContrasena() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escribe tu correo y te enviaremos un enlace para crear una '
              'nueva contraseña.',
              style: TextStyle(fontSize: 14, color: _mutedColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recoveryEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                'Correo electrónico',
                Icons.email_outlined,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: _accent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Si el correo está registrado, recibirás un enlace '
                    'para recuperar tu contraseña',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _turquoise,
              foregroundColor: _textColor,
            ),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAnimalsHeader(),
                          const SizedBox(height: 16),

                          // Título
                          const Text(
                            'HuellApp',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: _accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Adopta, reporta y ayuda a que más huellitas '
                            'encuentren un hogar 🐾',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: _mutedColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Selector de rol: Usuario, Refugio y Admin
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: _turquoise,
                              selectedForegroundColor: _textColor,
                              foregroundColor: _textColor,
                              side: const BorderSide(color: _borderColor),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'Usuario',
                                label: Text(
                                  'Usuario',
                                  style: TextStyle(fontSize: 12),
                                ),
                                icon: Icon(Icons.person, size: 16),
                              ),
                              ButtonSegment(
                                value: 'Refugio',
                                label: Text(
                                  'Refugio',
                                  style: TextStyle(fontSize: 12),
                                ),
                                icon: Icon(Icons.pets, size: 16),
                              ),
                              ButtonSegment(
                                value: 'Admin',
                                label: Text(
                                  'Admin',
                                  style: TextStyle(fontSize: 12),
                                ),
                                icon: Icon(
                                  Icons.admin_panel_settings,
                                  size: 16,
                                ),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _selectedRole = newSelection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Campo Usuario / Correo según el rol
                          TextFormField(
                            controller: _userOrEmailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              _userFieldLabel,
                              _userFieldIcon,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Escribe tu usuario o correo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo Contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _iniciarSesion(),
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
                                return 'Escribe tu contraseña';
                              }
                              return null;
                            },
                          ),

                          // ¿Olvidaste tu contraseña?
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _olvideContrasena,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: _accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Botón Iniciar Sesión
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _iniciarSesion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _turquoise,
                                foregroundColor: _textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: _textColor,
                                      ),
                                    )
                                  : Text(
                                      'Ingresar como $_selectedRole',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Separador
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'o',
                                  style: TextStyle(color: _mutedColor),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Botón Entrar como Visitante
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _entrar,
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text(
                                'Entrar como visitante',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accent,
                                side: const BorderSide(
                                  color: _accent,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Registro Usuario Normal
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                '¿No tienes cuenta?',
                                style: TextStyle(color: _mutedColor),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterUserScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Regístrate aquí',
                                  style: TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Registro Refugio
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterShelterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.maps_home_work_outlined,
                              size: 18,
                              color: _accent,
                            ),
                            label: const Text(
                              '¿Eres un refugio sin cuenta? Regístrate aquí',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _accent, fontSize: 13),
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
        ],
      ),
    );
  }

  // ---------- Widgets de apoyo ----------

  /// Fondo: imagen local con una capa turquesa encima.
  /// Si la imagen no existe todavía, se muestra el color menta.
  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _backgroundImage,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: _background),
        ),
        Container(color: const Color(0x9914524D)),
      ],
    );
  }

  /// Caritas de animales encimadas (perro, gato y cuyo).
  Widget _buildAnimalsHeader() {
    return Center(
      child: SizedBox(
        width: 204,
        height: 80,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _animalAvatar('🐶', const Color(0xFFFFE3C7)),
            ),
            Positioned(
              left: 62,
              child: _animalAvatar('🐱', const Color(0xFFD8EEE6)),
            ),
            Positioned(
              left: 124,
              child: _animalAvatar('🐹', const Color(0xFFFFE4EA)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animalAvatar(String emoji, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 36)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    );
  }
}
