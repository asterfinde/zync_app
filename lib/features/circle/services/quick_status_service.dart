// lib/features/circle/services/quick_status_service.dart 

import 'dart:async';
import 'dart:developer';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart'; // <--- CAMBIO 1: Importamos Material para la UI
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
// --- CAMBIO 2: Importamos nuestra nueva página de selección de estado ---
import 'package:zync_app/features/circle/presentation/pages/quick_status_selector_page.dart';
// import 'package:zync_app/firebase_options.dart';

// =======================================================================
// ESTA PARTE (QuickStatusTaskHandler) NO SE MODIFICA.
// Maneja la lógica de fondo de las notificaciones y está correcta.
// =======================================================================
class QuickStatusTaskHandler extends TaskHandler {
  String? _userId;
  String? _circleId;
  SendUserStatus? _sendUserStatus;

  @override
Future<void> onStart(DateTime timestamp, TaskStarter? starter) async {
  try {
    // if (Firebase.apps.isEmpty) {
    //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // }
    await di.init();
    _sendUserStatus = di.sl<SendUserStatus>();
    log('[QuickStatusTaskHandler] Service started.');
  } catch (e) {
    log('[QuickStatusTaskHandler] Initialization error: $e');
  }
}

  @override
  void onReceiveData(dynamic data) {
    if (data is Map<String, dynamic>) {
      final action = data['action'] as String?;
      log('[QuickStatusTaskHandler] Received event: $action');

      if (action == 'update_data') {
        _userId = data['userId'] as String?;
        _circleId = data['circleId'] as String?;
        log('[QuickStatusTaskHandler] Updated data: userId=$_userId, circleId=$_circleId');
        return;
      }
      if (action != null && action.startsWith('STATUS_')) {
        _handleStatusAction(action);
      }
    }
  }

  Future<void> _handleStatusAction(String action) async {
    if (_userId == null || _circleId == null || _sendUserStatus == null) {
      log('[QuickStatusTaskHandler] ERROR: Dependencies not ready.');
      return;
    }
    final statusType = _getStatusTypeFromString(action);
    if (statusType == null) return;

    try {
      final result = await _sendUserStatus!(SendUserStatusParams(
        circleId: _circleId!,
        statusType: statusType,
      ));
      result.fold(
        (failure) => log('[QuickStatusTaskHandler] ERROR sending status: $failure'),
        (_) => log('[QuickStatusTaskHandler] SUCCESS: Sent status $statusType'),
      );
    } catch (e) {
      log('[QuickStatusTaskHandler] CRITICAL ERROR: $e');
    }
  }

  StatusType? _getStatusTypeFromString(String action) {
    switch (action) {
      case 'STATUS_FINE':
        return StatusType.fine;
      case 'STATUS_SOS':
        return StatusType.sos;
      case 'STATUS_MEETING':
        return StatusType.meeting;
      case 'STATUS_READY':
        return StatusType.ready;
      case 'STATUS_LEAVE':
        return StatusType.leave;
      default:
        return null;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool? isTimeout) async {
    log('[QuickStatusTaskHandler] Service destroyed.');
  }
  
  @override
  void onRepeatEvent(DateTime timestamp) {}
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(QuickStatusTaskHandler());
}

// =======================================================================
// ESTA PARTE (QuickStatusService) ES LA QUE ACTUALIZAMOS
// =======================================================================
class QuickStatusService {
  QuickStatusService._();
  static const _channel = MethodChannel('zync/notification');

  // --- CAMBIO 3: AÑADIMOS UN NUEVO MÉTODO ESTÁTICO PARA MOSTRAR LA UI ---
  // Este método se llamará desde la HomePage para mostrar nuestro panel deslizable.
  static void showSelectorUI(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Fundamental para la transparencia
        pageBuilder: (context, animation, secondaryAnimation) => const QuickStatusSelectorPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Animación de fundido para una aparición suave
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // --- El resto de los métodos para el servicio de fondo se mantienen intactos ---

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zync_quick_status_channel',
        channelName: 'Zync Quick Actions',
        channelDescription: 'Servicio de Zync para acciones rápidas.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false, // Solo desactivar en iOS
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3600000), // 1 hora en ms
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> startService({required String userId, required String circleId}) async {
    _registerMethodCallHandler();

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Zync Activo',
        notificationText: 'Toca para abrir Zync y enviar estado rápido',
        callback: startCallback,
      );
      log('[QuickStatusService] Servicio iniciado - SOLO UNA notificación');
      // NO llamar updateNotificationWithActions() - FlutterForegroundTask ya crea la notificación
    }

    // Enviar datos al TaskHandler
    FlutterForegroundTask.sendDataToTask({
      'action': 'update_data',
      'userId': userId,
      'circleId': circleId,
    });

    try {
      await _channel.invokeMethod('showCustomNotification');
    } on PlatformException catch (e) {
      log("Failed to show custom notification: '${e.message}'.");
    }
  }

  static void _registerMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction') {
        final String? action = call.arguments as String?;
        if (action != null) {
          log('[QuickStatusService] Received onQuickAction from native. Forwarding...');
          FlutterForegroundTask.sendDataToTask({'action': action});
        }
      }
    });
  }

  static Future<void> stopService() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      try {
        await _channel.invokeMethod('hideCustomNotification');
      } on PlatformException catch (e) {
        log("Failed to hide custom notification: '${e.message}'.");
      }
      await FlutterForegroundTask.stopService();
    }
  }

  // Método para agregar botones de acción a la notificación (si es compatible)
  static Future<void> updateNotificationWithActions() async {
    try {
      await _channel.invokeMethod('updateNotificationWithActions', {
        'actions': [] // Sin acciones, solo modal
      });
    } on PlatformException catch (e) {
      log("Failed to update notification with actions: '${e.message}'.");
    }
  }
}



