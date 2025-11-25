import 'package:launcher_shortcuts/launcher_shortcuts.dart';
import '../core/services/status_service.dart';
import '../core/services/quick_actions_preferences_service.dart';
import '../core/models/user_status.dart';
import '../services/circle_service.dart';
import 'dart:developer';

/// Servicio para gestionar Launcher Shortcuts (Quick Actions)
/// OPCIÓN C: Fast Launch + Auto-Update
///
/// Funcionalidad:
/// - Si el usuario NO pertenece a círculo: NO shortcuts
/// - Si el usuario SI pertenece a círculo: SI shortcuts con iconos personalizados
/// - Al hacer tap: actualiza estado en Firebase sin UI visible (fast launch)
class QuickActionsService {
  static bool _isInitialized = false;
  static bool _isSilentLaunch = false;

  /// Flag para indicar si la app se abrió desde un shortcut (silent mode)
  static bool get isSilentLaunch => _isSilentLaunch;

  /// Inicializa las Launcher Shortcuts según membresía en círculo
  static Future<void> initialize() async {
    if (_isInitialized) {
      log('[QuickActionsService] ⚠️ Ya inicializado, saltando...');
      return;
    }

    try {
      await LauncherShortcuts.initialize();
      await _setupShortcutHandler();
      await updateShortcutsBasedOnCircle();
      _isInitialized = true;
      log('[QuickActionsService] ✅ Inicializado con launcher_shortcuts');
    } catch (e) {
      log('[QuickActionsService] ❌ Error inicializando: $e');
    }
  }

  /// Configura el handler de shortcuts (escucha eventos del sistema)
  static Future<void> _setupShortcutHandler() async {
    LauncherShortcuts.shortcutStream.listen((String shortcutType) async {
      log('[QuickActionsService] 🚀 Shortcut activado: $shortcutType');

      // Marcar como silent launch
      _isSilentLaunch = true;

      // Manejar la acción
      await handleShortcutAction(shortcutType);
    });
  }

  /// Maneja la acción cuando se selecciona un shortcut
  /// OPCIÓN C: Actualiza Firebase y marca para auto-close
  static Future<void> handleShortcutAction(String actionType) async {
    log('[QuickActionsService] 📱 Procesando shortcut: $actionType');

    try {
      final statusType = _parseStatusType(actionType);

      if (statusType != null) {
        log('[QuickActionsService] ✅ StatusType reconocido: ${statusType.emoji} ${statusType.description}');

        // Actualizar estado en Firebase (sin mostrar UI)
        final result = await StatusService.updateUserStatus(statusType);

        if (result.isSuccess) {
          log('[QuickActionsService] ✅ Estado actualizado en Firebase exitosamente');
          // La app se cerrará automáticamente en main.dart al detectar _isSilentLaunch
        } else {
          log('[QuickActionsService] ❌ Error actualizando estado: ${result.errorMessage}');
          _isSilentLaunch = false; // Cancelar auto-close si hubo error
        }
      } else {
        log('[QuickActionsService] ⚠️ StatusType desconocido: $actionType');
        _isSilentLaunch = false;
      }
    } catch (e) {
      log('[QuickActionsService] ❌ Error manejando shortcut: $e');
      _isSilentLaunch = false;
    }
  }

  /// Actualiza shortcuts según membresía en círculo
  /// - NO círculo: Limpia shortcuts
  /// - SI círculo: Configura shortcuts personalizados
  static Future<void> updateShortcutsBasedOnCircle() async {
    try {
      final circleService = CircleService();
      final userCircle = await circleService.getUserCircle();

      if (userCircle == null) {
        // Usuario NO tiene círculo -> CLEAR shortcuts
        log('[QuickActionsService] ⛔ Usuario sin círculo, limpiando shortcuts...');
        await LauncherShortcuts.clearShortcuts();
      } else {
        // Usuario tiene círculo -> CONFIGURAR shortcuts
        log('[QuickActionsService] ✅ Usuario en círculo ${userCircle.name}, configurando shortcuts...');
        await _setupUserShortcuts();
      }
    } catch (e) {
      log('[QuickActionsService] ❌ Error actualizando shortcuts: $e');
    }
  }

  /// Configura los shortcuts personalizados del usuario
  static Future<void> _setupUserShortcuts() async {
    try {
      // Obtener las 4 Quick Actions configuradas por el usuario
      final userQuickActions =
          await QuickActionsPreferencesService.getUserQuickActions();

      // Convertir a ShortcutItem con iconos personalizados
      final shortcutItems = userQuickActions.map((status) {
        final statusName = status.toString().split('.').last;

        return ShortcutItem(
          type: statusName, // 'available', 'busy', etc.
          localizedTitle: '${status.emoji} ${status.description}',
          androidConfig: AndroidConfig(
            icon: 'assets/launcher/$statusName.png',
          ),
          iosConfig: IosConfig(
            icon: statusName,
            localizedSubtitle: 'Actualizar estado',
          ),
        );
      }).toList();

      await LauncherShortcuts.setShortcuts(shortcutItems);

      log('[QuickActionsService] ✅ ${shortcutItems.length} shortcuts configurados: ${userQuickActions.map((s) => s.emoji).join(' ')}');
    } catch (e) {
      log('[QuickActionsService] ❌ Error configurando shortcuts: $e');
      // Fallback a shortcuts por defecto
      await _setupDefaultShortcuts();
    }
  }

  /// Configuración de fallback con shortcuts por defecto
  static Future<void> _setupDefaultShortcuts() async {
    log('[QuickActionsService] ⚙️ Usando shortcuts por defecto (fallback)');

    await LauncherShortcuts.setShortcuts([
      ShortcutItem(
        type: 'available',
        localizedTitle: '🟢 Disponible',
        androidConfig: AndroidConfig(icon: 'assets/launcher/available.png'),
        iosConfig: IosConfig(
            icon: 'available', localizedSubtitle: 'Actualizar estado'),
      ),
      ShortcutItem(
        type: 'busy',
        localizedTitle: '🔴 Ocupado',
        androidConfig: AndroidConfig(icon: 'assets/launcher/busy.png'),
        iosConfig:
            IosConfig(icon: 'busy', localizedSubtitle: 'Actualizar estado'),
      ),
      ShortcutItem(
        type: 'away',
        localizedTitle: '🟡 Ausente',
        androidConfig: AndroidConfig(icon: 'assets/launcher/away.png'),
        iosConfig:
            IosConfig(icon: 'away', localizedSubtitle: 'Actualizar estado'),
      ),
      ShortcutItem(
        type: 'sos',
        localizedTitle: '🆘 SOS',
        androidConfig: AndroidConfig(icon: 'assets/launcher/sos.png'),
        iosConfig:
            IosConfig(icon: 'sos', localizedSubtitle: 'Actualizar estado'),
      ),
    ]);
  }

  /// Convierte el string de acción a StatusType
  static StatusType? _parseStatusType(String actionType) {
    try {
      return StatusType.values.firstWhere(
        (status) => status.toString().split('.').last == actionType,
      );
    } catch (e) {
      log('[QuickActionsService] ❌ StatusType no encontrado: $actionType');
      return null;
    }
  }

  /// Habilita o deshabilita los shortcuts
  /// Usado cuando el usuario entra/sale de un círculo
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await updateShortcutsBasedOnCircle();
    } else {
      await LauncherShortcuts.clearShortcuts();
      log('[QuickActionsService] 🧹 Shortcuts deshabilitados');
    }
  }

  /// Actualiza los shortcuts cuando el usuario cambia su configuración
  /// Point 14: Permite configuración personalizada de 4 Quick Actions
  static Future<void> updateUserQuickActions(
      List<StatusType> newQuickActions) async {
    try {
      if (newQuickActions.length != 4) {
        log('[QuickActionsService] ❌ Error: Debe haber exactamente 4 Quick Actions');
        return;
      }

      // Guardar las nuevas preferencias
      final saved = await QuickActionsPreferencesService.saveUserQuickActions(
          newQuickActions);

      if (saved) {
        // Actualizar los shortcuts del sistema
        await _setupUserShortcuts();
        log('[QuickActionsService] ✅ Quick Actions actualizadas por el usuario');
      } else {
        log('[QuickActionsService] ❌ Error guardando preferencias');
      }
    } catch (e) {
      log('[QuickActionsService] ❌ Error actualizando Quick Actions: $e');
    }
  }

  /// Resetea el flag de silent launch (llamar después del auto-close)
  static void resetSilentLaunch() {
    _isSilentLaunch = false;
    log('[QuickActionsService] 🔄 Silent launch flag reseteado');
  }

  /// Método legacy mantenido para compatibilidad
  static Future<void> updateQuickActions(
      List<StatusType> enabledStatuses) async {
    await updateUserQuickActions(enabledStatuses);
  }
}
