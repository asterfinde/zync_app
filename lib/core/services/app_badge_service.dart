import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

/// Servicio para gestionar el badge (indicador rojo) del ícono de la aplicación
/// Comportamiento similar a WhatsApp: muestra indicador cuando hay cambios de estado
/// en miembros del círculo, sin mostrar cantidad específica
class AppBadgeService {
  static const String _lastSeenKey = 'app_badge_last_seen';
  
  /// Verificar si la plataforma soporta badges
  static Future<bool> isSupported() async {
    try {
      return await AppBadgePlus.isSupported();
    } catch (e) {
      log('[AppBadgeService] Error checking badge support: $e');
      return false;
    }
  }
  
  /// Mostrar badge (indicador rojo) en el ícono de la app
  /// No muestra cantidad, solo el indicador visual
  static Future<void> showBadge() async {
    try {
      final isSupported = await AppBadgeService.isSupported();
      if (!isSupported) {
        log('[AppBadgeService] Badge not supported on this platform');
        return;
      }
      
      // Mostrar badge con valor 1 (solo indicador, no cantidad)
      await AppBadgePlus.updateBadge(1);
      log('[AppBadgeService] Badge shown successfully');
    } catch (e) {
      log('[AppBadgeService] Error showing badge: $e');
    }
  }
  
  /// Limpiar badge (quitar indicador rojo) del ícono de la app
  static Future<void> clearBadge() async {
    try {
      final isSupported = await AppBadgeService.isSupported();
      if (!isSupported) {
        log('[AppBadgeService] Badge not supported on this platform');
        return;
      }
      
      await AppBadgePlus.updateBadge(0);
      log('[AppBadgeService] Badge cleared successfully');
    } catch (e) {
      log('[AppBadgeService] Error clearing badge: $e');
    }
  }
  
  /// Marcar que el usuario ha visto los cambios (para limpiar badge)
  static Future<void> markAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSeenKey, now);
      
      // Limpiar badge cuando el usuario ve los cambios
      await clearBadge();
      
      log('[AppBadgeService] Marked as seen and badge cleared');
    } catch (e) {
      log('[AppBadgeService] Error marking as seen: $e');
    }
  }
  
  /// Obtener timestamp de la última vez que el usuario vio los cambios
  static Future<DateTime?> getLastSeenTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastSeenKey);
      
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      return null;
    } catch (e) {
      log('[AppBadgeService] Error getting last seen time: $e');
      return null;
    }
  }
  
  /// Verificar si hay cambios nuevos desde la última vez que el usuario vio
  /// Para mostrar/ocultar badge según corresponda
  static Future<bool> hasNewChanges(DateTime? lastStatusChangeTime) async {
    try {
      if (lastStatusChangeTime == null) return false;
      
      final lastSeenTime = await getLastSeenTime();
      
      // Si nunca ha visto cambios, considerar que hay cambios nuevos
      if (lastSeenTime == null) return true;
      
      // Hay cambios nuevos si el último cambio de estado es posterior
      // a la última vez que el usuario vio la app
      return lastStatusChangeTime.isAfter(lastSeenTime);
    } catch (e) {
      log('[AppBadgeService] Error checking for new changes: $e');
      return false;
    }
  }
  
  /// Procesar cambio de estado de un miembro del círculo
  /// Mostrar badge si el cambio es nuevo y el usuario no lo ha visto
  static Future<void> handleStatusChange({
    required String userId,
    required String newStatus,
    DateTime? changeTime,
  }) async {
    try {
      final actualChangeTime = changeTime ?? DateTime.now();
      
      // Verificar si hay cambios nuevos
      final hasNew = await hasNewChanges(actualChangeTime);
      
      if (hasNew) {
        await showBadge();
        log('[AppBadgeService] Badge shown for status change: $userId -> $newStatus');
      } else {
        log('[AppBadgeService] No new changes, badge not updated');
      }
    } catch (e) {
      log('[AppBadgeService] Error handling status change: $e');
    }
  }
  
  /// Obtener estado actual del badge
  static Future<bool> hasBadge() async {
    try {
      // Esta implementación es básica ya que app_badge_plus no tiene un método directo
      // para consultar el estado actual del badge
      final lastSeenTime = await getLastSeenTime();
      
      // Si nunca se ha marcado como visto, probablemente hay badge
      if (lastSeenTime == null) return true;
      
      // Verificar si hay cambios recientes no vistos
      final now = DateTime.now();
      final timeSinceLastSeen = now.difference(lastSeenTime).inMinutes;
      
      // Lógica básica: si han pasado menos de 5 minutos desde que se vio,
      // probablemente no hay badge
      return timeSinceLastSeen > 5;
    } catch (e) {
      log('[AppBadgeService] Error checking badge status: $e');
      return false;
    }
  }
  
  /// Inicializar el servicio (llamar al inicio de la app)
  static Future<void> initialize() async {
    try {
      final isSupported = await AppBadgeService.isSupported();
      
      if (isSupported) {
        log('[AppBadgeService] Badge service initialized successfully');
      } else {
        log('[AppBadgeService] Badge not supported on this platform');
      }
    } catch (e) {
      log('[AppBadgeService] Error initializing badge service: $e');
    }
  }
}