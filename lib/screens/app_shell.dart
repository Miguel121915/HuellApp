import 'package:flutter/material.dart';
import 'package:huellapp/core/requiere_sesion.dart';
import 'package:huellapp/core/sesion_service.dart';
import 'package:huellapp/screens/coincidencias_screen.dart';
import 'package:huellapp/screens/favoritos_screen.dart';
import 'package:huellapp/screens/inicio_screen.dart';
import 'package:huellapp/screens/login_screen.dart';
import 'package:huellapp/screens/mis_mensajes_screen.dart';
import 'package:huellapp/screens/muro_huellapp_screen.dart';
import 'package:huellapp/screens/refugios_screen.dart';
import 'package:huellapp/screens/reportar_screen.dart';
import 'package:huellapp/widgets/barra_inferior.dart';

/// Estructura principal de la app: la barra de arriba (HuellApp) y la de
/// abajo se quedan fijas, y solo cambia el contenido de en medio.
/// Índices: 0 Foro, 1 Refugios, 2 Inicio, 3 Reportar, 4 Coincidencias.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Color _turquoise = Color(0xFF75E6DA);

  int _indice = 2; // Empieza en Inicio

  void _irA(int indice) => setState(() => _indice = indice);

  void _abrirLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Favoritos y mensajes son de la cuenta: al visitante se le pide iniciar sesión.
  Future<void> _abrir(String accion, Widget pantalla) async {
    if (!await requiereSesion(context, accion)) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  void _mostrarCuenta(Sesion sesion) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (hoja) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: _turquoise,
                child: Icon(Icons.person, color: Colors.black),
              ),
              title: Text(sesion.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${sesion.correo} · ${sesion.esRefugio ? 'Refugio' : 'Usuario'}'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_border),
              title: const Text('Mis favoritos'),
              subtitle: const Text('Guarda mascotas y compáralas'),
              onTap: () {
                Navigator.pop(hoja);
                _abrir('ver tus favoritos', const FavoritosScreen());
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: const Text('Mis mensajes'),
              subtitle: const Text('Lo que les escribiste a los refugios y sus respuestas'),
              onTap: () {
                Navigator.pop(hoja);
                _abrir('ver tus mensajes', const MisMensajesScreen());
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              onPressed: () async {
                Navigator.pop(hoja);
                await SesionService.instancia.cerrarSesion();
                if (!mounted) return;
                // Vuelve al inicio de sesión (fuera de la estructura principal de la app)
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _turquoise,
        elevation: 0,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: const Text(
          'HuellApp',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mis favoritos',
            icon: const Icon(Icons.favorite_border, color: Colors.black, size: 28),
            onPressed: () => _abrir('guardar y comparar mascotas favoritas', const FavoritosScreen()),
          ),
          IconButton(
            tooltip: 'Mis mensajes',
            icon: const Icon(Icons.mail_outline, color: Colors.black, size: 28),
            onPressed: () => _abrir('escribirles a los refugios', const MisMensajesScreen()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: SesionService.instancia,
              builder: (context, _) {
                final sesion = SesionService.instancia.actual;
                return IconButton(
                  tooltip: sesion == null ? 'Iniciar sesión' : 'Mi cuenta',
                  icon: Icon(
                    sesion == null ? Icons.pets : Icons.account_circle,
                    color: Colors.black,
                    size: 32,
                  ),
                  onPressed: () => sesion == null ? _abrirLogin() : _mostrarCuenta(sesion),
                );
              },
            ),
          ),
        ],
      ),
      // IndexedStack conserva lo que hiciste en cada sección al cambiar
      body: IndexedStack(
        index: _indice,
        children: [
          const MuroHuellAppScreen(),
          const RefugiosScreen(),
          InicioScreen(onIrA: _irA),
          const ReportarScreen(),
          const CoincidenciasScreen(),
        ],
      ),
      bottomNavigationBar: BarraInferiorHuellApp(
        indiceActual: _indice,
        onCambio: _irA,
      ),
    );
  }
}