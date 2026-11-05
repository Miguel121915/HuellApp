import 'package:flutter/widgets.dart';

import '../navigation.dart';
import '../screens/refugio/estado_refugio_screen.dart';
import '../screens/refugio/panel_refugio_screen.dart';
import 'sesion_service.dart';

/// Pantalla principal de cada rol en la app móvil (igual que en el sitio web):
///  * usuario o visitante → la app de usuario (Inicio, Refugios, Reportar, Foro, Coincidencias)
///  * refugio aprobado    → su panel
///  * refugio no aprobado → el estado de su solicitud
Widget destinoDeSesion(Sesion? sesion) {
  if (sesion != null && sesion.esRefugio) {
    return sesion.refugioAprobado ? const PanelRefugioScreen() : const EstadoRefugioScreen();
  }
  return const AppNavigation();
}
