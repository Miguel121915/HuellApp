import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';

/// Pide el código de 6 dígitos de Google Authenticator.
/// [alEnviar] lo manda a la API; si lanza [ApiException] el mensaje se muestra en el diálogo
/// y se puede volver a intentar. Devuelve true si el código fue aceptado.
Future<bool> pedirCodigoDosPasos(
  BuildContext context, {
  required Future<void> Function(String codigo) alEnviar,
  String titulo = 'Verificación en dos pasos',
  String texto = 'Abre Google Authenticator en tu teléfono y escribe el código de 6 dígitos de HuellApp.',
  String boton = 'Verificar',
}) async {
  final aceptado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCodigo(alEnviar: alEnviar, titulo: titulo, texto: texto, boton: boton),
  );
  return aceptado ?? false;
}

class _DialogoCodigo extends StatefulWidget {
  const _DialogoCodigo({required this.alEnviar, required this.titulo, required this.texto, required this.boton});

  final Future<void> Function(String codigo) alEnviar;
  final String titulo;
  final String texto;
  final String boton;

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _codigo = TextEditingController();
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final codigo = _codigo.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'Escribe los 6 dígitos que muestra Google Authenticator.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await widget.alEnviar(codigo);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.desafioVencido) {
        // Pasaron los 5 minutos: ningún código sirve ya. Se cierra el diálogo y se avisa
        // en la pantalla de atrás para que vuelva a escribir su contraseña.
        final avisos = ScaffoldMessenger.of(context);
        Navigator.pop(context, false);
        avisos.showSnackBar(SnackBar(content: Text(e.mensaje)));
        return;
      }
      setState(() {
        _enviando = false;
        _error = e.mensaje;
      });
      _codigo.selection = TextSelection(baseOffset: 0, extentOffset: _codigo.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.verified_user_outlined, color: Color(0xFF1B4F4A)),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.titulo)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.texto, style: const TextStyle(fontSize: 14, color: Color(0xFF3F5F5B))),
          const SizedBox(height: 16),
          TextField(
            controller: _codigo,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '123456',
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _enviando ? null : _enviar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF1B4F4A))),
        ),
        ElevatedButton(
          onPressed: _enviando ? null : _enviar,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF75E6DA), foregroundColor: const Color(0xFF14312E)),
          child: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.boton),
        ),
      ],
    );
  }
}
