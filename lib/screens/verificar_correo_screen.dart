import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/destino.dart';
import '../core/sesion_service.dart';
import '../core/tipografia.dart';

/// «Confirma tu correo»: el código de 6 dígitos que llega al registrarse (o al entrar con una
/// cuenta que aún no lo confirmó). Si es correcto, la API entrega la sesión y se entra directo.
class VerificarCorreoScreen extends StatefulWidget {
  const VerificarCorreoScreen({super.key, required this.correo});

  final String correo;

  @override
  State<VerificarCorreoScreen> createState() => _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends State<VerificarCorreoScreen> {
  final _codigo = TextEditingController();
  String? _error;
  bool _enviando = false;
  int _espera = 60; // recién llegó un código: 1 minuto antes de poder pedir otro
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _contar(_espera);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
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

  Future<void> _confirmar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.replaceAll(RegExp(r'\D'), '');
    if (codigo.length != 6) {
      setState(() => _error = 'El código tiene 6 dígitos.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final sesion = await SesionService.instancia.verificarCorreo(correo: widget.correo, codigo: codigo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Listo! Tu correo quedó confirmado. Bienvenido a HuellApp.')),
      );
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destinoDeSesion(sesion)),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.mensaje;
      });
      // Ya estaba confirmado (por ejemplo, desde la web): solo falta iniciar sesión
      if (e.codigo == 'ya-confirmado') Navigator.pop(context);
    }
  }

  Future<void> _reenviar() async {
    try {
      final espera = await SesionService.instancia.reenviarCodigoCorreo(widget.correo);
      if (!mounted) return;
      _contar(espera);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te enviamos un código nuevo. El anterior ya no sirve.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _contar((e.datos['esperaSegundos'] as num?)?.toInt() ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                sobretitulo: 'ÚLTIMO PASO',
                titulo: 'Confirma tu correo',
                texto: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Te enviamos un código de 6 dígitos a '),
                  TextSpan(text: widget.correo, style: const TextStyle(fontWeight: FontWeight.w700, color: Tipografia.tinta)),
                  const TextSpan(text: '. Escríbelo aquí para activar tu cuenta.'),
                ])),
                hijos: [
                  CampoCodigo(controlador: _codigo, error: _error, alEnviar: _confirmar),
                  const SizedBox(height: 16),
                  BotonPrincipal(texto: 'Confirmar y entrar', cargando: _enviando, alPresionar: _confirmar),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _espera > 0 ? null : _reenviar,
                    child: Text(_espera > 0 ? 'Reenviar código ($_espera s)' : '¿No te llegó? Reenviar código'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca de las pantallas de código (confirmar correo y recuperar contraseña).
class TarjetaCodigo extends StatelessWidget {
  const TarjetaCodigo({super.key, required this.sobretitulo, required this.titulo, required this.texto, required this.hijos});

  final String sobretitulo;
  final String titulo;
  final Widget texto;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x2414312E), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/img/logo_huellapp.png', height: 64),
          const SizedBox(height: 20),
          Text(sobretitulo, style: Tipografia.sobretitulo),
          const SizedBox(height: 6),
          Text(titulo, style: const TextStyle(fontFamily: Tipografia.fuenteTitulos, fontSize: 26, fontWeight: FontWeight.w700, color: Tipografia.aquaFuerte)),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(style: const TextStyle(fontSize: 14.5, height: 1.5, color: Tipografia.tintaSuave), child: texto),
          const SizedBox(height: 20),
          ...hijos,
        ],
      ),
    );
  }
}

/// Campo grande para el código de 6 dígitos.
class CampoCodigo extends StatelessWidget {
  const CampoCodigo({super.key, required this.controlador, this.error, this.alEnviar});

  final TextEditingController controlador;
  final String? error;
  final VoidCallback? alEnviar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: 7,
      textAlign: TextAlign.center,
      onSubmitted: (_) => alEnviar?.call(),
      style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w600, color: Tipografia.tinta),
      decoration: InputDecoration(
        labelText: 'Código de verificación',
        hintText: '123456',
        counterText: '',
        helperText: 'Vence en 15 minutos. Si no lo ves, revisa tu correo no deseado.',
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF9ED9D1), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Tipografia.aquaFuerte, width: 2)),
      ),
    );
  }
}

/// Botón turquesa de las pantallas de código.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({super.key, required this.texto, required this.cargando, required this.alPresionar});

  final String texto;
  final bool cargando;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: cargando ? null : alPresionar,
        style: ElevatedButton.styleFrom(
          backgroundColor: Tipografia.aquaFuerte,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: cargando
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(texto),
      ),
    );
  }
}

