import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/geofence_status_writer.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/apply_geofence_status.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

class _FakeGeofenceStatusWriter implements GeofenceStatusWriter {
  int enteredCalls = 0;
  int exitedCalls  = 0;
  ZoneEntered? lastEntered;
  ZoneExited?  lastExited;

  @override
  Future<Result<Unit>> onZoneEntered(ZoneEntered event) async {
    enteredCalls++;
    lastEntered = event;
    return Success(Unit.instance);
  }

  @override
  Future<Result<Unit>> onZoneExited(ZoneExited event) async {
    exitedCalls++;
    lastExited = event;
    return Success(Unit.instance);
  }
}

void main() {
  late DomainEventBus bus;
  late _FakeGeofenceStatusWriter writer;
  late ApplyGeofenceStatus useCase;

  setUp(() {
    bus     = DomainEventBus();
    writer  = _FakeGeofenceStatusWriter();
    useCase = ApplyGeofenceStatus(bus: bus, writer: writer)..initialize();
  });

  tearDown(() {
    useCase.dispose();
    bus.dispose();
  });

  test('ZoneEntered dispara onZoneEntered con los datos correctos', () async {
    const event = ZoneEntered(
      zoneId:        'z1',
      userId:        'u1',
      circleId:      'c1',
      zoneTypeValue: 'home',
      zoneName:      'Casa',
      isPredefined:  true,
    );

    bus.publish(event);
    await Future<void>.delayed(Duration.zero);

    expect(writer.enteredCalls, 1);
    expect(writer.exitedCalls,  0);
    expect(writer.lastEntered?.zoneId, 'z1');
    expect(writer.lastEntered?.isPredefined, isTrue);
  });

  test('ZoneExited dispara onZoneExited con los datos correctos', () async {
    const event = ZoneExited(zoneId: 'z1', userId: 'u1', circleId: 'c1');

    bus.publish(event);
    await Future<void>.delayed(Duration.zero);

    expect(writer.exitedCalls,  1);
    expect(writer.enteredCalls, 0);
    expect(writer.lastExited?.circleId, 'c1');
  });

  test('dispose — eventos posteriores no disparan el writer', () async {
    useCase.dispose();

    bus.publish(const ZoneEntered(zoneId: 'z2', userId: 'u2'));
    bus.publish(const ZoneExited(zoneId: 'z2', userId: 'u2'));
    await Future<void>.delayed(Duration.zero);

    expect(writer.enteredCalls, 0);
    expect(writer.exitedCalls,  0);
  });
}
