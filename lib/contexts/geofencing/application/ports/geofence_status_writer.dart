import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

abstract class GeofenceStatusWriter {
  Future<Result<Unit>> onZoneEntered(ZoneEntered event);
  Future<Result<Unit>> onZoneExited(ZoneExited event);
}
