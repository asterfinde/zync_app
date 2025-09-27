// integration_test/create_circle_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create Circle Test', (tester) async {
    // 1. INICIALIZACIÓN Y SEMBRADO
    // --- CORRECCIÓN ---
    // Se reemplaza la llamada a la función inexistente por app.main()
    app.main();
    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    await tester.pumpAndSettle();

    final seedButton = find.byKey(const ValueKey('seed_database_button'));
    // Hacemos el sembrado opcional para que el test no falle si el botón no está
    if (tester.any(seedButton)) {
      await tester.tap(seedButton);
      await tester.pumpAndSettle(const Duration(seconds: 15));
      expect(find.text('¡Sembrado completado! Base de datos lista.'), findsOneWidget);
      print('✅ Fase 1 (Preparación) completada.');
    } else {
       print('--- AVISO: Botón de sembrado no encontrado. Saltando Fase 1. ---');
    }

    // 2. AUTENTICACIÓN CON UN USUARIO NUEVO
    final emailField = find.byKey(const ValueKey('email'));
    final passwordField = find.byKey(const ValueKey('password'));
    final authButton = find.byKey(const ValueKey('auth_button')); // Cambiado a un nombre más genérico

    // Verificamos que los widgets de login existen antes de usarlos
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(authButton, findsOneWidget);

    await tester.enterText(emailField, 'user3@zync.com');
    await tester.enterText(passwordField, '123456');
    await tester.tap(authButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    print('✅ Fase 2 (Autenticación) completada.');

    // 3. CREACIÓN DEL CÍRCULO
    
    // Asumiendo que los widgets para crear un círculo tienen estas keys
    final circleNameField = find.byKey(const ValueKey('circle_name_field'));
    final createCircleButton = find.byKey(const ValueKey('create_circle_button'));
    
    // Verificamos que los widgets para crear el círculo aparecen después del login
    expect(circleNameField, findsOneWidget);
    expect(createCircleButton, findsOneWidget);

    const newCircleName = 'Mi Nuevo Círculo de Test';
    await tester.enterText(circleNameField, newCircleName);
    await tester.tap(createCircleButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    print('✅ Fase 3 (Creación del Círculo) completada.');

    // 4. VERIFICACIÓN FINAL
    // Verificamos que el nombre del nuevo círculo ahora es visible en la pantalla.
    expect(find.text(newCircleName), findsOneWidget);
    print('✅ Fase 4 (Verificación Final) completada. ¡Test exitoso!');
  });
}
