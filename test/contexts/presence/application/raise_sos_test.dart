import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/raise_sos.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/shared/contract.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import '../../../helpers/presence/fake_presence_publisher.dart';
import '../../../helpers/presence/fake_presence_repository.dart';

void main() {
  late FakePresenceRepository repo;
  late FakePresencePublisher  publisher;
  late RaiseSOS               useCase;

  setUp(() {
    repo      = FakePresenceRepository();
    publisher = FakePresencePublisher();
    useCase   = RaiseSOS(repository: repo, publisher: publisher);
  });

  tearDown(() => repo.dispose());

  group('RaiseSOS', () {
    test('1 — previousId captura visibleStatusId del estado actual', () async {
      repo.setState(const Normal(currentId: 'school', lastManualId: 'school'));

      await useCase.call(
        userId:    'u1',
        circleId:  'c1',
        latitude:  19.43,
        longitude: -99.13,
      );

      expect(repo.lastSavedState, isA<SOSActive>());
      final sos = repo.lastSavedState as SOSActive;
      expect(sos.previousId, 'school');
      expect(sos.latitude,   19.43);
      expect(sos.longitude,  -99.13);
    });

    test('2 — invoca publisher.publish con SOSActive', () async {
      await useCase.call(
        userId:    'u1',
        circleId:  'c1',
        latitude:  19.43,
        longitude: -99.13,
      );

      expect(publisher.publishCallCount,   1);
      expect(publisher.lastPublishedState, isA<SOSActive>());
      expect(publisher.lastUserId,         'u1');
      expect(publisher.lastCircleId,       'c1');
    });

    test('3 — si saveState falla → no llama al publisher', () async {
      repo.saveStateOverride = FailureResult(
        const UnexpectedFailure(message: 'disk full'),
      );

      final result = await useCase.call(
        userId:    'u1',
        circleId:  'c1',
        latitude:  0.0,
        longitude: 0.0,
      );

      expect(result.isFailure,           isTrue);
      expect(publisher.publishCallCount, 0);
    });

    test('4 — previousId desde SilentMode usa visibleStatusId (preSilentId)', () async {
      repo.setState(SilentMode(
        preSilentId: 'work',
        enteredAt:   DateTime(2026, 5, 20),
      ));

      await useCase.call(
        userId:    'u1',
        circleId:  'c1',
        latitude:  0.0,
        longitude: 0.0,
      );

      final sos = repo.lastSavedState as SOSActive;
      expect(sos.previousId, 'work');
    });

    test('5 — Contract.requires lanza cuando userId está vacío', () async {
      await expectLater(
        useCase.call(userId: '', circleId: 'c1', latitude: 0.0, longitude: 0.0),
        throwsA(isA<ContractViolation>()),
      );
    });

    test('6 — Contract.requires lanza cuando circleId está vacío', () async {
      await expectLater(
        useCase.call(userId: 'u1', circleId: '', latitude: 0.0, longitude: 0.0),
        throwsA(isA<ContractViolation>()),
      );
    });

    test('7 — desde cold start (fine) previousId = fine', () async {
      // Estado por defecto del fake: Normal(currentId: StatusIds.fine)
      await useCase.call(
        userId:    'u1',
        circleId:  'c1',
        latitude:  0.0,
        longitude: 0.0,
      );

      final sos = repo.lastSavedState as SOSActive;
      expect(sos.previousId, StatusIds.fine);
    });
  });
}
