import 'dart:async';

import 'package:nunakin_app/contexts/geofencing/application/ports/geofence_status_writer.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

class ApplyGeofenceStatus {
  final DomainEventBus _bus;
  final GeofenceStatusWriter _writer;
  StreamSubscription<ZoneEntered>? _enteredSub;
  StreamSubscription<ZoneExited>? _exitedSub;

  ApplyGeofenceStatus({
    required DomainEventBus bus,
    required GeofenceStatusWriter writer,
  })  : _bus    = bus,
        _writer = writer;

  void initialize() {
    _enteredSub = _bus.on<ZoneEntered>().listen((e) async => _writer.onZoneEntered(e));
    _exitedSub  = _bus.on<ZoneExited>().listen((e) async => _writer.onZoneExited(e));
  }

  void dispose() {
    _enteredSub?.cancel();
    _exitedSub?.cancel();
  }
}
