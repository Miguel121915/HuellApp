import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// «Continuar con Google» en la app. Solo obtiene el *ID token* de Google: quien decide si la
/// persona entra es la API (POST /api/auth/google), que lo confirma con Google.
///
/// El Client ID NO va en la app: se pide a la API (GET /api/auth/config, sale de GOOGLE_CLIENT_ID
/// en api/.env). En Android se usa como serverClientId; en el navegador, como clientId.
///
///  * Navegador (Flutter web, la demo): el botón lo dibuja Google y el token llega por [idTokens].
///  * Android: se abre el selector de cuentas con [elegirCuenta].
///  * Windows / iOS: no se muestra (iOS necesitaría su propio Client ID en Info.plist).
class GoogleLogin {
  GoogleLogin._();

  static final GoogleLogin instancia = GoogleLogin._();

  static bool get plataformaCompatible =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  final StreamController<String> _tokens = StreamController<String>.broadcast();
  Future<bool>? _listo;

  /// Tokens que entrega el botón web de Google cuando la persona elige su cuenta.
  Stream<String> get idTokens => _tokens.stream;

  /// Prepara Google Sign-In una sola vez. Devuelve false si no hay Client ID o no es compatible.
  Future<bool> preparar(String clientId) {
    if (clientId.isEmpty || !plataformaCompatible) return Future.value(false);
    return _listo ??= _iniciar(clientId);
  }

  Future<bool> _iniciar(String clientId) async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? clientId : null,
        serverClientId: kIsWeb ? null : clientId,
      );
      if (kIsWeb) {
        GoogleSignIn.instance.authenticationEvents.listen((evento) {
          if (evento is GoogleSignInAuthenticationEventSignIn) {
            final token = evento.user.authentication.idToken;
            if (token != null) _tokens.add(token);
          }
        }, onError: (_) {});
      }
      return true;
    } catch (e) {
      debugPrint('Google Sign-In no se pudo preparar: $e');
      _listo = null;
      return false;
    }
  }

  /// Android: abre el selector de cuentas. Devuelve el ID token, o null si la persona canceló.
  Future<String?> elegirCuenta() async {
    try {
      final cuenta = await GoogleSignIn.instance.authenticate();
      return cuenta.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  /// Al cerrar sesión: para que la próxima vez se pueda elegir otra cuenta de Google.
  Future<void> salir() async {
    if (_listo == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // no importa si falla: la sesión de HuellApp ya se cerró
    }
  }
}
