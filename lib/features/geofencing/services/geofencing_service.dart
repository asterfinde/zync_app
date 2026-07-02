// lib/features/geofencing/services/geofencing_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';
import 'package:nunakin_app/app/di/injection_container.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_event_repository.dart';
import 'package:nunakin_app/contexts/geofencing/application/ports/zone_repository.dart';
import '../domain/entities/zone.dart';
import '../domain/entities/zone_event.dart';

/// Servicio para monitoreo de geofencing y detección de entrada/salida de zonas
class GeofencingService {
  final ZoneRepository _zoneRepo = sl<ZoneRepository>();
  final ZoneEventRepository _eventService = sl<ZoneEventRepository>();
  final DomainEventBus? _bus;

  GeofencingService({DomainEventBus? bus}) : _bus = bus;

  // Cuando el usuario elige un emoji desde la BN con el proceso muerto, al reabrir
  // startMonitoring() dispararía checkCurrentLocation() y sobreescribiría ese emoji
  // con el estado de zona (ENTRY). Este flag hace que ese primer check se omita,
  // preservando lo que StatusUpdateWorker ya escribió en Firestore.
  static bool _suppressNextInitialCheck = false;

  // Estado del servicio
  bool _isMonitoring = false;
  StreamSubscription<Position>? _positionSubscription;
  String? _currentCircleId;
  String? _currentZoneId; // Zona en la que está el usuario actualmente

  // Constantes de configuración
  static const Duration CHECK_INTERVAL = Duration(minutes: 5); // Intervalo de verificación
  static const Duration DEBOUNCE_DURATION = Duration(minutes: 2); // Evitar eventos duplicados
  DateTime? _lastEventTime;

  /// Iniciar monitoreo de zonas para un círculo específico
  Future<void> startMonitoring(String circleId) async {
    if (_isMonitoring) {
      log('[GeofencingService] ⚠️ Monitoreo ya está activo');
      return;
    }

    try {
      log('[GeofencingService] 🟢 Iniciando monitoreo de zonas para círculo: $circleId');
      _currentCircleId = circleId;
      _isMonitoring = true;

      // Verificar ubicación actual en background — no bloquea el arranque de la UI
      // ni dispara modales de zona durante initState (fix: modal automático al reabrir).
      // El flag _suppressNextInitialCheck ya no se consume aquí: se consume directamente
      // en _detectZoneTransition() para cubrir también el stream de Geolocator
      // (fix AUTH-20260501-001: el stream emitía la primera posición antes del microtask).
      Future.microtask(() async {
        checkCurrentLocation();
      });

      // Configurar monitoreo continuo
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // Solo actualizar si se mueve más de 50 metros
        ),
      ).listen(
        (Position position) async {
          await _onLocationUpdate(position.latitude, position.longitude);
        },
        onError: (error) {
          log('[GeofencingService] ❌ Error en stream de ubicación: $error');
        },
      );

      log('[GeofencingService] ✅ Monitoreo iniciado exitosamente');
    } catch (e) {
      log('[GeofencingService] ❌ Error iniciando monitoreo: $e');
      _isMonitoring = false;
    }
  }

  /// Detener monitoreo de zonas
  Future<void> stopMonitoring() async {
    log('[GeofencingService] 🔴 Deteniendo monitoreo de zonas');
    _isMonitoring = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentCircleId = null;
    _currentZoneId = null;
    _lastEventTime = null;
  }

  /// Verificar ubicación actual contra todas las zonas del círculo
  Future<void> checkCurrentLocation() async {
    if (_currentCircleId == null) {
      log('[GeofencingService] ⚠️ No hay círculo configurado para verificar');
      return;
    }

    try {
      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      await _onLocationUpdate(position.latitude, position.longitude);
    } catch (e) {
      log('[GeofencingService] ❌ Error verificando ubicación actual: $e');
    }
  }

  /// Procesar actualización de ubicación
  Future<void> _onLocationUpdate(double latitude, double longitude) async {
    if (!_isMonitoring || _currentCircleId == null) return;

    try {
      // Obtener todas las zonas del círculo
      final zonesResult = await _zoneRepo.getCircleZones(_currentCircleId!);
      final zones = zonesResult.valueOrNull ?? const <Zone>[];
      if (zones.isEmpty) {
        log('[GeofencingService] ℹ️ No hay zonas configuradas en el círculo');
        return;
      }

      // Verificar en qué zona está el usuario.
      // Si hay zonas solapadas, gana la de menor radio (más específica).
      final containingZones = zones
          .where((z) => z.containsLocation(latitude, longitude))
          .toList()
        ..sort((a, b) => a.radiusMeters.compareTo(b.radiusMeters));
      final detectedZone = containingZones.isNotEmpty ? containingZones.first : null;

      // Detectar cambios de zona
      await _detectZoneTransition(
        detectedZone,
        latitude,
        longitude,
      );
    } catch (e) {
      log('[GeofencingService] ❌ Error procesando actualización de ubicación: $e');
    }
  }

  /// Detectar y registrar transiciones entre zonas
  Future<void> _detectZoneTransition(
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
      if (timeSinceLastEvent < DEBOUNCE_DURATION) {
        log('[GeofencingService] ⏸️ Evento ignorado por debounce (${timeSinceLastEvent.inSeconds}s)');
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // SALIDA de zona anterior
    if (_currentZoneId != null && newZoneId != _currentZoneId) {
      // Buscar la zona anterior para obtener su nombre
      final zonesResult = await _zoneRepo.getCircleZones(_currentCircleId!);
      final zones = zonesResult.valueOrNull ?? const <Zone>[];
      // ════════════════════════════════════════════════════════════
      // [FIX] Bug E — zona eliminada mientras el usuario estaba adentro
      // Fecha: 2026-05-16
      // PROBLEMA: firstWhere lanzaba StateError si la zona fue borrada,
      //   silenciando el crash en _onLocationUpdate y dejando el servicio
      //   en estado inválido.
      // SOLUCIÓN: guard con where().isEmpty → early-return y reset de _currentZoneId.
      // ════════════════════════════════════════════════════════════
      final zoneMatches = zones.where((z) => z.id == _currentZoneId);
      if (zoneMatches.isEmpty) {
        log('[GeofencingService] ⚠️ Zona $_currentZoneId fue eliminada — reseteando monitoreo');
        _currentZoneId = newZoneId;
        return;
      }
      final exitedZone = zoneMatches.first;

      log('[GeofencingService] 🚪 SALIDA de zona: ${exitedZone.name}');
      await _eventService.createEvent(
        circleId: _currentCircleId!,
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
        circleId: _currentCircleId!,
      ));
    }

    // ════════════════════════════════════════════════════════════
    // [FIX] AUTH-20260501-001 — Suprimir falso ENTER al reabrir
    // Fecha: 2026-05-01
    // PROBLEMA: _suppressNextInitialCheck solo cubría el microtask de
    //   startMonitoring(), pero el stream de Geolocator emitía la primera
    //   posición independientemente, causando un ENTER espurio cuando
    //   _currentZoneId == null (nueva instancia tras cada mount).
    // SOLUCIÓN: consumir el flag aquí, antes del bloque de ENTRADA, para
    //   cubrir tanto checkCurrentLocation() como el stream.
    // ════════════════════════════════════════════════════════════
    if (_suppressNextInitialCheck) {
      _suppressNextInitialCheck = false;
      _currentZoneId = newZoneId;
      log('[GeofencingService] ⏭️ Transición suprimida — status pendiente de BN (newZoneId=$newZoneId)');
      return;
    }

    // ENTRADA a nueva zona
    if (newZoneId != null) {
      log('[GeofencingService] 🚪 ENTRADA a zona: ${newZone!.name} (${newZone.type.emoji})');
      await _eventService.createEvent(
        circleId: _currentCircleId!,
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
        circleId:      _currentCircleId!,
        zoneTypeValue: newZone.type.value,
        zoneName:      newZone.name,
        isPredefined:  newZone.isPredefined,
      ));
    } // Actualizar estado actual
    _currentZoneId = newZoneId;
  }

  /// Señala que el próximo checkCurrentLocation() al iniciar debe omitirse.
  /// Llamar desde main.dart tras aplicar un status elegido en la BN con proceso muerto.
  static void suppressNextCheckOnReopen() {
    _suppressNextInitialCheck = true;
  }

  /// Obtener zona actual del usuario
  String? get currentZoneId => _currentZoneId;

  /// Verificar si el monitoreo está activo
  bool get isMonitoring => _isMonitoring;

  /// Obtener ID del círculo siendo monitoreado
  String? get monitoringCircleId => _currentCircleId;
}
