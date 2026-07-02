import 'package:nunakin_app/features/geofencing/domain/entities/zone_event.dart';

/// Puerto de persistencia de eventos de zona (entrada/salida).
///
/// Persistencia pura sobre `/circles/{circleId}/zone_events`. Expone solo las
/// operaciones con callers vivos: registrar un evento y escuchar el stream del
/// círculo. Los métodos de consulta puntual del servicio legacy
/// (`getZoneEvents`, `getUserEvents`, `getLastEventForZone`, `deleteOldEvents`)
/// se descartaron por no tener callers activos.
///
/// Nota: conserva las firmas throw-based del servicio legacy (no adopta el
/// patrón `Result<T>` del hermano `ZoneRepository`) para preservar el
/// comportamiento de los callers sin tocar su manejo de errores.
abstract class ZoneEventRepository {
  /// Registra un evento de zona en `/circles/{circleId}/zone_events` y devuelve
  /// la entidad persistida con su id. Lanza si el usuario no está autenticado o
  /// si Firestore falla.
  Future<ZoneEvent> createEvent({
    required String circleId,
    required String zoneId,
    required ZoneEventType eventType,
    required double latitude,
    required double longitude,
    String? zoneName,
  });

  /// Stream en tiempo real de los eventos del círculo (más recientes primero,
  /// hasta 100).
  Stream<List<ZoneEvent>> listenToCircleEvents(String circleId);
}
