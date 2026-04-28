// integration_test/silent_mode_flow_test.dart
//
// Fase 4 — Modo Silent
//
// T4.1 👁  App minimizada → ícono visible en barra superior         — MANUAL
// T4.2 👁  App activa sin cerrar sesión → permanece en modo silent  — MANUAL
// T4.3 👁  Con cierre de sesión → ícono desaparece                  — MANUAL
// T4.4 🔗  Modal NotificationStatusSelector abre y muestra 16 estados
// T4.5 🔗  Selección de estado desde modal → Firestore actualizado
//
// Nota: T4.1–T4.3 requieren interacción nativa con la barra de notificaciones
// del SO y no son automatizables con Flutter integration tests.
//
// Credenciales de prueba:
//   Cuenta primaria: test_ci@zync.test / ZyncTest2025!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nunakin_app/firebase_options.dart';
import 'package:nunakin_app/services/circle_service.dart';
import 'package:nunakin_app/widgets/notification_status_selector.dart';

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------
const _testEmail = 'test_ci@zync.test';
const _testPassword = 'ZyncTest2025!';
const _circleName = 'Círculo Test CI - Fase 4';

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
  debugPrint('  FASE 4 — RESUMEN DE TESTS');
  debugPrint(sep);
  debugPrint('  T4.1  👁  MANUAL (barra de notificaciones del SO)');
  debugPrint('  T4.2  👁  MANUAL (app en background)');
  debugPrint('  T4.3  👁  MANUAL (ícono tras cierre de sesión)');
  const order = ['T4.4', 'T4.5'];
  for (final key in order) {
    final result = _testResults[key] ?? '⚠️  NO EJECUTADO';
    debugPrint('  $key  $result');
  }
  debugPrint(sep);
}

// ---------------------------------------------------------------------------
// Helpers de setup / cleanup
// ---------------------------------------------------------------------------

Future<void> _ensureAccountExists(String email, String password) async {
  try {
    final cred = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    await _ensureUserDoc(cred.user!.uid, email);
    await FirebaseAuth.instance.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await _ensureUserDoc(cred.user!.uid, email);
      await FirebaseAuth.instance.signOut();
    }
  }
}

Future<void> _ensureUserDoc(String uid, String email) async {
  final ref = FirebaseFirestore.instance.collection('users').doc(uid);
  final doc = await ref.get();
  if (!doc.exists) {
    await ref.set({
      'uid': uid,
      'email': email,
      'nickname': email.split('@').first,
    });
  }
}

Future<void> _ensureNoCircle(String email, String password) async {
  try {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists) {
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId != null && circleId.isNotEmpty) {
        await CircleService().leaveCircle();
      }
    }
  } catch (_) {
    // Ignorar errores — el objetivo es solo limpiar el estado.
  } finally {
    await FirebaseAuth.instance.signOut();
  }
}

Future<String> _createCircleAndGetId() async {
  return await CircleService().createCircle(_circleName);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _ensureAccountExists(_testEmail, _testPassword);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
    await _ensureNoCircle(_testEmail, _testPassword);
  });

  tearDownAll(() async {
    await _ensureNoCircle(_testEmail, _testPassword);
    await FirebaseAuth.instance.signOut();
    _printSummary();
  });

  // -------------------------------------------------------------------------
  // T4.4 — Modal NotificationStatusSelector muestra los 16 estados
  // -------------------------------------------------------------------------
  testWidgets(
      'T4.4 — NotificationStatusSelector muestra grid con 16 botones de estado',
      (tester) async {
    await _track('T4.4', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      await _createCircleAndGetId();

      // Renderizar el modal directamente (simula T4.4: ícono tocado → modal abierto)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationStatusSelector(),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // El contenedor del modal debe estar visible
      expect(
          find.byKey(const Key('notification_status_selector')), findsOneWidget);

      // Deben existir los 16 botones de estado
      expect(find.byKey(const ValueKey('btn_status_fine')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_busy')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_sos')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_home')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_school')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_work')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_status_driving')), findsOneWidget);

      // Verificar que hay exactamente 16 botones en total
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Material &&
            widget.key is ValueKey &&
            (widget.key as ValueKey).value.toString().startsWith('btn_status_')),
        findsNWidgets(16),
      );

      await FirebaseAuth.instance.signOut();
    });
  });

  // -------------------------------------------------------------------------
  // T4.5 — Selección de estado desde modal → Firestore actualizado
  // -------------------------------------------------------------------------
  testWidgets(
      'T4.5 — Tap en btn_status_busy desde NotificationStatusSelector actualiza Firestore',
      (tester) async {
    await _track('T4.5', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      final circleId = await _createCircleAndGetId();
      final user = FirebaseAuth.instance.currentUser!;

      // Forzar estado inicial a 'fine' para poder detectar el cambio
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .update({'memberStatus.${user.uid}.statusType': 'fine'});

      // Renderizar el modal directamente
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationStatusSelector(),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
          find.byKey(const Key('notification_status_selector')), findsOneWidget);

      // Tap en el botón "Ocupado"
      await tester.tap(find.byKey(const ValueKey('btn_status_busy')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verificar que el estado cambió a 'busy' en Firestore
      final circleDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .get();
      final memberStatus = (circleDoc.data()!['memberStatus']
          as Map<String, dynamic>)[user.uid] as Map<String, dynamic>;
      expect(memberStatus['statusType'], equals('busy'));

      await FirebaseAuth.instance.signOut();
    });
  });
}
