// Pruebas automáticas de la app HuellApp.  Se ejecutan con:  flutter test
//
// No necesitan la API ni internet: revisan pantallas y reglas que funcionan sin red
// (en las pruebas, cualquier petición HTTP falla con 400 y la app debe seguir funcionando).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:huellapp/core/compartir.dart';
import 'package:huellapp/core/tipografia.dart';
import 'package:huellapp/main.dart';
import 'package:huellapp/screens/login_screen.dart';
import 'package:huellapp/screens/recuperar_contrasena_screen.dart';
import 'package:huellapp/screens/reportar_screen.dart';
import 'package:huellapp/screens/verificar_correo_screen.dart';
import 'package:huellapp/widgets/barra_inferior.dart';

/// Monta una pantalla con el tema real de la app.
Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2340); // celular común (ancho 412 a 2.625x)
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: MyApp.tema(), home: pantalla));
  await tester.pump();
}

void main() {
  group('Tema y tipografía', () {
    test('usa los colores de la marca y Fredoka en títulos, Inter en el texto', () {
      final tema = MyApp.tema();
      expect(tema.colorScheme.primary, Tipografia.aquaFuerte, reason: 'ya no es el naranja por defecto');
      expect(tema.textTheme.titleLarge?.fontFamily, Tipografia.fuenteTitulos);
      expect(tema.textTheme.headlineSmall?.fontFamily, Tipografia.fuenteTitulos);
      expect(tema.textTheme.bodyMedium?.fontFamily, Tipografia.fuente);
      // Cada nivel se distingue del siguiente (el texto ya no se ve «plano»)
      expect(tema.textTheme.titleSmall!.fontSize!, greaterThan(tema.textTheme.bodyMedium!.fontSize!));
      expect(tema.textTheme.titleMedium!.fontSize!, greaterThan(tema.textTheme.bodyLarge!.fontSize!));
    });
  });

  group('Compartir alertas', () {
    test('arma el mensaje según el tipo de alerta', () {
      expect(Compartir.texto({'tipo': 'perdida', 'nombre': 'Pelusa', 'zona': 'Col. Roma Norte'}),
          startsWith('🔎 SE BUSCA: Pelusa, se perdió en Col. Roma Norte.'));
      expect(Compartir.texto({'tipo': 'encontrada', 'especie': 'gato', 'zona': 'Col. Condesa'}),
          startsWith('🏠 Encontraron a un gatito en Col. Condesa.'));
      expect(Compartir.texto({'tipo': 'perdida', 'estado': 'reunido', 'nombre': 'Max'}), contains('¡Max ya está en casa!'));
      expect(Compartir.texto({'esAlerta': false}), 'Mira esta publicación en HuellApp:');
    });
  });

  group('Inicio de sesión', () {
    testWidgets('sin datos no se envía: pide correo y contraseña', (tester) async {
      await abrir(tester, const LoginScreen());
      await tester.tap(find.text('Ingresar como Usuario'));
      await tester.pump();
      expect(find.text('Escribe tu correo'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);
    });

    testWidgets('«¿Olvidaste tu contraseña?» abre la recuperación con el correo ya escrito', (tester) async {
      await abrir(tester, const LoginScreen());
      await tester.enterText(find.byType(TextFormField).first, 'lucia.torres@ejemplo.mx');
      await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(find.text('Recupera tu contraseña'), findsOneWidget);
      expect(find.text('lucia.torres@ejemplo.mx'), findsOneWidget);
    });
  });

  group('Código por correo', () {
    testWidgets('confirmar correo: muestra el correo y exige 6 dígitos', (tester) async {
      await abrir(tester, const VerificarCorreoScreen(correo: 'lucia.torres@ejemplo.mx'));
      expect(find.text('Confirma tu correo'), findsOneWidget);
      expect(find.textContaining('lucia.torres@ejemplo.mx', findRichText: true), findsOneWidget);
      // Recién llegó un código: hay que esperar para pedir otro
      expect(find.textContaining('Reenviar código ('), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Confirmar y entrar'));
      await tester.pump();
      expect(find.text('El código tiene 6 dígitos.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // cierra la pantalla y su cuenta atrás
    });

    testWidgets('recuperar contraseña: valida el correo antes de pedir el código', (tester) async {
      await abrir(tester, const RecuperarContrasenaScreen());
      expect(find.text('PASO 1 DE 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'correo-sin-arroba');
      await tester.tap(find.text('Enviar código'));
      await tester.pump();
      expect(find.text('Escribe un correo válido, por ejemplo nombre@correo.com.'), findsOneWidget);
    });
  });

  group('Barra de abajo', () {
    testWidgets('colores de la web, sección activa marcada y burbuja real de coincidencias', (tester) async {
      var elegida = -1;
      await abrir(tester, Scaffold(
        bottomNavigationBar: BarraInferiorHuellApp(indiceActual: 2, coincidencias: 3, onCambio: (i) => elegida = i),
      ));
      for (final texto in ['Foro', 'Refugios', 'Inicio', 'Reportar', 'Coincidencias']) {
        expect(find.text(texto), findsOneWidget);
      }
      // Activa (Inicio): texto verde oscuro; las demás en blanco sobre el verde
      expect(tester.widget<Text>(find.text('Inicio')).style?.color, Tipografia.aquaFuerte);
      expect(tester.widget<Text>(find.text('Foro')).style?.color, Colors.white);
      expect(find.text('3'), findsOneWidget, reason: 'la burbuja muestra las coincidencias pendientes, no un 1 fijo');
      await tester.tap(find.text('Coincidencias'));
      expect(elegida, 4);
    });

    testWidgets('sin coincidencias pendientes no hay burbuja', (tester) async {
      await abrir(tester, Scaffold(bottomNavigationBar: BarraInferiorHuellApp(indiceActual: 0, onCambio: (_) {})));
      expect(find.text('1'), findsNothing);
      expect(find.text('0'), findsNothing);
    });
  });

  group('Reportar', () {
    testWidgets('primero se elige qué pasó; luego aparece el formulario correcto', (tester) async {
      await abrir(tester, const ReportarScreen());
      expect(find.text('¿Qué pasó?'), findsOneWidget);
      expect(find.text('Se me perdió mi mascota'), findsOneWidget);
      expect(find.text('Encontré una mascota'), findsOneWidget);
      await tester.tap(find.text('Se me perdió mi mascota'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué pasó?'), findsNothing, reason: 'ya se eligió el tipo de reporte');
    });
  });
}
