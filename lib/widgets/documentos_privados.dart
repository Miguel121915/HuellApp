import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../services/refugio_service.dart';

/// Abre un documento privado de la API (PDF o imagen) en el navegador o visor del dispositivo,
/// con un enlace firmado que dura 5 minutos. [ruta] sin /api.
Future<void> abrirDocumentoPrivado(BuildContext context, String ruta) async {
  final avisos = ScaffoldMessenger.of(context);
  try {
    final url = await RefugioService.instancia.enlaceDocumento(ruta);
    final abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!abierto) {
      avisos.showSnackBar(const SnackBar(content: Text('No se pudo abrir el documento.')));
    }
  } on ApiException catch (e) {
    avisos.showSnackBar(SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red.shade700));
  }
}

/// Documentos de una mascota del inventario (vacunación, esterilización, pedigree…), igual que en
/// el inventario del sitio web: ver la lista, abrir, subir y eliminar. El administrador los revisa.
class DocumentosMascota extends StatefulWidget {
  const DocumentosMascota({super.key, required this.mascotaId});

  final String mascotaId;

  @override
  State<DocumentosMascota> createState() => _DocumentosMascotaState();
}

class _DocumentosMascotaState extends State<DocumentosMascota> {
  static const Color _accent = Color(0xFF1B4F4A);
  static const int _maxBytes = 5 * 1024 * 1024;

  List<Map<String, dynamic>> _documentos = [];
  bool _cargando = true;
  bool _subiendo = false;
  String? _error;

  RefugioService get _servicio => RefugioService.instancia;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final docs = await _servicio.documentosMascota(widget.mascotaId);
      if (!mounted) return;
      setState(() {
        _documentos = docs;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _subir() async {
    // 1) Tipo de documento
    final tipo = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿Qué documento vas a subir?'),
        children: [
          for (final t in RefugioService.tiposDocumentoMascota.entries)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, t.key), child: Text(t.value)),
        ],
      ),
    );
    if (tipo == null) return;
    // 2) Archivo
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final archivo = resultado?.files.single;
    if (archivo == null || archivo.bytes == null || !mounted) return;
    if (archivo.size > _maxBytes) {
      _avisar('El archivo pesa más de 5 MB. Elige uno más ligero.', error: true);
      return;
    }
    setState(() => _subiendo = true);
    try {
      await _servicio.subirDocumentoMascota(
        widget.mascotaId,
        tipo,
        ArchivoElegido(nombre: archivo.name, bytes: archivo.bytes!, mime: ArchivoElegido.mimeDe(archivo.name)),
      );
      await _cargar();
      if (mounted) _avisar('Documento subido. El administrador lo revisará.');
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminar(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar documento?'),
        content: Text(d['nombre'] as String? ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _servicio.eliminarDocumentoMascota(widget.mascotaId, '${d['id']}');
      await _cargar();
      if (mounted) _avisar('Documento eliminado');
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Documentos de la mascota', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                TextButton.icon(
                  onPressed: _subiendo ? null : _subir,
                  icon: _subiendo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: const Text('Subir'),
                ),
              ],
            ),
            const Text(
              'Vacunas, esterilización, pedigree… (PDF, JPG o PNG, máx. 5 MB). Los revisa el administrador.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            if (_cargando)
              const LinearProgressIndicator(color: _accent)
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_documentos.isEmpty)
              const Text('Sin documentos todavía.')
            else
              for (final d in _documentos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    (d['mime'] as String? ?? '').contains('pdf') ? Icons.picture_as_pdf : Icons.image_outlined,
                    color: _accent,
                  ),
                  title: Text(d['nombre'] as String? ?? '', overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${RefugioService.tiposDocumentoMascota[d['tipo']] ?? d['tipo']} · '
                    '${d['verificado'] == true ? 'Verificado ✓' : 'Sin verificar'}',
                  ),
                  onTap: () => abrirDocumentoPrivado(
                    context,
                    '/refugio/mascotas/${widget.mascotaId}/documentos/${d['id']}/archivo',
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _eliminar(d),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
