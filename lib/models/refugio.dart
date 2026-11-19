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

  // Datos que vienen de la API (sirven para los filtros, igual que en el sitio web)
  final String refugioId;
  final String especie; // 'perro' | 'gato'
  final String raza;
  final String tamano; // 'pequeño' | 'mediano' | 'grande'
  final int edadMeses;

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
    this.refugioId = '',
    this.especie = '',
    this.raza = '',
    this.tamano = '',
    this.edadMeses = 0,
  });

  String get imagenPrincipal => fotos.isNotEmpty ? fotos.first : '';

  /// Convierte la mascota que devuelve la API (/api/refugios/:id/mascotas).
  factory MascotaRefugio.desdeApi(Map<String, dynamic> j, String Function(String) urlArchivo) {
    final especie = (j['especie'] as String? ?? '').toLowerCase();
    final meses = (j['edadMeses'] as num?)?.toInt() ?? 0;
    final foto = j['foto'] as String? ?? '';
    final salud = (j['salud'] as String? ?? '').trim();
    return MascotaRefugio(
      id: '${j['id']}',
      refugioId: '${j['refugioId'] ?? ''}',
      nombre: j['nombre'] as String? ?? '',
      tipo: especie == 'gato' ? 'Gato' : 'Perro',
      especie: especie,
      raza: j['raza'] as String? ?? '',
      tamano: j['tamano'] as String? ?? '',
      edadMeses: meses,
      edad: textoEdad(meses),
      genero: (j['sexo'] as String?) == 'hembra' ? 'Hembra' : 'Macho',
      descripcion: j['descripcion'] as String? ?? '',
      // La API manda «fotos» (principal + hasta 2 extra del carrusel); si no viene, solo la principal
      fotos: ((j['fotos'] as List?)?.whereType<String>().where((f) => f.isNotEmpty).toList() ?? (foto.isEmpty ? <String>[] : [foto]))
          .map(urlArchivo)
          .toList(),
      salud: salud.isEmpty ? [] : [salud],
    );
  }

  static String textoEdad(int meses) {
    if (meses < 12) return meses == 1 ? '1 mes' : '$meses meses';
    final anios = meses ~/ 12;
    return anios == 1 ? '1 año' : '$anios años';
  }
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

  /// Rescatista independiente (sin acta constitutiva): HuellApp revisó su identificación,
  /// su domicilio y fotos del lugar. Se muestra con otra insignia que un refugio verificado.
  final bool independiente;

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
    this.independiente = false,
  });

  /// Convierte el refugio que devuelve la API (/api/refugios) junto con sus mascotas.
  /// La foto que el refugio sube en su Perfil va primero; si no tiene, se usan las de sus mascotas.
  factory Refugio.desdeApi(Map<String, dynamic> j, List<MascotaRefugio> mascotas, String Function(String) urlArchivo) {
    List<String> lista(dynamic v) => v is List ? v.map((e) => '$e').toList() : <String>[];
    final direccion = j['direccion'] as String? ?? '';
    final municipio = j['municipio'] as String? ?? '';
    final necesidades = lista(j['necesidades']);
    final fotoRefugio = j['foto'] as String? ?? '';
    final fotos = [
      if (fotoRefugio.isNotEmpty) urlArchivo(fotoRefugio),
      for (final m in mascotas) ...m.fotos,
    ].take(4).toList();
    return Refugio(
      id: '${j['id']}',
      nombre: j['nombre'] as String? ?? '',
      ubicacion: municipio.isEmpty ? direccion : '$direccion, $municipio',
      descripcion: j['descripcion'] as String? ?? '',
      contacto: j['telefono'] as String? ?? '',
      imagenUrl: fotos.isNotEmpty ? fotos.first : '',
      totalMascotas: mascotas.length,
      necesidades: necesidades,
      mascotas: mascotas,
      tienePerros: j['tienePerros'] as bool? ?? true,
      tieneGatos: j['tieneGatos'] as bool? ?? true,
      necesitaDonaciones: necesidades.isNotEmpty,
      latitud: (j['latitud'] as num?)?.toDouble(),
      longitud: (j['longitud'] as num?)?.toDouble(),
      horario: (j['horario'] as String?)?.isNotEmpty == true ? j['horario'] as String : 'Por confirmar',
      whatsapp: j['whatsapp'] as String? ?? '',
      redes: lista(j['redes']),
      fotos: fotos,
      independiente: j['independiente'] as bool? ?? false,
    );
  }
}
