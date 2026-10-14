import 'package:flutter/material.dart';
import 'package:huellapp/models/refugio.dart';

/// Hoja con el perfil de una mascota (fotos, descripción, salud y botón de
/// adopción). La usan la lista de refugios y el perfil del refugio.
/// [onCambio] se llama cuando se marca o desmarca como favorita.
void mostrarPerfilMascota(
  BuildContext context,
  MascotaRefugio mascota,
  String nombreRefugio, {
  VoidCallback? onCambio,
}) {
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    mascota.esFavorito = !mascota.esFavorito;
                                    onCambio?.call();
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
                              style: const TextStyle(fontSize: 14, height: 1.4),
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
