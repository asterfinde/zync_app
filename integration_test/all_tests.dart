// integration_test/all_tests.dart
//
// Punto de entrada único para ejecutar todas las fases automatizadas en batch.
// Uso: flutter test integration_test/all_tests.dart -d R58W315389R
//
// Fases incluidas:
//   Fase 1 — Registro y Login        (auth_flow_test.dart)
//   Fase 2 — Círculos                (circle_flow_test.dart)
//   Fase 3 — Emojis / Estados        (status_flow_test.dart)
//   Fase 4 — Modo Silent (auto only) (silent_mode_flow_test.dart)
//   Fase 5 — Configuración           (settings_flow_test.dart)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'auth_flow_test.dart' as fase1;
import 'circle_flow_test.dart' as fase2;
import 'status_flow_test.dart' as fase3;
import 'silent_mode_flow_test.dart' as fase4;
import 'settings_flow_test.dart' as fase5;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1 — Registro y Login', fase1.main);
  group('Fase 2 — Círculos', fase2.main);
  group('Fase 3 — Emojis y Estados', fase3.main);
  group('Fase 4 — Modo Silent', fase4.main);
  group('Fase 5 — Configuración', fase5.main);
}
