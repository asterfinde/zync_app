// integration_test/circle_flow_test.dart
//
// Fase 2 — Círculos
//
// T01 🔗 Crear círculo via UI → InCircleView visible
// T02 🔗 Salir del círculo via Settings → InCircleView ausente
// T03 👁 Crear más de un círculo → EXCLUIDO (no implementado en MVP)
// T04 🔗 Código de invitación visible en InCircleView
// T05 🔗 Estado "Todo bien" al unirse a un círculo
// T06 🔗 Cambiar estado via btn_change_status → actualización verificada en Firestore
//
// Credenciales de prueba:
//   Cuenta primaria  : test_ci@zync.test  / ZyncTest2025!
//   Cuenta secundaria: test_ci2@zync.test / ZyncTest2025!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nunakin_app/features/circle/presentation/pages/home_page.dart';
import 'package:nunakin_app/firebase_options.dart';
import 'package:nunakin_app/services/circle_service.dart';

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------
const _testEmail = 'test_ci@zync.test';
const _testPassword = 'ZyncTest2025!';
const _test2Email = 'test_ci2@zync.test';
const _test2Password = 'ZyncTest2025!';
const _circleName = 'Círculo Test CI';

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
  debugPrint('  FASE 2 — RESUMEN DE TESTS');
  debugPrint(sep);
  const order = ['T01', 'T02', 'T04', 'T05', 'T06'];
  for (final key in order) {
    final result = _testResults[key] ?? '⚠️  NO EJECUTADO';
    debugPrint('  $key  $result');
  }
  debugPrint(sep);
}

// ---------------------------------------------------------------------------
// Helpers de setup / cleanup
// ---------------------------------------------------------------------------

/// Garantiza que la cuenta exista en Firebase Auth Y que el documento
/// del usuario exista en Firestore (necesario para CircleService.createCircle,
/// que hace batch.update sobre users/{uid}).
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

/// Crea el documento del usuario en Firestore si no existe.
Future<void> _ensureUserDoc(String uid, String email) async {
  final ref =
      FirebaseFirestore.instance.collection('users').doc(uid);
  final doc = await ref.get();
  if (!doc.exists) {
    await ref.set({
      'uid': uid,
      'email': email,
      'nickname': email.split('@').first,
    });
  }
}

/// Garantiza que el usuario no pertenezca a ningún círculo ni tenga
/// solicitudes pendientes. Limpia circleId y pendingCircleId.
Future<void> _ensureNoCircle(String email, String password) async {
  try {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      final circleId = data['circleId'] as String?;
      final pendingCircleId = data['pendingCircleId'] as String?;

      // Limpiar circleId via leaveCircle si existe
      if (circleId != null && circleId.isNotEmpty) {
        await CircleService().leaveCircle();
      }

      // Limpiar pendingCircleId si existe (solicitud pendiente residual)
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        await userRef.update({'pendingCircleId': FieldValue.delete()});
      }
    }
  } catch (_) {
    // Ignorar errores — el objetivo es solo limpiar el estado.
  } finally {
    await FirebaseAuth.instance.signOut();
  }
}

/// Crea un círculo para el usuario actualmente autenticado.
/// Retorna el código de invitación del círculo creado.
Future<String> _createCircleProgrammatically() async {
  final service = CircleService();
  final circleId = await service.createCircle(_circleName);
  final circleDoc = await FirebaseFirestore.instance
      .collection('circles')
      .doc(circleId)
      .get();
  return circleDoc.data()!['invitation_code'] as String;
}

// ---------------------------------------------------------------------------
// Widget wrapper
// ---------------------------------------------------------------------------
Widget _homeWrapper() => const ProviderScope(
      child: MaterialApp(home: HomePage()),
    );

// ---------------------------------------------------------------------------
// Helpers de interacción
// ---------------------------------------------------------------------------

/// Desmonta todos los widgets antes de cerrar sesión.
/// Necesario cuando InCircleView está activo: así se cancelan los streams
/// de Firestore antes del signOut y se evitan errores post-test.
Future<void> _signOutFromCircle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await FirebaseAuth.instance.signOut();
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
    await _ensureAccountExists(_test2Email, _test2Password);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
    await _ensureNoCircle(_testEmail, _testPassword);
    await _ensureNoCircle(_test2Email, _test2Password);
  });

  tearDownAll(() async {
    await _ensureNoCircle(_testEmail, _testPassword);
    await _ensureNoCircle(_test2Email, _test2Password);
    await FirebaseAuth.instance.signOut();
    _printSummary();
  });

  // -------------------------------------------------------------------------
  // T01 — Crear círculo via UI
  // -------------------------------------------------------------------------
  testWidgets('T01 — Crear círculo muestra InCircleView', (tester) async {
    await _track('T01', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // NoCircleView debe estar visible
      expect(
          find.byKey(const Key('btn_navigate_create_circle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_navigate_create_circle')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_circle_name')), _circleName);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('btn_create_circle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_create_circle')));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // InCircleView debe estar visible
      expect(find.byKey(const Key('btn_settings')), findsOneWidget);

      await _signOutFromCircle(tester);
    });
  });

  // -------------------------------------------------------------------------
  // T02 — Salir del círculo via Settings
  // -------------------------------------------------------------------------
  testWidgets('T02 — Settings no muestra opción de salir del círculo (Brecha 1)',
      (tester) async {
    await _track('T02', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      await _createCircleProgrammatically();

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // InCircleView → abrir Settings
      expect(find.byKey(const Key('btn_settings')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_settings')));
      await tester.pumpAndSettle();

      // Ir al tab "Círculo"
      await tester.tap(find.text('Círculo'));
      await tester.pumpAndSettle();

      // btn_leave_circle fue eliminado en Brecha 1 — no debe existir
      expect(find.byKey(const Key('btn_leave_circle')), findsNothing);

      await _signOutFromCircle(tester);
    });
  });

  // -------------------------------------------------------------------------
  // T04 — Código de invitación visible en InCircleView
  // -------------------------------------------------------------------------
  testWidgets('T04 — Código de invitación visible en InCircleView',
      (tester) async {
    await _track('T04', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      final inviteCode = await _createCircleProgrammatically();

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byKey(const Key('text_invite_code')), findsOneWidget);
      expect(find.text(inviteCode), findsOneWidget);

      await _signOutFromCircle(tester);
    });
  });

  // -------------------------------------------------------------------------
  // T05 — Estado "Todo bien" al unirse a un círculo
  // -------------------------------------------------------------------------
  testWidgets('T05 — Solicitar unirse a un círculo muestra PendingRequestView',
      (tester) async {
    await _track('T05', tester, () async {
      // test_ci crea el círculo
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      final inviteCode = await _createCircleProgrammatically();
      await FirebaseAuth.instance.signOut();

      // test_ci2 solicita unirse via UI
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _test2Email,
        password: _test2Password,
      );

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(
          find.byKey(const Key('btn_navigate_join_circle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_navigate_join_circle')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('field_invite_code')), inviteCode);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('btn_join_circle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_join_circle')));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Con el flujo de aprobación, el usuario queda en PendingRequestView
      expect(find.byKey(const Key('pending_request_view')), findsOneWidget);

      // Verificar en Firestore: pendingCircleId seteado y joinRequest pendiente
      final user2 = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user2.uid)
          .get();
      expect(userDoc.data()!['pendingCircleId'], isNotNull);

      final circleId = userDoc.data()!['pendingCircleId'] as String;
      final requestDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('joinRequests')
          .doc(user2.uid)
          .get();
      expect(requestDoc.exists, isTrue);
      expect(requestDoc.data()!['status'], equals('pending'));

      await FirebaseAuth.instance.signOut();
    });
  });

  // -------------------------------------------------------------------------
  // T06 — Cambiar estado via btn_change_status
  // -------------------------------------------------------------------------
  testWidgets('T06 — btn_change_status actualiza estado en Firestore',
      (tester) async {
    await _track('T06', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      await _createCircleProgrammatically();
      final user = FirebaseAuth.instance.currentUser!;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final circleId = userDoc.data()!['circleId'] as String;

      // Forzar un estado diferente a 'fine' para poder detectar el cambio
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .update({'memberStatus.${user.uid}.statusType': 'sos'});

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byKey(const Key('btn_change_status')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_change_status')));
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Verificar que el estado cambió a 'fine' en Firestore
      final updatedCircleDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .get();
      final updatedStatus = (updatedCircleDoc.data()!['memberStatus']
          as Map<String, dynamic>)[user.uid] as Map<String, dynamic>;
      expect(updatedStatus['statusType'], equals('fine'));

      await _signOutFromCircle(tester);
    });
  });
}
