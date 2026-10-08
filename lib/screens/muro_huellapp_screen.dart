import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ModeloPublicacion {
  final String id;
  String usuario;
  String tiempo;
  String texto;
  String? urlImagen;
  Uint8List? bytesImagen;
  int meGusta;
  bool leGusta;
  int compartidos;
  List<String> comentarios;

  ModeloPublicacion({
    required this.id,
    required this.usuario,
    required this.tiempo,
    required this.texto,
    this.urlImagen,
    this.bytesImagen,
    this.meGusta = 0,
    this.leGusta = false,
    this.compartidos = 0,
    List<String>? comentarios,
  }) : comentarios = comentarios ?? [];
}

class MuroHuellAppScreen extends StatefulWidget {
  const MuroHuellAppScreen({super.key});

  @override
  State<MuroHuellAppScreen> createState() => _MuroHuellAppScreenState();
}

class _MuroHuellAppScreenState extends State<MuroHuellAppScreen> {
  final TextEditingController _publicacionController = TextEditingController();
  Uint8List? _bytesImagenWeb;

  final List<ModeloPublicacion> _publicaciones = [
    ModeloPublicacion(
      id: '1',
      usuario: 'HuellApp Oficial',
      tiempo: 'Hace 5 h · 🌐',
      texto: 'La familia nunca apaga tu brillo... ❤️️✨',
      meGusta: 121,
      compartidos: 12,
      comentarios: ['¡Qué gran mensaje!', 'Saludos a la comunidad HuellApp.'],
    ),
    ModeloPublicacion(
      id: '2',
      usuario: 'AdoptaChalco',
      tiempo: 'Hace 2 h · 🌐',
      texto: 'Se busca hogar para esta hermosa gatita rescatada ayer por la tarde.',
      meGusta: 46,
      compartidos: 5,
      comentarios: ['¿Dónde se puede ir a ver?', 'Compartido.'],
    ),
  ];

  Future<void> _seleccionarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);

    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        _bytesImagenWeb = bytes;
      });
    }
  }

  void _crearPublicacion() {
    if (_publicacionController.text.trim().isEmpty && _bytesImagenWeb == null) {
      return;
    }

    setState(() {
      _publicaciones.insert(
        0,
        ModeloPublicacion(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          usuario: 'Usuario HuellApp',
          tiempo: 'Hace un momento · 🌐',
          texto: _publicacionController.text.trim(),
          bytesImagen: _bytesImagenWeb,
        ),
      );
      _publicacionController.clear();
      _bytesImagenWeb = null;
    });
  }

  void _alternarMeGusta(ModeloPublicacion publicacion) {
    setState(() {
      publicacion.leGusta = !publicacion.leGusta;
      if (publicacion.leGusta) {
        publicacion.meGusta++;
      } else {
        publicacion.meGusta--;
      }
    });
  }

  void _abrirImagenPantallaCompleta(ModeloPublicacion publicacion) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: publicacion.bytesImagen != null
                  ? Image.memory(
                      publicacion.bytesImagen!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Image.network(
                      publicacion.urlImagen!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editarPublicacion(ModeloPublicacion publicacion) {
    final TextEditingController editarController = TextEditingController(
      text: publicacion.texto,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar publicación'),
        content: TextField(
          controller: editarController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Edita el contenido...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF75E6DA),
            ),
            onPressed: () {
              setState(() {
                publicacion.texto = editarController.text.trim();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Publicación actualizada')),
              );
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _borrarPublicacion(ModeloPublicacion publicacion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar publicación?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _publicaciones.removeWhere((item) => item.id == publicacion.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Publicación eliminada')),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarComentarios(ModeloPublicacion publicacion) {
    final TextEditingController comentarioController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Comentarios',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    height: 250,
                    child: publicacion.comentarios.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay comentarios aún. ¡Sé el primero!',
                            ),
                          )
                        : ListView.builder(
                            itemCount: publicacion.comentarios.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF75E6DA),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(publicacion.comentarios[index]),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: comentarioController,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un comentario...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF75E6DA)),
                        onPressed: () {
                          if (comentarioController.text.trim().isNotEmpty) {
                            setState(() {
                              publicacion.comentarios.add(
                                comentarioController.text.trim(),
                              );
                            });
                            setModalState(() {});
                            comentarioController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _compartirPublicacion(ModeloPublicacion publicacion) {
    setState(() {
      publicacion.compartidos++;
    });

    final String enlaceSimulado = 'https://huellapp.com/post/${publicacion.id}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enlace copiado al portapapeles: $enlaceSimulado'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _renderizarImagen(ModeloPublicacion publicacion) {
    if (publicacion.bytesImagen != null ||
        (publicacion.urlImagen != null && publicacion.urlImagen!.isNotEmpty)) {
      return GestureDetector(
        onTap: () => _abrirImagenPantallaCompleta(publicacion),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 380),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: publicacion.bytesImagen != null
                ? Image.memory(
                    publicacion.bytesImagen!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                : Image.network(
                    publicacion.urlImagen!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Foro de Comunidad',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Caja para redactar publicación
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFF75E6DA),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _publicacionController,
                            maxLines: null, // Permite que el campo crezca dinámicamente con cada Enter
                            minLines: 1, // Inicia con altura de 1 línea
                            keyboardType: TextInputType
                                .multiline, // Habilita el teclado multilínea
                            decoration: const InputDecoration(
                              hintText: '¿Qué quieres reportar o publicar en HuellApp?',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_bytesImagenWeb != null) ...[
                      const SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _bytesImagenWeb!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _bytesImagenWeb = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _seleccionarFoto,
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Foto',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF75E6DA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _crearPublicacion,
                          child: const Text(
                            'Publicar',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Lista de publicaciones
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _publicaciones.length,
              itemBuilder: (context, index) {
                final pub = _publicaciones[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: const Icon(
                                Icons.pets,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pub.usuario,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    pub.tiempo,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_horiz,
                                color: Colors.grey,
                              ),
                              onSelected: (value) {
                                if (value == 'editar') {
                                  _editarPublicacion(pub);
                                } else if (value == 'borrar') {
                                  _borrarPublicacion(pub);
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Editar publicación'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'borrar',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Borrar publicación'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (pub.texto.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(pub.texto, style: const TextStyle(fontSize: 14)),
                        ],
                        if (pub.bytesImagen != null ||
                            pub.urlImagen != null) ...[
                          const SizedBox(height: 10),
                          _renderizarImagen(pub),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.blue,
                                  child: Icon(
                                    Icons.thumb_up,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pub.meGusta}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${pub.comentarios.length} comentarios · ${pub.compartidos} compartidos',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            InkWell(
                              onTap: () => _alternarMeGusta(pub),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      pub.leGusta
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_alt_outlined,
                                      size: 18,
                                      color: pub.leGusta
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Me gusta',
                                      style: TextStyle(
                                        color: pub.leGusta
                                            ? Colors.blue
                                            : Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _mostrarComentarios(pub),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Comentar',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _compartirPublicacion(pub),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.share_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Compartir',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
