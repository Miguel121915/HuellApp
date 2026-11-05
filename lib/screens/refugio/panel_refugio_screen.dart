import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/sesion_service.dart';
import '../../services/refugio_service.dart';
import '../../widgets/foto_huellapp.dart';
import '../../widgets/selector_ubicacion.dart';
import '../login_screen.dart';
import 'mascota_form_screen.dart';

const Color _turquoise = Color(0xFF75E6DA);
const Color _accent = Color(0xFF1B4F4A);
const Color _fondo = Color(0xFFE6F8F5);
const Color _tinta = Color(0xFF14312E);

const Map<String, String> _estatusTexto = {
  'disponible': 'Disponible',
  'en proceso': 'En proceso',
  'adoptado': 'Adoptado',
};
const Map<String, Color> _estatusColor = {
  'disponible': Color(0xFF1F7A52),
  'en proceso': Color(0xFFB7791F),
  'adoptado': Color(0xFF5B5BB0),
};

/// Panel del refugio en la app móvil (lo que ve un refugio aprobado al iniciar sesión):
/// Resumen, Inventario de mascotas y Perfil. Mismas funciones que el panel del sitio web.
class PanelRefugioScreen extends StatefulWidget {
  const PanelRefugioScreen({super.key});

  @override
  State<PanelRefugioScreen> createState() => _PanelRefugioScreenState();
}

class _PanelRefugioScreenState extends State<PanelRefugioScreen> {
  int _indice = 0;
  // Se incrementa cuando cambia el inventario, para que el Resumen se recargue
  int _version = 0;

  void _inventarioCambio() => setState(() => _version++);

  Future<void> _salir() async {
    await SesionService.instancia.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = SesionService.instancia.actual;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _turquoise,
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: const Text(
          'HuellApp',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 26, fontStyle: FontStyle.italic),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle, color: Colors.black, size: 32),
            onSelected: (v) {
              if (v == 'salir') _salir();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(sesion?.nombre ?? 'Refugio')),
              const PopupMenuItem(value: 'salir', child: ListTile(leading: Icon(Icons.logout), title: Text('Cerrar sesión'))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          _ResumenTab(key: ValueKey('resumen-$_version'), onIrAInventario: () => setState(() => _indice = 1)),
          _InventarioTab(onCambio: _inventarioCambio),
          const _PerfilTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        backgroundColor: Colors.white,
        indicatorColor: _turquoise,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Panel'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Muestra "cargando", un error con Reintentar o el contenido.
Widget _segunEstado({required bool cargando, required String? error, required VoidCallback reintentar, required Widget Function() contenido}) {
  if (cargando) return const Center(child: CircularProgressIndicator(color: _accent));
  if (error != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: reintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
  return contenido();
}

/* ======================= Resumen ======================= */

class _ResumenTab extends StatefulWidget {
  const _ResumenTab({super.key, required this.onIrAInventario});

  final VoidCallback onIrAInventario;

  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab> {
  Map<String, dynamic>? _datos;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await RefugioService.instancia.resumen();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Widget _cifra(String etiqueta, Object? valor, Color color) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text('${valor ?? 0}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(etiqueta, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _segunEstado(
      cargando: _cargando,
      error: _error,
      reintentar: _cargar,
      contenido: () {
        final d = _datos!;
        final recientes = (d['recientes'] as List? ?? []).cast<Map<String, dynamic>>().map(MascotaInventario.new).toList();
        return RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '¡Hola, ${SesionService.instancia.actual?.nombre ?? ''}!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _tinta),
              ),
              const Text('Así va tu refugio en HuellApp', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(children: [
                _cifra('Mascotas', d['total'], _tinta),
                _cifra('Disponibles', d['disponibles'], _estatusColor['disponible']!),
              ]),
              Row(children: [
                _cifra('En proceso', d['enProceso'], _estatusColor['en proceso']!),
                _cifra('Adoptadas', d['adoptadas'], _estatusColor['adoptado']!),
              ]),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Agregadas recientemente', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  TextButton(onPressed: widget.onIrAInventario, child: const Text('Ver inventario ›')),
                ],
              ),
              if (recientes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no tienes mascotas. Agrégalas desde Inventario.'),
                )
              else
                for (final m in recientes) _FilaMascota(mascota: m),
            ],
          ),
        );
      },
    );
  }
}

class _FilaMascota extends StatelessWidget {
  const _FilaMascota({required this.mascota, this.alTocar, this.acciones});

  final MascotaInventario mascota;
  final VoidCallback? alTocar;
  final Widget? acciones;

  @override
  Widget build(BuildContext context) {
    final color = _estatusColor[mascota.estatus] ?? _accent;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: alTocar,
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FotoHuellApp(mascota.fotoUrl, width: 56, height: 56),
        ),
        title: Text(mascota.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${mascota.especie == 'gato' ? 'Gato' : 'Perro'} · ${mascota.raza}'),
        trailing: acciones ??
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(_estatusTexto[mascota.estatus] ?? mascota.estatus, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
      ),
    );
  }
}

/* ======================= Inventario ======================= */

class _InventarioTab extends StatefulWidget {
  const _InventarioTab({required this.onCambio});

  final VoidCallback onCambio;

  @override
  State<_InventarioTab> createState() => _InventarioTabState();
}

class _InventarioTabState extends State<_InventarioTab> {
  List<MascotaInventario> _mascotas = [];
  String? _error;
  bool _cargando = true;
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mascotas = await RefugioService.instancia.mascotas();
      if (!mounted) return;
      setState(() {
        _mascotas = mascotas;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _abrirFormulario([MascotaInventario? mascota]) async {
    final guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MascotaFormScreen(mascota: mascota)),
    );
    if (guardo == true) {
      await _cargar();
      widget.onCambio();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mascota == null ? 'Mascota agregada' : 'Cambios guardados')),
      );
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion, String mensaje) async {
    try {
      await accion();
      await _cargar();
      widget.onCambio();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _eliminar(MascotaInventario m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar a ${m.nombre}?'),
        content: const Text('También se borrarán sus publicaciones y documentos. Esto no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _ejecutar(() => RefugioService.instancia.eliminarMascota(m.id), '${m.nombre} se eliminó del inventario');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _filtro == 'todas' ? _mascotas : _mascotas.where((m) => m.estatus == _filtro).toList();
    return Scaffold(
      backgroundColor: _fondo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar mascota'),
      ),
      body: _segunEstado(
        cargando: _cargando,
        error: _error,
        reintentar: _cargar,
        contenido: () => RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in const {'todas': 'Todas', ..._estatusTexto}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.value),
                          selected: _filtro == f.key,
                          selectedColor: _turquoise,
                          onSelected: (_) => setState(() => _filtro = f.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay mascotas en esta lista.', textAlign: TextAlign.center),
                )
              else
                for (final m in visibles)
                  _FilaMascota(
                    mascota: m,
                    alTocar: () => _abrirFormulario(m),
                    acciones: PopupMenuButton<String>(
                      tooltip: 'Acciones',
                      onSelected: (accion) {
                        if (accion == 'editar') {
                          _abrirFormulario(m);
                        } else if (accion == 'eliminar') {
                          _eliminar(m);
                        } else {
                          _ejecutar(
                            () => RefugioService.instancia.cambiarEstatus(m.id, accion),
                            '${m.nombre}: ${_estatusTexto[accion]}',
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'editar', child: Text('Editar')),
                        for (final e in _estatusTexto.entries)
                          if (e.key != m.estatus) PopupMenuItem(value: e.key, child: Text('Marcar como ${e.value.toLowerCase()}')),
                        const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _estatusTexto[m.estatus] ?? m.estatus,
                              style: TextStyle(color: _estatusColor[m.estatus], fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const Icon(Icons.more_vert),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ======================= Perfil ======================= */

class _PerfilTab extends StatefulWidget {
  const _PerfilTab();

  @override
  State<_PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<_PerfilTab> {
  final _formKey = GlobalKey<FormState>();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _horario = TextEditingController();
  final _descripcion = TextEditingController();
  final _whatsapp = TextEditingController();
  final _municipio = TextEditingController();
  final _cp = TextEditingController();
  final _redes = TextEditingController();
  final _necesidades = TextEditingController();
  bool _perros = true;
  bool _gatos = true;
  double? _lat;
  double? _lng;

  Map<String, dynamic>? _refugio;
  String? _error;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_telefono, _direccion, _horario, _descripcion, _whatsapp, _municipio, _cp, _redes, _necesidades]) {
      c.dispose();
    }
    super.dispose();
  }

  void _rellenar(Map<String, dynamic> r) {
    List<String> lista(dynamic v) => v is List ? v.map((e) => '$e').toList() : <String>[];
    _telefono.text = r['telefono'] as String? ?? '';
    _direccion.text = r['direccion'] as String? ?? '';
    _horario.text = r['horario'] as String? ?? '';
    _descripcion.text = r['descripcion'] as String? ?? '';
    _whatsapp.text = r['whatsapp'] as String? ?? '';
    _municipio.text = r['municipio'] as String? ?? '';
    _cp.text = r['codigoPostal'] as String? ?? '';
    _redes.text = lista(r['redes']).join('\n');
    _necesidades.text = lista(r['necesidades']).join('\n');
    _perros = r['tienePerros'] as bool? ?? true;
    _gatos = r['tieneGatos'] as bool? ?? true;
    _lat = (r['latitud'] as num?)?.toDouble();
    _lng = (r['longitud'] as num?)?.toDouble();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await RefugioService.instancia.miRefugio();
      if (!mounted) return;
      setState(() {
        _refugio = r;
        _rellenar(r);
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    List<String> lineas(TextEditingController c) =>
        c.text.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    setState(() => _guardando = true);
    try {
      final r = await RefugioService.instancia.actualizarPerfil({
        'telefono': _telefono.text.trim(),
        'direccion': _direccion.text.trim(),
        'horario': _horario.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'municipio': _municipio.text.trim(),
        'codigoPostal': _cp.text.trim(),
        'redes': lineas(_redes).take(5).toList(),
        'necesidades': lineas(_necesidades).take(10).toList(),
        'tienePerros': _perros,
        'tieneGatos': _gatos,
        'latitud': _lat,
        'longitud': _lng,
      });
      if (!mounted) return;
      setState(() {
        _refugio = r;
        _guardando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
    }
  }

  InputDecoration _decoracion(String etiqueta, {String? ayuda}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _campo(TextEditingController c, String etiqueta,
      {String? ayuda, int lineas = 1, TextInputType? teclado, String? Function(String?)? validar}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: lineas,
        keyboardType: teclado,
        decoration: _decoracion(etiqueta, ayuda: ayuda),
        validator: validar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _segunEstado(
      cargando: _cargando,
      error: _error,
      reintentar: _cargar,
      contenido: () {
        final r = _refugio!;
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: _turquoise, child: Icon(Icons.verified, color: _accent)),
                  title: Text(r['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Refugio verificado\nResponsable: ${r['responsable'] ?? ''} · ${r['correo'] ?? ''}'),
                  isThreeLine: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Text(
                  'El nombre, el responsable y el correo solo los cambia el administrador.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              _campo(_telefono, 'Teléfono', teclado: TextInputType.phone, validar: (v) {
                final t = (v ?? '').trim();
                return RegExp(r'^[\d\s+()\-]{8,}$').hasMatch(t) ? null : 'Al menos 8 dígitos';
              }),
              _campo(_whatsapp, 'WhatsApp (opcional)', teclado: TextInputType.phone, validar: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || RegExp(r'^[\d\s+()\-]{8,}$').hasMatch(t) ? null : 'Al menos 8 dígitos';
              }),
              _campo(_direccion, 'Dirección', validar: (v) => (v ?? '').trim().length < 5 ? 'Escribe la dirección completa' : null),
              _campo(_municipio, 'Municipio o alcaldía (opcional)'),
              _campo(_cp, 'Código postal (opcional)', teclado: TextInputType.number, validar: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || RegExp(r'^\d{5}$').hasMatch(t) ? null : '5 dígitos';
              }),
              _campo(_horario, 'Horario', ayuda: 'Ejemplo: 09:00 - 18:00', validar: (v) {
                final m = RegExp(r'^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$').firstMatch((v ?? '').trim());
                if (m == null) return 'Escríbelo como 09:00 - 18:00';
                return '${m[3]}:${m[4]}'.compareTo('${m[1]}:${m[2]}') <= 0 ? 'El cierre debe ser después de la apertura' : null;
              }),
              _campo(_descripcion, 'Sobre el refugio (opcional)', lineas: 3, validar: (v) => (v ?? '').length > 400 ? 'Máximo 400 caracteres' : null),
              _campo(_redes, 'Redes sociales (una por línea)', lineas: 3),
              _campo(_necesidades, '¿Qué necesitan? (una por línea)', lineas: 3),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                title: const Text('Recibimos perros 🐶'),
                value: _perros,
                onChanged: (v) => setState(() => _perros = v ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                title: const Text('Recibimos gatos 🐱'),
                value: _gatos,
                onChanged: (v) => setState(() => _gatos = v ?? true),
              ),
              const SizedBox(height: 8),
              SelectorUbicacion(
                latitud: _lat,
                longitud: _lng,
                onCambio: (punto) => setState(() {
                  _lat = punto?.latitude;
                  _lng = punto?.longitude;
                }),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
