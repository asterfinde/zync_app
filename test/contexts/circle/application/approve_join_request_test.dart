import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/application/use_cases/approve_join_request.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class _FakeCircleRepository implements CircleRepository {
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
  Future<Result<Unit>> deleteAccount() async => Success(Unit.instance);
}

void main() {
  late ApproveJoinRequest useCase;

  setUp(() {
    useCase = ApproveJoinRequest(repository: _FakeCircleRepository());
  });

  test('éxito: retorna Success con IDs válidos', () async {
    final result = await useCase.call(
      circleId: 'circle-1',
      requestingUserId: 'user-1',
    );
    expect(result.isSuccess, isTrue);
  });

  test('circleId vacío: lanza ContractViolation', () {
    expect(
      () => useCase.call(circleId: '', requestingUserId: 'user-1'),
      throwsA(isA<Error>()),
    );
  });

  test('requestingUserId vacío: lanza ContractViolation', () {
    expect(
      () => useCase.call(circleId: 'circle-1', requestingUserId: ''),
      throwsA(isA<Error>()),
    );
  });
}
