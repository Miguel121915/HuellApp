import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Datos de la cuenta que inició sesión (lo que devuelve /api/auth/login y /api/auth/yo).
class Sesion {
  const Sesion({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.refugioId,
    this.refugioEstado,
  });

  final String id;
  final String nombre;
  final String correo;

  /// 'usuario', 'refugio' o 'admin'
  final String rol;
  final String? refugioId;

  /// 'pendiente', 'aprobado', 'rechazado' o 'suspendido' (solo cuentas de refugio)
  final String? refugioEstado;

  bool get esUsuario => rol == 'usuario';
  bool get esRefugio => rol == 'refugio';
  bool get esAdmin => rol == 'admin';
  bool get refugioAprobado => refugioEstado == 'aprobado';

  factory Sesion.desdeJson(Map<String, dynamic> j) => Sesion(
        id: '${j['id']}',
        nombre: j['nombre'] as String? ?? '',
        correo: j['correo'] as String? ?? '',
        rol: j['rol'] as String? ?? 'usuario',
        refugioId: j['refugioId'] == null ? null : '${j['refugioId']}',
        refugioEstado: j['refugioEstado'] as String?,
      );

  Map<String, dynamic> aJson() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        'rol': rol,
        'refugioId': refugioId,
        'refugioEstado': refugioEstado,
      };
}

/// Maneja el inicio y cierre de sesión y la guarda en el teléfono para no pedirla cada vez.
/// Escucha cambios con  SesionService.instancia.addListener(...)  o un ListenableBuilder.
class SesionService extends ChangeNotifier {
  SesionService._();

  static final SesionService instancia = SesionService._();

  static const String _clave = 'huellapp:sesion';

  Sesion? _actual;
  bool _invitado = false;

  Sesion? get actual => _actual;
  bool get haySesion => _actual != null;

  /// Entró con "Entrar como visitante": puede ver, pero no reportar, comentar ni adoptar.
  bool get esInvitado => _actual == null && _invitado;

  ApiClient get _api => ApiClient.instancia;

  /// Recupera la sesión guardada al abrir la app. Devuelve true si sigue siendo válida.
  Future<bool> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getString(_clave);
    if (guardada == null) return false;
    try {
      final datos = jsonDecode(guardada) as Map<String, dynamic>;
      _api.token = datos['token'] as String?;
      _actual = Sesion.desdeJson(datos['sesion'] as Map<String, dynamic>);
    } catch (_) {
      await _borrar();
      return false;
    }
    // Se confirma con el servidor: el estado del refugio pudo cambiar o el token vencer
    try {
      final r = await _api.get('/auth/yo');
      _actual = Sesion.desdeJson(r['sesion'] as Map<String, dynamic>);
      await _guardar();
    } on ApiException catch (e) {
      if (e.sesionVencida) {
        await _borrar();
        return false;
      }
      // Sin conexión: se conserva la sesión guardada
    }
    notifyListeners();
    return _actual != null;
  }

  /// Inicia sesión. [rol] es 'usuario' o 'refugio' (la app móvil no permite administradores).
  Future<Sesion> iniciarSesion({
    required String correo,
    required String password,
    required String rol,
  }) async {
    final r = await _api.post('/auth/login', {
      'correo': correo.trim(),
      'password': password,
      'rol': rol,
    });
    _api.token = r['token'] as String?;
    _actual = Sesion.desdeJson(r['sesion'] as Map<String, dynamic>);
    _invitado = false;
    await _guardar();
    notifyListeners();
    return _actual!;
  }

  /// Crea una cuenta de usuario. No inicia sesión: después hay que llamar a [iniciarSesion].
  Future<void> registrarUsuario({
    required String nombre,
    required String correo,
    required String password,
    String telefono = '',
  }) async {
    await _api.post('/auth/registro-usuario', {
      'nombre': nombre.trim(),
      'correo': correo.trim(),
      'password': password,
      if (telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
    });
  }

  /// Vuelve a pedir la sesión al servidor (por ejemplo, para ver si ya aprobaron el refugio).
  /// Devuelve los datos del refugio {nombre, estado, motivoRechazo, apelaciones} o null.
  Future<Map<String, dynamic>?> refrescar() async {
    final r = await _api.get('/auth/yo');
    _actual = Sesion.desdeJson(r['sesion'] as Map<String, dynamic>);
    await _guardar();
    notifyListeners();
    return r['refugio'] as Map<String, dynamic>?;
  }

  void entrarComoInvitado() {
    _invitado = true;
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    await _borrar();
    _invitado = false;
    notifyListeners();
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode({'token': _api.token, 'sesion': _actual?.aJson()}));
  }

  Future<void> _borrar() async {
    _actual = null;
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }
}
