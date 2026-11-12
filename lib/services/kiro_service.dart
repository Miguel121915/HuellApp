import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/refugio.dart';

/// Una mascota que recomienda KIRO, con el nombre de su refugio (para abrir su perfil).
class MascotaRecomendada {
  const MascotaRecomendada(this.mascota, this.refugioNombre);

  final MascotaRefugio mascota;
  final String refugioNombre;
}

class RespuestaKiro {
  const RespuestaKiro({required this.texto, this.mascotas = const [], this.enlace, this.iaUsada = false});

  final String texto;
  final List<MascotaRecomendada> mascotas;

  /// Sección sugerida: 'refugios', 'reportar', 'coincidencias', 'favoritos', 'foro', 'mensajes'…
  final String? enlace;
  final bool iaUsada;
}

/// KIRO, el asistente de adopción (HU-7): POST /api/kiro, igual que el sitio web.
class KiroService {
  KiroService._();

  static final KiroService instancia = KiroService._();

  /// [historial]: mensajes anteriores [{rol: 'usuario'|'kiro', texto}] para que recuerde la conversación.
  Future<RespuestaKiro> preguntar(String mensaje, List<Map<String, String>> historial) async {
    final r = await ApiClient.instancia.post(
      '/kiro',
      {'mensaje': mensaje, 'historial': historial.length > 8 ? historial.sublist(historial.length - 8) : historial},
      const Duration(seconds: 60),
    );
    return RespuestaKiro(
      texto: r['respuesta'] as String? ?? '',
      enlace: r['enlace'] as String?,
      iaUsada: r['iaUsada'] == true,
      mascotas: (r['mascotas'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .map((m) => MascotaRecomendada(
                MascotaRefugio.desdeApi(m, ApiConfig.urlArchivo),
                m['refugioNombre'] as String? ?? '',
              ))
          .toList(),
    );
  }
}
