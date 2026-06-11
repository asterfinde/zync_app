import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/shared/result.dart';
import 'package:nunakin_app/shared/unit.dart';

/// Puerto de acceso a la persistencia de zonas geográficas.
///
/// Persistencia pura (CRUD Firestore). Las validaciones de negocio
/// (límite de zonas, nombre único, permisos, reset de memberStatus
/// post-borrado, sync de cache nativo) viven en use cases — no aquí.
abstract class ZoneRepository {
  /// Todas las zonas del círculo, ordenadas por `createdAt` ascendente.
  Future<Result<List<Zone>>> getCircleZones(String circleId);

  /// Una zona por id, o `null` si no existe.
  Future<Result<Zone?>> getZone(String circleId, String zoneId);

  /// Stream en tiempo real de las zonas del círculo.
  Stream<List<Zone>> watchCircleZones(String circleId);

  /// Persiste una zona nueva. Si [Zone.id] está vacío, genera el id.
  /// Devuelve la zona persistida con su id definitivo.
  Future<Result<Zone>> createZone(Zone zone);

  /// Persiste los campos de [zone] sobre el documento existente.
  Future<Result<Unit>> updateZone(Zone zone);

  /// Elimina la zona indicada.
  Future<Result<Unit>> deleteZone(String circleId, String zoneId);
}
