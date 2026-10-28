import 'package:flutter/material.dart';

class CoincidenciasScreen extends StatefulWidget {
  final List dynamicCoincidencias;
  final int? reporteId;

  const CoincidenciasScreen({
    super.key,
    this.dynamicCoincidencias = const [],
    this.reporteId,
  });

  @override
  State<CoincidenciasScreen> createState() => _CoincidenciasScreenState();
}

class _CoincidenciasScreenState extends State<CoincidenciasScreen> {
  static const Color primaryTurquoise = Color(0xFF75E6DA);
  static const Color darkBorderColor = Color(0xFF1B4943);
  static const Color backgroundLight = Color(0xFFE8F9F8);

  late List<Map<String, dynamic>> _coincidencias;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() {
    if (widget.dynamicCoincidencias.isNotEmpty) {
      // Mapear la lista dinámica recibida de Node.js / Gemini
      _coincidencias = widget.dynamicCoincidencias.map((c) {
        return {
          'id': c['id'] ?? c['post_id'] ?? 0,
          'nombre': c['titulo'] ?? 'Mascota detectada en Foro',
          'raza': c['raza'] ?? 'Ver detalles en publicación',
          'ubicacion': c['ubicacion'] ?? 'Ubicación reportada en foro',
          'porcentajeSimilitud':
              (c['porcentaje_similitud'] ?? c['porcentajeSimilitud'] ?? 80)
                  .toInt(),
          'fechaReporte': 'Reciente',
          'descripcion':
              c['contenido'] ??
              c['descripcion'] ??
              'Coincidencia detectada con publicación activa en el Foro.',
          'contacto': '5512345678',
          'postIdForo': 'FORO-${c['post_id'] ?? c['id'] ?? 1}',
          'imagenUrl':
              c['imagen_url'] ??
              'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500',
        };
      }).toList();
    } else {
      _coincidencias = [];
    }
  }

  void _verPublicacionEnForo(String postId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirigiendo a la publicación $postId en el Foro...'),
        backgroundColor: darkBorderColor,
      ),
    );
  }

  void _contactarReportante(String contacto, String nombre) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contactar sobre $nombre',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBorderColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone, color: darkBorderColor),
              title: const Text('Llamar por teléfono'),
              subtitle: Text(contacto),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Iniciando llamada a $contacto...'),
                    backgroundColor: darkBorderColor,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline,
                color: darkBorderColor,
              ),
              title: const Text('Enviar mensaje directo'),
              subtitle: const Text('Abrir chat interno en HuellApp'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abriendo chat interno...'),
                    backgroundColor: darkBorderColor,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Coincidencias Detectadas',
          style: TextStyle(color: darkBorderColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: darkBorderColor),
      ),
      body: _coincidencias.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: darkBorderColor,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No hay coincidencias pendientes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBorderColor,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Te avisaremos cuando la IA encuentre similitudes con tus publicaciones en el Foro.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: primaryTurquoise,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: darkBorderColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Coincidencias con el Foro',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: darkBorderColor,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'La IA comparó los reportes con las publicaciones realizadas por los usuarios en la comunidad.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Similitudes encontradas:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBorderColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._coincidencias.map((item) {
                    final int porcentaje = item['porcentajeSimilitud'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryTurquoise, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                                child: Image.network(
                                  item['imagenUrl'],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 180,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.pets,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$porcentaje% Similitud',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['nombre'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: darkBorderColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item['fechaReporte'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.category,
                                      size: 16,
                                      color: darkBorderColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item['raza'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item['ubicacion'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['descripcion'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextButton.icon(
                                  onPressed: () =>
                                      _verPublicacionEnForo(item['postIdForo']),
                                  icon: const Icon(
                                    Icons.forum_outlined,
                                    size: 18,
                                    color: darkBorderColor,
                                  ),
                                  label: Text(
                                    'Ver publicación en el Foro (${item['postIdForo']})',
                                    style: const TextStyle(
                                      color: darkBorderColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _coincidencias.removeWhere(
                                              (element) =>
                                                  element['id'] == item['id'],
                                            );
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Coincidencia descartada.',
                                                  ),
                                                ),
                                              );
                                        },
                                        child: const Text('Descartar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryTurquoise,
                                          foregroundColor: darkBorderColor,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: const BorderSide(
                                              color: darkBorderColor,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _contactarReportante(
                                          item['contacto'],
                                          item['nombre'],
                                        ),
                                        child: const Text(
                                          'Contactar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
