// lib/features/circle/services/quick_status_service.dart

// C:/projects/zync_app/lib/features/circle/services/quick_status_service.dart
import 'dart:async';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'package:zync_app/firebase_options.dart';

/// Lógica que se ejecuta en el Isolate de segundo plano.
class QuickStatusTaskHandler extends TaskHandler {
  String? _userId;
  String? _circleId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter? starter) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await di.init();
    log('[QuickStatusTaskHandler] Service started. Firebase and DI initialized.');
  }
  
  @override
  void onRepeatEvent(DateTime timestamp) {
    // No necesitamos tareas repetitivas.
  }

    Future<void> onReceiveTaskData(dynamic data) async {
    log('[QuickStatusTaskHandler] Received data: $data');
    if (data is Map<String, dynamic>) {
      final action = data['action'] as String?;
      if (action != null && action.startsWith('STATUS_')) {
        _handleStatusAction(action);
      } else if (action == 'update_data') {
        _userId = data['userId'] as String?;
        _circleId = data['circleId'] as String?;
        log('[QuickStatusTaskHandler] Updated data: userId=$_userId, circleId=$_circleId');
      }
    }
  }

  void _handleStatusAction(String action) {
    if (_userId == null || _circleId == null) {
      log('[QuickStatusTaskHandler] Error: userId or circleId is null. Cannot send status.');
      return;
    }

    StatusType? statusType;
    switch (action) {
      case 'STATUS_FINE':
        statusType = StatusType.fine;
        break;
      case 'STATUS_WORRIED':
        statusType = StatusType.worried;
        break;
      case 'STATUS_LOCATION':
        statusType = StatusType.location;
        break;
      case 'STATUS_SOS':
        statusType = StatusType.sos;
        break;
      case 'STATUS_THINKING':
        statusType = StatusType.thinking;
        break;
    }

    if (statusType != null) {
      log('[QuickStatusTaskHandler] SUCCESS: Sending status: $statusType for circle $_circleId');
      final sendUserStatus = di.sl<SendUserStatus>();
      sendUserStatus(SendUserStatusParams(
        circleId: _circleId!,
        statusType: statusType,
      ));
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool? isTimeout) async {
    log('[QuickStatusTaskHandler] Service destroyed.');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}

/// Punto de entrada para el isolate.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(QuickStatusTaskHandler());
}

/// Clase fachada para gestionar el servicio.
class QuickStatusService {
  QuickStatusService._();

  static const _channel = MethodChannel('zync/notification');

  /// Inicializa el servicio y el listener del MethodChannel.
  static void initializeService() {
    // CORRECCIÓN: Se añade el listener para los eventos del código nativo.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction') {
        final String? action = call.arguments as String?;
        if (action != null) {
          log('[QuickStatusService] Received onQuickAction from native: $action. Forwarding to TaskHandler...');
          // Reenviamos la acción al Isolate de segundo plano.
          FlutterForegroundTask.sendDataToTask({'action': action});
        }
      }
    });

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zync_quick_status_channel',
        channelName: 'Zync Quick Actions',
        channelDescription: 'Servicio de Zync para acciones rápidas.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(3600000),
      ),
    );
  }

  /// Inicia el servicio y le pide al código nativo que muestre la notificación personalizada.
  static Future<void> startService({
    required String userId,
    required String circleId,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Zync Activo',
        notificationText: 'Servicio de acciones rápidas iniciado.',
        callback: startCallback,
      );
    }
    
    FlutterForegroundTask.sendDataToTask({
      'action': 'update_data',
      'userId': userId,
      'circleId': circleId,
    });

    try {
      await _channel.invokeMethod('showCustomNotification');
      log('[QuickStatusService] Invoked showCustomNotification.');
    } on PlatformException catch (e) {
      log("Failed to show custom notification: '${e.message}'.");
    }
  }

  /// Detiene el servicio y le pide al código nativo que oculte la notificación.
  static Future<void> stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      try {
        await _channel.invokeMethod('hideCustomNotification');
        log('[QuickStatusService] Invoked hideCustomNotification.');
      } on PlatformException catch (e) {
        log("Failed to hide custom notification: '${e.message}'.");
      }
      await FlutterForegroundTask.stopService();
    }
  }
}




// import 'dart:async';
// import 'dart:developer';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/services.dart'; 
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:zync_app/core/di/injection_container.dart' as di;
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';
// import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
// import 'package:zync_app/firebase_options.dart';

// /// Lógica que se ejecuta en el Isolate de segundo plano.
// class QuickStatusTaskHandler extends TaskHandler {
//   String? _userId;
//   String? _circleId;

//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter? starter) async {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//     await di.init();
//     log('[QuickStatusTaskHandler] Service started. Firebase and DI initialized.');
//   }
  
//   @override
//   void onRepeatEvent(DateTime timestamp) {
//     // No necesitamos tareas repetitivas.
//   }

//   // Este método NO es un override, la data se recibe al escuchar el stream.
//   // Sin embargo, la librería lo invoca internamente.
//   Future<void> onReceiveTaskData(dynamic data) async {
//     log('[QuickStatusTaskHandler] Received data: $data');
//     if (data is Map<String, dynamic>) {
//       final action = data['action'] as String?;
//       if (action != null && action.startsWith('STATUS_')) {
//         _handleStatusAction(action);
//       } else if (action == 'update_data') {
//         _userId = data['userId'] as String?;
//         _circleId = data['circleId'] as String?;
//         log('[QuickStatusTaskHandler] Updated data: userId=$_userId, circleId=$_circleId');
//       }
//     }
//   }

//   void _handleStatusAction(String action) {
//     if (_userId == null || _circleId == null) {
//       log('[QuickStatusTaskHandler] Error: userId or circleId is null. Cannot send status.');
//       return;
//     }

//     StatusType? statusType;
//     switch (action) {
//       case 'STATUS_FINE':
//         statusType = StatusType.fine;
//         break;
//       case 'STATUS_WORRIED':
//         statusType = StatusType.worried;
//         break;
//       case 'STATUS_LOCATION':
//         statusType = StatusType.location;
//         break;
//       case 'STATUS_SOS':
//         statusType = StatusType.sos;
//         break;
//       case 'STATUS_THINKING':
//         statusType = StatusType.thinking;
//         break;
//     }

//     if (statusType != null) {
//       log('[QuickStatusTaskHandler] Sending status: $statusType for circle $_circleId');
//       final sendUserStatus = di.sl<SendUserStatus>();
//       sendUserStatus(SendUserStatusParams(
//         circleId: _circleId!,
//         statusType: statusType,
//       ));
//     }
//   }

//   @override
//   Future<void> onDestroy(DateTime timestamp, bool? isTimeout) async {
//     log('[QuickStatusTaskHandler] Service destroyed.');
//   }

//   @override
//   void onNotificationPressed() {
//     FlutterForegroundTask.launchApp();
//   }
// }

// /// Punto de entrada para el isolate.
// @pragma('vm:entry-point')
// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(QuickStatusTaskHandler());
// }

// /// Clase fachada para gestionar el servicio.
// class QuickStatusService {
//   QuickStatusService._();

//   static const _channel = MethodChannel('zync/notification');

//   /// Inicializa el servicio en segundo plano.
//   static void initializeService() {
//     FlutterForegroundTask.init(
//       androidNotificationOptions: AndroidNotificationOptions(
//         channelId: 'zync_quick_status_channel',
//         channelName: 'Zync Quick Actions',
//         channelDescription: 'Servicio de Zync para acciones rápidas.',
//         channelImportance: NotificationChannelImportance.LOW,
//         priority: NotificationPriority.LOW,
//       ),
//       iosNotificationOptions: const IOSNotificationOptions(
//         showNotification: true,
//         playSound: false,
//       ),
//       // CORRECCIÓN DEFINITIVA: Se usa `eventAction` en lugar de `interval`.
//       foregroundTaskOptions: ForegroundTaskOptions(
//         autoRunOnBoot: true,
//         allowWakeLock: true,
//         allowWifiLock: true,
//         // CORRECCIÓN: El método repeat espera un argumento entero (milisegundos).
//         eventAction: ForegroundTaskEventAction.repeat(3600000),
//       ),
//     );
//   }

//   /// Inicia el servicio y le pide al código nativo que muestre la notificación personalizada.
//   static Future<void> startService({
//     required String userId,
//     required String circleId,
//   }) async {
//     // CORRECCIÓN: El getter receiveDataFromTask no existe en la API actual.
//     // Si necesitas recibir datos, usa FlutterForegroundTask.getData o sendDataToTask.
//     // Elimina el stream y solo envía los datos al task handler.
//     if (!await FlutterForegroundTask.isRunningService) {
//       await FlutterForegroundTask.startService(
//         notificationTitle: 'Zync Activo',
//         notificationText: 'Servicio de acciones rápidas iniciado.',
//         callback: startCallback,
//       );
//     }
    
//     FlutterForegroundTask.sendDataToTask({
//       'action': 'update_data',
//       'userId': userId,
//       'circleId': circleId,
//     });

//     try {
//       await _channel.invokeMethod('showCustomNotification');
//       log('[QuickStatusService] Invoked showCustomNotification.');
//     } on PlatformException catch (e) {
//       log("Failed to show custom notification: '${e.message}'.");
//     }
//   }

//   /// Detiene el servicio y le pide al código nativo que oculte la notificación.
//   static Future<void> stopService() async {
//     if (await FlutterForegroundTask.isRunningService) {
//       try {
//         await _channel.invokeMethod('hideCustomNotification');
//         log('[QuickStatusService] Invoked hideCustomNotification.');
//       } on PlatformException catch (e) {
//         log("Failed to hide custom notification: '${e.message}'.");
//       }
//       await FlutterForegroundTask.stopService();
//     }
//   }
// }

