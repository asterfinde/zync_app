import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
// TODO: Migrar a launcher_shortcuts
// import 'package:quick_actions/quick_actions.dart';
import '../../core/models/user_status.dart';
import '../../core/services/emoji_service.dart';

/// Widget service for handling home screen widgets and quick actions
/// NOTA: Quick Actions movidos a QuickActionsService (launcher_shortcuts)
class StatusWidgetService {
  static const String _widgetName = 'ZyncStatusWidget';
  static const String _statusKey = 'status';
  static const String _circleKey = 'circle';

  // static final QuickActions _quickActions = QuickActions(); // DEPRECATED

  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      // await _setupQuickActions(); // DEPRECATED - usar QuickActionsService
      await _setupWidget();
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error durante inicialización: $e');
    }
  }

  /// Setup quick actions for the app (DEPRECATED - usar QuickActionsService)
  /*
  static Future<void> _setupQuickActions() async {
    try {
      await _quickActions.initialize((String shortcutType) {
        _handleQuickAction(shortcutType);
      });
      
      await _quickActions.setShortcutItems([
        const ShortcutItem(
          type: _quickActionHappy,
          localizedTitle: '� Feliz',
          icon: 'icon_happy',
        ),
        const ShortcutItem(
          type: _quickActionSad,
          localizedTitle: '😢 Mal',
          icon: 'icon_sad',
        ),
        const ShortcutItem(
          type: _quickActionBusy,
          localizedTitle: '� Ocupado',
          icon: 'icon_busy',
        ),
        const ShortcutItem(
          type: _quickActionReady,
          localizedTitle: '✅ Listo',
          icon: 'icon_ready',
        ),
      ]);
      
      debugPrint('✅ [StatusWidgetService] Quick actions configuradas');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error configurando quick actions: $e');
    }
  }
  */

  /// Setup home screen widget
  static Future<void> _setupWidget() async {
    try {
      await HomeWidget.setAppGroupId('group.com.datainfers.zync');

      // Cargar emojis desde Firebase con fallback
      final emojis = await EmojiService.getPredefinedEmojis();
      final availableStatus = emojis.firstWhere(
        (s) => s.id == 'fine',
        orElse: () => emojis.firstWhere(
          (s) => s.id == 'available',
          orElse: () => StatusType.fallbackPredefined.first,
        ),
      );

      await _updateWidget(status: availableStatus, circleId: null);
      debugPrint('✅ [StatusWidgetService] Widget configurado');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error configurando widget: $e');
    }
  }

  /// Update the home screen widget display
  static Future<void> _updateWidget({
    required StatusType status,
    String? circleId,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(_statusKey, status.emoji);
      await HomeWidget.saveWidgetData<String>(_circleKey, circleId ?? 'Sin círculo');
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: _widgetName,
        androidName: _widgetName,
      );

      debugPrint('✅ [StatusWidgetService] Widget actualizado: ${status.emoji}');
    } catch (e) {
      debugPrint('🔴 [StatusWidgetService] Error actualizando widget: $e');
    }
  }

  /// Update widget when status changes from within the app
  static Future<void> onStatusChanged({
    required StatusType status,
    String? circleId,
  }) async {
    await _updateWidget(status: status, circleId: circleId);
  }
}
