import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/kiro_service.dart';
import '../widgets/foto_huellapp.dart';
import '../widgets/mascota_perfil_sheet.dart';
import '../widgets/kiro_avatar.dart';
import 'muro_huellapp_screen.dart';

/// KIRO, el asistente de adopción (HU-7). Se abre desde el botón flotante del inicio.
/// Conversa con la IA de la API y recomienda mascotas REALES disponibles; al tocar una se abre su
/// perfil (con requisitos, contacto y «Solicitar adopción»).
class KiroHomeScreen extends StatefulWidget {
  const KiroHomeScreen({super.key, this.onIrA});

  /// Para saltar a una pestaña de la app (1 Refugios, 3 Reportar, 4 Coincidencias, 0 Foro).
  final ValueChanged<int>? onIrA;

  @override
  State<KiroHomeScreen> createState() => _KiroHomeScreenState();
}

class _Tema {
  const _Tema(this.icono, this.texto, this.pregunta);
  final IconData icono;
  final String texto;
  final String pregunta;
}

class _Mensaje {
  _Mensaje.usuario(this.texto) : deKiro = false, mascotas = const [], reportes = const [], enlace = null;
  _Mensaje.kiro(this.texto, {this.mascotas = const [], this.reportes = const [], this.enlace}) : deKiro = true;

  final bool deKiro;
  final String texto;
  final List<MascotaRecomendada> mascotas;
  final List<ReporteKiro> reportes;
  final String? enlace;
}

class _KiroHomeScreenState extends State<KiroHomeScreen> {
  static const Color _turquesa = Color(0xFF75E6DA);
  static const Color _oscuro = Color(0xFF1B4943);

  static const List<_Tema> _temas = [
    _Tema(Icons.pets, 'Recomiéndame una mascota', 'Recomiéndame una mascota para mi casa'),
    _Tema(Icons.apartment, 'Vivo en departamento', 'Vivo en un departamento pequeño, ¿qué mascota me conviene?'),
    _Tema(Icons.checklist, '¿Qué necesito para adoptar?', '¿Qué necesito para adoptar?'),
    _Tema(Icons.warning_amber_rounded, 'Perdí a mi mascota', 'Se me perdió mi mascota, ¿qué hago?'),
  ];

  /// Pestañas de la app a las que puede llevar un enlace de KIRO.
  static const Map<String, (String, int)> _enlaces = {
    'refugios': ('Ver refugios', 1),
    'solicitudes': ('Ver refugios', 1),
    'reportar': ('Ir a Reportar', 3),
    'coincidencias': ('Ver coincidencias', 4),
    'foro': ('Ir al muro', 0),
  };

  final TextEditingController _entrada = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Mensaje> _mensajes = [
    _Mensaje.kiro(
      '¡Hola! Soy KIRO 🐾. Cuéntame cómo es tu hogar y tu rutina y te recomiendo una mascota que esté '
      'esperando familia, o pregúntame lo que quieras sobre adoptar.',
    ),
  ];
  bool _pensando = false;

  @override
  void dispose() {
    _entrada.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _preguntar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || _pensando) return;
    final historial = [
      for (final m in _mensajes.skip(1)) {'rol': m.deKiro ? 'kiro' : 'usuario', 'texto': m.texto},
    ];
    setState(() {
      _mensajes.add(_Mensaje.usuario(pregunta));
      _pensando = true;
    });
    _entrada.clear();
    _bajar();
    try {
      final r = await KiroService.instancia.preguntar(pregunta, historial);
      if (!mounted) return;
      setState(() => _mensajes.add(_Mensaje.kiro(r.texto, mascotas: r.mascotas, reportes: r.reportes, enlace: r.enlace)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _mensajes.add(
          _Mensaje.kiro(e.sinConexion ? 'No pude conectarme con HuellApp 😿. Revisa tu internet e inténtalo de nuevo.' : e.mensaje),
        ),
      );
    } finally {
      if (mounted) setState(() => _pensando = false);
      _bajar();
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _irA(int pestana) {
    if (widget.onIrA != null) {
      Navigator.pop(context);
      widget.onIrA!(pestana);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F9F8),
      appBar: AppBar(
        backgroundColor: _turquesa,
        foregroundColor: Colors.black,
        title: const Row(
          children: [
            KiroAvatar(size: 36),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KIRO', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Tu asistente de adopción', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensajes.length + (_pensando ? 1 : 0),
                    itemBuilder: (_, i) => i == _mensajes.length ? _escribiendo() : _burbuja(_mensajes[i]),
                  ),
                ),
                if (_mensajes.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final t in _temas)
                          ActionChip(
                            avatar: Icon(t.icono, size: 18, color: _oscuro),
                            label: Text(t.texto, style: const TextStyle(fontSize: 13)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: _oscuro),
                            onPressed: () => _preguntar(t.pregunta),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _oscuro, width: 1.5),
                    ),
                    child: TextField(
                      controller: _entrada,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _preguntar,
                      decoration: InputDecoration(
                        hintText: 'Pregúntale a KIRO',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: InputBorder.none,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(4),
                          child: IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: _oscuro),
                            tooltip: 'Enviar',
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _pensando ? null : () => _preguntar(_entrada.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _escribiendo() => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KiroAvatar(size: 30),
          SizedBox(width: 6),
          Text(
            'KIRO está pensando… 🐾',
            style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ),
  );

  static const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /// Reporte de mascota perdida o encontrada que encontró KIRO; al tocarlo se abre el muro (pestaña 0).
  Widget _tarjetaReporte(ReporteKiro r) {
    final cuando = r.fecha == null ? '' : ' el ${r.fecha!.day} ${_meses[r.fecha!.month - 1]}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onIrA == null
          ? null
          : () {
              // El muro abre la pestaña del reporte: «Se buscan» o «Buscan a su familia»
              MuroHuellAppScreen.pestanaPedida.value = r.perdida ? 'busca' : 'familia';
              _irA(0);
            },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: r.perdida ? const Color(0xFFFFF1E6) : const Color(0xFFE6F8F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: FotoHuellApp(r.foto, width: 56, height: 56)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.perdida ? 'Se busca' : 'Encontrada'}: ${r.titulo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (r.rasgos.isNotEmpty) Text(r.rasgos, style: const TextStyle(fontSize: 12)),
                  Text('${r.zona} · ${r.perdida ? 'se perdió' : 'la vieron'}$cuando', style: const TextStyle(fontSize: 12, color: _oscuro)),
                ],
              ),
            ),
            if (widget.onIrA != null) const Icon(Icons.chevron_right, color: _oscuro),
          ],
        ),
      ),
    );
  }

  Widget _burbuja(_Mensaje m) {
    final enlace = m.enlace == null ? null : _enlaces[m.enlace];
    final globo = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.deKiro ? Colors.white : _turquesa,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(m.deKiro ? 4 : 16),
          bottomRight: Radius.circular(m.deKiro ? 16 : 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.texto, style: const TextStyle(fontSize: 14, height: 1.35)),
          for (final r in m.mascotas) ...[
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => mostrarPerfilMascota(context, r.mascota, r.refugioNombre),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE6F8F5), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FotoHuellApp(r.mascota.fotos.isEmpty ? '' : r.mascota.fotos.first, width: 56, height: 56),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.mascota.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${r.mascota.tipo} · ${r.mascota.edad}', style: const TextStyle(fontSize: 12)),
                          Text(r.refugioNombre, style: const TextStyle(fontSize: 12, color: _oscuro)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _oscuro),
                  ],
                ),
              ),
            ),
          ],
          for (final r in m.reportes) ...[const SizedBox(height: 8), _tarjetaReporte(r)],
          if (enlace != null && widget.onIrA != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _irA(enlace.$2),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(enlace.$1),
              style: TextButton.styleFrom(foregroundColor: _oscuro, padding: EdgeInsets.zero),
            ),
          ],
        ],
      ),
    );
    // Los mensajes de KIRO llevan su carita al lado, como en un chat
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: m.deKiro ? Alignment.centerLeft : Alignment.centerRight,
        child: m.deKiro
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const KiroAvatar(size: 30),
                  const SizedBox(width: 6),
                  Flexible(child: globo),
                ],
              )
            : globo,
      ),
    );
  }
}
