import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';
import 'package:nunakin_app/contexts/identity/presentation/view_models/identity_view_model.dart';

class _FakeIdentityRepository implements IdentityRepository {
  final _controller = StreamController<SessionState>.broadcast();
  SessionState _current = const Anonymous();

  void emit(SessionState state) {
    _current = state;
    _controller.add(state);
  }

  @override
  Stream<SessionState> get session => _controller.stream;

  @override
  SessionState get current => _current;

  @override
  Future<void> signOut() async {}

  void close() => _controller.close();
}

void main() {
  late _FakeIdentityRepository repo;
  late IdentityViewModel vm;

  setUp(() {
    repo = _FakeIdentityRepository();
    vm = IdentityViewModel(repository: repo);
  });

  tearDown(() {
    vm.dispose();
    repo.close();
  });

  test('currentSnapshot es null antes de init()', () {
    expect(vm.currentSnapshot, isNull);
  });

  test('init() carga current del repositorio', () async {
    await vm.init();
    expect(vm.currentSnapshot, isA<Anonymous>());
  });

  test('sessionStream re-emite eventos del repo', () async {
    await vm.init();
    const auth = Authenticated(uid: 'u1', email: 'a@b.com');

    expectLater(vm.sessionStream, emits(auth));
    repo.emit(auth);
  });

  test('currentSnapshot se actualiza tras cada evento', () async {
    await vm.init();
    const auth = Authenticated(uid: 'u2', email: 'x@y.com');

    repo.emit(auth);
    await Future.delayed(Duration.zero);

    expect(vm.currentSnapshot, isA<Authenticated>());
    expect((vm.currentSnapshot as Authenticated).uid, 'u2');
  });

  test('dispose() cancela suscripción sin excepción', () async {
    await vm.init();
    expect(() => vm.dispose(), returnsNormally);
  });
}
