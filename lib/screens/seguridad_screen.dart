import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/sesion_service.dart';
import '../widgets/dialogo_codigo.dart';

/// Seguridad de la cuenta: activar o quitar la verificación en dos pasos con Google Authenticator.
/// Igual que la ventana «Seguridad» del sitio web (mismas rutas /api/auth/2fa/...).
class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  static const Color _accent = Color(0xFF1B4F4A);
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _muted = Color(0xFF3F5F5B);

  SesionService get _sesion => SesionService.instancia;

  bool _cargando = true;
  bool _activo = false;
  String? _error;

  /// Mientras se configura: {secreto, enlace} que generó la API.
  Map<String, dynamic>? _configuracion;

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
      final activo = await _sesion.dosPasosActivo();
      if (!mounted) return;
      setState(() {
        _activo = activo;
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

  Future<void> _empezar() async {
    setState(() => _cargando = true);
    try {
      final datos = await _sesion.prepararDosPasos();
      if (!mounted) return;
      setState(() {
        _configuracion = datos;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _aviso(e.mensaje, error: true);
    }
  }

  Future<void> _confirmar() async {
    final ok = await pedirCodigoDosPasos(
      context,
      titulo: 'Confirma el código',
      texto: 'Escribe el código de 6 dígitos que muestra ahora Google Authenticator para HuellApp.',
      boton: 'Activar',
      alEnviar: _sesion.activarDosPasos,
    );
    if (!ok || !mounted) return;
    setState(() {
      _activo = true;
      _configuracion = null;
    });
    _aviso('¡Listo! La próxima vez que inicies sesión te pediremos el código.');
  }

  Future<void> _desactivar() async {
    final ok = await pedirCodigoDosPasos(
      context,
      titulo: 'Desactivar verificación',
      texto: 'Escribe un código vigente de Google Authenticator para confirmar que eres tú.',
      boton: 'Desactivar',
      alEnviar: _sesion.desactivarDosPasos,
    );
    if (!ok || !mounted) return;
    setState(() => _activo = false);
    _aviso('Desactivaste la verificación en dos pasos. Puedes borrar HuellApp de Google Authenticator.');
  }

  Future<void> _abrirAutenticador(String enlace) async {
    final abierto = await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!abierto && mounted) {
      _aviso('No encontramos Google Authenticator. Instálalo o escribe la clave a mano.', error: true);
    }
  }

  void _aviso(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: _turquoise,
        foregroundColor: Colors.black,
        title: const Text('Seguridad', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [_contenido()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _tarjeta([
        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ]);
    }
    if (_activo) return _vistaActiva();
    if (_configuracion != null) return _vistaConfigurar(_configuracion!);
    return _vistaInactiva();
  }

  Widget _vistaInactiva() => _tarjeta([
        _titulo(Icons.lock_open, 'Verificación en dos pasos: desactivada'),
        const SizedBox(height: 8),
        const Text(
          'Al activarla, además de tu contraseña (o de tu cuenta de Google) te pediremos un código '
          'de 6 dígitos de la app Google Authenticator. Así nadie entra a tu cuenta aunque sepa tu contraseña.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        _botonPrincipal('Activar', _empezar),
      ]);

  Widget _vistaActiva() => _tarjeta([
        _titulo(Icons.verified_user, 'Verificación en dos pasos: activada'),
        const SizedBox(height: 8),
        const Text(
          'Cada vez que inicies sesión te pediremos el código de Google Authenticator.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _desactivar,
          icon: const Icon(Icons.phonelink_erase),
          label: const Text('Desactivar o cambiar de teléfono'),
          style: OutlinedButton.styleFrom(foregroundColor: _accent),
        ),
      ]);

  Widget _vistaConfigurar(Map<String, dynamic> datos) {
    final secreto = datos['secreto'] as String;
    final enlace = datos['enlace'] as String;
    final clave = secreto.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
    return _tarjeta([
      _titulo(Icons.qr_code_2, 'Configura Google Authenticator'),
      const SizedBox(height: 12),
      const Text('1. Instala Google Authenticator en tu teléfono.', style: TextStyle(height: 1.4)),
      const SizedBox(height: 6),
      const Text('2. Toca «Abrir en Google Authenticator» (en este teléfono) o escanea el código QR desde otro:',
          style: TextStyle(height: 1.4)),
      const SizedBox(height: 12),
      _botonPrincipal('Abrir en Google Authenticator', () => _abrirAutenticador(enlace), icono: Icons.open_in_new),
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
      Row(
        children: [
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
        ],
      ),
      const SizedBox(height: 12),
      const Text('3. Escribe el código que aparece en la app para confirmar.', style: TextStyle(height: 1.4)),
      const SizedBox(height: 12),
      _botonPrincipal('Ya lo agregué: escribir código', _confirmar, icono: Icons.pin),
      TextButton(
        onPressed: () => setState(() => _configuracion = null),
        child: const Text('Cancelar', style: TextStyle(color: _accent)),
      ),
    ]);
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

  Widget _titulo(IconData icono, String texto) => Row(children: [
        Icon(icono, color: _accent),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _accent))),
      ]);

  Widget _botonPrincipal(String texto, VoidCallback alPresionar, {IconData? icono}) => SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: alPresionar,
          icon: Icon(icono ?? Icons.lock_outline),
          label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _turquoise,
            foregroundColor: const Color(0xFF14312E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
