import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/core/models/user_status.dart';
import 'app_badge_service.dart';
import 'gps_service.dart';
import 'dart:async';
import 'dart:developer';

/// Servicio centralizado para actualizar estados de usuario
/// Extraído de EmojiStatusBottomSheet para reutilización en widgets
class StatusService {
  static StreamSubscription<DocumentSnapshot>? _circleStatusListener;
  static bool _isListenerInitialized = false;

  static const String _zoneManualSelectionNotAllowedError = 'zone_manual_selection_not_allowed';
  static const Set<String> _blockedZoneStatusIds = {
    'home',
    'school',
    'work',
    'university',
  };

  /// Inicializar el listener de cambios de estado para badge
  static Future<void> initializeStatusListener() async {
    // Evitar re-inicializar si ya está activo
    if (_isListenerInitialized && _circleStatusListener != null) {
      log('[StatusService] ⚡ Status listener ya está inicializado, saltando...');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        log('[StatusService] ⚠️ No hay usuario autenticado, saltando inicialización');
        return;
      }

      // Obtener el circleId del usuario
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) {
        log('[StatusService] ⚠️ Usuario sin círculo, saltando listener');
        return;
      }

      // Cancelar listener anterior si existe
      await _circleStatusListener?.cancel();

      // Escuchar cambios en memberStatus del círculo
      _circleStatusListener =
          FirebaseFirestore.instance.collection('circles').doc(circleId).snapshots().listen(_handleCircleStatusChange);

      _isListenerInitialized = true;
      log('[StatusService] ✅ Status listener initialized for circle: $circleId');
    } catch (e) {
      log('[StatusService] ❌ Error initializing status listener: $e');
      _isListenerInitialized = false;
    }
  }

  /// Manejar cambios de estado en el círculo
  static void _handleCircleStatusChange(DocumentSnapshot snapshot) {
    try {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      final memberStatus = data?['memberStatus'] as Map<String, dynamic>?;

      if (memberStatus == null) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Verificar cambios de otros miembros (no del usuario actual)
      memberStatus.forEach((userId, statusData) {
        if (userId != currentUser.uid && statusData is Map<String, dynamic>) {
          final timestamp = statusData['timestamp'] as Timestamp?;
          final statusType = statusData['statusType'] as String?;

          if (timestamp != null && statusType != null) {
            // Procesar cambio de estado para badge
            AppBadgeService.handleStatusChange(
              userId: userId,
              newStatus: statusType,
              changeTime: timestamp.toDate(),
            );
          }
        }
      });
    } catch (e) {
      log('[StatusService] Error handling circle status change: $e');
    }
  }

  /// Detener el listener de cambios de estado
  static Future<void> disposeStatusListener() async {
    await _circleStatusListener?.cancel();
    _circleStatusListener = null;
    _isListenerInitialized = false;
    log('[StatusService] Status listener disposed');
  }

  /// Actualiza el estado del usuario actual en su círculo
  /// Point 16: Incluye ubicación GPS cuando se envía estado SOS
  ///
  /// Throws [Exception] si:
  /// - Usuario no está autenticado
  /// - Usuario no pertenece a ningún círculo
  /// - Error en Firebase
  static Future<StatusUpdateResult> updateUserStatus(StatusType newStatus) async {
    try {
      log('[StatusService] Actualizando estado a: ${newStatus.description} ${newStatus.emoji}');

      // Actualización directa a Firestore sin capas intermedias complejas
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener el circleId del usuario
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) {
        throw Exception('Usuario no está en ningún círculo');
      }

      if (_blockedZoneStatusIds.contains(newStatus.id)) {
        final isThisZoneConfigured = await _isSpecificZoneTypeConfigured(circleId, newStatus.id);
        if (isThisZoneConfigured) {
          log('[StatusService] 🚫 Bloqueado: zona ${newStatus.id} está configurada como zona de geofencing');
          return StatusUpdateResult.error(_zoneManualSelectionNotAllowedError);
        }
      }

      // Leer el estado actual del usuario para verificar si estaba en una zona
      final circleDoc = await FirebaseFirestore.instance.collection('circles').doc(circleId).get();

      final currentMemberStatus = circleDoc.data()?['memberStatus'] as Map<String, dynamic>?;
      final currentUserStatus = currentMemberStatus?[user.uid] as Map<String, dynamic>?;

      // Verificar si el usuario estaba en una zona (solo si tiene zoneId)
      // NOTA: customEmoji también se usa para "En camino" automático (🚗), así que NO es una prueba confiable.
      final wasInZone = currentUserStatus?['zoneId'] != null;
      final previousZoneName = currentUserStatus?['zoneName'] as String?;
      final previousZoneId = currentUserStatus?['zoneId'] as String?;
      final previousZoneEmoji = currentUserStatus?['customEmoji'] as String?;

      final previousWasAutoUpdated = currentUserStatus?['autoUpdated'] as bool? ?? false;
      final previousManualOverride = currentUserStatus?['manualOverride'] as bool? ?? false;
      // PA1 FIX: Solo marcar manualOverride si el usuario SIGUE en la zona
      // Si salió de la zona, NO marcar locationUnknown para estados "fine" (Todo bien)
      final manualOverride = (wasInZone && (previousWasAutoUpdated || previousManualOverride));
      final locationUnknown =
          (previousWasAutoUpdated || previousManualOverride) && !wasInZone && newStatus.id != 'fine';

      log('[StatusService] 📍 Usuario estaba en zona: $wasInZone${wasInZone ? ' ($previousZoneName)' : ''}');

      // Point 16: Obtener ubicación GPS si es estado SOS
      Coordinates? coordinates;
      if (newStatus.id == 'sos') {
        log('[StatusService] 🆘 Estado SOS detectado - obteniendo ubicación GPS...');
        coordinates = await GPSService.getCurrentLocation();
        if (coordinates != null) {
          log('[StatusService] 📍 Ubicación GPS obtenida para SOS: ${coordinates.latitude}, ${coordinates.longitude}');
        } else {
          log('[StatusService] ⚠️ No se pudo obtener ubicación GPS para SOS');
        }
      }

      // Actualizar el estado en el círculo
      final batch = FirebaseFirestore.instance.batch();

      // Actualizar memberStatus en el documento del círculo
      final statusData = {
        'userId': user.uid,
        'statusType': newStatus.id,
        'timestamp': FieldValue.serverTimestamp(),
        'autoUpdated': false, // Estado manual
        'manualOverride': manualOverride,
        'locationUnknown': locationUnknown,
        'customEmoji': wasInZone ? previousZoneEmoji : null,
        'zoneName': wasInZone ? previousZoneName : null,
        'zoneId': wasInZone ? previousZoneId : null,
      };

      // Si estaba en una zona, guardar como última zona conocida
      if (wasInZone && previousZoneName != null) {
        statusData['lastKnownZone'] = previousZoneName;
        statusData['lastKnownZoneTime'] = FieldValue.serverTimestamp();
        log('[StatusService] 💾 Guardando última zona conocida: $previousZoneName');
      }

      // Point 16: Agregar coordenadas GPS si están disponibles (solo para SOS)
      if (coordinates != null) {
        statusData['coordinates'] = {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
        };
        log('[StatusService] 🗺️ Coordenadas GPS agregadas al estado SOS');
      }

      log('[StatusService] 📤 Enviando a Firestore - Circle: $circleId');
      log('[StatusService] 📤 StatusData completo: $statusData');

      batch.update(
          FirebaseFirestore.instance.collection('circles').doc(circleId), {'memberStatus.${user.uid}': statusData});

      // Crear evento en historial (opcional, si existe)
      final historyRef =
          FirebaseFirestore.instance.collection('circles').doc(circleId).collection('statusEvents').doc();

      final historyData = {
        'uid': user.uid,
        'statusType': newStatus.id,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Point 16: Incluir coordenadas en historial para SOS
      if (coordinates != null) {
        historyData['coordinates'] = {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
        };
      }

      batch.set(historyRef, historyData);

      await batch.commit();
      log('[StatusService] ✅ Estado actualizado exitosamente${coordinates != null ? ' con GPS' : ''}');

      // ════════════════════════════════════════════════════════════
      // [FIX] Persistir ID del estado activo en SharedPreferences
      // Fecha: 2026-05-04
      // PROBLEMA: El modal de selección no mostraba cuál estado estaba activo.
      // SOLUCIÓN: Escribir flutter.current_status_id tras commit exitoso para
      //           que in_circle_view y EmojiDialogActivity puedan leerlo.
      // ════════════════════════════════════════════════════════════
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('flutter.current_status_id', newStatus.id);
        log('[StatusService] 💾 current_status_id guardado: ${newStatus.id}');
      } catch (e) {
        log('[StatusService] ⚠️ Error guardando current_status_id: $e');
      }

      // Actualizar notificación persistente con nuevo estado
      await _updatePersistentNotification(newStatus);

      return StatusUpdateResult.success(newStatus, coordinates);
    } catch (e) {
      log('[StatusService] Error actualizando estado: $e');
      return StatusUpdateResult.error(e.toString());
    }
  }

  // ========================================================================
  // [ELIMINADO] setOfflineStatus / clearOfflineStatus — concepto "Desconectado"
  // Fecha: 2026-04-14
  //
  // PROBLEMA ORIGINAL:
  // - Con finishAndRemoveTask() el isolate Dart muere en AppLifecycleState.detached.
  //   Flutter escribía "loggedOut: true" en Firestore, mostrando "💤 Desconectado"
  //   a los miembros del círculo aunque el usuario solo activó Modo Silencio.
  //
  // SOLUCIÓN IMPLEMENTADA:
  // - Eliminar el concepto "Desconectado" por completo.
  // - Al activar Modo Silencio → se escribe 'do_not_disturb' en Firestore (ver
  //   SilentFunctionalityCoordinator.activateSilentMode).
  // - Al reabrir la app → el último estado persiste en Firestore sin reset a 'fine'.
  // - Estos métodos se conservan como no-ops para evitar errores de compilación
  //   durante la transición; eliminar en post-MVP.
  // ========================================================================

  /// @deprecated — No-op. Reemplazado por escritura de 'do_not_disturb' en activateSilentMode.
  static Future<void> setOfflineStatus() async {
    log('[StatusService] ⚠️ setOfflineStatus() llamado — no-op (deprecado)');
  }

  /// @deprecated — No-op. El último estado se preserva en Firestore; no resetear a fine.
  static Future<void> clearOfflineStatus() async {
    log('[StatusService] ⚠️ clearOfflineStatus() llamado — no-op (deprecado)');
  }

  static Future<bool> _isSpecificZoneTypeConfigured(String circleId, String zoneType) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .collection('zones')
          .where('type', isEqualTo: zoneType)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      log('[StatusService] ⚠️ Error verificando zona $zoneType: $e');
      return false;
    }
  }

  /// Actualiza la notificación persistente con el nuevo estado
  /// Point 15: DESHABILITADO - No hacer eco con la barra de notificaciones
  static Future<void> _updatePersistentNotification(StatusType status) async {
    try {
      // Point 15: Comportamiento silencioso - NO actualizar notificación
      // Solo mantener la notificación inicial para acceso rápido
      log('[StatusService] 🔇 Actualización silenciosa - notificación persistente sin cambios');

      // await NotificationService.showQuickActionNotification(currentStatus: status);
    } catch (e) {
      log('[StatusService] Error actualizando notificación persistente: $e');
      // No lanzamos la excepción para no afectar el flujo principal
    }
  }
}

/// Resultado de la actualización de estado
/// Point 16: Incluye coordenadas GPS para estados SOS
class StatusUpdateResult {
  final bool isSuccess;
  final StatusType? status;
  final String? errorMessage;
  final Coordinates? coordinates; // Point 16: Coordenadas GPS para SOS

  StatusUpdateResult._({
    required this.isSuccess,
    this.status,
    this.errorMessage,
    this.coordinates,
  });

  factory StatusUpdateResult.success(StatusType status, [Coordinates? coordinates]) {
    return StatusUpdateResult._(
      isSuccess: true,
      status: status,
      coordinates: coordinates,
    );
  }

  factory StatusUpdateResult.error(String message) {
    return StatusUpdateResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
