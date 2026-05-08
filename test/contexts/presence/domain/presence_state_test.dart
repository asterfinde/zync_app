import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';

void main() {
  group('PresenceState', () {
    group('Normal', () {
      test('visibleStatusId devuelve currentId', () {
        const state = Normal(currentId: 'school', lastManualId: 'school');
        expect(state.visibleStatusId, 'school');
      });

      test('copyWith actualiza campos correctamente', () {
        const original = Normal(currentId: 'fine', lastManualId: null);
        final updated = original.copyWith(currentId: 'work', lastManualId: 'work');
        expect(updated.currentId, 'work');
        expect(updated.lastManualId, 'work');
      });

      test('isSilent es false, isSOS es false', () {
        const state = Normal(currentId: 'fine');
        expect(state.isSilent, isFalse);
        expect(state.isSOS, isFalse);
      });
    });

    group('SilentMode', () {
      test('visibleStatusId devuelve preSilentId', () {
        final state = SilentMode(
          preSilentId: 'work',
          enteredAt: DateTime(2026, 5, 18),
        );
        expect(state.visibleStatusId, 'work');
      });

      test('isSilent es true, isSOS es false', () {
        final state = SilentMode(
          preSilentId: 'fine',
          enteredAt: DateTime.now(),
        );
        expect(state.isSilent, isTrue);
        expect(state.isSOS, isFalse);
      });
    });

    group('BackgroundNotificationActive', () {
      test('visibleStatusId usa manualBeneathId cuando está presente', () {
        const state = BackgroundNotificationActive(
          notifStatusId: 'home',
          manualBeneathId: 'school',
        );
        expect(state.visibleStatusId, 'school');
      });

      test('visibleStatusId usa notifStatusId cuando manualBeneathId es null', () {
        const state = BackgroundNotificationActive(notifStatusId: 'home');
        expect(state.visibleStatusId, 'home');
      });

      test('isSilent es false, isSOS es false', () {
        const state = BackgroundNotificationActive(notifStatusId: 'fine');
        expect(state.isSilent, isFalse);
        expect(state.isSOS, isFalse);
      });
    });

    group('SOSActive', () {
      test('visibleStatusId siempre devuelve StatusIds.sos', () {
        const state = SOSActive(
          previousId: 'school',
          latitude: -33.4,
          longitude: -70.6,
        );
        expect(state.visibleStatusId, StatusIds.sos);
      });

      test('isSOS es true, isSilent es false', () {
        const state = SOSActive(
          previousId: 'fine',
          latitude: 0.0,
          longitude: 0.0,
        );
        expect(state.isSOS, isTrue);
        expect(state.isSilent, isFalse);
      });
    });
  });
}
