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
    await app.initializeApp();
    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    await tester.pumpAndSettle();

    final seedButton = find.byKey(const ValueKey('seed_database_button'));
    await tester.tap(seedButton);
    await tester.pumpAndSettle(const Duration(seconds: 15));
    expect(find.text('¡Sembrado completado! Base de datos lista.'), findsOneWidget);
    print('✅ Fase 1 (Preparación) completada.');

    // 2. AUTENTICACIÓN CON UN USUARIO NUEVO
    final emailField = find.byKey(const ValueKey('email'));
    final passwordField = find.byKey(const ValueKey('password'));
    final loginButton = find.byKey(const ValueKey('auth_button'));

    await tester.enterText(emailField, 'user3@zync.com');
    await tester.enterText(passwordField, '123456');
    await tester.tap(loginButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    print('✅ Fase 2 (Autenticación) completada.');

    // 3. CREACIÓN DEL CÍRCULO (Usando buscadores corregidos)

    // CORRECCIÓN: Buscamos el TextFormField que es "ancestro" (padre) del texto 'Circle Name'.
    final circleNameField = find.ancestor(
      of: find.text('Circle Name'),
      matching: find.byType(TextFormField),
    );

    // Buscamos un ElevatedButton que contenga un widget de Texto 'Create Circle'.
    final confirmCreateButton = find.widgetWithText(ElevatedButton, 'Create Circle');

    expect(circleNameField, findsOneWidget);
    expect(confirmCreateButton, findsOneWidget);

    const newCircleName = 'Mi Nuevo Círculo de Test';
    await tester.enterText(circleNameField, newCircleName);
    await tester.tap(confirmCreateButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    print('✅ Fase 3 (Creación del Círculo) completada.');

    // 4. VERIFICACIÓN FINAL
    // Verificamos que el nombre del nuevo círculo ahora es visible en la pantalla.
    expect(find.text(newCircleName), findsOneWidget);
    print('✅ Fase 4 (Verificación Final) completada. ¡Test exitoso!');
  });
}