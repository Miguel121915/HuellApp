import 'package:huellapp/models/refugio.dart';

// Refugios APROBADOS con sus mascotas disponibles, tal como vienen de la API.
// La llena CatalogoService (lib/services/catalogo_service.dart); las pantallas escuchan
// a CatalogoService.instancia para redibujarse cuando cambia.
final List<Refugio> listaRefugios = [];
