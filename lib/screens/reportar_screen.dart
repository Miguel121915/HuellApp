import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportarScreen extends StatefulWidget {
  const ReportarScreen({super.key});

  @override
  State<ReportarScreen> createState() => _ReportarScreenState();
}

class _ReportarScreenState extends State<ReportarScreen> {
  static const Color primaryTurquoise = Color(0xFF75E6DA);
  static const Color darkBorderColor = Color(0xFF1B4943);
  static const Color backgroundLight = Color(0xFFE8F9F8);

  final _formKey = GlobalKey<FormState>();

  String _tipoReporte = 'Extraviada';

  final TextEditingController _nombreMascotaController =
      TextEditingController();
  final TextEditingController _razaController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  // Guardamos los bytes de la imagen para compatibilidad total con Web y Móvil
  Uint8List? _imagenBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nombreMascotaController.dispose();
    _razaController.dispose();
    _ubicacionController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // Método universal compatible con Web y App nativa
  Future<void> _seleccionarImagen(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
      });
    }
  }

  void _enviarReporte() {
    if (_formKey.currentState!.validate()) {
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: darkBorderColor),
              SizedBox(height: 16),
              Text(
                'Analizando imagen con IA y generando alerta...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Reporte creado con éxito! Se han buscado coincidencias.',
            ),
            backgroundColor: darkBorderColor,
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          _imagenBytes = null;
          _nombreMascotaController.clear();
          _razaController.clear();
          _ubicacionController.clear();
          _descripcionController.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: Column(
                  children: const [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: darkBorderColor,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Reportar Mascota con IA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBorderColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sube una fotografía clara. Nuestra inteligencia artificial analizará los rasgos para buscar similitudes en reportes activos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: primaryTurquoise,
                  selectedForegroundColor: darkBorderColor,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'Extraviada',
                    label: Text('Se busca (Extraviada)'),
                    icon: Icon(Icons.search, size: 16),
                  ),
                  ButtonSegment(
                    value: 'Avistamiento',
                    label: Text('La encontré (Avistamiento)'),
                    icon: Icon(Icons.pets, size: 16),
                  ),
                ],
                selected: {_tipoReporte},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _tipoReporte = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
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
                },
                child: Container(
                  height: 180,
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
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombreMascotaController,
                decoration: _inputDecoration(
                  'Nombre de la mascota (si lo sabes)',
                  Icons.pets,
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _ubicacionController,
                decoration: _inputDecoration(
                  'Zona o Colonia del extravío / avistamiento',
                  Icons.location_on_outlined,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Indica la ubicación' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Señas particulares (color de collar, manchas, cicatrices...)',
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTurquoise,
                  foregroundColor: darkBorderColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: darkBorderColor, width: 1.5),
                  ),
                ),
                onPressed: _enviarReporte,
                child: const Text(
                  'Generar Alerta y Buscar Coincidencias',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
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
