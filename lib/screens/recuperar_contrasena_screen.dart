import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/sesion_service.dart';
import '../core/tipografia.dart';
import 'verificar_correo_screen.dart' show BotonPrincipal, CampoCodigo, TarjetaCodigo;

/// «¿Olvidaste tu contraseña?» en dos pasos:
///   1) el correo de la cuenta → la API manda un código de 6 dígitos (si existe; no lo revela)
///   2) el código + la contraseña nueva → se cambia y se regresa al inicio de sesión
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key, this.correoInicial = ''});

  final String correoInicial;

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  late final _correo = TextEditingController(text: widget.correoInicial);
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  int _paso = 1;
  bool _enviando = false;
  bool _verPassword = false;
  String? _errorCorreo, _errorCodigo, _errorPassword, _errorConfirmar;
  int _espera = 0;
  Timer? _reloj;

  @override
  void dispose() {
    _reloj?.cancel();
    for (final c in [_correo, _codigo, _password, _confirmar]) {
      c.dispose();
    }
    super.dispose();
  }

  void _contar(int segundos) {
    _reloj?.cancel();
    setState(() => _espera = segundos);
    if (segundos <= 0) return;
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _espera--);
      if (_espera <= 0) t.cancel();
    });
  }

  void _aviso(String texto, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : null),
      );

  Future<bool> _pedirCodigo() async {
    try {
      _contar(await SesionService.instancia.pedirRecuperacion(_correo.text));
      return true;
    } on ApiException catch (e) {
      if (mounted) _aviso(e.mensaje, error: true);
      return false;
    }
  }

  Future<void> _enviarCorreo() async {
    FocusScope.of(context).unfocus();
    final correo = _correo.text.trim();
    final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);
    setState(() => _errorCorreo = valido ? null : 'Escribe un correo válido, por ejemplo nombre@correo.com.');
    if (!valido) return;
    setState(() => _enviando = true);
    final ok = await _pedirCodigo();
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (ok) _paso = 2;
    });
  }

  Future<void> _cambiar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _errorCodigo = codigo.length == 6 ? null : 'El código tiene 6 dígitos.';
      _errorPassword = _password.text.length >= 8 ? null : 'La contraseña debe tener al menos 8 caracteres.';
      _errorConfirmar = _confirmar.text == _password.text ? null : 'Las contraseñas no coinciden.';
    });
    if (_errorCodigo != null || _errorPassword != null || _errorConfirmar != null) return;
    setState(() => _enviando = true);
    try {
      await SesionService.instancia.confirmarRecuperacion(correo: _correo.text.trim(), codigo: codigo, password: _password.text);
      if (!mounted) return;
      _aviso('Tu contraseña cambió. Ya puedes iniciar sesión con la nueva.');
      Navigator.pop(context, _correo.text.trim());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        if (e.codigo == 'codigo-incorrecto' || e.codigo == 'codigo-vencido') {
          _errorCodigo = e.mensaje;
        } else {
          _errorPassword = e.mensaje;
        }
      });
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono, {String? error, String? ayuda, Widget? sufijo}) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono, color: Tipografia.aquaFuerte),
        suffixIcon: sufijo,
        helperText: ayuda,
        errorText: error,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF9ED9D1), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Tipografia.aquaFuerte, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final ojo = IconButton(
      tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
      icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility, color: Tipografia.tintaTenue),
      onPressed: () => setState(() => _verPassword = !_verPassword),
    );
    final paso1 = <Widget>[
      TextField(
        controller: _correo,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _enviarCorreo(),
        decoration: _decoracion('Correo electrónico', Icons.email_outlined, error: _errorCorreo),
      ),
      const SizedBox(height: 16),
      BotonPrincipal(texto: 'Enviar código', cargando: _enviando, alPresionar: _enviarCorreo),
    ];
    final paso2 = <Widget>[
      CampoCodigo(controlador: _codigo, error: _errorCodigo),
      const SizedBox(height: 14),
      TextField(
        controller: _password,
        obscureText: !_verPassword,
        autofillHints: const [AutofillHints.newPassword],
        decoration: _decoracion('Contraseña nueva', Icons.lock_outline, error: _errorPassword, ayuda: 'Mínimo 8 caracteres.', sufijo: ojo),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _confirmar,
        obscureText: !_verPassword,
        onSubmitted: (_) => _cambiar(),
        decoration: _decoracion('Confirma la contraseña nueva', Icons.lock_outline, error: _errorConfirmar),
      ),
      const SizedBox(height: 16),
      BotonPrincipal(texto: 'Cambiar contraseña', cargando: _enviando, alPresionar: _cambiar),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: _espera > 0
                ? null
                : () async {
                    if (await _pedirCodigo() && mounted) _aviso('Si la cuenta existe, te enviamos un código nuevo.');
                  },
            child: Text(_espera > 0 ? 'Reenviar código ($_espera s)' : 'Reenviar código'),
          ),
          TextButton(onPressed: () => setState(() => _paso = 1), child: const Text('Usar otro correo')),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Tipografia.aquaFuerte),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: TarjetaCodigo(
                sobretitulo: 'PASO $_paso DE 2',
                titulo: 'Recupera tu contraseña',
                texto: _paso == 1
                    ? const Text('Escribe el correo de tu cuenta y te enviaremos un código de 6 dígitos para crear una contraseña nueva.')
                    : Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Si '),
                        TextSpan(text: _correo.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700, color: Tipografia.tinta)),
                        const TextSpan(text: ' tiene una cuenta en HuellApp, ya le llegó un código. Escríbelo junto con tu contraseña nueva.'),
                      ])),
                hijos: _paso == 1 ? paso1 : paso2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
