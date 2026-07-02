// lib/features/geofencing/services/geofencing_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:nunakin_app/app/di/injection_container.dart';
import 'package:nunakin_app/contexts/geofencing/application/use_cases/detect_zone_transition.dart';

/// Adapter delgado sobre el stream de GPS: escucha la posición y delega la
/// detección de transiciones de zona a [DetectZoneTransition] (Sem 8 —
/// extracción de dominio, ver `docs/dev/refactor-arch-2026-q2/00-plan-unificado.md` §3.8).
class GeofencingService {
  final DetectZoneTransition _detect = sl<DetectZoneTransition>();

  // Cuando el usuario elige un emoji desde la BN con el proceso muerto, al reabrir
  // startMonitoring() dispararía checkCurrentLocation() y sobreescribiría ese emoji
  // con el estado de zona (ENTRY). Este flag hace que ese primer check se omita,
  // preservando lo que StatusUpdateWorker ya escribió en Firestore.
  static bool _suppressNextInitialCheck = false;

  // Estado del servicio
  bool _isMonitoring = false;
  StreamSubscription<Position>? _positionSubscription;
  String? _currentCircleId;

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

      // Consumir el flag static aquí, antes de que arranque cualquier chequeo,
      // y forwardearlo al use case (que es quien realmente lo consume durante
      // la detección de transición).
      if (_suppressNextInitialCheck) {
        _suppressNextInitialCheck = false;
        _detect.suppressNextCheck();
      }

      // Verificar ubicación actual en background — no bloquea el arranque de la UI
      // ni dispara modales de zona durante initState (fix: modal automático al reabrir).
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
    _detect.reset();
  }

  /// Verificar ubicación actual contra todas las zonas del círculo
  Future<void> checkCurrentLocation() async {
    if (_currentCircleId == null) {
      log('[GeofencingService] ⚠️ No hay círculo configurado para verificar');
      return;
    }

    try {
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

  Future<void> _onLocationUpdate(double latitude, double longitude) async {
    if (!_isMonitoring || _currentCircleId == null) return;
    await _detect.onLocation(
      circleId: _currentCircleId!,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Señala que el próximo chequeo al iniciar debe omitirse.
  /// Llamar desde main.dart tras aplicar un status elegido en la BN con proceso muerto.
  static void suppressNextCheckOnReopen() {
    _suppressNextInitialCheck = true;
  }
}
