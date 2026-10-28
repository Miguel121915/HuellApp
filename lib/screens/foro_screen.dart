import 'package:flutter/material.dart';
import 'package:huellapp/servicios_ia.dart'; // Importa tu servicio de IA / Backend

class ForoScreen extends StatefulWidget {
  const ForoScreen({super.key});

  @override
  State<ForoScreen> createState() => _ForoScreenState();
}

class _ForoScreenState extends State<ForoScreen> {
  final ServiciosIA _serviciosIA = ServiciosIA();
  List<dynamic> _publicacionesBD = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPublicaciones();
  }

  Future<void> _cargarPublicaciones() async {
    setState(() => _cargando = true);
    final posts = await _serviciosIA.obtenerPublicacionesForo();
    if (mounted) {
      setState(() {
        _publicacionesBD = posts;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F5),
      appBar: AppBar(
        title: const Text(
          'Foro de Comunidad',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPublicaciones,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _publicacionesBD.isEmpty
          ? const Center(
              child: Text(
                'No hay publicaciones registradas en el Foro.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 590),
                child: RefreshIndicator(
                  onRefresh: _cargarPublicaciones,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _publicacionesBD.length,
                    itemBuilder: (context, index) {
                      final post = _publicacionesBD[index];
                      return PublicacionCard(post: post);
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class PublicacionCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const PublicacionCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final String usuario = post['nombre_usuario'] ?? 'HuellApp Usuario';
    final String titulo = post['titulo'] ?? 'Reporte de Mascota';
    final String contenido = post['contenido'] ?? '';
    final String? imagenUrl = post['imagen_url'];
    final String fecha = post['fecha_post'] != null
        ? post['fecha_post'].toString().split('T')[0]
        : 'Reciente';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Encabezado del Post
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF1877F2),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fecha,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Título y Contenido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  contenido,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Imagen cargada desde la carpeta uploads de Node.js
          if (imagenUrl != null && imagenUrl.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFF0F2F5),
              child: Image.network(
                imagenUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
