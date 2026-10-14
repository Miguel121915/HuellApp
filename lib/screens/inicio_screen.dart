import 'package:flutter/material.dart';
import 'package:huellapp/data/refugios_data.dart';
import 'package:huellapp/models/refugio.dart';
import 'package:huellapp/screens/kiro_home_screen.dart';
import 'package:huellapp/screens/refugios_cercanos_screen.dart';
import 'package:huellapp/widgets/mascota_perfil_sheet.dart';

/// Pantalla de inicio: bienvenida, búsqueda, accesos rápidos y mascotas en
/// adopción. KIRO queda como un botón flotante que abre su propia pantalla.
class InicioScreen extends StatefulWidget {
  /// Cambia de sección en la pantalla principal (AppShell):
  /// 0 Foro, 1 Refugios, 2 Inicio, 3 Reportar, 4 Coincidencias.
  final ValueChanged<int> onIrA;

  const InicioScreen({super.key, required this.onIrA});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _MascotaConRefugio {
  final MascotaRefugio mascota;
  final String refugio;
  _MascotaConRefugio(this.mascota, this.refugio);
}

class _InicioScreenState extends State<InicioScreen> {
  static const Color _turquoise = Color(0xFF75E6DA);
  static const Color _darkTeal = Color(0xFF1B4943);
  static const Color _textColor = Color(0xFF14312E);
  static const Color _mutedColor = Color(0xFF3F5F5B);
  static const double _anchoMaximo = 720;

  final TextEditingController _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // Mascotas de todos los refugios (las primeras 8)
  List<_MascotaConRefugio> get _mascotas => [
    for (final r in listaRefugios)
      for (final m in r.mascotas) _MascotaConRefugio(m, r.nombre),
  ].take(8).toList();

  // ---------- Acciones ----------

  void _abrir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
  }

  // "Alerta Patitas" y "Reportar" abren la misma sección
  void _abrirReportar() => widget.onIrA(3);

  void _buscar() {
    // TODO: pasar el texto a RefugiosScreen para que filtre los resultados
    widget.onIrA(1);
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FCFA),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _anchoMaximo),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  children: [
                    _buildBienvenida(),
                    _buildAccesos(),
                    _buildMascotas(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(right: 14, bottom: 12, child: _buildBotonKiro()),
        ],
      ),
    );
  }

  // Banner de bienvenida con la búsqueda
  Widget _buildBienvenida() {
    return Container(
      height: 250,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFD3F4EE),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -50,
            child: Container(
              width: 290,
              height: 290,
              decoration: const BoxDecoration(
                color: Color(0xFFBDEEE4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // TODO: reemplazar por una foto guardada en assets
          // (Image.asset('assets/images/hero_perro.png'))
          const Positioned(
            right: 8,
            bottom: 66,
            child: Text('🐶', style: TextStyle(fontSize: 120)),
          ),
          Positioned(
            left: 20,
            top: 22,
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cada mascota merece un hogar',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Color(0xFF0F4A44),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adopta · Reporta · Comparte',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F4A44),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 3,
              color: Colors.white,
              shape: const StadiumBorder(),
              child: TextField(
                controller: _busquedaController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Busca mascotas o refugios',
                  prefixIcon: const Icon(Icons.search, color: _darkTeal),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.arrow_forward, color: _darkTeal),
                    onPressed: _buscar,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cuatro accesos redondos
  Widget _buildAccesos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _acceso(
            Icons.pets,
            'Adopción',
            const Color(0xFFCFF3EC),
            () => widget.onIrA(1),
          ),
          _acceso(
            Icons.warning_amber_rounded,
            'Alerta Patitas',
            const Color(0xFFFFF0C2),
            _abrirReportar,
          ),
          _acceso(
            Icons.location_on,
            'Refugios cerca de ti',
            const Color(0xFFD5F0F8),
            () => _abrir(const RefugiosCercanosScreen()),
          ),
          _acceso(
            Icons.photo_camera,
            'Reportar',
            const Color(0xFFE6E0FA),
            _abrirReportar,
          ),
        ],
      ),
    );
  }

  Widget _acceso(
    IconData icono,
    String texto,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color,
                child: Icon(icono, size: 30, color: _textColor),
              ),
              const SizedBox(height: 6),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: _textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fila de mascotas en adopción
  Widget _buildMascotas() {
    final lista = _mascotas;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B4943),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 20, color: _darkTeal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mascotas en adopción',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                // TODO: decidir si "Ver más" abre una pantalla propia
                onPressed: () => widget.onIrA(1),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ver más', style: TextStyle(color: _darkTeal)),
                    Icon(Icons.chevron_right, size: 18, color: _darkTeal),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 14, bottom: 8),
              child: Text(
                'Aún no hay mascotas publicadas.',
                style: TextStyle(color: _mutedColor),
              ),
            )
          else
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 14),
                itemCount: lista.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _tarjetaMascota(lista[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaMascota(_MascotaConRefugio item) {
    final m = item.mascota;
    return SizedBox(
      width: 132,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => mostrarPerfilMascota(
            context,
            m,
            item.refugio,
            onCambio: () => setState(() {}),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Image.network(
                      m.imagenPrincipal,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFD3F4EE),
                        child: const Icon(
                          Icons.pets,
                          size: 36,
                          color: _darkTeal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F7A52),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'En adopción',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        m.esFavorito = !m.esFavorito;
                      }),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(
                          m.esFavorito ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: m.esFavorito ? Colors.red : _darkTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${m.tipo} · ${m.edad}',
                      style: const TextStyle(fontSize: 12, color: _mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Botón flotante de KIRO: abre su pantalla
  Widget _buildBotonKiro() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x2E1B4943),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            '¿Te ayudo?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Hablar con KIRO',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _abrir(const KiroHomeScreen()),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _turquoise,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x401B4943),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  size: 36,
                  color: _darkTeal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
