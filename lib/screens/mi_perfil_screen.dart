import 'package:flutter/material.dart';

import '../core/api_client.dart';
import 'seguridad_screen.dart';

/// Mi perfil (usuario): datos de la cuenta, mi actividad y los datos que se pueden editar
/// (teléfono, ciudad y datos del hogar). Igual que «Mi perfil» del sitio web (GET/PUT /api/perfil).
/// El nombre y el correo no se editan: identifican la cuenta.
class MiPerfilScreen extends StatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  State<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends State<MiPerfilScreen> {
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _muted = Color(0xFF3F5F5B);
  static const int _maxSobreMi = 300;
  static const Map<String, String> _viviendas = {
    'casa': 'Casa',
    'departamento': 'Departamento',
    'otro': 'Otro',
    '': 'Prefiero no decir',
  };
  static const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  final _formulario = GlobalKey<FormState>();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _ocupacion = TextEditingController();
  final _otrasMascotas = TextEditingController();
  final _sobreMi = TextEditingController();
  String _vivienda = '';

  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  Map<String, dynamic> _perfil = {};
  Map<String, dynamic> _actividad = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_telefono, _ciudad, _ocupacion, _otrasMascotas, _sobreMi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ApiClient.instancia.get('/perfil');
      if (!mounted) return;
      _mostrar(r);
      setState(() => _cargando = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _mostrar(Map<String, dynamic> r) {
    _perfil = (r['perfil'] as Map?)?.cast<String, dynamic>() ?? {};
    _actividad = (r['actividad'] as Map?)?.cast<String, dynamic>() ?? {};
    _telefono.text = _texto('telefono');
    _ciudad.text = _texto('ciudad');
    _ocupacion.text = _texto('ocupacion');
    _otrasMascotas.text = _texto('otrasMascotas');
    _sobreMi.text = _texto('sobreMi');
    _vivienda = _viviendas.containsKey(_texto('tipoVivienda')) ? _texto('tipoVivienda') : '';
  }

  String _texto(String clave) => '${_perfil[clave] ?? ''}';

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final r = await ApiClient.instancia.put('/perfil', {
        'telefono': _telefono.text.trim(),
        'ciudad': _ciudad.text.trim(),
        'ocupacion': _ocupacion.text.trim(),
        'tipoVivienda': _vivienda,
        'otrasMascotas': _otrasMascotas.text.trim(),
        'sobreMi': _sobreMi.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _mostrar(r);
        _guardando = false;
      });
      _aviso('¡Listo! Guardamos los cambios de tu perfil.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso(e.mensaje, error: true);
    }
  }

  Future<void> _abrirSeguridad() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SeguridadScreen()));
    if (mounted) _cargar(); // por si activó o quitó la verificación en dos pasos
  }

  void _aviso(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  /// "2026-10-15T14:30:00.123Z" → "15 oct 2026"
  String _fecha(String? iso) {
    final f = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return f == null ? '' : '${f.day} ${_meses[f.month - 1]} ${f.year}';
  }

  String get _iniciales {
    final partes = _texto('nombre').split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return partes.map((p) => p[0].toUpperCase()).join();
  }

  /* ---------- Validaciones (las mismas que revisa el servidor) ---------- */

  String? _validarTelefono(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    return RegExp(r'^[\d\s+()\-]{8,}$').hasMatch(t) ? null : 'Usa solo números, espacios, + - y paréntesis (mínimo 8).';
  }

  String? _minimo2(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty || t.length >= 2 ? null : 'Escribe al menos 2 letras.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: _turquoise,
        foregroundColor: Colors.black,
        title: const Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _contenido(),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _tarjeta([
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _cuenta(),
          const SizedBox(height: 16),
          _actividadTarjeta(),
          const SizedBox(height: 16),
          _formularioTarjeta(),
        ],
      ),
    );
  }

  Widget _cuenta() {
    final dosPasos = _perfil['dosPasos'] == true;
    final desde = _fecha(_perfil['miembroDesde'] as String?);
    return _tarjeta([
      Center(
        child: CircleAvatar(
          radius: 40,
          backgroundColor: _turquoise,
          child: _iniciales.isEmpty
              ? const Icon(Icons.pets, size: 36, color: Colors.black)
              : Text(_iniciales, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
      ),
      const SizedBox(height: 10),
      Text(_texto('nombre'),
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _accent)),
      if (desde.isNotEmpty)
        Text('En HuellApp desde el $desde', textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13)),
      const Divider(height: 28),
      _datoFijo('Correo', _texto('correo'), Icons.mail_outline),
      _datoFijo('Inicio de sesión', _perfil['conGoogle'] == true ? 'Contraseña o cuenta de Google' : 'Correo y contraseña',
          Icons.login),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(dosPasos ? Icons.verified_user : Icons.lock_open, color: _accent),
        title: const Text('Verificación en dos pasos', style: TextStyle(fontSize: 13, color: _muted)),
        subtitle: Text(dosPasos ? 'Activada' : 'Desactivada',
            style: TextStyle(fontWeight: FontWeight.w700, color: dosPasos ? Colors.green.shade800 : Colors.orange.shade900)),
        trailing: TextButton(onPressed: _abrirSeguridad, child: const Text('Cambiar', style: TextStyle(color: _accent))),
      ),
      const SizedBox(height: 4),
      const Text('Tu nombre y tu correo identifican tu cuenta, por eso no se cambian desde aquí.',
          style: TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _datoFijo(String etiqueta, String valor, IconData icono) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icono, color: _accent),
        title: Text(etiqueta, style: const TextStyle(fontSize: 13, color: _muted)),
        subtitle: Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
      );

  Widget _actividadTarjeta() {
    Widget cuadro(String clave, String etiqueta, IconData icono) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F8F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF9ED9D1), width: 2),
            ),
            child: Column(children: [
              Icon(icono, color: _accent, size: 20),
              Text('${_actividad[clave] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(etiqueta, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _muted)),
            ]),
          ),
        );
    return _tarjeta([
      _titulo(Icons.insights, 'Mi actividad'),
      const SizedBox(height: 12),
      Row(children: [
        cuadro('reportes', 'Reportes', Icons.photo_camera_outlined),
        const SizedBox(width: 8),
        cuadro('favoritos', 'Favoritos', Icons.favorite_border),
        const SizedBox(width: 8),
        cuadro('solicitudes', 'Adopciones', Icons.description_outlined),
        const SizedBox(width: 8),
        cuadro('publicaciones', 'En el foro', Icons.forum_outlined),
      ]),
    ]);
  }

  Widget _formularioTarjeta() => _tarjeta([
        Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titulo(Icons.contact_phone_outlined, 'Datos de contacto'),
              const SizedBox(height: 12),
              _campo(_telefono, 'Teléfono (opcional)',
                  teclado: TextInputType.phone, maximo: 25, validar: _validarTelefono, pista: 'Ej. 55 1234 5678'),
              _campo(_ciudad, 'Ciudad o municipio (opcional)', maximo: 80, validar: _minimo2, pista: 'Ej. Puebla'),
              const SizedBox(height: 8),
              _titulo(Icons.home_outlined, 'Sobre mi hogar'),
              const SizedBox(height: 4),
              const Text('Estos datos te ayudan a llenar más rápido tus solicitudes de adopción.',
                  style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 12),
              _campo(_ocupacion, 'Ocupación (opcional)', maximo: 100, validar: _minimo2),
              const Text('Tipo de vivienda (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _viviendas.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _vivienda == e.key,
                          selectedColor: _turquoise,
                          onSelected: (_) => setState(() => _vivienda = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              _campo(_otrasMascotas, '¿Tienes otras mascotas? (opcional)',
                  maximo: 200, pista: 'Ej. Una gata de 3 años, esterilizada'),
              _campo(_sobreMi, 'Sobre mí (opcional)',
                  maximo: _maxSobreMi, lineas: 4, pista: 'Cuéntanos un poco de ti y qué tipo de compañero buscas.'),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _turquoise,
                    foregroundColor: const Color(0xFF14312E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]);

  Widget _campo(
    TextEditingController controlador,
    String etiqueta, {
    TextInputType? teclado,
    int? maximo,
    int lineas = 1,
    String? pista,
    String? Function(String?)? validar,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controlador,
          keyboardType: lineas > 1 ? TextInputType.multiline : teclado,
          maxLength: maximo,
          minLines: lineas,
          maxLines: lineas,
          validator: validar,
          decoration: InputDecoration(
            labelText: etiqueta,
            hintText: pista,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _tarjeta(List<Widget> hijos) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
      );

  Widget _titulo(IconData icono, String texto) => Row(children: [
        Icon(icono, color: _accent),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _accent))),
      ]);
}
