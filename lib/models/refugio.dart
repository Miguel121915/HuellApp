// Modelos de refugios y mascotas, compartidos por todas las pantallas.

class MascotaRefugio {
  final String id;
  final String nombre;
  final String tipo;
  final String edad;
  final String genero;
  final String descripcion;
  final List<String> fotos;
  final List<String> salud;
  bool esFavorito;

  MascotaRefugio({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.edad,
    required this.genero,
    required this.descripcion,
    required this.fotos,
    required this.salud,
    this.esFavorito = false,
  });

  String get imagenPrincipal => fotos.isNotEmpty ? fotos.first : '';
}

class Refugio {
  final String id;
  final String nombre;
  final String ubicacion;
  final String descripcion;
  final String contacto;
  final String imagenUrl;
  final int totalMascotas;
  final List<String> necesidades;
  final List<MascotaRefugio> mascotas;
  final bool tienePerros;
  final bool tieneGatos;
  final bool necesitaDonaciones;

  // Ubicación y datos del perfil (los captura el refugio desde su panel)
  final double? latitud;
  final double? longitud;
  final String horario;
  final String whatsapp;
  final List<String> redes;
  final List<String> fotos;

  Refugio({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.descripcion,
    required this.contacto,
    required this.imagenUrl,
    required this.totalMascotas,
    required this.necesidades,
    required this.mascotas,
    this.tienePerros = true,
    this.tieneGatos = true,
    this.necesitaDonaciones = true,
    this.latitud,
    this.longitud,
    this.horario = 'Por confirmar',
    this.whatsapp = '',
    this.redes = const [],
    this.fotos = const [],
  });
}
