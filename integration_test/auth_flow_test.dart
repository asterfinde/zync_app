// integration_test/auth_flow_test.dart
//
// Fase 1 — Registro y Login de Usuarios
//
// T01 🔗 Registro exitoso
// T02 🔬 Registro fallido — contraseñas no coinciden (test de UI local, sin Firebase)
// T03 🔗 Registro fallido — email ya registrado
// T04 🔗 Login exitoso
// T05 👁 Login fallido — correo no encontrado → MANUAL
//       Firebase email-enumeration-protection devuelve 'invalid-credential'
//       en vez de 'user-not-found'. Ver CLAUDE.md Fase 1 fila 5.
// T06 🔗 Login fallido — contraseña incorrecta
// T07 🔗 Recuperación de contraseña — correo válido registrado
// T08 🔗 Cierre de sesión
//
// Credenciales de prueba:
//   Cuenta existente : test_ci@zync.test / ZyncTest2025!
//   Cuenta nueva     : test_new@zync.test / ZyncTest2025!

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/features/auth/presentation/pages/auth_final_page.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
import 'package:zync_app/firebase_options.dart';

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------
const _testEmail = 'test_ci@zync.test';
const _testPassword = 'ZyncTest2025!';
const _newEmail = 'test_new@zync.test';
const _newPassword = 'ZyncTest2025!';

// ---------------------------------------------------------------------------
// Helpers de setup / cleanup
// ---------------------------------------------------------------------------

/// Garantiza que test_ci@zync.test exista en Firebase Auth.
Future<void> _ensureTestAccountExists() async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _testEmail,
      password: _testPassword,
    );
    await FirebaseAuth.instance.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      await FirebaseAuth.instance.signOut();
    }
  }
}

/// Elimina test_new@zync.test si existe.
Future<void> _cleanupNewAccount() async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _newEmail,
      password: _newPassword,
    );
    await FirebaseAuth.instance.currentUser?.delete();
  } catch (_) {
    // Cuenta no existe — no hay nada que limpiar.
  } finally {
    await FirebaseAuth.instance.signOut();
  }
}

// ---------------------------------------------------------------------------
// Widget wrappers
// ---------------------------------------------------------------------------
Widget _authWrapper() => const ProviderScope(
      child: MaterialApp(home: AuthFinalPage()),
    );

Widget _homeWrapper() => const ProviderScope(
      child: MaterialApp(home: HomePage()),
    );

// ---------------------------------------------------------------------------
// Seguimiento de resultados para el resumen final
// ---------------------------------------------------------------------------
final _testResults = <String, String>{};

Future<void> _track(
    String label, WidgetTester tester, Future<void> Function() body) async {
  try {
    await body();
    _testResults[label] = '✅ PASS';
  } catch (e) {
    _testResults[label] = '❌ FAIL: ${e.toString().split('\n').first}';
    rethrow;
  }
}

void _printSummary() {
  final sep = '═' * 54;
  debugPrint('\n$sep');
  debugPrint('  FASE 1 — RESUMEN DE TESTS');
  debugPrint(sep);
  const order = ['T01', 'T02', 'T03', 'T04', 'T06', 'T07', 'T08'];
  for (final key in order) {
    final result = _testResults[key] ?? '⚠️  NO EJECUTADO';
    debugPrint('  $key  $result');
  }
  debugPrint(sep);
}

// ---------------------------------------------------------------------------
// Helpers de interacción
// ---------------------------------------------------------------------------

/// Asegura que btn_auth sea visible (scroll si el teclado lo oculta) y lo toca.
Future<void> _tapAuthButton(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('btn_auth')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('btn_auth')));
}

/// Cierra sesión via UI (logout button → confirmar dialog).
/// Necesario al final de tests que navegan a HomePage para cancelar
/// el stream de Firestore y evitar errores post-test.
Future<void> _logoutViaUI(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_logout')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('dialog_btn_logout_confirm')));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _ensureTestAccountExists();
    await _cleanupNewAccount();
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
  });

  tearDownAll(() async {
    // Garantizar cleanup de test_new aunque T01 haya fallado.
    await _cleanupNewAccount();
    _printSummary();
  });

  // -------------------------------------------------------------------------
  // T01 — Registro exitoso
  // -------------------------------------------------------------------------
  testWidgets('T01 — Registro exitoso con datos válidos', (tester) async {
    await _track('T01', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_toggle_mode')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_nickname')), 'TestUser');
      await tester.enterText(find.byKey(const Key('field_email')), _newEmail);
      await tester.enterText(
          find.byKey(const Key('field_password')), _newPassword);
      await tester.enterText(
          find.byKey(const Key('field_confirm_password')), _newPassword);
      await tester.pumpAndSettle();

      await _tapAuthButton(tester);
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byKey(const Key('btn_logout')), findsOneWidget);

      await _logoutViaUI(tester);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _newEmail, password: _newPassword);
      await FirebaseAuth.instance.currentUser?.delete();
      await FirebaseAuth.instance.signOut();
    });
  });

  // -------------------------------------------------------------------------
  // T02 — Contraseñas no coinciden (validación local, sin Firebase)
  // -------------------------------------------------------------------------
  testWidgets('T02 — Botón deshabilitado cuando contraseñas no coinciden',
      (tester) async {
    await _track('T02', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_toggle_mode')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_nickname')), 'TestUser');
      await tester.enterText(
          find.byKey(const Key('field_email')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('field_password')), 'password123');
      await tester.enterText(
          find.byKey(const Key('field_confirm_password')), 'diferente456');
      await tester.pumpAndSettle();

      final btn =
          tester.widget<ElevatedButton>(find.byKey(const Key('btn_auth')));
      expect(btn.onPressed, isNull,
          reason:
              'El botón debe estar deshabilitado cuando las contraseñas no coinciden');
    });
  });

  // -------------------------------------------------------------------------
  // T03 — Registro fallido: email ya registrado
  // -------------------------------------------------------------------------
  testWidgets('T03 — Registro fallido: email ya registrado', (tester) async {
    await _track('T03', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_toggle_mode')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_nickname')), 'TestUser');
      await tester.enterText(find.byKey(const Key('field_email')), _testEmail);
      await tester.enterText(
          find.byKey(const Key('field_password')), _testPassword);
      await tester.enterText(
          find.byKey(const Key('field_confirm_password')), _testPassword);
      await tester.pumpAndSettle();

      await _tapAuthButton(tester);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.text(
            'Este correo ya tiene una cuenta registrada. Inicia sesión.'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // T04 — Login exitoso
  // -------------------------------------------------------------------------
  testWidgets('T04 — Login exitoso con credenciales válidas', (tester) async {
    await _track('T04', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field_email')), _testEmail);
      await tester.enterText(
          find.byKey(const Key('field_password')), _testPassword);
      await tester.pumpAndSettle();

      await _tapAuthButton(tester);
      await tester.pumpAndSettle(const Duration(seconds: 15));

      expect(find.byKey(const Key('btn_logout')), findsOneWidget);

      await _logoutViaUI(tester);
      expect(find.byKey(const Key('btn_auth')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // T06 — Login fallido: contraseña incorrecta
  // -------------------------------------------------------------------------
  testWidgets('T06 — Login fallido: contraseña incorrecta', (tester) async {
    await _track('T06', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('field_email')), _testEmail);
      await tester.enterText(
          find.byKey(const Key('field_password')), 'contraseñaIncorrecta999');
      await tester.pumpAndSettle();

      await _tapAuthButton(tester);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.text('La contraseña es incorrecta. Verifica e intenta de nuevo.'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // T07 — Recuperación de contraseña
  // -------------------------------------------------------------------------
  testWidgets('T07 — Recuperación de contraseña: instrucciones enviadas',
      (tester) async {
    await _track('T07', tester, () async {
      await tester.pumpWidget(_authWrapper());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_forgot_password')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_reset_email')), _testEmail);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_send_reset')));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.text(
            'Hemos enviado las instrucciones. Si no las recibes, verifica que el correo esté registrado.'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // T08 — Cierre de sesión
  // -------------------------------------------------------------------------
  testWidgets('T08 — Cierre de sesión regresa a pantalla de login',
      (tester) async {
    await _track('T08', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(const Key('btn_logout')), findsOneWidget);

      await _logoutViaUI(tester);

      expect(find.byKey(const Key('btn_auth')), findsOneWidget);
    });
  });
}
