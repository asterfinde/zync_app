import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/contexts/circle/presentation/view_models/circle_view_model.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class _FakeCircleRepository implements CircleRepository {
  final _controller = StreamController<MembershipState>.broadcast();

  void emit(MembershipState state) => _controller.add(state);

  @override
  Stream<MembershipState> get membership => _controller.stream;

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

  void close() => _controller.close();
}

void main() {
  late _FakeCircleRepository repo;
  late CircleViewModel vm;

  setUp(() {
    repo = _FakeCircleRepository();
    vm = CircleViewModel(repository: repo);
  });

  tearDown(() {
    vm.dispose();
    repo.close();
  });

  test('currentSnapshot es null antes de init()', () {
    expect(vm.currentSnapshot, isNull);
  });

  test('init() suscribe al stream — currentSnapshot sigue null hasta primer evento', () async {
    await vm.init();
    expect(vm.currentSnapshot, isNull);
  });

  test('membershipStream re-emite eventos del repo', () async {
    await vm.init();
    const state = UserInCircle(circleId: 'c1', isCreator: true);

    expectLater(vm.membershipStream, emits(state));
    repo.emit(state);
  });

  test('currentSnapshot se actualiza tras cada evento', () async {
    await vm.init();
    const state = UserPendingRequest(circleId: 'c2');

    repo.emit(state);
    await Future.delayed(Duration.zero);

    expect(vm.currentSnapshot, isA<UserPendingRequest>());
    expect((vm.currentSnapshot as UserPendingRequest).circleId, 'c2');
  });

  test('dispose() cancela suscripción sin excepción', () async {
    await vm.init();
    expect(() => vm.dispose(), returnsNormally);
  });
}
