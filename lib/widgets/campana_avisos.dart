import 'package:flutter/material.dart';

import '../services/avisos_service.dart';

/// Campana del encabezado con el número de avisos sin leer (HU-19).
/// Al tocarla abre la lista; al elegir un aviso llama a [alElegir] con su sección.
/// Cuando llegan avisos nuevos muestra un mensaje abajo con «Ver».
class CampanaAvisos extends StatefulWidget {
  const CampanaAvisos({super.key, required this.alElegir});

  final ValueChanged<String> alElegir;

  @override
  State<CampanaAvisos> createState() => _CampanaAvisosState();
}

class _CampanaAvisosState extends State<CampanaAvisos> {
  AvisosService get _servicio => AvisosService.instancia;

  @override
  void initState() {
    super.initState();
    _servicio.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _servicio.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    final nuevos = _servicio.nuevos;
    if (nuevos.isEmpty) return;
    final primero = nuevos.first;
    _servicio.nuevos = []; // se muestra una sola vez
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(nuevos.length == 1 ? '🔔 ${primero.titulo}' : '🔔 Tienes ${nuevos.length} avisos nuevos'),
      action: SnackBarAction(label: 'Ver', onPressed: nuevos.length == 1 ? () => _elegir(primero) : _abrirLista),
    ));
  }

  Future<void> _elegir(Aviso aviso) async {
    await _servicio.marcarLeido(aviso);
    widget.alElegir(aviso.seccion);
  }

  String _hace(DateTime? f) {
    if (f == null) return '';
    final d = DateTime.now().difference(f);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return '${f.day}/${f.month}/${f.year}';
  }

  void _abrirLista() {
    _servicio.actualizar();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (hoja) => ListenableBuilder(
        listenable: _servicio,
        builder: (hoja, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(hoja).size.height * 0.75),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(children: [
                  const Expanded(child: Text('Avisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  if (_servicio.noLeidos > 0)
                    TextButton(onPressed: _servicio.marcarTodos, child: const Text('Marcar todo como leído')),
                ]),
              ),
              const Divider(height: 1),
              if (_servicio.avisos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No tienes avisos todavía.', style: TextStyle(color: Colors.black54)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _servicio.avisos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = _servicio.avisos[i];
                      return ListTile(
                        tileColor: a.leido ? null : const Color(0xFFE6F8F5),
                        leading: Icon(a.leido ? Icons.notifications_none : Icons.notifications_active, color: const Color(0xFF1B4F4A)),
                        title: Text(a.titulo, style: TextStyle(fontWeight: a.leido ? FontWeight.w500 : FontWeight.w800)),
                        subtitle: Text([if (a.texto.isNotEmpty) a.texto, _hace(a.fecha)].join('\n')),
                        isThreeLine: a.texto.isNotEmpty,
                        onTap: () {
                          Navigator.pop(hoja);
                          _elegir(a);
                        },
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _servicio.noLeidos;
    return IconButton(
      tooltip: n == 0 ? 'Avisos' : 'Avisos: $n sin leer',
      onPressed: _abrirLista,
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text(n > 9 ? '9+' : '$n'),
        child: const Icon(Icons.notifications_none, color: Colors.black, size: 28),
      ),
    );
  }
}
