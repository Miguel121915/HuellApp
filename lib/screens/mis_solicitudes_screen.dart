import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../services/adopcion_service.dart';
import '../widgets/foto_huellapp.dart';
import 'guia_cuidados_screen.dart';

/// «Mis solicitudes» (HU-14): las solicitudes de adopción del usuario con su estado y la nota
/// que dejó el refugio al revisarla (HU-15).
class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  static const Color _oscuro = Color(0xFF1B4F4A);

  List<Map<String, dynamic>> _solicitudes = [];
  bool _cargando = true;
  String? _error;

  /// estado → (texto, color, ícono)
  static const Map<String, (String, Color, IconData)> _estados = {
    'pendiente': ('Pendiente', Color(0xFFB7791F), Icons.hourglass_empty),
    'en revision': ('En revisión', Color(0xFF2B6CB0), Icons.manage_search),
    'aprobada': ('¡Aprobada!', Color(0xFF2F855A), Icons.celebration),
    'rechazada': ('No aprobada', Color(0xFFC53030), Icons.cancel_outlined),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _solicitudes.isEmpty;
      _error = null;
    });
    try {
      final lista = await AdopcionService.instancia.misSolicitudes();
      if (!mounted) return;
      setState(() {
        _solicitudes = lista;
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

  String _fecha(String? iso) {
    final f = DateTime.tryParse(iso ?? '')?.toLocal();
    return f == null ? '' : '${f.day}/${f.month}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF75E6DA),
        foregroundColor: Colors.black,
        title: const Text('Mis solicitudes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_cargando)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Column(children: [
                    const SizedBox(height: 40),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                  ])
                else if (_solicitudes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60, horizontal: 16),
                    child: Column(children: [
                      Icon(Icons.pets, size: 56, color: _oscuro),
                      SizedBox(height: 12),
                      Text('Aún no has enviado solicitudes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _oscuro)),
                      SizedBox(height: 6),
                      Text('Busca una mascota en «Refugios» y toca «Solicitar adopción».',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    ]),
                  )
                else
                  ..._solicitudes.map(_tarjeta),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> s) {
    final (texto, color, icono) = _estados[s['estado']] ?? ('${s['estado']}', Colors.grey, Icons.help_outline);
    final nota = (s['notaRefugio'] as String? ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FotoHuellApp(ApiConfig.urlArchivo(s['mascotaFoto'] as String? ?? ''), width: 60, height: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['mascotaNombre'] as String? ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(s['refugioNombre'] as String? ?? '', style: const TextStyle(color: _oscuro)),
                Text('Enviada el ${_fecha(s['fecha'] as String?)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icono, size: 14, color: color),
                const SizedBox(width: 4),
                Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
          ]),
          if (nota.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF4F7F6), borderRadius: BorderRadius.circular(10)),
              child: Text('Nota del refugio: $nota', style: const TextStyle(fontSize: 13)),
            ),
          ],
          // HU-23: con la adopción aprobada, la guía para cuidar a la nueva mascota
          if (s['estado'] == 'aprobada') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _oscuro),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Ver guía de cuidado'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GuiaCuidadosScreen(
                    solicitudId: '${s['id']}',
                    mascotaNombre: s['mascotaNombre'] as String? ?? 'tu mascota',
                  ),
                )),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
