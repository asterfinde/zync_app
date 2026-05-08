import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/enter_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/exit_silent_mode.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/raise_sos.dart';
import 'package:nunakin_app/contexts/presence/application/use_cases/set_manual_status.dart';
import 'package:nunakin_app/contexts/presence/domain/presence_state.dart';
import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';
import 'package:nunakin_app/contexts/presence/presentation/view_models/presence_view_model.dart';
import '../../helpers/presence/fake_presence_publisher.dart';
import '../../helpers/presence/fake_presence_repository.dart';

void main() {
  late FakePresenceRepository repo;
  late FakePresencePublisher publisher;
  late SetManualStatus setManual;
  late EnterSilentMode enterSilent;
  late ExitSilentMode exitSilent;
  late RaiseSOS raiseSos;
  late PresenceViewModel vm;

  setUp(() {
    repo      = FakePresenceRepository();
    publisher = FakePresencePublisher();
    setManual  = SetManualStatus(repository: repo, publisher: publisher);
    enterSilent = EnterSilentMode(repository: repo);
    exitSilent  = ExitSilentMode(repository: repo);
    raiseSos    = RaiseSOS(repository: repo, publisher: publisher);
    vm = PresenceViewModel(repository: repo);
  });

  tearDown(() {
    repo.dispose();
    vm.dispose();
  });

  test('ciclo completo Normal→Manual→Silent→Normal→SOS', () async {
    // Recolectar estados emitidos por el VM
    final emitted = <PresenceState>[];
    await vm.init();
    vm.stateStream.listen(emitted.add);

    // Estado inicial
    expect(vm.currentSnapshot, isA<Normal>());
    expect((vm.currentSnapshot as Normal).currentId, StatusIds.fine);

    // SetManualStatus
    final r1 = await setManual.call(
      statusId: 'school',
      userId:   'u1',
      circleId: 'c1',
    );
    expect(r1.isSuccess, isTrue);
    expect(repo.lastSavedState, isA<Normal>());
    final n1 = repo.lastSavedState as Normal;
    expect(n1.currentId,    'school');
    expect(n1.lastManualId, 'school');

    // EnterSilentMode
    final r2 = await enterSilent.call(userId: 'u1');
    expect(r2.isSuccess, isTrue);
    expect(repo.lastSavedState, isA<SilentMode>());
    expect((repo.lastSavedState as SilentMode).preSilentId, 'school');

    // ExitSilentMode
    final r3 = await exitSilent.call(userId: 'u1');
    expect(r3.isSuccess, isTrue);
    expect(repo.lastSavedState, isA<Normal>());
    final n3 = repo.lastSavedState as Normal;
    expect(n3.currentId,    'school');
    expect(n3.lastManualId, 'school');

    // RaiseSOS
    final r4 = await raiseSos.call(
      userId:    'u1',
      circleId:  'c1',
      latitude:  4.7110,
      longitude: -74.0721,
    );
    expect(r4.isSuccess, isTrue);
    expect(repo.lastSavedState, isA<SOSActive>());
    final sos = repo.lastSavedState as SOSActive;
    expect(sos.previousId, 'school');
    expect(sos.latitude,   4.7110);
    expect(sos.longitude,  -74.0721);

    // El publisher fue llamado por SetManualStatus + RaiseSOS (2 veces)
    expect(publisher.publishCallCount, 2);

    // El VM recibió 4 estados (uno por cada transición)
    await Future.microtask(() {});
    expect(emitted.length, 4);
    expect(emitted[0], isA<Normal>());
    expect(emitted[1], isA<SilentMode>());
    expect(emitted[2], isA<Normal>());
    expect(emitted[3], isA<SOSActive>());
  });

  test('PresenceViewModel.currentSnapshot se actualiza tras cada transición', () async {
    await vm.init();

    await setManual.call(statusId: 'work', userId: 'u1', circleId: 'c1');
    await Future.microtask(() {});
    expect((vm.currentSnapshot as Normal).currentId, 'work');

    await enterSilent.call(userId: 'u1');
    await Future.microtask(() {});
    expect(vm.currentSnapshot, isA<SilentMode>());

    await exitSilent.call(userId: 'u1');
    await Future.microtask(() {});
    expect((vm.currentSnapshot as Normal).currentId, 'work');
  });

  test('SetManualStatus con statusId=sos compila y devuelve Success (bloqueo es deuda Sem 4)', () async {
    // El bloqueo de zona activa viene de StatusService._blockedZoneStatusIds
    // y se migra al dominio en Sem 4. En Sem 2 el use case no bloquea.
    final r = await setManual.call(
      statusId: StatusIds.sos,
      userId:   'u1',
      circleId: 'c1',
    );
    expect(r.isSuccess, isTrue);
  });

  test('PresenceViewModel antes de init — currentSnapshot es null', () {
    expect(vm.currentSnapshot, isNull);
  });
}
