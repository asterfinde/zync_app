import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

void main() {
  group('SessionState', () {
    test('Anonymous — isAuthenticated es false y pattern match sin default', () {
      const SessionState state = Anonymous();
      expect(state.isAuthenticated, isFalse);

      final label = switch (state) {
        Anonymous() => 'anon',
        Authenticated() => 'auth',
      };
      expect(label, 'anon');
    });

    test('Authenticated — isAuthenticated es true, campos accesibles', () {
      const state = Authenticated(uid: 'uid-123', email: 'user@test.com');
      expect(state.isAuthenticated, isTrue);
      expect(state.uid, 'uid-123');
      expect(state.email, 'user@test.com');
    });

    test('Constructores son const — misma instancia en igualdad referencial', () {
      const a1 = Anonymous();
      const a2 = Anonymous();
      expect(identical(a1, a2), isTrue);

      const auth1 = Authenticated(uid: 'u', email: 'e');
      const auth2 = Authenticated(uid: 'u', email: 'e');
      expect(identical(auth1, auth2), isTrue);
    });

    test('Switch exhaustivo — no requiere default al cubrir Anonymous y Authenticated', () {
      SessionState state = const Authenticated(uid: 'u', email: 'e');
      final result = switch (state) {
        Anonymous() => 0,
        Authenticated() => 1,
      };
      expect(result, 1);
    });
  });
}
