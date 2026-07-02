import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_event_repository.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone.dart';
import 'package:nunakin_app/features/geofencing/domain/entities/zone_event.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

/// Determina, a partir de una posición GPS, si el usuario entró o salió de
/// una zona del círculo — y produce el evento correspondiente (auditoría en
/// [ZoneEventRepository] + publicación en [DomainEventBus] para que
/// `ApplyGeofenceStatus` actualice el estado).
///
/// Extraído de `GeofencingService` (Sem 8) para dejar ese servicio como un
/// adapter delgado sobre el stream de GPS. Move 1:1 de la lógica —
/// mismo comportamiento, ahora testeable sin depender de Geolocator.
///
/// Singleton stateful (vía DI): mantiene en memoria la última zona detectada
/// y el timestamp del último evento para el debounce.
class DetectZoneTransition {
  final ZoneRepository _zoneRepo;
  final ZoneEventRepository _eventRepo;
  final FirebaseAuth _auth;
  final DomainEventBus? _bus;
  final Duration _debounceDuration;

  DetectZoneTransition({
    required ZoneRepository zoneRepo,
    required ZoneEventRepository eventRepo,
    required FirebaseAuth auth,
    DomainEventBus? bus,
    Duration debounceDuration = defaultDebounceDuration,
  })  : _zoneRepo = zoneRepo,
        _eventRepo = eventRepo,
        _auth = auth,
        _bus = bus,
        _debounceDuration = debounceDuration;

  /// Evita eventos duplicados por fluctuación de GPS cerca del borde de una zona.
  /// Overridable por constructor solo para tests — el DI de producción usa
  /// siempre este default.
  static const Duration defaultDebounceDuration = Duration(minutes: 2);

  String? _currentZoneId;
  DateTime? _lastEventTime;

  // Cuando el usuario elige un emoji desde la BN con el proceso muerto, al reabrir
  // el monitoreo dispararía un chequeo inicial que sobreescribiría ese emoji
  // con el estado de zona (ENTRY). Este flag hace que esa primera transición se
  // omita, preservando lo que StatusUpdateWorker ya escribió en Firestore.
  bool _suppressNextCheck = false;

  /// Reinicia el estado en memoria. Llamar al detener el monitoreo
  /// (`GeofencingService.stopMonitoring`).
  void reset() {
    _currentZoneId = null;
    _lastEventTime = null;
  }

  /// Última zona detectada para el usuario, o `null` si no está en ninguna.
  String? get currentZoneId => _currentZoneId;

  /// Señala que la próxima transición detectada debe omitirse.
  /// Llamar desde `main.dart` tras aplicar un status elegido en la BN con
  /// proceso muerto o desde el canal nativo `status_update`.
  void suppressNextCheck() {
    _suppressNextCheck = true;
  }

  /// Procesa una actualización de ubicación para [circleId]: determina en qué
  /// zona está el usuario (si hay solapadas, gana la de menor radio) y detecta
  /// transiciones de entrada/salida respecto de la última zona conocida.
  Future<void> onLocation({
    required String circleId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final zonesResult = await _zoneRepo.getCircleZones(circleId);
      final zones = zonesResult.valueOrNull ?? const <Zone>[];
      if (zones.isEmpty) {
        log('[DetectZoneTransition] ℹ️ No hay zonas configuradas en el círculo');
        return;
      }

      // Si hay zonas solapadas, gana la de menor radio (más específica).
      final containingZones = zones
          .where((z) => z.containsLocation(latitude, longitude))
          .toList()
        ..sort((a, b) => a.radiusMeters.compareTo(b.radiusMeters));
      final detectedZone = containingZones.isNotEmpty ? containingZones.first : null;

      await _detectTransition(circleId, detectedZone, latitude, longitude);
    } catch (e) {
      log('[DetectZoneTransition] ❌ Error procesando actualización de ubicación: $e');
    }
  }

  Future<void> _detectTransition(
    String circleId,
    Zone? newZone,
    double latitude,
    double longitude,
  ) async {
    final newZoneId = newZone?.id;

    // No hay cambio de zona
    if (newZoneId == _currentZoneId) {
      return;
    }

    // Aplicar debounce para evitar eventos duplicados
    if (_lastEventTime != null) {
      final timeSinceLastEvent = DateTime.now().difference(_lastEventTime!);
      if (timeSinceLastEvent < _debounceDuration) {
        log('[DetectZoneTransition] ⏸️ Evento ignorado por debounce (${timeSinceLastEvent.inSeconds}s)');
        return;
      }
    }

    final user = _auth.currentUser;
    if (user == null) return;

    // SALIDA de zona anterior
    if (_currentZoneId != null && newZoneId != _currentZoneId) {
      // Buscar la zona anterior para obtener su nombre
      final zonesResult = await _zoneRepo.getCircleZones(circleId);
      final zones = zonesResult.valueOrNull ?? const <Zone>[];
      // ════════════════════════════════════════════════════════════
      // [FIX] Bug E — zona eliminada mientras el usuario estaba adentro
      // Fecha: 2026-05-16
      // PROBLEMA: firstWhere lanzaba StateError si la zona fue borrada,
      //   silenciando el crash y dejando el servicio en estado inválido.
      // SOLUCIÓN: guard con where().isEmpty → early-return y reset de _currentZoneId.
      // ════════════════════════════════════════════════════════════
      final zoneMatches = zones.where((z) => z.id == _currentZoneId);
      if (zoneMatches.isEmpty) {
        log('[DetectZoneTransition] ⚠️ Zona $_currentZoneId fue eliminada — reseteando monitoreo');
        _currentZoneId = newZoneId;
        return;
      }
      final exitedZone = zoneMatches.first;

      log('[DetectZoneTransition] 🚪 SALIDA de zona: ${exitedZone.name}');
      await _eventRepo.createEvent(
        circleId: circleId,
        zoneId: _currentZoneId!,
        eventType: ZoneEventType.exit,
        latitude: latitude,
        longitude: longitude,
        zoneName: exitedZone.name,
      );
      _lastEventTime = DateTime.now();

      // US-GEO-004: Publicar evento de salida → ApplyGeofenceStatus actualiza el estado
      _bus?.publish(ZoneExited(
        zoneId:   _currentZoneId!,
        userId:   user.uid,
        circleId: circleId,
      ));
    }

    // ════════════════════════════════════════════════════════════
    // [FIX] AUTH-20260501-001 — Suprimir falso ENTER al reabrir
    // Fecha: 2026-05-01
    // PROBLEMA: el flag de supresión solo cubría el microtask inicial de
    //   startMonitoring(), pero el stream de Geolocator emitía la primera
    //   posición independientemente, causando un ENTER espurio cuando
    //   _currentZoneId == null (nueva instancia tras cada mount).
    // SOLUCIÓN: consumir el flag aquí, antes del bloque de ENTRADA, para
    //   cubrir tanto el chequeo inicial como el stream.
    // ════════════════════════════════════════════════════════════
    if (_suppressNextCheck) {
      _suppressNextCheck = false;
      _currentZoneId = newZoneId;
      log('[DetectZoneTransition] ⏭️ Transición suprimida — status pendiente de BN (newZoneId=$newZoneId)');
      return;
    }

    // ENTRADA a nueva zona
    if (newZoneId != null) {
      log('[DetectZoneTransition] 🚪 ENTRADA a zona: ${newZone!.name} (${newZone.type.emoji})');
      await _eventRepo.createEvent(
        circleId: circleId,
        zoneId: newZoneId,
        eventType: ZoneEventType.entry,
        latitude: latitude,
        longitude: longitude,
        zoneName: newZone.name,
      );
      _lastEventTime = DateTime.now();

      // US-GEO-004: Publicar evento de entrada → ApplyGeofenceStatus actualiza el estado
      _bus?.publish(ZoneEntered(
        zoneId:        newZoneId,
        userId:        user.uid,
        circleId:      circleId,
        zoneTypeValue: newZone.type.value,
        zoneName:      newZone.name,
        isPredefined:  newZone.isPredefined,
      ));
    }

    _currentZoneId = newZoneId;
  }
}
