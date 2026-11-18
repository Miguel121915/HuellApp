import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'tipografia.dart';

/// Compartir una alerta con su enlace público (la misma página que usa el sitio web):
///   pages/alerta.html?id=…  se ve sin cuenta
///   pages/cartel.html?id=…  cartel imprimible con código QR (se abre en el navegador del celular)
/// La dirección sale de SITIO_URL (api/.env) si está configurada; si no, de la dirección de la API.
class Compartir {
  Compartir._();

  static String? _base;

  static Future<String> _sitio() async {
    if (_base != null) return _base!;
    try {
      final config = await ApiClient.instancia.get('/auth/config');
      final sitio = (config['sitioUrl'] as String? ?? '').trim();
      _base = sitio.isNotEmpty ? sitio : ApiConfig.servidor;
    } on ApiException {
      _base = ApiConfig.servidor;
    }
    return _base!;
  }

  static Future<String> enlaceAlerta(String id) async => '${await _sitio()}/pages/alerta.html?id=${Uri.encodeComponent(id)}';
  static Future<String> enlaceCartel(String id) async => '${await _sitio()}/pages/cartel.html?id=${Uri.encodeComponent(id)}';

  static const _especie = {'perro': 'un perrito', 'gato': 'un gatito', 'otro': 'una mascota'};

  /// Mensaje corto para WhatsApp o redes (igual que en el sitio web).
  static String texto(Map<String, dynamic> a) {
    final quien = (a['nombre'] as String?) ?? _especie[a['especie']] ?? 'una mascota';
    final zona = (a['zona'] as String?) != null ? ' en ${a['zona']}' : '';
    if (a['estado'] == 'reunido') return '💚 ¡${a['nombre'] ?? 'La mascota'} ya está en casa! Gracias a todos los que compartieron en HuellApp.';
    if (a['tipo'] == 'perdida') return '🔎 SE BUSCA: $quien, se perdió$zona. ¿La has visto? Comparte para ayudar a que vuelva a casa:';
    if (a['tipo'] == 'encontrada') return '🏠 Encontraron a $quien$zona. ¿Es tuya o conoces a su familia? Mira la alerta:';
    return 'Mira esta publicación en HuellApp:';
  }

  /// Hoja de abajo con: WhatsApp, Facebook, copiar enlace y (si es alerta activa) cartel con QR.
  static Future<void> mostrar(BuildContext context, String id) async {
    Map<String, dynamic> alerta = {'id': id, 'esAlerta': false};
    try {
      alerta = (await ApiClient.instancia.get('/alertas/$id'))['alerta'] as Map<String, dynamic>;
    } on ApiException {
      // Sin datos de la alerta se comparte igual, con un mensaje genérico
    }
    final url = await enlaceAlerta(id);
    final cartel = await enlaceCartel(id);
    final mensaje = '${texto(alerta)} $url';
    final conCartel = alerta['esAlerta'] == true && alerta['estado'] != 'reunido';
    if (!context.mounted) return;

    Future<void> abrir(String direccion) async {
      final ok = await launchUrl(Uri.parse(direccion), mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir. Copia el enlace y pégalo donde quieras.')));
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Compartir alerta',
                  style: TextStyle(fontFamily: Tipografia.fuenteTitulos, fontSize: 22, fontWeight: FontWeight.w600, color: Tipografia.aquaFuerte)),
              const SizedBox(height: 4),
              const Text('Mientras más personas la vean, más fácil es que vuelva a casa.',
                  style: TextStyle(fontSize: 13.5, color: Tipografia.tintaSuave)),
              const SizedBox(height: 12),
              _opcion(Icons.chat, 'WhatsApp', const Color(0xFF1F7A52), () {
                Navigator.pop(hoja);
                abrir('https://wa.me/?text=${Uri.encodeComponent(mensaje)}');
              }),
              _opcion(Icons.facebook, 'Facebook', const Color(0xFF1877F2), () {
                Navigator.pop(hoja);
                abrir('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}');
              }),
              _opcion(Icons.link, 'Copiar enlace', Tipografia.aquaFuerte, () async {
                await Clipboard.setData(ClipboardData(text: mensaje));
                if (hoja.mounted) Navigator.pop(hoja);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado: pégalo en WhatsApp o tus redes.')));
                }
              }),
              if (conCartel)
                _opcion(Icons.print_outlined, 'Imprimir cartel con QR', const Color(0xFFB42318), () {
                  Navigator.pop(hoja);
                  abrir(cartel);
                }),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _opcion(IconData icono, String texto, Color color, VoidCallback alTocar) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icono, color: color)),
        title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: alTocar,
      );
}
