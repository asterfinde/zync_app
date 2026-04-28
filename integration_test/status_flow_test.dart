// integration_test/status_flow_test.dart
//
// Fase 3 — Actualización de Emojis / Estados
//
// T10.1 🔗 Sin zonas — card de miembro muestra timestamp relativo
// T30.1 🔗 manualOverride=true, locationUnknown=false → badge ✋ Manual visible, sin badge de ubicación
// T30.2 🔗 manualOverride=true, locationUnknown=true  → badge ✋ Manual + ❓ Ubicación desconocida visibles
// T30.3 👁 Manual — con zonas configuradas, seleccionar zona bloqueada muestra modal "Acción no permitida"
//
// Nota: T1 y T2 están cubiertos por Fase 2 T05 y T06 respectivamente.
// Nota: T20.1, T20.2 y T30.3 son 👁 manuales.
//
// Credenciales de prueba:
//   Cuenta primaria: test_ci@zync.test / ZyncTest2025!

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
const _circleName = 'Círculo Test CI - Fase 3';

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
  debugPrint('  FASE 3 — RESUMEN DE TESTS');
  debugPrint(sep);
  const order = ['T10.1', 'T30.1', 'T30.2'];
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

/// Crea un círculo y retorna el circleId.
Future<String> _createCircleAndGetId() async {
  return await CircleService().createCircle(_circleName);
}

Widget _homeWrapper() => const ProviderScope(
      child: MaterialApp(home: HomePage()),
    );

/// Desmonta todos los widgets antes de cerrar sesión para cancelar
/// los streams de Firestore y evitar errores post-test.
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
  // T10.1 — Card de miembro muestra timestamp relativo (sin zonas)
  // -------------------------------------------------------------------------
  testWidgets(
      'T10.1 — Card de miembro muestra timestamp relativo tras crear círculo',
      (tester) async {
    await _track('T10.1', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      await _createCircleAndGetId();

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // InCircleView debe estar visible
      expect(find.byKey(const Key('btn_settings')), findsOneWidget);

      // El widget de timestamp debe existir
      expect(find.byKey(const Key('text_member_timestamp')), findsOneWidget);

      // El texto debe ser uno de los formatos relativos válidos
      final timestampWidget = tester.widget<Text>(
        find.byKey(const Key('text_member_timestamp')),
      );
      final text = timestampWidget.data ?? '';
      final validFormats = [
        RegExp(r'^Justo Ahora$'),
        RegExp(r'^Hace \d+ min$'),
        RegExp(r'^Hace \d+ h$'),
        RegExp(r'^Hace \d+ d$'),
      ];
      expect(
        validFormats.any((re) => re.hasMatch(text)),
        isTrue,
        reason: 'Timestamp relativo esperado, se obtuvo: "$text"',
      );

      await _signOutFromCircle(tester);
    });
  });

  // -------------------------------------------------------------------------
  // T30.1 — manualOverride=true, locationUnknown=false → solo badge ✋ Manual
  // -------------------------------------------------------------------------
  testWidgets(
      'T30.1 — Badge ✋ Manual visible cuando manualOverride=true sin locationUnknown',
      (tester) async {
    await _track('T30.1', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      final circleId = await _createCircleAndGetId();
      final user = FirebaseAuth.instance.currentUser!;

      // Simular override manual sin ubicación desconocida
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .update({
        'memberStatus.${user.uid}.manualOverride': true,
        'memberStatus.${user.uid}.locationUnknown': false,
      });

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byKey(const Key('btn_settings')), findsOneWidget);

      // Badge ✋ Manual debe ser visible
      expect(find.byKey(const Key('badge_manual')), findsOneWidget);
      expect(find.text('✋ Manual'), findsOneWidget);

      // Badge de ubicación NO debe ser visible
      expect(find.byKey(const Key('text_location_info')), findsNothing);

      await _signOutFromCircle(tester);
    });
  });

  // -------------------------------------------------------------------------
  // T30.2 — manualOverride=true, locationUnknown=true → ✋ Manual + ❓ Ubicación
  // -------------------------------------------------------------------------
  testWidgets(
      'T30.2 — Badge ✋ Manual y ❓ Ubicación desconocida visibles cuando manualOverride=true y locationUnknown=true',
      (tester) async {
    await _track('T30.2', tester, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _testEmail,
        password: _testPassword,
      );
      final circleId = await _createCircleAndGetId();
      final user = FirebaseAuth.instance.currentUser!;

      // Simular override manual con ubicación desconocida
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .update({
        'memberStatus.${user.uid}.manualOverride': true,
        'memberStatus.${user.uid}.locationUnknown': true,
      });

      await tester.pumpWidget(_homeWrapper());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byKey(const Key('btn_settings')), findsOneWidget);

      // Badge ✋ Manual debe ser visible
      expect(find.byKey(const Key('badge_manual')), findsOneWidget);
      expect(find.text('✋ Manual'), findsOneWidget);

      // Badge ❓ Ubicación desconocida debe ser visible
      expect(find.byKey(const Key('text_location_info')), findsOneWidget);
      expect(find.text('❓ Ubicación desconocida'), findsOneWidget);

      await _signOutFromCircle(tester);
    });
  });

}
