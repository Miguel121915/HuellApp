import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../services/refugio_service.dart';
import '../../widgets/documentos_privados.dart';
import '../../widgets/foto_huellapp.dart';

/// Alta o edición de una mascota del inventario del refugio (como en el panel del sitio web).
class MascotaFormScreen extends StatefulWidget {
  const MascotaFormScreen({super.key, this.mascota});

  /// null = mascota nueva
  final MascotaInventario? mascota;

  @override
  State<MascotaFormScreen> createState() => _MascotaFormScreenState();
}

class _MascotaFormScreenState extends State<MascotaFormScreen> {
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _raza;
  late final TextEditingController _edad;
  late final TextEditingController _salud;
  late final TextEditingController _descripcion;
  String _especie = 'perro';
  String _sexo = 'macho';
  String _tamano = 'mediano';
  String _estatus = 'disponible';
  String _unidadEdad = 'meses';
  ArchivoElegido? _fotoNueva;
  bool _guardando = false;

  bool get _esNueva => widget.mascota == null;

  @override
  void initState() {
    super.initState();
    final m = widget.mascota;
    _nombre = TextEditingController(text: m?.nombre ?? '');
    _raza = TextEditingController(text: m?.raza ?? '');
    _salud = TextEditingController(text: m?.salud ?? '');
    _descripcion = TextEditingController(text: m?.descripcion ?? '');
    final meses = m?.edadMeses ?? 0;
    if (meses >= 12 && meses % 12 == 0) {
      _unidadEdad = 'años';
      _edad = TextEditingController(text: '${meses ~/ 12}');
    } else {
      _edad = TextEditingController(text: meses == 0 ? '' : '$meses');
    }
    if (m != null) {
      _especie = m.especie;
      _sexo = m.sexo;
      _tamano = m.tamano;
      _estatus = m.estatus;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _raza, _edad, _salud, _descripcion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource origen) async {
    final archivo = await ImagePicker().pickImage(source: origen, maxWidth: 1200, imageQuality: 80);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 3 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La foto pesa más de 3 MB. Elige otra.')),
      );
      return;
    }
    setState(() => _fotoNueva = ArchivoElegido(nombre: archivo.name, bytes: bytes, mime: ArchivoElegido.mimeDe(archivo.name)));
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final numero = int.parse(_edad.text.trim());
    final datos = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'especie': _especie,
      'raza': _raza.text.trim(),
      'edadMeses': _unidadEdad == 'años' ? numero * 12 : numero,
      'sexo': _sexo,
      'tamano': _tamano,
      'salud': _salud.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'estatus': _estatus,
      // Foto nueva como data URL; si no se cambió, se manda la que ya tenía
      'foto': _fotoNueva?.dataUrl ?? widget.mascota?.foto ?? '',
    };
    setState(() => _guardando = true);
    try {
      await RefugioService.instancia.guardarMascota(datos, id: widget.mascota?.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700),
      );
    }
  }

  InputDecoration _decoracion(String etiqueta) => InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _opciones(String etiqueta, String valor, Map<String, String> opciones, ValueChanged<String> alCambiar) {
    return DropdownButtonFormField<String>(
      value: valor,
      decoration: _decoracion(etiqueta),
      items: [for (final e in opciones.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => alCambiar(v!)),
    );
  }

  String? _texto(String? v, {int minimo = 1, required int maximo}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Campo obligatorio';
    if (t.length < minimo) return 'Mínimo $minimo caracteres';
    if (t.length > maximo) return 'Máximo $maximo caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fotoActual = widget.mascota?.fotoUrl ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: _turquoise,
        title: Text(_esNueva ? 'Nueva mascota' : 'Editar ${widget.mascota!.nombre}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 200,
                  height: 160,
                  child: _fotoNueva != null
                      ? Image.memory(_fotoNueva!.bytes, fit: BoxFit.cover)
                      : FotoHuellApp(fotoActual, width: 200, height: 160),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _elegirFoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _elegirFoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              decoration: _decoracion('Nombre'),
              validator: (v) => _texto(v, minimo: 2, maximo: 40),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _opciones('Especie', _especie, const {'perro': 'Perro', 'gato': 'Gato'}, (v) => _especie = v)),
                const SizedBox(width: 12),
                Expanded(child: _opciones('Sexo', _sexo, const {'macho': 'Macho', 'hembra': 'Hembra'}, (v) => _sexo = v)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _raza,
              decoration: _decoracion('Raza (ej. Mestizo)'),
              validator: (v) => _texto(v, maximo: 60),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _edad,
                    keyboardType: TextInputType.number,
                    decoration: _decoracion('Edad'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'Escribe un número';
                      final meses = _unidadEdad == 'años' ? n * 12 : n;
                      return meses > 360 ? 'Máximo 30 años' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _opciones('Unidad', _unidadEdad, const {'meses': 'Meses', 'años': 'Años'}, (v) => _unidadEdad = v)),
              ],
            ),
            const SizedBox(height: 12),
            _opciones('Tamaño', _tamano, const {'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'}, (v) => _tamano = v),
            const SizedBox(height: 12),
            TextFormField(
              controller: _salud,
              decoration: _decoracion('Salud (ej. Vacunado y desparasitado)'),
              validator: (v) => _texto(v, maximo: 120),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              maxLines: 4,
              decoration: _decoracion('Descripción'),
              validator: (v) => _texto(v, minimo: 10, maximo: 400),
            ),
            const SizedBox(height: 12),
            _opciones(
              'Estatus',
              _estatus,
              const {'disponible': 'Disponible', 'en proceso': 'En proceso de adopción', 'adoptado': 'Adoptado'},
              (v) => _estatus = v,
            ),
            const SizedBox(height: 16),
            // Documentos (vacunas, esterilización…): igual que en el inventario del sitio web
            if (_esNueva)
              const Text(
                'Después de agregar la mascota podrás subir sus documentos (vacunas, esterilización…) desde «Editar».',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              )
            else
              DocumentosMascota(mascotaId: widget.mascota!.id),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_guardando ? 'Guardando…' : (_esNueva ? 'Agregar mascota' : 'Guardar cambios')),
            ),
          ],
        ),
      ),
    );
  }
}
