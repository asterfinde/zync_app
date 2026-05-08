import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import '../../../helpers/presence/fake_presence_repository.dart';
import '../../../helpers/presence/fake_presence_publisher.dart';

void main() {
  late FakePresenceRepository repo;
  late FakePresencePublisher publisher;
  late SetManualStatus useCase;

  setUp(() {
    repo      = FakePresenceRepository();
    publisher = FakePresencePublisher();
    useCase   = SetManualStatus(repository: repo, publisher: publisher);
  });

  tearDown(() => repo.dispose());

  group('SetManualStatus', () {
    test('1 — guarda Normal con currentId = lastManualId = statusId', () async {
      await useCase.call(statusId: 'school', userId: 'u1', circleId: 'c1');

      expect(repo.lastSavedState, isA<Normal>());
      final saved = repo.lastSavedState as Normal;
      expect(saved.currentId,    'school');
      expect(saved.lastManualId, 'school');
    });

    test('2 — invoca publisher con userId y circleId correctos', () async {
      await useCase.call(statusId: 'work', userId: 'u1', circleId: 'c1');

      expect(publisher.publishCallCount,    1);
      expect(publisher.lastUserId,          'u1');
      expect(publisher.lastCircleId,        'c1');
      expect(publisher.lastPublishedState,  isA<Normal>());
    });

    test('3 — si saveState falla no llama al publisher y retorna FailureResult',
        () async {
      repo.saveStateOverride = FailureResult(
        UnexpectedFailure(message: 'disk full'),
      );

      final result = await useCase.call(
        statusId: 'fine', userId: 'u1', circleId: 'c1',
      );

      expect(result.isFailure,           isTrue);
      expect(publisher.publishCallCount, 0);
    });

    test('4 — Contract.requires lanza cuando statusId está vacío', () async {
      await expectLater(
        useCase.call(statusId: '', userId: 'u1', circleId: 'c1'),
        throwsA(isA<ContractViolation>()),
      );
    });

    test('5 — Contract.requires lanza cuando circleId está vacío', () async {
      await expectLater(
        useCase.call(statusId: 'fine', userId: 'u1', circleId: ''),
        throwsA(isA<ContractViolation>()),
      );
    });
  });
}
