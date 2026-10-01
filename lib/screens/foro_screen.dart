import 'package:flutter/material.dart';

class ForoScreen extends StatelessWidget {
  const ForoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Publicacion> publicaciones = [
      Publicacion(
        usuario: 'HuellApp Oficial',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
        fecha: 'Hace 5 h • 🌐',
        texto: 'La familia puede apagar tu brillo... ❤️✨',
        imagenUrl:
            'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800',
        likes: 121,
        comentarios: 66,
      ),
      Publicacion(
        usuario: 'AdoptaChalco',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
        fecha: 'Hace 2 h • 🌐',
        texto: 'Se busca hogar para esta hermosa gatita rescatada ayer por la tarde.',
        imagenUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800',
        likes: 45,
        comentarios: 12,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(
        0xF3F2F5,
      ), // Color de fondo característico de FB Web
      appBar: AppBar(
        title: const Text(
          'Foro de Comunidad',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Container(
          // Ancho máximo para imitar la columna central de publicaciones de Facebook
          constraints: const BoxConstraints(maxWidth: 590),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: publicaciones.length,
            itemBuilder: (context, index) {
              return PublicacionCard(publicacion: publicaciones[index]);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1877F2), // Azul estilo Facebook
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }
}

class Publicacion {
  final String usuario;
  final String avatarUrl;
  final String fecha;
  final String texto;
  final String? imagenUrl;
  final int likes;
  final int comentarios;

  Publicacion({
    required this.usuario,
    required this.avatarUrl,
    required this.fecha,
    required this.texto,
    this.imagenUrl,
    required this.likes,
    required this.comentarios,
  });
}

class PublicacionCard extends StatelessWidget {
  final Publicacion publicacion;

  const PublicacionCard({super.key, required this.publicacion});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          8,
        ), // Bordes suavizados de la tarjeta
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Encabezado del Post
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(publicacion.avatarUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publicacion.usuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        publicacion.fecha,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // 2. Texto de la publicación
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              publicacion.texto,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Imagen (Ocupando todo el ancho de la tarjeta)
          if (publicacion.imagenUrl != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFF0F2F5),
              child: Image.network(
                publicacion.imagenUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),

          // 4. Contador de reacciones y comentarios
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.thumb_up,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${publicacion.likes}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  '${publicacion.comentarios} comentarios',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 12, endIndent: 12),

          // 5. Botones de interacción (Me gusta, Comentar, Compartir)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 18,
                      color: Colors.grey[700],
                    ),
                    label: Text(
                      'Me gusta',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Colors.grey[700],
                    ),
                    label: Text(
                      'Comentar',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(
                      Icons.share_outlined,
                      size: 18,
                      color: Colors.grey[700],
                    ),
                    label: Text(
                      'Compartir',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
