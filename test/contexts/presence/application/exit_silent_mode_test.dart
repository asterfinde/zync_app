import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/exit_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import '../../../helpers/presence/fake_presence_repository.dart';

void main() {
  late FakePresenceRepository repo;
  late ExitSilentMode useCase;

  setUp(() {
    repo    = FakePresenceRepository();
    useCase = ExitSilentMode(repository: repo);
  });

  tearDown(() => repo.dispose());

  group('ExitSilentMode', () {
    test('1 — SilentMode(preSilentId: work) → Normal(currentId: work, lastManualId: work)',
        () async {
      repo.setState(SilentMode(
        preSilentId: 'work',
        enteredAt:   DateTime(2026, 5, 20),
      ));

      final result = await useCase.call(userId: 'u1');

      expect(result.isSuccess, isTrue);
      expect(repo.lastSavedState, isA<Normal>());
      final saved = repo.lastSavedState as Normal;
      expect(saved.currentId,    'work');
      expect(saved.lastManualId, 'work');
    });

    test('2 — idempotencia: ya en Normal → Success sin escribir', () async {
      repo.setState(const Normal(currentId: 'school', lastManualId: 'school'));

      final result = await useCase.call(userId: 'u1');

      expect(result.isSuccess,   isTrue);
      expect(repo.saveCallCount, 0);
    });

    test('3 — Contract.requires lanza cuando userId está vacío', () async {
      await expectLater(
        useCase.call(userId: ''),
        throwsA(isA<ContractViolation>()),
      );
    });
  });
}
