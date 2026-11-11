import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'google_login.dart';

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

/// Resultado del primer paso del inicio de sesión: o ya hay [sesion], o falta el código
/// de Google Authenticator para el [desafio] (válido 5 minutos).
class ResultadoLogin {
  const ResultadoLogin({this.sesion, this.desafio, this.configurar = false});

  final Sesion? sesion;
  final String? desafio;

  /// Admin o refugio sin verificación en dos pasos: es obligatoria y debe configurarla ahora
  /// (desafío válido 15 minutos). Ver [SesionService.configurarDosPasos].
  final bool configurar;

  bool get requiereCodigo => desafio != null && !configurar;
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
  /// Si la cuenta tiene verificación en dos pasos, el resultado trae [ResultadoLogin.desafio]
  /// y falta llamar a [verificarCodigo] con el código de Google Authenticator.
  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String password,
    required String rol,
  }) async {
    final r = await _api.post('/auth/login', {
      'correo': correo.trim(),
      'password': password,
      'rol': rol,
    });
    return _recibir(r);
  }

  /// «Continuar con Google»: [idToken] es el que entrega Google al elegir la cuenta.
  Future<ResultadoLogin> iniciarSesionGoogle({required String idToken, required String rol}) async {
    final r = await _api.post('/auth/google', {'idToken': idToken, 'rol': rol});
    return _recibir(r);
  }

  /// Segundo paso: código de 6 dígitos de Google Authenticator.
  Future<Sesion> verificarCodigo({required String desafio, required String codigo}) async {
    final r = await _api.post('/auth/2fa/verificar', {
      'desafio': desafio,
      'codigo': codigo.replaceAll(RegExp(r'\s'), ''),
    });
    return (await _recibir(r)).sesion!;
  }

  /// Primera vez de un refugio (o admin): secreto y enlace otpauth:// para Google Authenticator.
  Future<Map<String, dynamic>> configurarDosPasos(String desafio) =>
      _api.post('/auth/2fa/configurar/preparar', {'desafio': desafio});

  /// Confirma el primer código: activa la verificación y entrega la sesión.
  Future<Sesion> activarDosPasosObligatoria({required String desafio, required String codigo}) async {
    final r = await _api.post('/auth/2fa/configurar/activar', {
      'desafio': desafio,
      'codigo': codigo.replaceAll(RegExp(r'\s'), ''),
    });
    return (await _recibir(r)).sesion!;
  }

  Future<ResultadoLogin> _recibir(Map<String, dynamic> r) async {
    if (r['requiere2fa'] == true) return ResultadoLogin(desafio: r['desafio'] as String);
    if (r['requiereConfigurar2fa'] == true) return ResultadoLogin(desafio: r['desafio'] as String, configurar: true);
    _api.token = r['token'] as String?;
    _actual = Sesion.desdeJson(r['sesion'] as Map<String, dynamic>);
    _invitado = false;
    await _guardar();
    notifyListeners();
    return ResultadoLogin(sesion: _actual);
  }

  /// Client ID web de Google configurado en la API ('' = sin botón de Google).
  Future<String> googleClientId() async {
    try {
      final r = await _api.get('/auth/config');
      return (r['googleClientId'] as String?) ?? '';
    } on ApiException {
      return '';
    }
  }

  /* ---------- Verificación en dos pasos de la cuenta (con sesión) ---------- */

  Future<bool> dosPasosActivo() async => (await _api.get('/auth/2fa'))['activo'] == true;

  /// Secreto nuevo: {secreto, enlace}. El enlace otpauth:// va en el QR o abre Google Authenticator.
  Future<Map<String, dynamic>> prepararDosPasos() => _api.post('/auth/2fa/preparar');

  Future<void> activarDosPasos(String codigo) => _api.post('/auth/2fa/activar', {'codigo': codigo});

  Future<void> desactivarDosPasos(String codigo) => _api.post('/auth/2fa/desactivar', {'codigo': codigo});

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
    await GoogleLogin.instancia.salir();
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
