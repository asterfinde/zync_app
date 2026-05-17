import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/delete_account.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class _FakeCircleRepository implements CircleRepository {
  Result<Unit> deleteAccountResult = Success(Unit.instance);

  @override
  Stream<MembershipState> get membership => const Stream.empty();

  @override
  Future<CircleEntity?> getCircle(String circleId) async => null;

  @override
  Future<String> createCircle(String name) async => 'fake-id';

  @override
  Future<Result<Unit>> requestToJoin(String invitationCode) async =>
      Success(Unit.instance);

  @override
  Future<Result<Unit>> approveJoin({
    required String circleId,
    required String requestingUserId,
  }) async => Success(Unit.instance);

  @override
  Future<Result<Unit>> deleteAccount() async => deleteAccountResult;
}

void main() {
  late _FakeCircleRepository repo;
  late DeleteAccount useCase;

  setUp(() {
    repo = _FakeCircleRepository();
    useCase = DeleteAccount(repository: repo);
  });

  test('éxito: retorna Success cuando el repo devuelve Success', () async {
    final result = await useCase.call();
    expect(result.isSuccess, isTrue);
  });

  test('fallo: propaga FailureResult del repo', () async {
    repo.deleteAccountResult =
        FailureResult(const UnexpectedFailure(message: 'error de red'));

    final result = await useCase.call();
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });
}
