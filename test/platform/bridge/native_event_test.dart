import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

void main() {
  group('NativeEvent', () {
    test('StatusUpdatedFromNotification stores statusId', () {
      const event = StatusUpdatedFromNotification('fine');
      expect(event.statusId, 'fine');
    });

    test('SilentDeactivatedByUser instantiates correctly', () {
      const event = SilentDeactivatedByUser();
      expect(event, isA<NativeEvent>());
    });

    test('GeofenceEntered stores zoneId', () {
      const event = GeofenceEntered('zone-1');
      expect(event.zoneId, 'zone-1');
    });

    test('GeofenceExited stores zoneId', () {
      const event = GeofenceExited('zone-1');
      expect(event.zoneId, 'zone-1');
    });

    test('SessionCleared instantiates correctly', () {
      const event = SessionCleared();
      expect(event, isA<NativeEvent>());
    });

    test('switch over all subtypes is exhaustive — no default needed', () {
      const NativeEvent event = StatusUpdatedFromNotification('university');

      // Si se añade un nuevo subtipo y no se cubre aquí, el análisis falla.
      final label = switch (event) {
        StatusUpdatedFromNotification() => 'status',
        SilentDeactivatedByUser()      => 'silent',
        GeofenceEntered()              => 'entered',
        GeofenceExited()               => 'exited',
        SessionCleared()               => 'cleared',
      };

      expect(label, 'status');
    });
  });
}
