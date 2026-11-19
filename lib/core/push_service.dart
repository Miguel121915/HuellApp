import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../services/avisos_service.dart';
import 'api_client.dart';
import 'sesion_service.dart';

/// Notificaciones push reales en Android (HU-19), con Firebase Cloud Messaging.
///
/// Al iniciar sesión pide el permiso y registra este celular en la API (POST /api/push/registrar):
/// desde entonces cada aviso de la campana llega como notificación aunque la app esté cerrada.
/// Al cerrar sesión se quita (POST /api/push/quitar). Usa android/app/google-services.json.
///
/// Solo en Android: en el navegador (flutter run -d web-server) y en las pruebas no hace nada,
/// y la campana sigue funcionando como siempre.
class PushService {
  PushService._();
  static final PushService instancia = PushService._();

  static bool get soportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _listo = false;
  String? _token;
  bool _conSesion = false;

  /// Se llama una vez al abrir la app (main.dart).
  Future<void> iniciar() async {
    if (!soportado || _listo) return;
    try {
      await Firebase.initializeApp();
      _listo = true;
      // Con la app abierta, Android no muestra la notificación: se actualiza la campana al instante
      FirebaseMessaging.onMessage.listen((_) => AvisosService.instancia.actualizar());
      // Se usa el token de registro de FCM (getToken/onTokenRefresh) y no el FID de register(): es el
      // que acepta el campo "token" del envío HTTP v1 que hace la API (api/src/Push.php).
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((nuevo) {
        _token = nuevo;
        if (SesionService.instancia.haySesion) _registrar(nuevo);
      });
      SesionService.instancia.addListener(_alCambiarSesion);
      _alCambiarSesion();
    } catch (e) {
      debugPrint('Notificaciones push no disponibles: $e');
    }
  }

  Future<void> _alCambiarSesion() async {
    final hay = SesionService.instancia.haySesion;
    if (hay == _conSesion) return;
    _conSesion = hay;
    if (!hay) return; // el token se quita en quitar(), antes de borrar la sesión
    try {
      final permiso = await FirebaseMessaging.instance.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) return;
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registrar(token);
    } catch (e) {
      debugPrint('No se pudo activar el push: $e');
    }
  }

  Future<void> _registrar(String token) async {
    try {
      await ApiClient.instancia.post('/push/registrar', {'token': token, 'plataforma': 'android'});
      _token = token;
    } on ApiException catch (e) {
      debugPrint('La API no registró el celular para push: ${e.mensaje}');
    }
  }

  /// Al cerrar sesión (con el token de sesión todavía válido): este celular deja de recibir los avisos.
  Future<void> quitar() async {
    final token = _token;
    if (!_listo || token == null) return;
    _token = null;
    try {
      await ApiClient.instancia.post('/push/quitar', {'token': token});
    } on ApiException {
      // Sin conexión: la API lo borra sola cuando Firebase diga que ese token ya no sirve
    }
  }
}
