import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/contexts/presence/infrastructure/shared_prefs_presence_repository.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';
import 'package:nunakin_app/shared/result.dart';

void main() {
  group('SharedPrefsPresenceRepository', () {
    late SharedPrefsPresenceRepository repo;

    Future<SharedPrefsPresenceRepository> build(
        Map<String, Object> initialValues) async {
      SharedPreferences.setMockInitialValues(initialValues);
      final prefs = await SharedPreferences.getInstance();
      return SharedPrefsPresenceRepository(SharedPrefsKvStore(prefs));
    }

    tearDown(() => repo.dispose());

    // ── currentState ──────────────────────────────────────────────────────────

    test('1 — cold start vacío devuelve Normal(fine, null)', () async {
      repo = await build({});
      final result = await repo.currentState();
      expect(result, isA<Success<PresenceState>>());
      final state = (result as Success<PresenceState>).value;
      expect(state, isA<Normal>());
      expect((state as Normal).currentId, StatusIds.fine);
      expect(state.lastManualId, isNull);
    });

    test('2 — Normal con historial devuelve currentId y lastManualId', () async {
      repo = await build({
        'flutter.current_status_id': 'school',
        'flutter.manual_status_id': 'school',
      });
      final result = await repo.currentState();
      final state = (result as Success<PresenceState>).value as Normal;
      expect(state.currentId, 'school');
      expect(state.lastManualId, 'school');
    });

    test('3 — SilentMode activo con timestamp reconstituye correctamente',
        () async {
      final ts = DateTime(2026, 5, 19, 10, 0).millisecondsSinceEpoch;
      repo = await build({
        'flutter.is_silent_mode_active': true,
        'flutter.pre_silent_status_id': 'work',
        'flutter.silent_entered_at': ts,
      });
      final result = await repo.currentState();
      final state = (result as Success<PresenceState>).value as SilentMode;
      expect(state.preSilentId, 'work');
      expect(state.enteredAt.millisecondsSinceEpoch, ts);
    });

    test('4 — SilentMode sin entered_at (legado) usa DateTime.now()', () async {
      final before = DateTime.now();
      repo = await build({
        'flutter.is_silent_mode_active': true,
        'flutter.pre_silent_status_id': 'home',
      });
      final result = await repo.currentState();
      final after = DateTime.now();
      final state = (result as Success<PresenceState>).value as SilentMode;
      expect(state.preSilentId, 'home');
      expect(
        state.enteredAt.millisecondsSinceEpoch,
        inInclusiveRange(
          before.millisecondsSinceEpoch,
          after.millisecondsSinceEpoch,
        ),
      );
    });

    // ── saveState ─────────────────────────────────────────────────────────────

    test('5 — saveState(Normal) limpia todas las claves de Silent Mode',
        () async {
      final ts = DateTime(2026, 5, 19).millisecondsSinceEpoch;
      repo = await build({
        'flutter.is_silent_mode_active': true,
        'flutter.pre_silent_status_id': 'work',
        'flutter.silent_entered_at': ts,
      });
      final result =
          await repo.saveState(const Normal(currentId: 'fine'));
      expect(result, isA<Success>());

      // Verify by reading back
      final stateResult = await repo.currentState();
      final state = (stateResult as Success<PresenceState>).value;
      expect(state, isA<Normal>());
      expect((state as Normal).currentId, 'fine');
    });

    test('6 — saveState(SilentMode) escribe las 3 claves de Silent Mode',
        () async {
      repo = await build({});
      final enteredAt = DateTime(2026, 5, 19, 12, 0);
      final result = await repo.saveState(
        SilentMode(preSilentId: 'school', enteredAt: enteredAt),
      );
      expect(result, isA<Success>());

      // Verify by reading back
      final stateResult = await repo.currentState();
      final state = (stateResult as Success<PresenceState>).value as SilentMode;
      expect(state.preSilentId, 'school');
      expect(state.enteredAt.millisecondsSinceEpoch,
          enteredAt.millisecondsSinceEpoch);
    });

    // ── stateStream ───────────────────────────────────────────────────────────

    test('7 — stateStream emite el estado tras saveState exitoso', () async {
      repo = await build({});
      final emitted = <PresenceState>[];
      repo.stateStream.listen(emitted.add);

      await repo.saveState(const Normal(currentId: 'work', lastManualId: 'work'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.first, isA<Normal>());
      expect((emitted.first as Normal).currentId, 'work');
    });
  });
}
