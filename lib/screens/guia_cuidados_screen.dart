import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/adopcion_service.dart';
import '../widgets/kiro_avatar.dart';

/// Guía de cuidado después de adoptar (HU-23): la guía base por especie y edad (al instante) y,
/// arriba, consejos con IA para esa mascota (se piden la primera vez y la API los guarda).
class GuiaCuidadosScreen extends StatefulWidget {
  const GuiaCuidadosScreen({super.key, required this.solicitudId, required this.mascotaNombre});

  final String solicitudId;
  final String mascotaNombre;

  @override
  State<GuiaCuidadosScreen> createState() => _GuiaCuidadosScreenState();
}

class _GuiaCuidadosScreenState extends State<GuiaCuidadosScreen> {
  static const Color _oscuro = Color(0xFF1B4F4A);
  static const Map<String, String> _etapas = {
    'cachorro': 'Etapa: cachorro',
    'adulto': 'Etapa: adulto',
    'senior': 'Etapa: edad avanzada (senior)',
  };

  Map<String, dynamic>? _guia;
  String? _error;
  List<String>? _consejos;
  bool _preparandoConsejos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final guia = await AdopcionService.instancia.guiaCuidados(widget.solicitudId);
      if (!mounted) return;
      setState(() {
        _guia = guia;
        _consejos = (guia['consejos'] as List?)?.cast<String>();
      });
      if (_consejos == null) _personalizar();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  /// Los consejos con IA tardan unos segundos: la guía base ya se ve mientras tanto.
  Future<void> _personalizar() async {
    setState(() => _preparandoConsejos = true);
    try {
      final consejos = await AdopcionService.instancia.personalizarCuidados(widget.solicitudId);
      if (mounted) setState(() => _consejos = consejos);
    } on ApiException {
      // Sin consejos personalizados: la guía base sigue sirviendo
    } finally {
      if (mounted) setState(() => _preparandoConsejos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guia = _guia;
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF75E6DA),
        foregroundColor: Colors.black,
        title: Text('Cuidar a ${widget.mascotaNombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                  ]),
                )
              : guia == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(guia['titulo'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _oscuro)),
                    Text(_etapas[guia['etapa']] ?? '', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    _tarjetaConsejos(),
                    const SizedBox(height: 12),
                    for (final s in (guia['secciones'] as List? ?? []).cast<Map<String, dynamic>>()) _seccion(s),
                    const SizedBox(height: 8),
                    const Text(
                      'Son recomendaciones generales: tu veterinario es quien mejor conoce a tu mascota.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tarjetaConsejos() {
    final consejos = _consejos;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FC),
        border: Border.all(color: const Color(0xFFB8B8E8), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          KiroAvatar(size: 28),
          SizedBox(width: 8),
          Expanded(child: Text('Consejos para tu nueva mascota', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        if (consejos != null)
          for (final c in consejos) _punto(c)
        else if (_preparandoConsejos)
          const Text('Preparando consejos para tu mascota… 🐾', style: TextStyle(color: Colors.black54))
        else
          const Text(
            'Por ahora no pudimos preparar consejos personalizados. La guía de abajo aplica para tu mascota.',
            style: TextStyle(color: Colors.black54),
          ),
      ]),
    );
  }

  Widget _seccion(Map<String, dynamic> s) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s['icono']} ${s['titulo']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final p in (s['puntos'] as List? ?? []).cast<String>()) _punto(p),
      ]),
    ),
  );

  Widget _punto(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold, color: _oscuro)),
      Expanded(child: Text(texto, style: const TextStyle(height: 1.35))),
    ]),
  );
}
