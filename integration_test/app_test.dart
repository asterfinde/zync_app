import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';
import 'package:zync_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolTest(
    'Verifica que la SignInPage se carga y muestra el título "Zync"',
    ($) async {
      // 1. Inicializamos la aplicación.
      app.main();

      // 2. Esperamos a que la UI se estabilice.
      await $.pumpAndSettle();

      // 3. Da tiempo adicional para que Firebase se inicialice
      await Future.delayed(const Duration(seconds: 3));

      // 4. Busca el texto 'Zync' - usa find.text() para mayor precisión
      final appBarTitle = $(find.text('Zync'));

      // 5. Verificamos que el título existe.
      expect(appBarTitle, findsOneWidget);
    },
  );
}
