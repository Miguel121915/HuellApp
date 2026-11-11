import 'dart:async';

import 'package:flutter/material.dart';
import 'package:huellapp/widgets/foto_huellapp.dart';
import 'package:huellapp/data/refugios_data.dart';
import 'package:huellapp/models/refugio.dart';
import 'package:huellapp/services/catalogo_service.dart';
import 'package:huellapp/services/usuario_service.dart';
import 'package:huellapp/widgets/mascota_perfil_sheet.dart';

class RefugiosScreen extends StatefulWidget {
  const RefugiosScreen({super.key});

  @override
  State<RefugiosScreen> createState() => _RefugiosScreenState();
}

class _RefugiosScreenState extends State<RefugiosScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _filtroSeleccionado = 'Todos';

  @override
  void initState() {
    super.initState();
    CatalogoService.instancia.addListener(_alCambiarCatalogo);
    CatalogoService.instancia.cargar();
    // El corazón de favoritos cambia también desde otras pantallas (HU-12)
    FavoritosService.instancia.addListener(_alCambiarFavoritos);
  }

  void _alCambiarFavoritos() {
    if (mounted) setState(() {});
  }

  void _alCambiarCatalogo() {
    if (!mounted) return;
    final catalogo = CatalogoService.instancia;
    if (catalogo.busquedaPendiente.isNotEmpty) {
      // Viene de la búsqueda de Inicio
      _busquedaController.text = catalogo.busquedaPendiente;
      catalogo.busquedaPendiente = '';
    }
    setState(() {});
  }

  @override
  void dispose() {
    CatalogoService.instancia.removeListener(_alCambiarCatalogo);
    FavoritosService.instancia.removeListener(_alCambiarFavoritos);
    _busquedaController.dispose();
    super.dispose();
  }

  /// Lo que se muestra cuando la lista está vacía: cargando, error o sin resultados.
  Widget _listaVacia() {
    final catalogo = CatalogoService.instancia;
    if (catalogo.cargando) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1B4943)));
    }
    if (catalogo.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(catalogo.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => catalogo.cargar(forzar: true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: Text('No se encontraron refugios con este filtro.'));
  }

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

  // Filtros de mascotas (los mismos que tiene el sitio web: nombre, especie, edad y tamaño)
  static const _especies = {'todas': 'Especie', 'perro': 'Perros', 'gato': 'Gatos'};
  static const _edades = {
    'todas': 'Edad',
    'cachorro': 'Cachorro (< 1 año)',
    'joven': 'Joven (1–2)',
    'adulto': 'Adulto (3–7)',
    'senior': 'Senior (8+)',
  };
  static const _tamanos = {'todos': 'Tamaño', 'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'};

  bool _pasaFiltros(MascotaRefugio m, String texto, String especie, String edad, String tamano) {
    if (texto.isNotEmpty && !m.nombre.toLowerCase().contains(texto) && !m.raza.toLowerCase().contains(texto)) {
      return false;
    }
    if (especie != 'todas' && m.especie != especie) return false;
    if (tamano != 'todos' && m.tamano != tamano) return false;
    if (edad == 'cachorro' && m.edadMeses >= 12) return false;
    if (edad == 'joven' && (m.edadMeses < 12 || m.edadMeses >= 36)) return false;
    if (edad == 'adulto' && (m.edadMeses < 36 || m.edadMeses >= 96)) return false;
    if (edad == 'senior' && m.edadMeses < 96) return false;
    return true;
  }

  Widget _selectorFiltro(Map<String, String> opciones, String valor, ValueChanged<String> alCambiar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: [
            for (final e in opciones.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => alCambiar(v ?? opciones.keys.first),
        ),
      ),
    );
  }

  void _mostrarMascotasModal(Refugio refugio) {
    String texto = '';
    String especie = 'todas';
    String edad = 'todas';
    String tamano = 'todos';
    // Filtros (HU-3): se envían a la API; mientras responde (o si falla) se filtra aquí mismo
    Set<String>? idsApi;
    var consulta = 0;
    Timer? espera;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filtrar(void Function() cambio, {bool conEspera = false}) {
              setModalState(() {
                cambio();
                idsApi = null; // hasta que conteste la API se usa el filtro local
              });
              espera?.cancel();
              final sinFiltros = texto.isEmpty && especie == 'todas' && edad == 'todas' && tamano == 'todos';
              if (sinFiltros) return;
              final id = ++consulta;
              espera = Timer(Duration(milliseconds: conEspera ? 300 : 0), () async {
                try {
                  final ids = await CatalogoService.instancia
                      .filtrarMascotas(refugio.id, texto: texto, especie: especie, edad: edad, tamano: tamano);
                  if (id == consulta && context.mounted) setModalState(() => idsApi = ids);
                } catch (_) {
                  // Sin conexión con la API: se queda el filtro local
                }
              });
            }

            final visibles = refugio.mascotas
                .where((m) => idsApi != null ? idsApi!.contains(m.id) : _pasaFiltros(m, texto, especie, edad, tamano))
                .toList();
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
                  if (refugio.mascotas.isNotEmpty) ...[
                    TextField(
                      onChanged: (v) => filtrar(() => texto = v.trim().toLowerCase(), conEspera: true),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o raza...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _selectorFiltro(_especies, especie, (v) => filtrar(() => especie = v)),
                        _selectorFiltro(_edades, edad, (v) => filtrar(() => edad = v)),
                        _selectorFiltro(_tamanos, tamano, (v) => filtrar(() => tamano = v)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: visibles.isEmpty
                        ? Center(
                            child: Text(
                              refugio.mascotas.isEmpty
                                  ? 'No hay mascotas disponibles por ahora.'
                                  : 'Ninguna mascota coincide con los filtros.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibles.length,
                            itemBuilder: (context, index) {
                              final mascota = visibles[index];
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
                                          child: FotoHuellApp(
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
                                                    onPressed: () async {
                                                      await FavoritosService.instancia.alternar(context, mascota);
                                                      if (!mounted) return;
                                                      setState(() {});
                                                      if (context.mounted) setModalState(() {});
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
                ? _listaVacia()
                : RefreshIndicator(
                    onRefresh: () => CatalogoService.instancia.cargar(forzar: true),
                    child: ListView.builder(
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
                              child: FotoHuellApp(
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
          ),
        ],
      ),
    );
  }
}
