import 'package:huellapp/models/refugio.dart';

// DATOS DE EJEMPLO para pruebas. Las coordenadas, el horario, el WhatsApp y las
// redes son inventados: reemplazar por los reales o, cuando exista el servidor,
// obtenerlos de la API (GET /api/shelters).
final List<Refugio> listaRefugios = [
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
    latitud: 19.2644,
    longitud: -98.8970,
    horario: 'Lunes a sábado, 10:00 a 17:00',
    whatsapp: '55 1234 5678',
    redes: ['Facebook: Huellitas Chalco', 'Instagram: @huellitaschalco'],
    fotos: [
      'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=500',
      'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500',
    ],
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
    latitud: 19.3181,
    longitud: -98.8820,
    horario: 'Sábados y domingos, 11:00 a 16:00',
    whatsapp: '55 8765 4321',
    redes: ['Facebook: Hogar Temporal Ixtapaluca'],
    fotos: [
      'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=500',
      'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=500',
    ],
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
