// integration_test/expiration_flow_test.dart
//
// Fase 2 — Expiración de solicitudes de ingreso
//
// T2.12 👁 Solicitud expira (48h / umbral 1 min para test) — lazy expiration:
//          El creador abre la app → solicitud desaparece de InCircleView
//          → Firestore: joinRequests/{uid}.status = "expired"
//
// T2.13 👁 Solicitante reenvía código tras expiración:
//          Solicitante abre app → ve NoCircleView (pendingCircleId limpiado)
//          → reingresa código → nueva solicitud "pending" creada
//
// ⚠️  IMPORTANTE: Este test requiere el umbral de expiración en 1 minuto.
//     Verificar que circle_service.dart tenga: age.inMinutes >= 1
//     Restaurar a age.inHours >= 48 antes del release.
//
// Ejecución standalone (NO incluir en all_tests.dart — tarda ~2 min):
//   flutter test integration_test/expiration_flow_test.dart -d R58W315389R
//
// Credenciales de prueba:
//   Creador  : test_ci@zync.test  / ZyncTest2025!
//   Miembro  : test_ci2@zync.test / ZyncTest2025!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/services/circle_service.dart';

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------
const _creatorEmail = 'test_ci@zync.test';
const _creatorPassword = 'ZyncTest2025!';
const _memberEmail = 'test_ci2@zync.test';
const _memberPassword = 'ZyncTest2025!';
const _circleName = 'Círculo Test Expiración';

// ---------------------------------------------------------------------------
// Seguimiento de resultados
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
  debugPrint('  FASE 2 — EXPIRACIÓN — RESUMEN DE TESTS');
  debugPrint(sep);
  for (final key in ['T2.12', 'T2.13']) {
    final result = _testResults[key] ?? '⚠️  NO EJECUTADO';
    debugPrint('  $key  $result');
  }
  debugPrint(sep);
}

// ---------------------------------------------------------------------------
// Helpers
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

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      final circleId = data['circleId'] as String?;
      final pendingCircleId = data['pendingCircleId'] as String?;

      if (circleId != null && circleId.isNotEmpty) {
        await CircleService().leaveCircle();
      }
      if (pendingCircleId != null && pendingCircleId.isNotEmpty) {
        await userRef.update({'pendingCircleId': FieldValue.delete()});
      }
    }
  } catch (_) {
  } finally {
    await FirebaseAuth.instance.signOut();
  }
}

Future<String> _createCircleProgrammatically() async {
  final service = CircleService();
  final circleId = await service.createCircle(_circleName);
  final circleDoc = await FirebaseFirestore.instance
      .collection('circles')
      .doc(circleId)
      .get();
  return circleDoc.data()!['invitation_code'] as String;
}

Widget _homeWrapper() =>
    const ProviderScope(child: MaterialApp(home: HomePage()));

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
          options: DefaultFirebaseOptions.currentPlatform);
    }
    await _ensureAccountExists(_creatorEmail, _creatorPassword);
    await _ensureAccountExists(_memberEmail, _memberPassword);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
    await _ensureNoCircle(_creatorEmail, _creatorPassword);
    await _ensureNoCircle(_memberEmail, _memberPassword);
  });

  tearDownAll(() async {
    await _ensureNoCircle(_creatorEmail, _creatorPassword);
    await _ensureNoCircle(_memberEmail, _memberPassword);
    await FirebaseAuth.instance.signOut();
    _printSummary();
  });

  // -------------------------------------------------------------------------
  // T2.12 + T2.13 — flujo secuencial (se ejecutan juntos, comparten estado)
  // -------------------------------------------------------------------------
  testWidgets('T2.12 + T2.13 — Expiración de solicitud y reenvío',
      (tester) async {
    // ── SETUP: Creador crea círculo, miembro envía solicitud ──────────────

    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _creatorEmail, password: _creatorPassword);
    final inviteCode = await _createCircleProgrammatically();
    await FirebaseAuth.instance.signOut();

    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _memberEmail, password: _memberPassword);
    final memberUid = FirebaseAuth.instance.currentUser!.uid;

    await tester.pumpWidget(_homeWrapper());
    await tester.pumpAndSettle(const Duration(seconds: 8));

    await tester.tap(find.byKey(const Key('btn_navigate_join_circle')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('field_invite_code')), inviteCode);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('btn_join_circle')));
    await tester.tap(find.byKey(const Key('btn_join_circle')));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Verificar que el miembro quedó en PendingRequestView
    expect(find.byKey(const Key('pending_request_view')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await FirebaseAuth.instance.signOut();

    // ── T2.12 — Esperar expiración (65 seg con umbral 1 min) ─────────────
    await _track('T2.12', tester, () async {
      debugPrint('[T2.12] Esperando 65 segundos para que expire la solicitud...');
      await Future.delayed(const Duration(seconds: 65));

      // Creador abre app → stream aplica expiración lazy
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _creatorEmail, password: _creatorPassword);
      final creatorUid = FirebaseAuth.instance.currentUser!.uid;

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // InCircleView visible sin sección de solicitudes
      expect(find.byKey(const Key('btn_settings')), findsOneWidget);
      expect(find.textContaining('Solicitudes de ingreso'), findsNothing);

      // Verificar en Firestore: status = "expired"
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorUid)
          .get();
      final circleId = creatorDoc.data()!['circleId'] as String;

      final requestDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('joinRequests')
          .doc(memberUid)
          .get();
      expect(requestDoc.exists, isTrue);
      expect(requestDoc.data()!['status'], equals('expired'));

      await _signOutFromCircle(tester);
    });

    // ── T2.13 — Miembro reenvía código tras expiración ───────────────────
    await _track('T2.13', tester, () async {
      // Miembro abre app → stream detecta expired → limpia pendingCircleId
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _memberEmail, password: _memberPassword);

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Debe ver NoCircleView
      expect(find.byKey(const Key('btn_navigate_join_circle')), findsOneWidget);

      // Reenviar el mismo código
      await tester.tap(find.byKey(const Key('btn_navigate_join_circle')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('field_invite_code')), inviteCode);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('btn_join_circle')));
      await tester.tap(find.byKey(const Key('btn_join_circle')));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Debe volver a PendingRequestView
      expect(find.byKey(const Key('pending_request_view')), findsOneWidget);

      // Verificar en Firestore: nueva solicitud con status "pending"
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberUid)
          .get();
      final pendingCircleId = userDoc.data()!['pendingCircleId'] as String;

      final newRequestDoc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(pendingCircleId)
          .collection('joinRequests')
          .doc(memberUid)
          .get();
      expect(newRequestDoc.exists, isTrue);
      expect(newRequestDoc.data()!['status'], equals('pending'));

      await FirebaseAuth.instance.signOut();
    });
  });
}
