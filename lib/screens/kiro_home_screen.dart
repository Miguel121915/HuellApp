import 'package:flutter/material.dart';
import 'package:huellapp/screens/muro_huellapp_screen.dart';

class KiroHomeScreen extends StatefulWidget {
  const KiroHomeScreen({super.key});

  @override
  State<KiroHomeScreen> createState() => _KiroHomeScreenState();
}

class _KiroHomeScreenState extends State<KiroHomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  int _selectedIndex = 2;

  static const Color primaryTurquoise = Color(0xFF75E6DA);
  static const Color darkBorderColor = Color(0xFF1B4943);

  // Función para abrir la ventana modal de Iniciar Sesión al tocar la huella
  void _mostrarLoginModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkBorderColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión iniciada con éxito'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Ingresar',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F9F8),
      appBar: AppBar(
        backgroundColor: primaryTurquoise,
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: const Text(
          'HuellApp',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              tooltip: 'Iniciar Sesión',
              icon: const Icon(Icons.pets, color: Colors.black, size: 32),
              onPressed: () => _mostrarLoginModal(context),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo con patrón de huellitas
          Positioned.fill(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 35,
                crossAxisSpacing: 35,
              ),
              itemBuilder: (context, index) => Icon(
                Icons.pets,
                color: Colors.teal.shade100.withOpacity(0.4),
                size: 28,
              ),
            ),
          ),
          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Mensaje del Asistente KIRO
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Hola, me llamo KIRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Icono del Robot KIRO
                const Icon(
                  Icons.smart_toy_rounded,
                  size: 140,
                  color: primaryTurquoise,
                ),
                const Spacer(),
                // Campo de Búsqueda Inferior
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: darkBorderColor, width: 1.5),
                    ),
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'Busqueda',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        border: InputBorder.none,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            backgroundColor: darkBorderColor,
                            child: const Icon(
                              Icons.search,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 0) {
            // Si toca el botón Foro (posición 0), abre la pantalla del foro
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MuroHuellAppScreen(),
              ),
            );
          } else {
            // Para los demás botones, cambia de pestaña normalmente
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: primaryTurquoise,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        showUnselectedLabels: true,
        items: [
          // 1. Foro
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: Colors.black,
                size: 24,
              ),
            ),
            label: 'Foro',
          ),

          // 2. Refugios
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.maps_home_work_outlined,
                color: Colors.black,
                size: 24,
              ),
            ),
            label: 'Refugios',
          ),

          // 3. Inicio (Círculo central)
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: primaryTurquoise, width: 2),
              ),
              child: const Icon(
                Icons.other_houses_outlined,
                color: Colors.black,
                size: 32,
              ),
            ),
            label: 'Inicio',
          ),

          // 4. Reportar
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.videocam_outlined, color: Colors.black, size: 24),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Icon(Icons.pets, color: Colors.red, size: 8),
                  ),
                ],
              ),
            ),
            label: 'Reportar',
          ),

          // 5. Coincidencias
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            label: 'Coincidencias',
          ),
        ],
      ),
    );
  }
}
