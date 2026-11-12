import 'dart:async';

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
import 'package:huellapp/screens/seguridad_screen.dart';
import 'package:huellapp/services/comunidad_service.dart';
import 'package:huellapp/widgets/barra_inferior.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const int _refugios = 1;

  // Con cuenta empieza en Inicio; el visitante sin cuenta solo puede ver Refugios (mascotas en adopción)
  int _indice = SesionService.instancia.haySesion ? 2 : _refugios;

  /// Lo que se le dice al visitante al tocar cada pestaña que pide cuenta.
  static const Map<int, String> _accionPorPestana = {
    0: 'ver el foro de la comunidad',
    2: 'usar el inicio de HuellApp',
    3: 'reportar una mascota',
    4: 'ver tus coincidencias',
  };

  Future<void> _irA(int indice) async {
    if (indice != _refugios && !SesionService.instancia.haySesion) {
      // Pide iniciar sesión o registrarse; si lo hace, entra a la pestaña que quería
      if (!await requiereSesion(context, _accionPorPestana[indice] ?? 'usar esta sección')) return;
      if (!mounted) return;
    }
    setState(() => _indice = indice);
    if (indice == 4) _revisarCoincidencias(marcarVistas: true);
  }

  /// Si cierra sesión estando en otra pestaña, vuelve a Refugios.
  void _alCambiarSesion() {
    if (!SesionService.instancia.haySesion && _indice != _refugios && mounted) {
      setState(() => _indice = _refugios);
    }
  }

  /* ---------- Aviso de coincidencias nuevas (la IA trabaja en segundo plano) ---------- */
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    SesionService.instancia.addListener(_alCambiarSesion);
    _revisarCoincidencias();
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) => _revisarCoincidencias());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    SesionService.instancia.removeListener(_alCambiarSesion);
    super.dispose();
  }

  /// Si hay más coincidencias que la última vez que la persona las vio, avisa con «Ver».
  Future<void> _revisarCoincidencias({bool marcarVistas = false}) async {
    final sesion = SesionService.instancia.actual;
    if (sesion == null || !sesion.esUsuario) return;
    try {
      final total = (await ComunidadService.instancia.resumenCoincidencias())['pendientes'] ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final clave = 'huellapp:coincidencias-vistas:${sesion.id}';
      final vistas = prefs.getInt(clave);
      await prefs.setInt(clave, total);
      if (marcarVistas || vistas == null || total <= vistas || !mounted || _indice == 4) return;
      final nuevas = total - vistas;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(nuevas == 1
            ? '🐾 Encontramos 1 posible coincidencia para tu reporte.'
            : '🐾 Encontramos $nuevas posibles coincidencias para tus reportes.'),
        action: SnackBarAction(label: 'Ver', onPressed: () => _irA(4)),
      ));
    } catch (_) {
      // Sin conexión: se vuelve a intentar en 30 s
    }
  }

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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Seguridad'),
              subtitle: const Text('Verificación en dos pasos con Google Authenticator'),
              onTap: () {
                Navigator.pop(hoja);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SeguridadScreen()));
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