import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/sesion_service.dart';
import '../models/refugio.dart';
import '../services/adopcion_service.dart';
import '../services/refugio_service.dart' show ArchivoElegido;
import '../widgets/foto_huellapp.dart';
import 'mis_solicitudes_screen.dart';

/// Solicitud de adopción desde la app (HU-14). Los mismos datos y documentos que pide el sitio web:
/// datos de contacto, vivienda, motivo, identificación, comprobante de domicilio y fotos del espacio.
/// El refugio la revisa en su panel (HU-15) y el usuario ve el estado en «Mis solicitudes».
class SolicitudAdopcionScreen extends StatefulWidget {
  const SolicitudAdopcionScreen({super.key, required this.mascota, required this.nombreRefugio});

  final MascotaRefugio mascota;
  final String nombreRefugio;

  @override
  State<SolicitudAdopcionScreen> createState() => _SolicitudAdopcionScreenState();
}

class _SolicitudAdopcionScreenState extends State<SolicitudAdopcionScreen> {
  static const Color _turquesa = Color(0xFF75E6DA);
  static const Color _oscuro = Color(0xFF1B4F4A);
  static const int _maxBytes = 5 * 1024 * 1024;
  static const int _maxFotosVivienda = 3;

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _ocupacion = TextEditingController();
  final _otrasMascotas = TextEditingController();
  final _motivo = TextEditingController();

  String _tipoVivienda = 'casa';
  String _viviendaPropia = 'propia';
  ArchivoElegido? _identificacion;
  ArchivoElegido? _domicilio;
  final List<ArchivoElegido> _fotosVivienda = [];
  bool _acepta = false;
  bool _enviando = false;
  bool _intentoEnviar = false;

  @override
  void initState() {
    super.initState();
    final sesion = SesionService.instancia.actual;
    _nombre.text = sesion?.nombre ?? '';
    _correo.text = sesion?.correo ?? '';
  }

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _telefono, _direccion, _ocupacion, _otrasMascotas, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : _oscuro),
    );
  }

  Future<ArchivoElegido?> _elegir({required bool soloImagenes}) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: soloImagenes ? const ['jpg', 'jpeg', 'png'] : const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final archivo = resultado?.files.single;
    if (archivo == null || archivo.bytes == null || !mounted) return null;
    if (archivo.size > _maxBytes) {
      _aviso('«${archivo.name}» pesa más de 5 MB. Elige uno más ligero.', error: true);
      return null;
    }
    return ArchivoElegido(nombre: archivo.name, bytes: archivo.bytes!, mime: ArchivoElegido.mimeDe(archivo.name));
  }

  bool get _documentosCompletos => _identificacion != null && _domicilio != null && _fotosVivienda.isNotEmpty;

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intentoEnviar = true);
    final formularioOk = _formKey.currentState!.validate();
    if (!formularioOk || !_documentosCompletos || !_acepta) {
      _aviso(!formularioOk
          ? 'Revisa los campos marcados en rojo.'
          : !_documentosCompletos
              ? 'Adjunta tu identificación, el comprobante de domicilio y al menos una foto del espacio.'
              : 'Acepta que el refugio revise tus datos y documentos.', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      await AdopcionService.instancia.solicitar(
        mascotaId: widget.mascota.id,
        datos: {
          'nombre': _nombre.text.trim(),
          'correo': _correo.text.trim(),
          'telefono': _telefono.text.trim(),
          'direccion': _direccion.text.trim(),
          'ocupacion': _ocupacion.text.trim(),
          'tipoVivienda': _tipoVivienda,
          'viviendaPropia': _viviendaPropia,
          'otrasMascotas': _otrasMascotas.text.trim(),
          'motivo': _motivo.text.trim(),
        },
        identificacion: _identificacion!,
        domicilio: _domicilio!,
        vivienda: _fotosVivienda,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('¡Solicitud enviada! 🐾'),
          content: Text(
            '${widget.nombreRefugio} revisará tu solicitud para adoptar a ${widget.mascota.nombre}. '
            'Puedes ver su estado en «Mis solicitudes» (menú de tu cuenta).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogo), child: const Text('Listo')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MisSolicitudesScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _aviso(e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mascota;
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: _turquesa,
        foregroundColor: Colors.black,
        title: Text('Adoptar a ${m.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(children: [
        Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _tarjeta([
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FotoHuellApp(m.fotos.isEmpty ? '' : m.fotos.first, width: 72, height: 72),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('${m.tipo} · ${m.edad}', style: const TextStyle(color: Colors.black54)),
                          Text(widget.nombreRefugio, style: const TextStyle(color: _oscuro, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    const Text(
                      'El refugio usará estos datos solo para evaluar la adopción. Revisa antes sus requisitos.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ]),
                  _titulo('Tus datos'),
                  _tarjeta([
                    _campo(_nombre, 'Nombre completo', Icons.person_outline, min: 3, max: 100),
                    _campo(_correo, 'Correo', Icons.email_outlined, teclado: TextInputType.emailAddress, max: 120,
                        validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Escribe un correo válido'),
                    _campo(_telefono, 'Teléfono (10 dígitos)', Icons.phone_outlined, teclado: TextInputType.phone, max: 20,
                        validar: (v) => v.replaceAll(RegExp(r'\D'), '').length >= 10 ? null : 'Escribe un teléfono de 10 dígitos'),
                    _campo(_direccion, 'Dirección (calle, número, colonia, municipio)', Icons.home_outlined, min: 8, max: 200),
                    _campo(_ocupacion, 'Ocupación (opcional)', Icons.work_outline, max: 100, opcional: true),
                  ]),
                  _titulo('Tu hogar'),
                  _tarjeta([
                    DropdownButtonFormField<String>(
                      initialValue: _tipoVivienda,
                      decoration: _decoracion('Tipo de vivienda', Icons.house_outlined),
                      items: const [
                        DropdownMenuItem(value: 'casa', child: Text('Casa')),
                        DropdownMenuItem(value: 'departamento', child: Text('Departamento')),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (v) => setState(() => _tipoVivienda = v ?? 'casa'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _viviendaPropia,
                      decoration: _decoracion('La vivienda es…', Icons.key_outlined),
                      items: const [
                        DropdownMenuItem(value: 'propia', child: Text('Propia')),
                        DropdownMenuItem(value: 'rentada', child: Text('Rentada')),
                        DropdownMenuItem(value: 'familiar', child: Text('De un familiar')),
                      ],
                      onChanged: (v) => setState(() => _viviendaPropia = v ?? 'propia'),
                    ),
                    _campo(_otrasMascotas, '¿Tienes otras mascotas? ¿Cuáles? (opcional)', Icons.pets, max: 200, opcional: true),
                    _campo(_motivo, '¿Por qué quieres adoptar a ${m.nombre}?', Icons.favorite_outline,
                        min: 20, max: 800, lineas: 4),
                  ]),
                  _titulo('Documentos'),
                  _tarjeta([
                    _documento(
                      'Identificación oficial (INE, pasaporte…)',
                      _identificacion,
                      () async {
                        final a = await _elegir(soloImagenes: false);
                        if (a != null) setState(() => _identificacion = a);
                      },
                    ),
                    _documento(
                      'Comprobante de domicilio',
                      _domicilio,
                      () async {
                        final a = await _elegir(soloImagenes: false);
                        if (a != null) setState(() => _domicilio = a);
                      },
                    ),
                    const Text('Fotos del espacio donde vivirá (1 a 3)', style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in _fotosVivienda)
                        InputChip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: Text(f.nombre, overflow: TextOverflow.ellipsis),
                          onDeleted: () => setState(() => _fotosVivienda.remove(f)),
                        ),
                      if (_fotosVivienda.length < _maxFotosVivienda)
                        ActionChip(
                          avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: const Text('Agregar foto'),
                          onPressed: () async {
                            final a = await _elegir(soloImagenes: true);
                            if (a != null) setState(() => _fotosVivienda.add(a));
                          },
                        ),
                    ]),
                    if (_intentoEnviar && !_documentosCompletos)
                      Text('Faltan documentos por adjuntar.', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    const Text('PDF, JPG o PNG de hasta 5 MB cada uno. Solo el refugio puede verlos.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                  CheckboxListTile(
                    value: _acepta,
                    activeColor: _oscuro,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _acepta = v ?? false),
                    title: const Text('Acepto que el refugio revise mis datos y documentos para evaluar la adopción.',
                        style: TextStyle(fontSize: 13)),
                    subtitle: _intentoEnviar && !_acepta
                        ? Text('Necesitamos tu aceptación.', style: TextStyle(color: Colors.red.shade700, fontSize: 12))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _enviando ? null : _enviar,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _turquesa,
                        foregroundColor: const Color(0xFF14312E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        if (_enviando)
          Container(
            color: Colors.black45,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: _oscuro),
                    SizedBox(height: 12),
                    Text('Enviando tu solicitud y documentos…'),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _oscuro)),
      );

  Widget _tarjeta(List<Widget> hijos) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final h in hijos) Padding(padding: const EdgeInsets.only(bottom: 12), child: h)],
        ),
      );

  InputDecoration _decoracion(String etiqueta, IconData icono) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _campo(
    TextEditingController c,
    String etiqueta,
    IconData icono, {
    int min = 1,
    int max = 200,
    int lineas = 1,
    bool opcional = false,
    TextInputType? teclado,
    String? Function(String)? validar,
  }) =>
      TextFormField(
        controller: c,
        keyboardType: teclado ?? (lineas > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: lineas,
        maxLength: max,
        decoration: _decoracion(etiqueta, icono).copyWith(counterText: lineas > 1 ? null : ''),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return opcional ? null : 'Este dato es obligatorio';
          if (t.length < min) return 'Escribe al menos $min caracteres';
          return validar?.call(t);
        },
      );

  Widget _documento(String etiqueta, ArchivoElegido? archivo, VoidCallback elegir) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(archivo == null ? Icons.upload_file : Icons.check_circle,
            color: archivo == null ? (_intentoEnviar ? Colors.red.shade700 : _oscuro) : Colors.green),
        title: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(archivo?.nombre ?? 'Sin archivo', overflow: TextOverflow.ellipsis),
        trailing: TextButton(onPressed: elegir, child: Text(archivo == null ? 'Elegir' : 'Cambiar')),
      );
}
