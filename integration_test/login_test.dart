// integration_test/login_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login Test with User 2', (tester) async {
    // ignore_for_file: avoid_print
    debugPrint('--- TEST CHECKPOINT 1: Login test started ---');

    // --- CORRECCIÓN ---
    // En lugar de llamar a una función que no existe, llamamos directamente
    // a la función main() de tu aplicación, que se encarga de toda la inicialización.
    app.main();
    debugPrint('--- TEST CHECKPOINT 2: App initialization finished (via app.main) ---');

    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    debugPrint('--- TEST CHECKPOINT 3: App UI pumped ---');

    await tester.pumpAndSettle();
    debugPrint('--- TEST CHECKPOINT 4: pumpAndSettle finished ---');

    // --- FASE 1: PREPARACIÓN (Sembrado de BD) ---
    // NOTA: Esta parte asume que tu UI en modo test muestra un botón para sembrar.
    // Esto es una buena práctica para tests de integración.
    final seedButton = find.byKey(const ValueKey('seed_database_button'));
    if (tester.any(seedButton)) {
      debugPrint('--- TEST CHECKPOINT 5: Seed button found ---');
      await tester.tap(seedButton);
      await tester.pumpAndSettle();
      // Esperamos a que aparezca y desaparezca el texto de sembrado.
      expect(find.text('Iniciando sembrado...'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 15));
      expect(find.text('¡Sembrado completado! Base de datos lista.'), findsOneWidget);
      debugPrint('✅ Fase 1 completada: La base de datos ha sido reseteada y poblada.');
    } else {
      debugPrint('--- AVISO: Botón de sembrado no encontrado. Saltando Fase 1. ---');
    }
    
    // --- FASE 2: AUTENTICACIÓN ---
    final emailField = find.byKey(const ValueKey('email'));
    final passwordField = find.byKey(const ValueKey('password'));
    final loginButton = find.byKey(const ValueKey('auth_button'));

    expect(emailField, findsOneWidget, reason: 'El campo de email no se encontró');
    expect(passwordField, findsOneWidget, reason: 'El campo de contraseña no se encontró');
    expect(loginButton, findsOneWidget, reason: 'El botón de login no se encontró');

    await tester.enterText(emailField, 'user2@zync.com');
    await tester.enterText(passwordField, '123456');
    await tester.tap(loginButton);
    debugPrint('--- TEST CHECKPOINT 6: Login button tapped ---');

    await tester.pumpAndSettle(const Duration(seconds: 5));
    debugPrint('--- TEST CHECKPOINT 7: pumpAndSettle after login finished ---');

    // --- FASE 3: VERIFICACIÓN ---
    // Verificamos que, tras el login, aparece el texto del círculo correcto.
    expect(find.text('Círculo de Prueba'), findsOneWidget);
    debugPrint('✅ Login de user2 verificado exitosamente. Test completado.');
  });
}
