import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';

void main() {
  group('NativeCommand', () {
    test('ActivateSilentMode is NativeCommand<void>', () {
      const cmd = ActivateSilentMode();
      expect(cmd, isA<NativeCommand<void>>());
    });

    test('DeactivateSilentMode is NativeCommand<void>', () {
      const cmd = DeactivateSilentMode();
      expect(cmd, isA<NativeCommand<void>>());
    });

    test('GetCurrentLocation is NativeCommand with record type', () {
      const cmd = GetCurrentLocation();
      expect(cmd, isA<NativeCommand<({double lat, double lng})>>());
    });

    test('SetUserSession stores uid and email', () {
      const cmd = SetUserSession(uid: 'u1', email: 'test@test.com');
      expect(cmd.uid, 'u1');
      expect(cmd.email, 'test@test.com');
    });

    test('ClearSession is NativeCommand<void>', () {
      const cmd = ClearSession();
      expect(cmd, isA<NativeCommand<void>>());
    });

    test('switch over all subtypes is exhaustive — no default needed', () {
      const NativeCommand<void> cmd = ActivateSilentMode();

      // Si se añade un nuevo subtipo y no se cubre aquí, el análisis falla.
      final label = switch (cmd) {
        ActivateSilentMode()   => 'activate',
        DeactivateSilentMode() => 'deactivate',
        GetCurrentLocation()   => 'location',
        SetUserSession()       => 'setSession',
        ClearSession()         => 'clearSession',
      };

      expect(label, 'activate');
    });
  });
}
