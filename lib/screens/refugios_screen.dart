import 'package:flutter/material.dart';

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
  });
}

class RefugiosScreen extends StatefulWidget {
  const RefugiosScreen({super.key});

  @override
  State<RefugiosScreen> createState() => _RefugiosScreenState();
}

class _RefugiosScreenState extends State<RefugiosScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _filtroSeleccionado = 'Todos';

  final List<Refugio> _listaRefugios = [
    Refugio(
      id: '1',
      nombre: 'Refugio Huellitas Chalco',
      ubicacion: 'Chalco, Edo. de México',
      descripcion: 'Dedicados al rescate, rehabilitación y adopción responsable de animales en situación de calle.',
      contacto: '55 1234 5678',
      imagenUrl:
          'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=500',
      totalMascotas: 18,
      necesidades: ['Croquetas adulto/cachorro', 'Cobijas', 'Desparasitantes'],
      tienePerros: true,
      tieneGatos: true,
      necesitaDonaciones: true,
      mascotas: [
        MascotaRefugio(
          id: 'm1',
          nombre: 'Rocky',
          tipo: 'Perro',
          edad: '2 años',
          genero: 'Macho',
          descripcion: 'Rocky es un perrito muy juguetón, activo y sociable con niños. Le encanta correr en el parque y aprender trucos.',
          fotos: [
            'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=500',
            'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500',
            'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=500',
          ],
          salud: ['Vacunas completas', 'Esterilizado', 'Desparasitado'],
        ),
        MascotaRefugio(
          id: 'm2',
          nombre: 'Luna',
          tipo: 'Gato',
          edad: '1 año',
          genero: 'Hembra',
          descripcion: 'Luna es una gatita tranquila, cariñosa y muy limpia. Le gusta dormir bajo los rayos del sol y recibir mimos en la barbilla.',
          fotos: [
            'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500',
            'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=500',
          ],
          salud: ['Esterilizada', 'Prueba FIV/FeLV Negativa', 'Desparasitada'],
        ),
      ],
    ),
    Refugio(
      id: '2',
      nombre: 'Hogar Temporal Ixtapaluca',
      ubicacion: 'Ixtapaluca, Edo. de México',
      descripcion: 'Santuario comunitario enfocando esfuerzos en esterilización masiva y cuidado de gatos y perros viejitos.',
      contacto: '55 8765 4321',
      imagenUrl:
          'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=500',
      totalMascotas: 12,
      necesidades: [
        'Croquetas para gato',
        'Arena sanitaria',
        'Material de curación',
      ],
      tienePerros: false,
      tieneGatos: true,
      necesitaDonaciones: true,
      mascotas: [
        MascotaRefugio(
          id: 'm3',
          nombre: 'Michi',
          tipo: 'Gato',
          edad: '3 años',
          genero: 'Macho',
          descripcion: 'Michi es independiente pero muy curioso. Se adapta fácilmente a nuevos entornos y convive sin problema con otros gatos.',
          fotos: [
            'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=500',
            'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=500',
          ],
          salud: ['Vacunado', 'Esterilizado'],
        ),
      ],
    ),
  ];

  List<Refugio> get _refugiosFiltrados {
    return _listaRefugios.where((refugio) {
      final coincideTexto =
          refugio.nombre.toLowerCase().contains(
            _busquedaController.text.toLowerCase(),
          ) ||
          refugio.ubicacion.toLowerCase().contains(
            _busquedaController.text.toLowerCase(),
          );

      if (!coincideTexto) return false;

      if (_filtroSeleccionado == 'Perros') return refugio.tienePerros;
      if (_filtroSeleccionado == 'Gatos') return refugio.tieneGatos;
      if (_filtroSeleccionado == 'Urgente') return refugio.necesitaDonaciones;

      return true;
    }).toList();
  }

  void _abrirPerfilMascota(MascotaRefugio mascota, String nombreRefugio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Galería de fotos con PageView
                        SizedBox(
                          height: 280,
                          child: PageView.builder(
                            itemCount: mascota.fotos.length,
                            itemBuilder: (context, index) {
                              return Image.network(
                                mascota.fotos[index],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.pets, size: 60),
                                    ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    mascota.nombre,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      mascota.esFavorito
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: mascota.esFavorito
                                          ? Colors.red
                                          : Colors.grey,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        mascota.esFavorito =
                                            !mascota.esFavorito;
                                      });
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                '${mascota.tipo} · ${mascota.edad} · ${mascota.genero}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.home,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    nombreRefugio,
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              const Text(
                                'Sobre la mascota',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                mascota.descripcion,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Estado de Salud',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: mascota.salud
                                    .map(
                                      (s) => Chip(
                                        avatar: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                        label: Text(
                                          s,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.teal.shade50,
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF75E6DA),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Solicitud de adopción enviada para ${mascota.nombre}',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.pets,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    'Solicitar Adopción de ${mascota.nombre}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarMascotasModal(Refugio refugio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Mascotas en ${refugio.nombre}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: refugio.mascotas.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay mascotas registradas por ahora.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: refugio.mascotas.length,
                            itemBuilder: (context, index) {
                              final mascota = refugio.mascotas[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _abrirPerfilMascota(
                                    mascota,
                                    refugio.nombre,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 110,
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        // Imagen Rectangular
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            mascota.imagenPrincipal,
                                            width: 110,
                                            height: 94,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 110,
                                                      height: 94,
                                                      color:
                                                          Colors.grey.shade300,
                                                      child: const Icon(
                                                        Icons.pets,
                                                        size: 40,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Información Horizontal Rectangular
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    mascota.nombre,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    constraints:
                                                        const BoxConstraints(),
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(
                                                      mascota.esFavorito
                                                          ? Icons.favorite
                                                          : Icons
                                                                .favorite_border,
                                                      color: mascota.esFavorito
                                                          ? Colors.red
                                                          : Colors.grey,
                                                      size: 22,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        mascota.esFavorito =
                                                            !mascota.esFavorito;
                                                      });
                                                      setModalState(() {});
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${mascota.tipo} · ${mascota.edad} (${mascota.genero})',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${mascota.fotos.length} foto(s) · Toca para ver perfil',
                                                style: const TextStyle(
                                                  color: Colors.teal,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarContactoModal(Refugio refugio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(refugio.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(refugio.ubicacion)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Contacto: ${refugio.contacto}')),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Necesidades actuales de donación:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...refugio.necesidades.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                child: Text('• $item'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF75E6DA),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Contactando a ${refugio.nombre}...')),
              );
            },
            icon: const Icon(Icons.chat, color: Colors.black),
            label: const Text(
              'Contactar',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Refugios y Adopciones',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaController,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar refugio o municipio...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Perros', 'Gatos', 'Urgente'].map((
                      filtro,
                    ) {
                      final selected = _filtroSeleccionado == filtro;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(filtro),
                          selected: selected,
                          selectedColor: const Color(0xFF75E6DA),
                          onSelected: (bool value) {
                            setState(() {
                              _filtroSeleccionado = filtro;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _refugiosFiltrados.isEmpty
                ? const Center(
                    child: Text('No se encontraron refugios con este filtro.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _refugiosFiltrados.length,
                    itemBuilder: (context, index) {
                      final refugio = _refugiosFiltrados[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                refugio.imagenUrl,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 160,
                                      color: Colors.teal.shade100,
                                      child: const Icon(
                                        Icons.store,
                                        size: 50,
                                        color: Colors.teal,
                                      ),
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          refugio.nombre,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        refugio.ubicacion,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    refugio.descripcion,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _mostrarMascotasModal(refugio),
                                          icon: const Icon(
                                            Icons.pets,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Ver Mascotas (${refugio.totalMascotas})',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF75E6DA,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _mostrarContactoModal(refugio),
                                          icon: const Icon(
                                            Icons.favorite,
                                            size: 16,
                                            color: Colors.black,
                                          ),
                                          label: const Text(
                                            'Apoyar / Contacto',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
