// lib/features/geofencing/services/geofencing_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/entities/zone.dart';
import '../domain/entities/zone_event.dart';
import 'zone_service.dart';
import 'zone_event_service.dart';

/// Servicio para monitoreo de geofencing y detección de entrada/salida de zonas
class GeofencingService {
  final ZoneService _zoneService = ZoneService();
  final ZoneEventService _eventService = ZoneEventService();

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
      // ni dispara modales de zona durante initState (fix: modal automático al reabrir)
      Future.microtask(() => checkCurrentLocation());

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
      final zones = await _zoneService.getCircleZones(_currentCircleId!);
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
      final zones = await _zoneService.getCircleZones(_currentCircleId!);
      final exitedZone = zones.firstWhere((z) => z.id == _currentZoneId);

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

      // US-GEO-004: Actualizar estado a "Viajando" al salir de cualquier zona
      try {
        await _updateUserStatusByZoneEvent(isEntry: false, zone: null);
        log('[Geofencing] ✅ Estado actualizado a: Viajando (salida de ${exitedZone.name})');
      } catch (e) {
        log('[Geofencing] ❌ Error al actualizar estado en salida: $e');
      }
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

      // US-GEO-004: Actualizar estado según tipo de zona
      try {
        await _updateUserStatusByZoneEvent(isEntry: true, zone: newZone);
        log('[Geofencing] ✅ Estado actualizado según zona (entrada a ${newZone.type.emoji}${newZone.name})');
      } catch (e) {
        log('[Geofencing] ❌ Error al actualizar estado en entrada: $e');
      }
    } // Actualizar estado actual
    _currentZoneId = newZoneId;
  }

  /// Obtener zona actual del usuario
  String? get currentZoneId => _currentZoneId;

  /// Verificar si el monitoreo está activo
  bool get isMonitoring => _isMonitoring;

  /// Obtener ID del círculo siendo monitoreado
  String? get monitoringCircleId => _currentCircleId;

  /// Actualiza el estado del usuario en Firestore según el evento de zona
  /// US-GEO-004: Actualización automática de estado basado en zona
  Future<void> _updateUserStatusByZoneEvent({
    required bool isEntry,
    Zone? zone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentCircleId == null) return;

    try {
      final Map<String, dynamic> statusData = {
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (isEntry && zone != null) {
        // ENTRADA A ZONA
        if (zone.isPredefined) {
          // Zona predefinida: emoji específico (🏠🏫🎓💼)
          statusData['customEmoji'] = zone.type.emoji;
          statusData['statusType'] = _getStatusFromZoneType(zone.type);
        } else {
          // Zona personalizada: emoji genérico (📍)
          statusData['customEmoji'] = '📍';
          statusData['statusType'] = 'fine';
        }

        statusData['zoneName'] = zone.name;
        statusData['zoneId'] = zone.id;
        statusData['autoUpdated'] = true;
      } else {
        // SALIDA DE ZONA → "Bien" (neutral, sin implicar dirección desconocida)
        statusData['statusType'] = 'fine';
        statusData['customEmoji'] = null;
        statusData['zoneName'] = null;
        statusData['zoneId'] = null;
        statusData['autoUpdated'] = true;

        // Guardar última zona conocida
        if (_currentZoneId != null) {
          statusData['lastKnownZone'] = _currentZoneId;
          statusData['lastKnownZoneTime'] = FieldValue.serverTimestamp();
        }
      }

      await FirebaseFirestore.instance.collection('circles').doc(_currentCircleId).update({
        'memberStatus.${user.uid}': statusData,
      });

      log('[Geofencing] ✅ Estado actualizado a: ${statusData['statusType']}');
    } catch (e) {
      log('[Geofencing] ❌ Error actualizando estado: $e');
      rethrow;
    }
  }

  String _getStatusFromZoneType(ZoneType type) {
    switch (type) {
      case ZoneType.home:
        return 'fine';
      case ZoneType.school:
        return 'studying'; // 📚 Estudiando
      case ZoneType.university:
        return 'studying'; // 📚 Estudiando
      case ZoneType.work:
        return 'busy'; // 🔴 Ocupado
      default:
        return 'fine';
    }
  }
}
