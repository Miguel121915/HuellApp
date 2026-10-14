import 'package:flutter/material.dart';
import 'package:huellapp/screens/login_screen.dart';

/// Pantalla de KIRO: se abre desde el botón flotante del inicio.
/// Muestra en qué puede ayudar y una caja para escribirle.
class KiroHomeScreen extends StatefulWidget {
  const KiroHomeScreen({super.key});

  @override
  State<KiroHomeScreen> createState() => _KiroHomeScreenState();
}

class _TemaAyuda {
  final IconData icono;
  final String texto;
  final String pregunta;
  const _TemaAyuda(this.icono, this.texto, this.pregunta);
}

class _KiroHomeScreenState extends State<KiroHomeScreen> {
  final TextEditingController _queryController = TextEditingController();

  static const Color primaryTurquoise = Color(0xFF75E6DA);
  static const Color darkBorderColor = Color(0xFF1B4943);

  // En qué puede ayudar KIRO (ajustar según lo que KIRO pueda hacer)
  static const List<_TemaAyuda> _temas = [
    _TemaAyuda(
      Icons.pets,
      'Encontrar una mascota para adoptar',
      '¿Cómo puedo adoptar una mascota?',
    ),
    _TemaAyuda(
      Icons.location_on,
      'Ver refugios cerca de ti',
      '¿Qué refugios hay cerca de mí?',
    ),
    _TemaAyuda(
      Icons.warning_amber_rounded,
      'Reportar una mascota perdida o encontrada',
      '¿Cómo reporto una mascota?',
    ),
    _TemaAyuda(
      Icons.favorite_border,
      'Resolver dudas sobre la adopción',
      '¿Qué necesito para adoptar?',
    ),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _usarTema(_TemaAyuda tema) {
    _queryController.text = tema.pregunta;
    _queryController.selection = TextSelection.collapsed(
      offset: tema.pregunta.length,
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
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
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
              tooltip: 'Iniciar sesión',
              icon: const Icon(Icons.pets, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
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
                color: Colors.teal.shade100.withValues(alpha: 0.4),
                size: 28,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(),
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
                                color: Colors.black.withValues(alpha: 0.08),
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
                        const SizedBox(height: 16),
                        const Icon(
                          Icons.smart_toy_rounded,
                          size: 110,
                          color: primaryTurquoise,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Puedo ayudarte a:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: darkBorderColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final tema in _temas)
                                ActionChip(
                                  avatar: Icon(
                                    tema.icono,
                                    size: 18,
                                    color: darkBorderColor,
                                  ),
                                  label: Text(
                                    tema.texto,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: darkBorderColor,
                                  ),
                                  onPressed: () => _usarTema(tema),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: darkBorderColor,
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _queryController,
                              // TODO: conectar con las respuestas de KIRO
                              decoration: InputDecoration(
                                hintText: 'Pregúntale a KIRO',
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
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}