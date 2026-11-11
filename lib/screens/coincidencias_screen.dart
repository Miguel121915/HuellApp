import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/requiere_sesion.dart';
import '../core/sesion_service.dart';
import '../services/comunidad_service.dart';
import '../widgets/foto_huellapp.dart';

/// Coincidencias (HU-8): reportes de otras personas que se parecen a los tuyos. Las ven los dos
/// lados: si perdiste una mascota, las encontradas que se le parecen; si encontraste una, las
/// pérdidas de sus posibles dueños ("lado" en la API). Las calcula la API al crear cada reporte:
/// compara las fotos con IA (Gemini) y, si no hay IA, la descripción y la zona. Es la misma lista
/// que ve el sitio web.
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

  // La IA revisa las fotos en segundo plano: mientras tanto la pantalla se actualiza sola
  int _analizando = 0;
  List<Map<String, dynamic>> _duplicados = [];
  Timer? _recarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _recarga?.cancel();
    super.dispose();
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
      final estado = await _servicio.coincidenciasConEstado();
      final resumen = await _servicio.resumenCoincidencias();
      if (!mounted) return;
      setState(() {
        _coincidencias = estado.coincidencias;
        _analizando = estado.analizando;
        _duplicados = estado.duplicados;
        _descartadas = resumen['descartadas'] ?? 0;
        _cargando = false;
      });
      _recarga?.cancel();
      if (_analizando > 0) _recarga = Timer(const Duration(seconds: 15), _cargar);
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

  /// El reporte de la otra persona. Las versiones anteriores de la API solo mandaban "hallazgo".
  Map<String, dynamic> _otro(Map<String, dynamic> c) =>
      ((c['otroReporte'] ?? c['hallazgo']) as Map).cast<String, dynamic>();

  /// true si yo encontré la mascota (la otra persona es quien la perdió).
  bool _encontre(Map<String, dynamic> c) => c['lado'] == 'encontrada';

  /// Seña secreta: si el dueño la pidió, quien encontró la describe antes de ver el contacto.
  Future<void> _pedirSena(Map<String, dynamic> c) async {
    final controller = TextEditingController();
    String? error;
    final enviada = await showDialog<bool>(
      context: context,
      builder: (dialogo) => StatefulBuilder(
        builder: (dialogo, setDialogo) => AlertDialog(
          title: const Text('Confirma que es la misma mascota'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'El dueño registró una seña particular que no aparece en la foto. Describe alguna seña de la '
              'mascota que encontraste (manchas, cicatrices, collar…). El dueño revisará tu respuesta.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'Tiene una mancha blanca en el pecho', errorText: error),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().length < 3) {
                  setDialogo(() => error = 'Escribe al menos 3 caracteres.');
                  return;
                }
                try {
                  await _servicio.responderSena('${c['id']}', controller.text);
                  if (dialogo.mounted) Navigator.pop(dialogo, true);
                } on ApiException catch (e) {
                  setDialogo(() => error = e.mensaje);
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (enviada != true || !mounted) return;
    await _cargar();
    if (!mounted) return;
    final actualizada = _coincidencias.where((x) => '${x['id']}' == '${c['id']}').firstOrNull;
    if (actualizada != null) _contactar(actualizada);
  }

  void _contactar(Map<String, dynamic> c) {
    if ((c['verificacion'] as Map?)?['requerida'] == true) {
      _pedirSena(c);
      return;
    }
    final encontre = _encontre(c);
    final contacto = (_otro(c)['contacto'] as Map?)?.cast<String, dynamic>() ?? {};
    final nombre = contacto['nombre'] as String? ?? (encontre ? 'quien la perdió' : 'quien la encontró');
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
              Text(
                  encontre
                      ? 'Pídele una foto o señas de su mascota para confirmar que es la misma.'
                      : 'Pregunta por señas que solo tú conoces antes de ir por tu mascota.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                    final saludo = encontre
                        ? 'Hola, vi en HuellApp que perdiste una mascota. Creo que encontré a la tuya.'
                        : 'Hola, vi en HuellApp que encontraste una mascota que podría ser la mía.';
                    _abrir(Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(saludo)}'));
                  },
                ),
              if (correo.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: _oscuro),
                  title: const Text('Enviar correo'),
                  subtitle: Text(correo),
                  onTap: () {
                    Navigator.pop(hoja);
                    final asunto = encontre ? 'Encontré a una mascota que podría ser la tuya (HuellApp)' : 'Mascota encontrada (HuellApp)';
                    _abrir(Uri(scheme: 'mailto', path: correo, query: 'subject=${Uri.encodeComponent(asunto)}'));
                  },
                ),
              if (telefono.length < 8 && correo.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Esta persona no dejó teléfono ni correo. Escríbele en los comentarios de su alerta en el muro.',
                      textAlign: TextAlign.center),
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
            'Cuando reportes una mascota perdida o encontrada, aquí verás los reportes de otras personas que se le parecen.'),
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
      if (_analizando > 0) ...[
        _avisoIa(
          Icons.auto_awesome,
          'La IA está revisando la foto de ${_analizando == 1 ? 'tu reporte' : '$_analizando de tus reportes'} '
          'y comparándola con otros. Esta pantalla se actualiza sola.',
          const Color(0xFFE6F8F5),
          _oscuro,
        ),
        const SizedBox(height: 12),
      ],
      for (final d in _duplicados) ...[
        _avisoDuplicado(d),
        const SizedBox(height: 12),
      ],
      if (_coincidencias.isEmpty)
        _vacio(Icons.check_circle_outline, 'No hay coincidencias pendientes',
            'Te avisaremos aquí cuando alguien reporte una mascota parecida a la tuya.')
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

  /// Seña secreta: al dueño le muestra su seña y la respuesta; a quien encontró, qué falta.
  Widget _cajaSena(Map<String, dynamic> v) {
    final esDueno = v.containsKey('tuSena');
    final respuesta = v['respuesta'] as String?;
    final lineas = esDueno
        ? [
            '🔒 Tu seña secreta: «${v['tuSena']}»',
            respuesta != null
                ? 'Quien la encontró describe: «$respuesta». ¿Coincide? Si no, puedes descartarla.'
                : 'Quien la encontró todavía no describe la seña.',
          ]
        : [
            v['requerida'] == true
                ? '🔒 El dueño pidió confirmar una seña particular. Toca «Contactar» para describirla.'
                : '✅ Ya describiste la seña: «$respuesta». El dueño la revisará.',
          ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6B8DD6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in lineas) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: const TextStyle(fontSize: 13)))],
      ),
    );
  }

  Widget _avisoIa(IconData icono, String texto, Color fondo, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14), border: Border.all(color: color)),
        child: Row(children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        ]),
      );

  /// La IA cree que mi alerta es de la misma mascota que otra ya publicada (p. ej. por un familiar).
  Widget _avisoDuplicado(Map<String, dynamic> d) {
    final mio = (d['miReporte'] as Map?)?.cast<String, dynamic>() ?? {};
    final otro = (d['otro'] as Map?)?.cast<String, dynamic>() ?? {};
    final nombre = (mio['nombre'] as String?)?.isNotEmpty == true ? 'de ${mio['nombre']} ' : '';
    const color = Color(0xFF7A5A00);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFDECB5), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((otro['foto'] as String? ?? '').isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FotoHuellApp(ApiConfig.urlArchivo(otro['foto'] as String), width: 72, height: 72),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tu alerta ${nombre}parece ser de la misma mascota que otra ya publicada',
                style: const TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(
              'La publicó ${otro['autor'] ?? 'otra persona'} (zona: ${otro['zona'] ?? ''}). Si es la misma, '
              'pónganse de acuerdo en los comentarios de esa alerta en el muro.',
              style: const TextStyle(fontSize: 13, color: color),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _encabezado() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          CircleAvatar(backgroundColor: _turquesa, child: Icon(Icons.auto_awesome, color: _oscuro)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Comparamos las fotos de tus reportes con las de otras personas: mascotas encontradas si perdiste la tuya, y sus posibles dueños si encontraste una.',
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
    final otro = _otro(c);
    final encontre = _encontre(c);
    final similitud = (c['similitud'] as num?)?.toInt() ?? 0;
    final porIA = c['porIA'] == true;
    // Los dos reportes usan la MISMA fotografía (p. ej. copiada del muro): la foto no prueba nada
    final mismaFoto = c['mismaFoto'] == true;
    final analisis = (otro['analisisIA'] as Map?)?.cast<String, dynamic>();
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
                Expanded(child: _foto(otro['foto'] as String? ?? '', encontre ? 'La que buscan' : 'Encontrada')),
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
                  if (mismaFoto)
                    _chip('Misma foto del reporte', Colors.orange.shade800, Icons.warning_amber_rounded)
                  else
                    _chip(porIA ? 'Fotos comparadas con IA' : 'Por descripción y zona',
                        porIA ? const Color(0xFF8A6D00) : Colors.blueGrey, porIA ? Icons.auto_awesome : Icons.text_snippet_outlined),
                ]),
                if (mismaFoto) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFDECB5), borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      'Usa la misma fotografía que el reporte original, así que la foto no prueba que sea la misma '
                      'mascota. Pide una foto actual antes de ir por ella.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF7A5A00), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(encontre ? 'Alguien busca a esta mascota' : 'Mascota encontrada',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _oscuro)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${otro['zona'] as String? ?? ''}'
                      '${c['distanciaKm'] != null ? ' · a ${c['distanciaKm']} km de tu reporte' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                if (c['verificacion'] is Map) _cajaSena((c['verificacion'] as Map).cast<String, dynamic>()),
                Text(otro['descripcion'] as String? ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
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
                      child: Text(encontre ? 'No es la misma' : 'No es mi mascota'),
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
