import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';

void main() {
  group('MembershipState', () {
    test('UserNoCircle — pattern match sin default, no es UserInCircle', () {
      const MembershipState state = UserNoCircle();

      final label = switch (state) {
        UserNoCircle() => 'none',
        UserPendingRequest() => 'pending',
        UserInCircle() => 'in',
      };
      expect(label, 'none');
      expect(state is UserInCircle, isFalse);
    });

    test('UserPendingRequest — campo circleId accesible, es const', () {
      const state = UserPendingRequest(circleId: 'circle-abc');
      expect(state.circleId, 'circle-abc');

      const state2 = UserPendingRequest(circleId: 'circle-abc');
      expect(identical(state, state2), isTrue);
    });

    test('UserInCircle — ambos campos, isCreator correcto', () {
      const state = UserInCircle(circleId: 'circle-xyz', isCreator: true);
      expect(state.circleId, 'circle-xyz');
      expect(state.isCreator, isTrue);

      const nonCreator = UserInCircle(circleId: 'circle-xyz', isCreator: false);
      expect(nonCreator.isCreator, isFalse);
    });

    test('Switch exhaustivo — cubre los 3 estados sin default', () {
      final states = <MembershipState>[
        const UserNoCircle(),
        const UserPendingRequest(circleId: 'c1'),
        const UserInCircle(circleId: 'c2', isCreator: false),
      ];

      final labels = states.map((s) => switch (s) {
            UserNoCircle() => 'none',
            UserPendingRequest() => 'pending',
            UserInCircle() => 'in',
          }).toList();

      expect(labels, ['none', 'pending', 'in']);
    });
  });
}
