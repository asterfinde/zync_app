import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/enter_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import '../../../helpers/presence/fake_presence_repository.dart';

void main() {
  late FakePresenceRepository repo;
  late EnterSilentMode useCase;

  setUp(() {
    repo    = FakePresenceRepository();
    useCase = EnterSilentMode(repository: repo);
  });

  tearDown(() => repo.dispose());

  group('EnterSilentMode', () {
    test('1 — Normal con lastManualId → preSilentId = lastManualId', () async {
      repo.setState(const Normal(currentId: 'school', lastManualId: 'school'));
      final before = DateTime.now();

      await useCase.call(userId: 'u1');

      final after = DateTime.now();
      expect(repo.lastSavedState, isA<SilentMode>());
      final saved = repo.lastSavedState as SilentMode;
      expect(saved.preSilentId, 'school');
      expect(
        saved.enteredAt.millisecondsSinceEpoch,
        inInclusiveRange(
          before.millisecondsSinceEpoch,
          after.millisecondsSinceEpoch,
        ),
      );
    });

    test('2 — Normal sin lastManualId → preSilentId = currentId', () async {
      repo.setState(const Normal(currentId: 'work'));

      await useCase.call(userId: 'u1');

      final saved = repo.lastSavedState as SilentMode;
      expect(saved.preSilentId, 'work');
    });

    test('3 — idempotencia: ya en SilentMode → Success sin escribir', () async {
      repo.setState(SilentMode(
        preSilentId: 'work',
        enteredAt:   DateTime(2026, 5, 20),
      ));

      final result = await useCase.call(userId: 'u1');

      expect(result.isSuccess,    isTrue);
      expect(repo.saveCallCount,  0);
    });

    test('4 — Contract.requires lanza cuando userId está vacío', () async {
      await expectLater(
        useCase.call(userId: ''),
        throwsA(isA<ContractViolation>()),
      );
    });
  });
}
