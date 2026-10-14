import 'package:flutter/material.dart';
import 'package:huellapp/data/refugios_data.dart';
import 'package:huellapp/models/refugio.dart';
import 'package:huellapp/widgets/mascota_perfil_sheet.dart';

class RefugiosScreen extends StatefulWidget {
  const RefugiosScreen({super.key});

  @override
  State<RefugiosScreen> createState() => _RefugiosScreenState();
}

class _RefugiosScreenState extends State<RefugiosScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _filtroSeleccionado = 'Todos';

  List<Refugio> get _refugiosFiltrados {
    return listaRefugios.where((refugio) {
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
    mostrarPerfilMascota(
      context,
      mascota,
      nombreRefugio,
      onCambio: () => setState(() {}),
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
