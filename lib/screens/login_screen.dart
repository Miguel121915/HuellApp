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
  // Ahora manejamos los 3 roles de login: 'Usuario', 'Refugio', 'Admin'
  String _selectedRole = 'Usuario';

  final TextEditingController _userOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _iniciarSesion() {
    if (_userOrEmailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena usuario y contraseña')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AppNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Imagen de fondo decorativa de mascotas
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1548767797-d8c844163c4c?q=80&w=1000&auto=format&fit=crop',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Capa traslúcida para que los campos sigan viéndose nítidos
          Container(color: Colors.black.withOpacity(0.35)),

          // 3. Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.93),
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ícono animado / llamativo
                      const Icon(Icons.pets, size: 60, color: Colors.orange),
                      const SizedBox(height: 8),

                      // Título con tipografía bonita y llamativa
                      Text(
                        'HuellApp',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange.shade800,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.orange.shade100,
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector con los 3 tipos de usuario: Usuario, Refugio y Admin
                      SegmentedButton<String>(
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
                            icon: Icon(Icons.admin_panel_settings, size: 16),
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
                      TextField(
                        controller: _userOrEmailController,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'Admin'
                              ? 'Usuario Admin'
                              : _selectedRole == 'Refugio'
                              ? 'Correo o Usuario del Refugio'
                              : 'Nombre de usuario o Correo',
                          prefixIcon: Icon(
                            _selectedRole == 'Admin'
                                ? Icons.badge_outlined
                                : _selectedRole == 'Refugio'
                                ? Icons.maps_home_work_outlined
                                : Icons.person_outline,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo Contraseña
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botón Iniciar Sesión
                      ElevatedButton(
                        onPressed: _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Ingresar como $_selectedRole',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón Entrar como Visitante
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppNavigation(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.visibility_outlined,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Entrar como Visitante',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Registro Usuario Normal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿No tienes cuenta? '),
                          GestureDetector(
                            onTap: () {
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
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

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
                        ),
                        label: const Text(
                          '¿Eres un Refugio sin cuenta? Regístrate aquí',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
