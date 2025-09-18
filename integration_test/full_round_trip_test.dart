// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Round-trip completo: Login + Crear Círculo', (tester) async {
    // 1. Inicializar la app
    app.main();
    await tester.pumpAndSettle();

    // 2. Encontrar y presionar el botón de sembrado de BD
    final seedButton = find.byTooltip('Limpiar y Poblar BD');
    expect(seedButton, findsOneWidget); // Verificamos que el botón exista
    await tester.tap(seedButton);

    // 3. Esperar a que el proceso de sembrado termine
    // Primero, esperamos que aparezca el SnackBar de "Iniciando"
    await tester.pumpAndSettle();
    expect(find.text('Iniciando sembrado...'), findsOneWidget);

    // Luego, esperamos un tiempo prudencial a que se complete
    // y aparezca el SnackBar de éxito.
    await tester.pumpAndSettle(const Duration(seconds: 10));
    
    // 4. Verificar que el sembrado fue exitoso
    expect(find.text('¡Sembrado completado! Base de datos lista.'), findsOneWidget);
    print('✅ Fase 1 completada: La base de datos ha sido reseteada y poblada.');
  });
}