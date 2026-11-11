import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/sesion_service.dart';
import '../widgets/dialogo_codigo.dart';

/// Primera vez que entra un refugio (o admin): la verificación en dos pasos es obligatoria,
/// así que se configura aquí antes de entrar. Devuelve la [Sesion] al terminar (o null si regresa).
class ConfigurarDosPasosScreen extends StatefulWidget {
  const ConfigurarDosPasosScreen({super.key, required this.desafio});

  final String desafio;

  @override
  State<ConfigurarDosPasosScreen> createState() => _ConfigurarDosPasosScreenState();
}

class _ConfigurarDosPasosScreenState extends State<ConfigurarDosPasosScreen> {
  static const _accent = Color(0xFF1B4D47);
  static const _turquoise = Color(0xFF7BE0D6);
  static const _muted = Colors.black54;

  Map<String, dynamic>? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    setState(() => _error = null);
    try {
      final datos = await SesionService.instancia.configurarDosPasos(widget.desafio);
      if (mounted) setState(() => _datos = datos);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _abrirAutenticador(String enlace) async {
    final abierto = await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!abierto && mounted) {
      _aviso('No encontramos Google Authenticator. Instálalo o escribe la clave a mano.');
    }
  }

  Future<void> _confirmar() async {
    Sesion? sesion;
    final ok = await pedirCodigoDosPasos(
      context,
      titulo: 'Activar verificación',
      texto: 'Escribe el código de 6 dígitos que aparece en Google Authenticator para HuellApp.',
      boton: 'Activar y entrar',
      alEnviar: (codigo) async {
        sesion = await SesionService.instancia.activarDosPasosObligatoria(desafio: widget.desafio, codigo: codigo);
      },
    );
    if (ok && mounted && sesion != null) Navigator.pop(context, sesion);
  }

  void _aviso(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F7F5),
      appBar: AppBar(
        title: const Text('Protege tu cuenta', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _turquoise,
        foregroundColor: _accent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _tarjeta(_contenido()),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    if (_error != null) {
      return [
        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver al inicio de sesión')),
      ];
    }
    final datos = _datos;
    if (datos == null) {
      return const [Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))];
    }
    final secreto = datos['secreto'] as String;
    final enlace = datos['enlace'] as String;
    final clave = secreto.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
    return [
      const Row(children: [
        Icon(Icons.verified_user, color: _accent),
        SizedBox(width: 8),
        Expanded(
          child: Text('Verificación en dos pasos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _accent)),
        ),
      ]),
      const SizedBox(height: 8),
      const Text(
        'Para refugios y administradores es obligatoria: así nadie entra a tu cuenta aunque sepa tu contraseña. '
        'Solo se configura una vez.',
        style: TextStyle(height: 1.4),
      ),
      const SizedBox(height: 12),
      const Text('1. Instala Google Authenticator en tu teléfono.', style: TextStyle(height: 1.4)),
      const SizedBox(height: 6),
      const Text('2. Toca «Abrir en Google Authenticator» (en este teléfono) o escanea el código QR desde otro:',
          style: TextStyle(height: 1.4)),
      const SizedBox(height: 12),
      _boton('Abrir en Google Authenticator', () => _abrirAutenticador(enlace), Icons.open_in_new),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: QrImageView(data: enlace, size: 200, semanticsLabel: 'Código QR para Google Authenticator'),
        ),
      ),
      const SizedBox(height: 12),
      const Text('¿No puedes escanear? Elige «Introducir clave de configuración» y escribe:',
          style: TextStyle(color: _muted, fontSize: 13)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: SelectableText(clave,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          tooltip: 'Copiar clave',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: secreto));
            if (mounted) _aviso('Clave copiada.');
          },
        ),
      ]),
      const SizedBox(height: 12),
      const Text('3. Escribe el código que aparece en la app para activar y entrar.', style: TextStyle(height: 1.4)),
      const SizedBox(height: 12),
      _boton('Ya lo agregué: escribir código', _confirmar, Icons.pin),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver', style: TextStyle(color: _accent)),
      ),
    ];
  }

  Widget _tarjeta(List<Widget> hijos) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
      );

  Widget _boton(String texto, VoidCallback alPresionar, IconData icono) => SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: alPresionar,
          icon: Icon(icono),
          label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _turquoise,
            foregroundColor: const Color(0xFF14312E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
