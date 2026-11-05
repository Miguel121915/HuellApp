import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../services/refugio_service.dart';
import '../../widgets/foto_huellapp.dart';

// Secciones del panel del refugio que también tiene el sitio web:
// Publicaciones, Adopciones (solicitudes recibidas) y Preguntas frecuentes.

const Color _turquoise = Color(0xFF75E6DA);
const Color _accent = Color(0xFF1B4F4A);
const Color _fondo = Color(0xFFE6F8F5);

/// Base común: carga una lista de la API y muestra cargando / error / vacío / contenido.
abstract class _SeccionState<T extends StatefulWidget> extends State<T> {
  List<Map<String, dynamic>> datos = [];
  String? error;
  bool cargando = true;

  Future<List<Map<String, dynamic>>> pedir();

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final r = await pedir();
      if (!mounted) return;
      setState(() {
        datos = r;
        cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.mensaje;
        cargando = false;
      });
    }
  }

  /// Ejecuta una acción contra la API, recarga y avisa con un SnackBar.
  Future<bool> ejecutar(Future<void> Function() accion, String mensaje) async {
    try {
      await accion();
      await cargar();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
      return false;
    }
  }

  Future<bool> confirmar(String titulo, String texto, {String accion = 'Eliminar'}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(accion, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    return r == true;
  }

  Widget envolver({required String vacio, required Widget Function() lista, Widget? boton}) {
    Widget cuerpo;
    if (cargando) {
      cuerpo = const Center(child: CircularProgressIndicator(color: _accent));
    } else if (error != null) {
      cuerpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: cargar, child: const Text('Reintentar')),
          ]),
        ),
      );
    } else if (datos.isEmpty) {
      cuerpo = RefreshIndicator(
        onRefresh: cargar,
        child: ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Text(vacio, textAlign: TextAlign.center))]),
      );
    } else {
      cuerpo = RefreshIndicator(onRefresh: cargar, child: lista());
    }
    return Scaffold(backgroundColor: _fondo, floatingActionButton: boton, body: cuerpo);
  }
}

InputDecoration _decoracion(String etiqueta, {String? ayuda}) => InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      helperMaxLines: 2,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

/* ======================= Publicaciones ======================= */

class PublicacionesTab extends StatefulWidget {
  const PublicacionesTab({super.key});

  @override
  State<PublicacionesTab> createState() => _PublicacionesTabState();
}

class _PublicacionesTabState extends _SeccionState<PublicacionesTab> {
  @override
  Future<List<Map<String, dynamic>>> pedir() => RefugioService.instancia.publicaciones();

  Future<void> _formulario([Map<String, dynamic>? publicacion]) async {
    final guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PublicacionForm(publicacion: publicacion)),
    );
    if (guardo == true) {
      await cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicacion == null ? 'Publicación creada' : 'Publicación actualizada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return envolver(
      vacio: 'Aún no tienes publicaciones. Publica una mascota para que más personas la conozcan.',
      boton: FloatingActionButton.extended(
        onPressed: () => _formulario(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign),
        label: const Text('Nueva publicación'),
      ),
      lista: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: datos.length,
        itemBuilder: (context, i) {
          final p = datos[i];
          final cada = p['republicarCadaDias'];
          final proxima = fechaCorta(p['proximaRepublicacion'] as String?);
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FotoHuellApp(ApiConfig.urlArchivo(p['foto'] as String? ?? ''), height: 170, width: double.infinity),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p['mascotaNombre'] ?? ''} · ${fechaCorta(p['fecha'] as String?)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (a) async {
                          if (a == 'editar') {
                            _formulario(p);
                          } else if (await confirmar('¿Eliminar publicación?', 'Dejará de verse en tu perfil público.')) {
                            ejecutar(() => RefugioService.instancia.eliminarPublicacion('${p['id']}'), 'Publicación eliminada');
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'editar', child: Text('Editar')),
                          PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(p['texto'] as String? ?? ''),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(
                    p['mascotaEstatus'] == 'adoptado'
                        ? 'Mascota adoptada: ya no se muestra a los usuarios'
                        : cada == null
                            ? 'Sin republicación automática'
                            : 'Se republica cada $cada días${proxima.isEmpty ? '' : ' · próxima: $proxima'}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PublicacionForm extends StatefulWidget {
  const _PublicacionForm({this.publicacion});

  final Map<String, dynamic>? publicacion;

  @override
  State<_PublicacionForm> createState() => _PublicacionFormState();
}

class _PublicacionFormState extends State<_PublicacionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _texto;
  List<MascotaInventario> _mascotas = [];
  String? _mascotaId;
  int? _cadaDias;
  ArchivoElegido? _foto;
  bool _guardando = false;
  bool _cargandoMascotas = true;

  bool get _esNueva => widget.publicacion == null;

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.publicacion?['texto'] as String? ?? '');
    _cadaDias = (widget.publicacion?['republicarCadaDias'] as num?)?.toInt();
    if (_esNueva) {
      RefugioService.instancia.mascotas().then((m) {
        if (!mounted) return;
        setState(() {
          _mascotas = m.where((x) => x.estatus != 'adoptado').toList();
          _cargandoMascotas = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _cargandoMascotas = false);
      });
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    setState(() => _foto = ArchivoElegido(nombre: archivo.name, bytes: bytes, mime: ArchivoElegido.mimeDe(archivo.name)));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await RefugioService.instancia.guardarPublicacion({
        if (_esNueva) 'mascotaId': _mascotaId,
        'texto': _texto.text.trim(),
        'republicarCadaDias': _cadaDias,
        if (_foto != null) 'foto': _foto!.dataUrl,
      }, id: _esNueva ? null : '${widget.publicacion!['id']}');
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(backgroundColor: _turquoise, title: Text(_esNueva ? 'Nueva publicación' : 'Editar publicación')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_esNueva)
              _cargandoMascotas
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _mascotaId,
                      decoration: _decoracion('Mascota', ayuda: 'Solo mascotas disponibles o en proceso'),
                      items: [for (final m in _mascotas) DropdownMenuItem(value: m.id, child: Text(m.nombre))],
                      onChanged: (v) => setState(() => _mascotaId = v),
                      validator: (v) => v == null ? 'Elige una mascota' : null,
                    )
            else
              Text('Mascota: ${widget.publicacion!['mascotaNombre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _texto,
              maxLines: 5,
              decoration: _decoracion('Texto de la publicación'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 10) return 'Mínimo 10 caracteres';
                return t.length > 500 ? 'Máximo 500 caracteres' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _cadaDias,
              decoration: _decoracion('Republicar automáticamente', ayuda: 'Vuelve a aparecer arriba en tu perfil cada cierto tiempo'),
              items: const [
                DropdownMenuItem(value: null, child: Text('No republicar')),
                DropdownMenuItem(value: 7, child: Text('Cada 7 días')),
                DropdownMenuItem(value: 15, child: Text('Cada 15 días')),
                DropdownMenuItem(value: 30, child: Text('Cada 30 días')),
              ],
              onChanged: (v) => setState(() => _cadaDias = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirFoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_foto == null ? 'Foto propia (opcional; si no, se usa la de la mascota)' : 'Foto elegida: ${_foto!.nombre}'),
            ),
            if (_foto != null) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_foto!.bytes, height: 160, fit: BoxFit.cover)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
              child: Text(_guardando ? 'Guardando…' : (_esNueva ? 'Publicar' : 'Guardar cambios')),
            ),
          ],
        ),
      ),
    );
  }
}

/* ======================= Adopciones ======================= */

const Map<String, String> _estadosAdopcion = {
  'pendiente': 'Pendiente',
  'en revision': 'En revisión',
  'aprobada': 'Aprobada',
  'rechazada': 'Rechazada',
};
const Map<String, Color> _coloresAdopcion = {
  'pendiente': Color(0xFFB7791F),
  'en revision': Color(0xFF2B6CB0),
  'aprobada': Color(0xFF1F7A52),
  'rechazada': Color(0xFFC53030),
};

class AdopcionesTab extends StatefulWidget {
  const AdopcionesTab({super.key});

  @override
  State<AdopcionesTab> createState() => _AdopcionesTabState();
}

class _AdopcionesTabState extends _SeccionState<AdopcionesTab> {
  String _filtro = 'todas';

  @override
  Future<List<Map<String, dynamic>>> pedir() => RefugioService.instancia.adopciones();

  Future<void> _cambiarEstado(Map<String, dynamic> s, String estado) async {
    final nota = TextEditingController(text: s['notaRefugio'] as String? ?? '');
    final rechazar = estado == 'rechazada';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar como ${_estadosAdopcion[estado]!.toLowerCase()}'),
        content: TextField(
          controller: nota,
          maxLines: 3,
          maxLength: 400,
          decoration: _decoracion(rechazar ? 'Motivo (obligatorio)' : 'Nota para el solicitante (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (confirmado != true) return;
    if (rechazar && nota.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe el motivo del rechazo.')));
      return;
    }
    final ok = await ejecutar(
      () => RefugioService.instancia.cambiarEstadoAdopcion('${s['id']}', estado, nota.text.trim()),
      'Solicitud: ${_estadosAdopcion[estado]}',
    );
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  void _detalle(Map<String, dynamic> s) {
    String t(String clave) => (s[clave] as String? ?? '').trim();
    final vivienda = {'casa': 'Casa', 'departamento': 'Departamento', 'otro': 'Otro'}[t('tipoVivienda')] ?? t('tipoVivienda');
    final propia = {'propia': 'propia', 'rentada': 'rentada', 'familiar': 'familiar'}[t('viviendaPropia')] ?? t('viviendaPropia');
    final documentos = (s['documentos'] as List? ?? []).cast<Map<String, dynamic>>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (hoja) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Solicitud para adoptar a ${t('mascotaNombre')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Recibida el ${fechaCorta(s['fecha'] as String?)} · ${_estadosAdopcion[t('estado')] ?? t('estado')}'),
            const Divider(height: 24),
            for (final (etiqueta, valor) in [
              ('Solicitante', t('nombre')),
              ('Correo', t('correo')),
              ('Teléfono', t('telefono')),
              ('Dirección', t('direccion')),
              ('Ocupación', t('ocupacion')),
              ('Vivienda', '$vivienda ($propia)'),
              ('Otras mascotas', t('otrasMascotas')),
              ('¿Por qué quiere adoptar?', t('motivo')),
            ])
              if (valor.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(etiqueta, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(valor),
                  ]),
                ),
            if (documentos.isNotEmpty) ...[
              const Text('Documentos', style: TextStyle(fontSize: 12, color: Colors.black54)),
              for (final d in documentos) Text('• ${d['nombre']}'),
              const Text('Para abrirlos usa el panel del sitio web.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 10),
            ],
            if (t('notaRefugio').isNotEmpty) Text('Tu nota: ${t('notaRefugio')}', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _estadosAdopcion.entries)
                  if (e.key != 'pendiente' && e.key != t('estado'))
                    OutlinedButton(
                      onPressed: () => _cambiarEstado(s, e.key),
                      style: OutlinedButton.styleFrom(foregroundColor: _coloresAdopcion[e.key]),
                      child: Text(e.key == 'en revision' ? 'Poner en revisión' : e.key == 'aprobada' ? 'Aprobar' : 'Rechazar'),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _filtro == 'todas' ? datos : datos.where((s) => s['estado'] == _filtro).toList();
    return envolver(
      vacio: 'Todavía no recibes solicitudes de adopción.',
      lista: () => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in const {'todas': 'Todas', ..._estadosAdopcion}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.value),
                    selected: _filtro == f.key,
                    selectedColor: _turquoise,
                    onSelected: (_) => setState(() => _filtro = f.key),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          if (visibles.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No hay solicitudes en esta lista.', textAlign: TextAlign.center)),
          for (final s in visibles)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () => _detalle(s),
                contentPadding: const EdgeInsets.all(8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FotoHuellApp(ApiConfig.urlArchivo(s['mascotaFoto'] as String? ?? ''), width: 56, height: 56),
                ),
                title: Text('${s['nombre'] ?? ''} → ${s['mascotaNombre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Recibida el ${fechaCorta(s['fecha'] as String?)}'),
                trailing: Text(
                  _estadosAdopcion[s['estado']] ?? '${s['estado']}',
                  style: TextStyle(color: _coloresAdopcion[s['estado']], fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ======================= Preguntas frecuentes ======================= */

class PreguntasTab extends StatefulWidget {
  const PreguntasTab({super.key});

  @override
  State<PreguntasTab> createState() => _PreguntasTabState();
}

class _PreguntasTabState extends _SeccionState<PreguntasTab> {
  @override
  Future<List<Map<String, dynamic>>> pedir() => RefugioService.instancia.preguntas();

  Future<void> _formulario([Map<String, dynamic>? p]) async {
    final pregunta = TextEditingController(text: p?['pregunta'] as String? ?? '');
    final respuesta = TextEditingController(text: p?['respuesta'] as String? ?? '');
    final claves = TextEditingController(text: (p?['claves'] as List? ?? []).join(', '));
    var activa = p?['activa'] as bool? ?? true;
    final formKey = GlobalKey<FormState>();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) => AlertDialog(
          title: Text(p == null ? 'Nueva pregunta' : 'Editar pregunta'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: pregunta,
                  decoration: _decoracion('Pregunta'),
                  validator: (v) => (v ?? '').trim().length < 5 ? 'Mínimo 5 caracteres' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: respuesta,
                  maxLines: 4,
                  decoration: _decoracion('Respuesta'),
                  validator: (v) => (v ?? '').trim().length < 10 ? 'Mínimo 10 caracteres' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: claves,
                  decoration: _decoracion('Palabras clave (separadas por comas)', ayuda: 'Ayudan al asistente a encontrar esta respuesta'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible para los usuarios'),
                  value: activa,
                  onChanged: (v) => setDialogo(() => activa = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (guardar != true) return;
    await ejecutar(
      () => RefugioService.instancia.guardarPregunta({
        'pregunta': pregunta.text.trim(),
        'respuesta': respuesta.text.trim(),
        'claves': claves.text,
        'activa': activa,
      }, id: p == null ? null : '${p['id']}'),
      p == null ? 'Pregunta agregada' : 'Pregunta actualizada',
    );
  }

  @override
  Widget build(BuildContext context) {
    return envolver(
      vacio: 'Agrega las preguntas que más te hacen (requisitos, visitas, costos…). '
          'El asistente del formulario de adopción las usará para responder a los usuarios.',
      boton: FloatingActionButton.extended(
        onPressed: () => _formulario(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva pregunta'),
      ),
      lista: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: datos.length,
        itemBuilder: (context, i) {
          final p = datos[i];
          final activa = p['activa'] as bool? ?? true;
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(activa ? Icons.visibility : Icons.visibility_off, color: activa ? _accent : Colors.grey),
              title: Text(p['pregunta'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['respuesta'] as String? ?? ''),
                if ((p['claves'] as List? ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Claves: ${(p['claves'] as List).join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => _formulario(p), child: const Text('Editar')),
                  TextButton(
                    onPressed: () async {
                      if (await confirmar('¿Eliminar pregunta?', p['pregunta'] as String? ?? '')) {
                        ejecutar(() => RefugioService.instancia.eliminarPregunta('${p['id']}'), 'Pregunta eliminada');
                      }
                    },
                    child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
