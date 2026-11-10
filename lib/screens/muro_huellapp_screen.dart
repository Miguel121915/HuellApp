import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/requiere_sesion.dart';
import '../services/comunidad_service.dart';
import '../widgets/foto_huellapp.dart';

/// Muro de la comunidad (HU-5): las publicaciones del foro de la API, incluidas las alertas de
/// mascotas perdidas y encontradas que se crean desde «Reportar». Es el mismo foro del sitio web.
class MuroHuellAppScreen extends StatefulWidget {
  const MuroHuellAppScreen({super.key});

  @override
  State<MuroHuellAppScreen> createState() => _MuroHuellAppScreenState();
}

class _MuroHuellAppScreenState extends State<MuroHuellAppScreen> {
  static const Color _turquesa = Color(0xFF75E6DA);
  static const Color _oscuro = Color(0xFF1B4943);

  ComunidadService get _servicio => ComunidadService.instancia;

  final TextEditingController _publicacionController = TextEditingController();
  Uint8List? _foto;
  bool _publicando = false;

  List<PublicacionForo> _publicaciones = [];
  bool _cargando = true;
  String? _error;

  /// Filtro: 'todo', 'alertas'
  String _filtro = 'todo';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _publicacionController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _publicaciones.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.publicaciones();
      if (!mounted) return;
      setState(() {
        _publicaciones = lista;
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

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _seleccionarFoto() async {
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (imagen == null) return;
    final bytes = await imagen.readAsBytes();
    if (mounted) setState(() => _foto = bytes);
  }

  Future<void> _publicar() async {
    final texto = _publicacionController.text.trim();
    if (texto.length < 5) {
      _aviso('Escribe al menos 5 caracteres.', error: true);
      return;
    }
    if (!await requiereSesion(context, 'publicar en el muro')) return;
    setState(() => _publicando = true);
    try {
      final nueva = await _servicio.publicar(texto, foto: _foto);
      if (!mounted) return;
      setState(() {
        _publicaciones.insert(0, nueva);
        _publicacionController.clear();
        _foto = null;
        _publicando = false;
      });
      FocusScope.of(context).unfocus();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _publicando = false);
      _aviso(e.mensaje, error: true);
    }
  }

  Future<void> _alternarMeGusta(PublicacionForo p) async {
    if (!await requiereSesion(context, 'dar «me gusta»')) return;
    final nuevo = !p.leGusta;
    setState(() => p.leGusta = nuevo); // se ve al instante; si falla se regresa
    try {
      await _servicio.meGusta(p.id, nuevo);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => p.leGusta = !nuevo);
      _aviso(e.mensaje, error: true);
    }
  }

  Future<void> _compartir(PublicacionForo p) async {
    await Clipboard.setData(ClipboardData(text: '${p.texto}\n\n— Compartido desde HuellApp'));
    if (mounted) _aviso('Texto copiado: pégalo en WhatsApp o tus redes para que más gente lo vea.');
  }

  void _abrirFoto(PublicacionForo p) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: FotoHuellApp(p.fotoUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity)),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarComentarios(PublicacionForo p) {
    final controller = TextEditingController();
    var enviando = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (hoja) => StatefulBuilder(
        builder: (hoja, setHoja) {
          Future<void> enviar() async {
            final texto = controller.text.trim();
            if (texto.isEmpty || enviando) return;
            if (!await requiereSesion(context, 'comentar')) return;
            setHoja(() => enviando = true);
            try {
              final comentarios = await _servicio.comentar(p.id, texto);
              if (!mounted) return;
              setState(() => p.comentarios = comentarios);
              setHoja(() => enviando = false);
              controller.clear();
            } on ApiException catch (e) {
              setHoja(() => enviando = false);
              if (mounted) _aviso(e.mensaje, error: true);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(hoja).viewInsets.bottom, top: 16, left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Comentarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(hoja)),
                  ],
                ),
                const Divider(),
                SizedBox(
                  height: 250,
                  child: p.comentarios.isEmpty
                      ? const Center(child: Text('No hay comentarios aún. ¡Sé el primero!'))
                      : ListView.builder(
                          itemCount: p.comentarios.length,
                          itemBuilder: (_, i) => ListTile(
                            leading: const CircleAvatar(backgroundColor: _turquesa, child: Icon(Icons.person, color: Colors.white)),
                            title: Text(p.comentarios[i].autor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(p.comentarios[i].texto),
                          ),
                        ),
                ),
                const Divider(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario...',
                          border: OutlineInputBorder(),
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: enviando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: _oscuro),
                      onPressed: enviar,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  String _hace(DateTime? fecha) {
    if (fecha == null) return '';
    final d = DateTime.now().difference(fecha);
    if (d.inMinutes < 1) return 'Hace un momento';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    if (d.inDays < 7) return 'Hace ${d.inDays} d';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _filtro == 'alertas'
        ? _publicaciones.where((p) => p.esAlertaPerdida || p.esAlertaEncontrada).toList()
        : _publicaciones;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Muro de la comunidad', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _cajaPublicar(),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Todo'),
                    selected: _filtro == 'todo',
                    onSelected: (_) => setState(() => _filtro = 'todo'),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Solo alertas'),
                    selected: _filtro == 'alertas',
                    onSelected: (_) => setState(() => _filtro = 'alertas'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_cargando)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ]),
                  )
                else if (visibles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Todavía no hay publicaciones aquí.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                  )
                else
                  ...visibles.map(_tarjeta),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cajaPublicar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              const CircleAvatar(backgroundColor: _turquesa, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _publicacionController,
                  maxLines: null,
                  minLines: 1,
                  maxLength: 600,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: '¿Qué quieres compartir con la comunidad?',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ]),
            if (_foto != null) ...[
              const SizedBox(height: 10),
              Stack(alignment: Alignment.topRight, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_foto!, height: 160, width: double.infinity, fit: BoxFit.contain),
                ),
                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => _foto = null)),
              ]),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _seleccionarFoto,
                  icon: const Icon(Icons.photo_library, color: Colors.green),
                  label: const Text('Foto', style: TextStyle(color: Colors.black87)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _turquesa,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _publicando ? null : _publicar,
                  child: _publicando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Publicar', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(PublicacionForo p) {
    final alerta = p.esAlertaPerdida || p.esAlertaEncontrada;
    final colorAlerta = p.esAlertaPerdida ? const Color(0xFFFFC83D) : const Color(0xFF3DBE8B);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alerta ? BorderSide(color: colorAlerta, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: alerta ? colorAlerta.withValues(alpha: 0.25) : Colors.purple.shade100,
                child: Icon(alerta ? Icons.campaign : Icons.pets, color: alerta ? _oscuro : Colors.purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.autor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(_hace(p.fecha), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              if (alerta)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: colorAlerta, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    p.esAlertaPerdida ? 'SE BUSCA' : 'ENCONTRADA',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF14312E)),
                  ),
                ),
            ]),
            if (p.texto.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(p.texto, style: const TextStyle(fontSize: 14, height: 1.35)),
            ],
            if (p.fotoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _abrirFoto(p),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 380),
                    width: double.infinity,
                    color: Colors.black12,
                    child: FotoHuellApp(p.fotoUrl, fit: BoxFit.contain, width: double.infinity, height: 300),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('❤ ${p.meGusta}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text('${p.comentarios.length} comentarios', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _accion(
                  p.leGusta ? Icons.favorite : Icons.favorite_border,
                  'Me gusta',
                  () => _alternarMeGusta(p),
                  color: p.leGusta ? Colors.red : null,
                ),
                _accion(Icons.chat_bubble_outline, 'Comentar', () => _mostrarComentarios(p)),
                _accion(Icons.share_outlined, 'Compartir', () => _compartir(p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accion(IconData icono, String texto, VoidCallback alTocar, {Color? color}) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(children: [
          Icon(icono, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color ?? Colors.grey.shade700, fontSize: 13)),
        ]),
      ),
    );
  }
}
