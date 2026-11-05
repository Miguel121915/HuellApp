import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/requiere_sesion.dart';
import '../core/sesion_service.dart';
import '../models/refugio.dart';
import '../services/usuario_service.dart';

const Color _turquoise = Color(0xFF75E6DA);
const Color _accent = Color(0xFF1B4F4A);
const Color _tinta = Color(0xFF14312E);

/// HU-13: hoja para escribirle al refugio (en general o sobre una [mascota]).
/// El visitante primero tiene que iniciar sesión. La respuesta llega a «Mis mensajes».
Future<void> abrirContactoRefugio(
  BuildContext context, {
  required String refugioId,
  required String refugioNombre,
  MascotaRefugio? mascota,
}) async {
  if (!await requiereSesion(context, 'escribirle al refugio')) return;
  if (!context.mounted) return;
  if (SesionService.instancia.actual?.rol != 'usuario') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solo las cuentas de usuario pueden escribirles a los refugios.')),
    );
    return;
  }
  final enviado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _HojaContacto(refugioId: refugioId, refugioNombre: refugioNombre, mascota: mascota),
  );
  if (enviado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Mensaje enviado a $refugioNombre. Verás su respuesta en «Mis mensajes».'),
    ));
  }
}

class _HojaContacto extends StatefulWidget {
  const _HojaContacto({required this.refugioId, required this.refugioNombre, this.mascota});

  final String refugioId;
  final String refugioNombre;
  final MascotaRefugio? mascota;

  @override
  State<_HojaContacto> createState() => _HojaContactoState();
}

class _HojaContactoState extends State<_HojaContacto> {
  final _mensaje = TextEditingController();
  final _telefono = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _mensaje.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ContactoService.instancia.enviar(
        refugioId: widget.refugioId,
        mascotaId: widget.mascota?.id,
        mensaje: _mensaje.text.trim(),
        telefono: _telefono.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mascota;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Escribir al refugio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _tinta)),
              const SizedBox(height: 4),
              Text(
                m == null ? 'Para ${widget.refugioNombre}' : 'Para ${widget.refugioNombre} · sobre ${m.nombre}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mensaje,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Tu mensaje',
                  hintText: m == null
                      ? 'Ej. Hola, ¿qué días puedo visitar el refugio?'
                      : 'Ej. Hola, me interesa ${m.nombre}. ¿Cuándo puedo conocerlo?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v ?? '').trim().length < 10 ? 'Escribe al menos 10 caracteres' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                maxLength: 25,
                decoration: InputDecoration(
                  labelText: 'Teléfono para que te llamen (opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[\d\s+()\-]{8,}$').hasMatch(t) ? null : 'Al menos 8 dígitos';
                },
              ),
              const Text(
                'El refugio verá tu nombre y tu correo.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _turquoise,
                    foregroundColor: _tinta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Enviar mensaje', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HU-16: requisitos de adopción de un refugio (los define el refugio en su panel).
class RequisitosRefugio extends StatefulWidget {
  const RequisitosRefugio({super.key, required this.refugioId});

  final String refugioId;

  @override
  State<RequisitosRefugio> createState() => _RequisitosRefugioState();
}

class _RequisitosRefugioState extends State<RequisitosRefugio> {
  late Future<List<Map<String, dynamic>>> _futuro = ContactoService.instancia.requisitos(widget.refugioId);

  @override
  void didUpdateWidget(covariant RequisitosRefugio anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.refugioId != widget.refugioId) _futuro = ContactoService.instancia.requisitos(widget.refugioId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.refugioId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuro,
      builder: (context, foto) {
        if (foto.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))),
          );
        }
        if (foto.hasError) {
          return TextButton.icon(
            onPressed: () => setState(() => _futuro = ContactoService.instancia.requisitos(widget.refugioId)),
            icon: const Icon(Icons.refresh),
            label: const Text('No se pudieron cargar los requisitos. Reintentar'),
          );
        }
        final requisitos = foto.data ?? [];
        if (requisitos.isEmpty) {
          return const Text(
            'Este refugio aún no publica requisitos. Puedes escribirle para preguntar.',
            style: TextStyle(color: Colors.black54),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final q in requisitos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      (q['obligatorio'] as bool? ?? true) ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: _accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: q['texto'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: _tinta)),
                            TextSpan(
                              text: (q['obligatorio'] as bool? ?? true) ? '  · Obligatorio' : '  · Recomendable',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ])),
                          if ((q['detalle'] as String? ?? '').isNotEmpty)
                            Text(q['detalle'] as String, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
