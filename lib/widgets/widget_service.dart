import 'package:home_widget/home_widget.dart';
import '../core/services/status_service.dart';
import '../core/services/emoji_service.dart';
import '../core/models/user_status.dart';
import 'dart:developer';

class WidgetService {
  static const String _widgetName = 'ZyncStatusWidget';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId('group.zync.widget');
    await _setupInitialData();
    await _updateWidget();
  }

  static Future<void> _setupInitialData() async {
    // Solo guardamos datos simples (String, int, double, bool)
    await HomeWidget.saveWidgetData('appName', 'Zync');
    await HomeWidget.saveWidgetData('currentStatus', 'fine');
    await HomeWidget.saveWidgetData('currentEmoji', '😊');
    await HomeWidget.saveWidgetData('circleName', 'Sin círculo');
    await HomeWidget.saveWidgetData('lastUpdate', DateTime.now().toIso8601String());
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _widgetName,
      iOSName: _widgetName,
    );
  }

  static Future<void> handleWidgetAction(String action) async {
    try {
      final statusType = await _parseStatusFromAction(action);
      if (statusType != null) {
        await StatusService.updateUserStatus(statusType);
        await _updateWidgetWithStatus(action);
      }
    } catch (e) {
      log('Error handling widget action: $e');
      await _showWidgetError();
    }
  }

  static Future<StatusType?> _parseStatusFromAction(String action) async {
    // Mapeo de action IDs a status IDs del nuevo sistema
    final String? statusId;
    switch (action) {
      case 'away':
        statusId = 'away'; // Sin cambio
        break;
      case 'busy':
        statusId = 'busy'; // Sin cambio
        break;
      case 'good':
        statusId = 'fine';
        break;
      case 'bad':
        statusId = 'do_not_disturb'; // Reemplazo de sad
        break;
      case 'available':
        statusId = 'fine';
        break;
      case 'emergency':
        statusId = 'sos'; // Sin cambio
        break;
      default:
        statusId = null;
    }

    if (statusId == null) return null;

    try {
      final emojis = await EmojiService.getPredefinedEmojis();
      return emojis.firstWhere(
        (s) => s.id == statusId,
        orElse: () => StatusType.fallbackPredefined.first,
      );
    } catch (e) {
      log('Error loading status: $e');
      return StatusType.fallbackPredefined.first;
    }
  }

  static Future<void> _updateWidgetWithStatus(String status) async {
    final emoji = _getEmojiForStatus(status);

    await HomeWidget.saveWidgetData('currentStatus', status);
    await HomeWidget.saveWidgetData('currentEmoji', emoji);
    await HomeWidget.saveWidgetData('lastUpdate', DateTime.now().toIso8601String());
    await HomeWidget.saveWidgetData('status', 'success');
    await _updateWidget();

    await Future.delayed(const Duration(seconds: 2));
    await HomeWidget.saveWidgetData('status', 'normal');
    await _updateWidget();
  }

  static String _getEmojiForStatus(String status) {
    switch (status) {
      case 'away':
        return '🚶‍♂️';
      case 'busy':
        return '🔥';
      case 'good':
        return '😊';
      case 'bad':
        return '😢';
      case 'available':
        return '🙂';
      case 'emergency':
        return '🆘';
      default:
        return '😊';
    }
  }

  static Future<void> _showWidgetError() async {
    await HomeWidget.saveWidgetData('status', 'error');
    await _updateWidget();

    await Future.delayed(const Duration(seconds: 3));
    await HomeWidget.saveWidgetData('status', 'normal');
    await _updateWidget();
  }
}
