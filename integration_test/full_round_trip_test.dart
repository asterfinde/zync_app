// integration_test/full_round_trip_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Round-trip completo: Login + Crear Círculo', (tester) async {
    // ------------------- FASE 1: PREPARACIÓN -------------------
    // 1. Inicializar la app llamando a la nueva función en main.dart
    app.main; 
    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    await tester.pumpAndSettle();

    // 2. Resetear la base de datos con el botón de sembrado
    final seedButton = find.byKey(const ValueKey('seed_database_button'));
    if (tester.any(seedButton)) {
      expect(seedButton, findsOneWidget);
      await tester.tap(seedButton);
      await tester.pumpAndSettle();
      expect(find.text('Iniciando sembrado...'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('¡Sembrado completado! Base de datos lista.'), findsOneWidget);
      print('✅ Fase 1 completada: La base de datos ha sido reseteada y poblada.');
    } else {
      print('--- AVISO: Botón de sembrado no encontrado. Saltando Fase 1. ---');
    }
    
    // ------------------- FASE 2: AUTENTICACIÓN -------------------
    // 3. Identificar los campos y el botón del formulario por su Key
    final emailField = find.byKey(const ValueKey('email'));
    final passwordField = find.byKey(const ValueKey('password'));
    final loginButton = find.byKey(const ValueKey('auth_button'));

    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(loginButton, findsOneWidget);

    // 4. Introducir credenciales y presionar el botón de login
    await tester.enterText(emailField, 'user1@zync.com');
    await tester.enterText(passwordField, '123456');
    await tester.tap(loginButton);

    // 5. Esperar a que la autenticación y la navegación terminen
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 6. Verificar que el login fue exitoso y estamos en la siguiente pantalla.
    expect(find.text('Crear un Círculo'), findsOneWidget);
    print('✅ Fase 2 completada: Login exitoso.');
  });
}

