import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../models/refugio.dart';
import '../services/usuario_service.dart';
import '../widgets/foto_huellapp.dart';
import '../widgets/mascota_perfil_sheet.dart';

const Color _turquoise = Color(0xFF75E6DA);
const Color _accent = Color(0xFF1B4F4A);
const Color _fondo = Color(0xFFE6F8F5);
const Color _tinta = Color(0xFF14312E);

const Map<String, String> _estatusTexto = {'disponible': 'Disponible', 'en proceso': 'En proceso', 'adoptado': 'Adoptado'};

/// HU-12: mis mascotas favoritas. Se pueden quitar y comparar de 2 a 3 a la vez
/// (lo mismo que la página «Favoritos» del sitio web).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  static const int _maxComparar = 3;

  final Set<String> _seleccion = {};
  bool _cargando = true;

  FavoritosService get _servicio => FavoritosService.instancia;

  @override
  void initState() {
    super.initState();
    _servicio.addListener(_alCambiar);
    _recargar();
  }

  @override
  void dispose() {
    _servicio.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() => _seleccion.removeWhere((id) => !_servicio.esFavorito(id)));
  }

  Future<void> _recargar() async {
    await _servicio.cargar();
    if (mounted) setState(() => _cargando = false);
  }

  MascotaRefugio _comoMascota(Map<String, dynamic> m) =>
      MascotaRefugio.desdeApi(m, ApiConfig.urlArchivo)..esFavorito = true;

  void _alternarSeleccion(String id) {
    setState(() {
      if (_seleccion.contains(id)) {
        _seleccion.remove(id);
      } else if (_seleccion.length < _maxComparar) {
        _seleccion.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puedes comparar hasta 3 mascotas a la vez.')),
        );
      }
    });
  }

  void _comparar() {
    final elegidas = _servicio.lista.where((m) => _seleccion.contains('${m['id']}')).toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ComparacionScreen(mascotas: elegidas)));
  }

  @override
  Widget build(BuildContext context) {
    final lista = _servicio.lista;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _turquoise,
        foregroundColor: _tinta,
        title: const Text('Mis favoritos', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: lista.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _seleccion.length >= 2 ? _comparar : null,
              backgroundColor: _seleccion.length >= 2 ? _accent : Colors.grey,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.compare_arrows),
              label: Text(_seleccion.length >= 2 ? 'Comparar (${_seleccion.length})' : 'Marca 2 o 3 para comparar'),
            )
          : null,
      body: _cargando && lista.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: _servicio.cargar,
              child: lista.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: const [
                        Icon(Icons.favorite_border, size: 64, color: _accent),
                        SizedBox(height: 12),
                        Text('Aún no tienes favoritos', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text(
                          'Toca el ♡ de una mascota en Inicio o en Refugios para guardarla aquí y compararla después.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemCount: lista.length,
                      itemBuilder: (context, i) => _tarjeta(lista[i]),
                    ),
            ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> m) {
    final id = '${m['id']}';
    final mascota = _comoMascota(m);
    final estatus = m['estatus'] as String? ?? 'disponible';
    final seleccionada = _seleccion.contains(id);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: seleccionada ? const BorderSide(color: _accent, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => mostrarPerfilMascota(context, mascota, m['refugioNombre'] as String? ?? ''),
        child: Row(
          children: [
            FotoHuellApp(mascota.imagenPrincipal, width: 96, height: 104, fit: BoxFit.cover),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mascota.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _tinta)),
                  Text('${mascota.tipo} · ${mascota.edad} · ${mascota.genero}', style: const TextStyle(fontSize: 12)),
                  Text(m['refugioNombre'] as String? ?? '', style: const TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.w600)),
                  if (estatus != 'disponible')
                    Text(_estatusTexto[estatus] ?? estatus, style: const TextStyle(fontSize: 12, color: Color(0xFFB7791F), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Quitar de favoritos',
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _servicio.establecer(context, id, false, nombre: mascota.nombre),
                ),
                Tooltip(
                  message: 'Comparar',
                  child: Checkbox(
                    value: seleccionada,
                    activeColor: _accent,
                    onChanged: (_) => _alternarSeleccion(id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Comparación lado a lado (las filas con valores distintos se resaltan, igual que en la web).
class _ComparacionScreen extends StatelessWidget {
  const _ComparacionScreen({required this.mascotas});

  final List<Map<String, dynamic>> mascotas;

  static String _mayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  static final List<(String, String Function(Map<String, dynamic>))> _filas = [
    ('Especie', (m) => m['especie'] == 'gato' ? 'Gato' : 'Perro'),
    ('Raza', (m) => m['raza'] as String? ?? ''),
    ('Edad', (m) => MascotaRefugio.textoEdad((m['edadMeses'] as num?)?.toInt() ?? 0)),
    ('Sexo', (m) => _mayuscula(m['sexo'] as String? ?? '')),
    ('Tamaño', (m) => _mayuscula(m['tamano'] as String? ?? '')),
    ('Salud', (m) => m['salud'] as String? ?? ''),
    ('Estatus', (m) => _estatusTexto[m['estatus']] ?? '${m['estatus']}'),
    ('Refugio', (m) {
      final municipio = m['refugioMunicipio'] as String? ?? '';
      return '${m['refugioNombre'] ?? ''}${municipio.isEmpty ? '' : ' ($municipio)'}';
    }),
    ('Descripción', (m) => m['descripcion'] as String? ?? ''),
  ];

  @override
  Widget build(BuildContext context) {
    const anchoColumna = 150.0;
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _turquoise,
        foregroundColor: _tinta,
        title: const Text('Comparación', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(anchoColumna),
            columnWidths: const {0: FixedColumnWidth(96)},
            border: TableBorder.all(color: const Color(0xFF9ED9D1)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _turquoise),
                children: [
                  const SizedBox.shrink(),
                  for (final m in mascotas)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: FotoHuellApp(ApiConfig.urlArchivo(m['foto'] as String? ?? ''), width: anchoColumna - 16, height: 96),
                        ),
                        const SizedBox(height: 6),
                        Text(m['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ),
                ],
              ),
              for (final (etiqueta, valor) in _filas)
                () {
                  final valores = mascotas.map(valor).toList();
                  final distintos = valores.toSet().length > 1;
                  return TableRow(
                    decoration: BoxDecoration(color: distintos ? const Color(0xFFFDECB5) : Colors.white),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3F5F5B))),
                      ),
                      for (final v in valores)
                        Padding(padding: const EdgeInsets.all(8), child: Text(v.isEmpty ? '—' : v)),
                    ],
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}
