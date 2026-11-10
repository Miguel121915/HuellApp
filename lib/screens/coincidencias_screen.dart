import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/requiere_sesion.dart';
import '../core/sesion_service.dart';
import '../services/comunidad_service.dart';
import '../widgets/foto_huellapp.dart';

/// Coincidencias (HU-8): mascotas encontradas por otras personas que se parecen a las que TÚ
/// reportaste como perdidas. Las calcula la API al crear cada reporte: compara las fotos con IA
/// (Gemini) y, si no hay IA, la descripción y la zona. Es la misma lista que ve el sitio web.
class CoincidenciasScreen extends StatefulWidget {
  const CoincidenciasScreen({super.key});

  @override
  State<CoincidenciasScreen> createState() => _CoincidenciasScreenState();
}

class _CoincidenciasScreenState extends State<CoincidenciasScreen> {
  static const Color _turquesa = Color(0xFF75E6DA);
  static const Color _oscuro = Color(0xFF1B4943);
  static const Color _fondo = Color(0xFFE8F9F8);

  ComunidadService get _servicio => ComunidadService.instancia;

  List<Map<String, dynamic>> _coincidencias = [];
  int _descartadas = 0;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!SesionService.instancia.haySesion) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = _coincidencias.isEmpty;
      _error = null;
    });
    try {
      final lista = await _servicio.coincidencias();
      final resumen = await _servicio.resumenCoincidencias();
      if (!mounted) return;
      setState(() {
        _coincidencias = lista;
        _descartadas = resumen['descartadas'] ?? 0;
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
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : _oscuro),
    );
  }

  Future<void> _descartar(Map<String, dynamic> c) async {
    final id = '${c['id']}';
    setState(() => _coincidencias.removeWhere((x) => '${x['id']}' == id));
    try {
      await _servicio.descartarCoincidencia(id);
      if (!mounted) return;
      setState(() => _descartadas++);
      _aviso('Coincidencia descartada. Puedes recuperarla abajo.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _aviso(e.mensaje, error: true);
      _cargar();
    }
  }

  Future<void> _restaurar() async {
    try {
      await _servicio.restaurarCoincidencias();
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) _aviso(e.mensaje, error: true);
    }
  }

  Future<void> _abrir(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) _aviso('No se pudo abrir ${uri.scheme == 'tel' ? 'el teléfono' : 'el correo'} en este dispositivo.', error: true);
  }

  void _contactar(Map<String, dynamic> c) {
    final hallazgo = c['hallazgo'] as Map<String, dynamic>;
    final contacto = (hallazgo['contacto'] as Map?)?.cast<String, dynamic>() ?? {};
    final nombre = contacto['nombre'] as String? ?? 'quien la encontró';
    final telefono = (contacto['telefono'] as String? ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    final correo = contacto['correo'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Contactar a $nombre',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _oscuro)),
              const SizedBox(height: 6),
              const Text('Pregunta por señas que solo tú conoces antes de ir por tu mascota.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              if (telefono.length >= 8)
                ListTile(
                  leading: const Icon(Icons.phone, color: _oscuro),
                  title: const Text('Llamar'),
                  subtitle: Text(contacto['telefono'] as String),
                  onTap: () {
                    Navigator.pop(hoja);
                    _abrir(Uri(scheme: 'tel', path: telefono));
                  },
                ),
              if (telefono.length >= 10)
                ListTile(
                  leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  title: const Text('WhatsApp'),
                  onTap: () {
                    Navigator.pop(hoja);
                    final numero = telefono.length == 10 ? '52$telefono' : telefono.replaceAll('+', '');
                    _abrir(Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent('Hola, vi en HuellApp que encontraste una mascota que podría ser la mía.')}'));
                  },
                ),
              if (correo.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: _oscuro),
                  title: const Text('Enviar correo'),
                  subtitle: Text(correo),
                  onTap: () {
                    Navigator.pop(hoja);
                    _abrir(Uri(scheme: 'mailto', path: correo, query: 'subject=${Uri.encodeComponent('Mascota encontrada (HuellApp)')}'));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Coincidencias', style: TextStyle(color: _oscuro, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _oscuro),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(16), children: _contenido()),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))];
    }
    if (!SesionService.instancia.haySesion) {
      return [
        _vacio(Icons.lock_outline, 'Inicia sesión para ver tus coincidencias',
            'Cuando reportes una mascota perdida, aquí verás las mascotas encontradas que se le parecen.'),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: () async {
              if (await requiereSesion(context, 'ver tus coincidencias')) _cargar();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _turquesa, foregroundColor: _oscuro),
            child: const Text('Iniciar sesión'),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        _vacio(Icons.cloud_off, 'No se pudieron cargar', _error!),
        Center(child: OutlinedButton(onPressed: _cargar, child: const Text('Reintentar'))),
      ];
    }
    return [
      _encabezado(),
      const SizedBox(height: 16),
      if (_coincidencias.isEmpty)
        _vacio(Icons.check_circle_outline, 'No hay coincidencias pendientes',
            'Te avisaremos aquí cuando alguien reporte una mascota encontrada parecida a la tuya.')
      else
        ..._coincidencias.map(_tarjeta),
      if (_descartadas > 0)
        Center(
          child: TextButton.icon(
            onPressed: _restaurar,
            icon: const Icon(Icons.restore, color: _oscuro),
            label: Text('Recuperar $_descartadas descartada${_descartadas == 1 ? '' : 's'}', style: const TextStyle(color: _oscuro)),
          ),
        ),
    ];
  }

  Widget _encabezado() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          CircleAvatar(backgroundColor: _turquesa, child: Icon(Icons.auto_awesome, color: _oscuro)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Comparamos las fotos de tus reportes de mascotas perdidas con las mascotas que otras personas encontraron.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ]),
      );

  Widget _vacio(IconData icono, String titulo, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(children: [
          Icon(icono, size: 56, color: _oscuro),
          const SizedBox(height: 12),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _oscuro)),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        ]),
      );

  Widget _tarjeta(Map<String, dynamic> c) {
    final mio = (c['miReporte'] as Map).cast<String, dynamic>();
    final hallazgo = (c['hallazgo'] as Map).cast<String, dynamic>();
    final similitud = (c['similitud'] as num?)?.toInt() ?? 0;
    final porIA = c['porIA'] == true;
    final analisis = (hallazgo['analisisIA'] as Map?)?.cast<String, dynamic>();
    final colorSimilitud = similitud >= 75 ? Colors.green.shade600 : similitud >= 55 ? Colors.orange.shade700 : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _turquesa, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Las dos fotos lado a lado: tu mascota y la que encontraron
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: SizedBox(
              height: 170,
              child: Row(children: [
                Expanded(child: _foto(mio['foto'] as String? ?? '', 'Tu reporte')),
                const SizedBox(width: 2),
                Expanded(child: _foto(hallazgo['foto'] as String? ?? '', 'Encontrada')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip('$similitud % de parecido', colorSimilitud, Icons.verified),
                  _chip(porIA ? 'Fotos comparadas con IA' : 'Por descripción y zona',
                      porIA ? const Color(0xFF8A6D00) : Colors.blueGrey, porIA ? Icons.auto_awesome : Icons.text_snippet_outlined),
                ]),
                const SizedBox(height: 12),
                const Text('Mascota encontrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _oscuro)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Expanded(child: Text(hallazgo['zona'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 6),
                Text(hallazgo['descripcion'] as String? ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if (analisis != null && (analisis['raza'] ?? '') != '') ...[
                  const SizedBox(height: 6),
                  Text('IA: ${[analisis['raza'], analisis['color'], analisis['tamano']].where((v) => v != null && v != '').join(' · ')}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
                const SizedBox(height: 8),
                Text('Tu reporte: ${mio['descripcion'] ?? ''}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _descartar(c),
                      child: const Text('No es mi mascota'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _turquesa,
                        foregroundColor: _oscuro,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: _oscuro)),
                      ),
                      onPressed: () => _contactar(c),
                      child: const Text('Contactar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _foto(String ruta, String etiqueta) => Stack(fit: StackFit.expand, children: [
        FotoHuellApp(ApiConfig.urlArchivo(ruta), fit: BoxFit.cover),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
            child: Text(etiqueta, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

  Widget _chip(String texto, Color color, IconData icono) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      );
}
