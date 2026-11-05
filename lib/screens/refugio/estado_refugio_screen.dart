import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/sesion_service.dart';
import '../login_screen.dart';
import 'panel_refugio_screen.dart';

/// Estado de la solicitud de un refugio que todavía no está aprobado (igual que en el sitio web):
/// pendiente de verificación, rechazado (con el motivo) o suspendido.
class EstadoRefugioScreen extends StatefulWidget {
  const EstadoRefugioScreen({super.key});

  @override
  State<EstadoRefugioScreen> createState() => _EstadoRefugioScreenState();
}

class _EstadoRefugioScreenState extends State<EstadoRefugioScreen> {
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _fondo = Color(0xFFE6F8F5);

  Map<String, dynamic>? _refugio;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _actualizar();
  }

  Future<void> _actualizar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final refugio = await SesionService.instancia.refrescar();
      if (!mounted) return;
      // Si ya lo aprobaron, pasa directo a su panel
      if (refugio?['estado'] == 'aprobado') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PanelRefugioScreen()));
        return;
      }
      setState(() {
        _refugio = refugio;
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

  Future<void> _salir() async {
    await SesionService.instancia.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = _refugio?['estado'] as String? ?? 'pendiente';
    final (icono, color, titulo, texto) = switch (estado) {
      'rechazado' => (
          Icons.cancel_outlined,
          Colors.red.shade700,
          'Solicitud rechazada',
          'El administrador revisó tu solicitud y no pudo aprobarla. Corrige lo que se indica abajo y '
              'envía tu apelación desde el sitio web de HuellApp (Iniciar sesión → Solicitar apelación).',
        ),
      'suspendido' => (
          Icons.pause_circle_outline,
          Colors.orange.shade800,
          'Refugio suspendido',
          'Tu refugio está suspendido temporalmente. Comunícate con el administrador de HuellApp.',
        ),
      _ => (
          Icons.hourglass_top,
          _accent,
          'Pendiente de verificación',
          'Un administrador está revisando los documentos de tu refugio. Cuando lo apruebe, '
              'aquí mismo podrás entrar a tu panel.',
        ),
    };
    final motivo = (_refugio?['motivoRechazo'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _turquoise,
        automaticallyImplyLeading: false,
        title: const Text(
          'HuellApp',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
        ),
        actions: [
          IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout, color: Colors.black), onPressed: _salir),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (_cargando)
                const Center(child: CircularProgressIndicator(color: _accent))
              else if (_error != null)
                Text(_error!, textAlign: TextAlign.center)
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(icono, size: 64, color: color),
                        const SizedBox(height: 12),
                        Text(
                          _refugio?['nombre'] as String? ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(titulo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                        const SizedBox(height: 12),
                        Text(texto, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
                        if (estado == 'rechazado' && motivo.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Motivo: $motivo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargando ? null : _actualizar,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar estado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turquoise,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
