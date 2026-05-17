/// Eventos de dominio publicados por bounded contexts vía DomainEventBus.
/// Los BCs no se importan mutuamente; se comunican solo a través de estos eventos.
sealed class DomainEvent {
  const DomainEvent();
}

// ── Geofencing ──────────────────────────────────────────────────────────────

class ZoneEntered extends DomainEvent {
  final String zoneId;
  final String userId;
  final String circleId;
  final String zoneTypeValue;  // 'home'|'school'|'university'|'work'|'custom'
  final String zoneName;
  final bool   isPredefined;

  const ZoneEntered({
    required this.zoneId,
    required this.userId,
    this.circleId      = '',
    this.zoneTypeValue = 'custom',
    this.zoneName      = '',
    this.isPredefined  = false,
  });
}

class ZoneExited extends DomainEvent {
  final String zoneId;
  final String userId;
  final String circleId;

  const ZoneExited({
    required this.zoneId,
    required this.userId,
    this.circleId = '',
  });
}

// ── Identity ─────────────────────────────────────────────────────────────────

class SessionEnded extends DomainEvent {
  final String userId;
  const SessionEnded({required this.userId});
}

// ── Notifications ─────────────────────────────────────────────────────────────

class NotificationStatusSelected extends DomainEvent {
  final String statusId;
  const NotificationStatusSelected({required this.statusId});
}
