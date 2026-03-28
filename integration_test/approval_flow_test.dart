// integration_test/approval_flow_test.dart
//
// Fase 2 — Aprobación de solicitud de ingreso
//
// T2.11 🔗 Creador aprueba solicitud:
//          A ve la solicitud en InCircleView con botón "Aceptar".
//          A toca "Aceptar" → Firestore: status = "approved", circleId seteado en B.
//          B abre app → ve InCircleView automáticamente.
//
// Ejecución standalone:
//   flutter test integration_test/approval_flow_test.dart -d R58W315389R
//
// Credenciales de prueba:
//   Creador : test_ci@zync.test  / ZyncTest2025!
//   Miembro : test_ci2@zync.test / ZyncTest2025!

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
const _circleName = 'Círculo Test Aprobación';

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
  debugPrint('  FASE 2 — APROBACIÓN — RESUMEN DE TESTS');
  debugPrint(sep);
  final result = _testResults['T2.11'] ?? '⚠️  NO EJECUTADO';
  debugPrint('  T2.11  $result');
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
  final circleId = await CircleService().createCircle(_circleName);
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
  // T2.11 — Creador aprueba solicitud de ingreso
  // -------------------------------------------------------------------------
  testWidgets('T2.11 — Creador aprueba solicitud, miembro entra al círculo',
      (tester) async {
    await _track('T2.11', tester, () async {
      // ── Paso 1: Creador crea círculo ──────────────────────────────────
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _creatorEmail, password: _creatorPassword);
      final inviteCode = await _createCircleProgrammatically();
      await FirebaseAuth.instance.signOut();

      // ── Paso 2: Miembro envía solicitud via UI ────────────────────────
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

      expect(find.byKey(const Key('pending_request_view')), findsOneWidget);

      await _signOutFromCircle(tester);

      // ── Paso 3: Creador abre app y aprueba la solicitud ───────────────
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _creatorEmail, password: _creatorPassword);

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // InCircleView visible con la solicitud pendiente
      expect(find.byKey(const Key('btn_settings')), findsOneWidget);
      expect(find.textContaining('Solicitudes de ingreso'), findsOneWidget);

      // Tocar el botón "Aceptar" de la solicitud del miembro
      await tester.tap(find.byKey(ValueKey('btn_approve_$memberUid')));
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // La sección de solicitudes debe desaparecer
      expect(find.textContaining('Solicitudes de ingreso'), findsNothing);

      // Verificar en Firestore: joinRequest aprobado + circleId seteado en miembro
      final creatorUid = FirebaseAuth.instance.currentUser!.uid;
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
      expect(requestDoc.data()!['status'], equals('approved'));

      final memberDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberUid)
          .get();
      expect(memberDoc.data()!['circleId'], equals(circleId));
      expect(memberDoc.data()!['pendingCircleId'], isNull);

      await _signOutFromCircle(tester);

      // ── Paso 4: Miembro abre app → debe ver InCircleView ─────────────
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _memberEmail, password: _memberPassword);

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byKey(const Key('btn_change_status')), findsOneWidget);

      await _signOutFromCircle(tester);
    });
  });
}
