import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/join_circle.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class _FakeCircleRepository implements CircleRepository {
  Result<Unit> requestToJoinResult = Success(Unit.instance);

  @override
  Stream<MembershipState> get membership => const Stream.empty();

  @override
  Future<CircleEntity?> getCircle(String circleId) async => null;

  @override
  Future<String> createCircle(String name) async => 'fake-id';

  @override
  Future<Result<Unit>> requestToJoin(String invitationCode) async =>
      requestToJoinResult;

  @override
  Future<Result<Unit>> approveJoin({
    required String circleId,
    required String requestingUserId,
  }) async => Success(Unit.instance);

  @override
  Future<Result<Unit>> deleteAccount() async => Success(Unit.instance);
}

void main() {
  late _FakeCircleRepository repo;
  late JoinCircle useCase;

  setUp(() {
    repo = _FakeCircleRepository();
    useCase = JoinCircle(repository: repo);
  });

  test('éxito: retorna Success cuando el repo devuelve Success', () async {
    final result = await useCase.call('ABC123');
    expect(result.isSuccess, isTrue);
  });

  test('invitationCode vacío: lanza ContractViolation', () {
    expect(
      () => useCase.call(''),
      throwsA(isA<Error>()),
    );
  });

  test('fallo: propaga FailureResult del repo', () async {
    repo.requestToJoinResult =
        FailureResult(const DomainFailure(message: 'código inválido'));

    final result = await useCase.call('ZZZ999');
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<DomainFailure>());
  });
}
