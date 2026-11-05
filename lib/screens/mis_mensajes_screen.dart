import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../services/refugio_service.dart' show fechaCorta;
import '../services/usuario_service.dart';
import '../widgets/foto_huellapp.dart';

const Color _turquoise = Color(0xFF75E6DA);
const Color _accent = Color(0xFF1B4F4A);
const Color _fondo = Color(0xFFE6F8F5);
const Color _tinta = Color(0xFF14312E);

/// HU-13: lo que el usuario les escribió a los refugios y sus respuestas
/// (lo mismo que la página «Mensajes» del sitio web).
class MisMensajesScreen extends StatefulWidget {
  const MisMensajesScreen({super.key});

  @override
  State<MisMensajesScreen> createState() => _MisMensajesScreenState();
}

class _MisMensajesScreenState extends State<MisMensajesScreen> {
  static const Map<String, (String, Color)> _estados = {
    'nuevo': ('Enviado', Color(0xFFB7791F)),
    'leido': ('Leído', Color(0xFFB7791F)),
    'respondido': ('Respondido', Color(0xFF1F7A52)),
  };

  List<Map<String, dynamic>> _mensajes = [];
  bool _cargando = true;
  String? _error;

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
      final r = await ContactoService.instancia.misMensajes();
      if (!mounted) return;
      setState(() {
        _mensajes = r;
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

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator(color: _accent));
    } else if (_error != null) {
      cuerpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ]),
        ),
      );
    } else if (_mensajes.isEmpty) {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.all(32), children: const [
          Icon(Icons.mail_outline, size: 64, color: _accent),
          SizedBox(height: 12),
          Text('Aún no le has escrito a ningún refugio', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(
            '¿Tienes dudas sobre una mascota o el proceso de adopción? Abre su perfil y toca «Preguntar al refugio».',
            textAlign: TextAlign.center,
          ),
        ]),
      );
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _mensajes.length,
          itemBuilder: (context, i) => _tarjeta(_mensajes[i]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _turquoise,
        foregroundColor: _tinta,
        title: const Text('Mis mensajes', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: cuerpo,
    );
  }

  Widget _tarjeta(Map<String, dynamic> m) {
    final estado = _estados[m['estado']] ?? _estados['nuevo']!;
    final respuesta = m['respuesta'] as String? ?? '';
    final foto = ContactoService.urlFoto(m['mascotaFoto'] as String? ?? '');
    final mascota = m['mascotaNombre'] as String? ?? '';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (foto.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: FotoHuellApp(foto, width: 44, height: 44)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['refugioNombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: _tinta)),
                      Text(
                        [if (mascota.isNotEmpty) 'Sobre $mascota', fechaCorta(m['fecha'] as String?)].join(' · '),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(estado.$1, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: estado.$2,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(m['mensaje'] as String? ?? ''),
            if (respuesta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                // Sin esquinas redondeadas: Flutter no permite radio con un borde de un solo lado
                decoration: const BoxDecoration(
                  color: _fondo,
                  border: Border(left: BorderSide(color: _accent, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Respuesta de ${m['refugioNombre']}', style: const TextStyle(fontWeight: FontWeight.bold, color: _accent)),
                    const SizedBox(height: 4),
                    Text(respuesta),
                    if (m['respondido'] != null)
                      Text(fechaCorta(m['respondido'] as String?), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
