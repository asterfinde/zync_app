// lib/features/circle/services/quick_status_service.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:zync_app/core/di/injection_container.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'package:zync_app/firebase_options.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(QuickStatusTaskHandler());
}

class QuickStatusTaskHandler extends TaskHandler {
  final _sendUserStatusCompleter = Completer<SendUserStatus>();
  final _circleIdCompleter = Completer<String>();
  final _uidCompleter = Completer<String>();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    log('[QuickStatusTaskHandler] Iniciando servicio en segundo plano...');
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await init();

    if (!_sendUserStatusCompleter.isCompleted) {
      _sendUserStatusCompleter.complete(sl<SendUserStatus>());
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !_uidCompleter.isCompleted) {
      log('[QuickStatusTaskHandler] uid en background: ${currentUser.uid}');
      _uidCompleter.complete(currentUser.uid);
    } else {
      log('[QuickStatusTaskHandler] Advertencia: FirebaseAuth.currentUser es null en background isolate.');
    }

    log('[QuickStatusTaskHandler] Servicio y dependencias inicializados correctamente.');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    log('[QuickStatusTaskHandler] Servicio destruido.');
  }

  @override
  void onReceiveData(Object data) {
    if (data is String) {
      log('[QuickStatusTaskHandler] Recibido circleId: $data');
      if (!_circleIdCompleter.isCompleted) {
        _circleIdCompleter.complete(data);
      }
    } else if (data is Map) {
      final circleId = data['circleId'] as String?;
      final uid = data['uid'] as String?;
      if (circleId != null && !_circleIdCompleter.isCompleted) {
        log('[QuickStatusTaskHandler] Recibido circleId (map): $circleId');
        _circleIdCompleter.complete(circleId);
      }
      if (uid != null && !_uidCompleter.isCompleted) {
        log('[QuickStatusTaskHandler] Recibido uid (map): $uid');
        _uidCompleter.complete(uid);
      }
    }
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    log('[QuickStatusTaskHandler] Botón presionado: $id');

    try {
      final sendUserStatus = await _sendUserStatusCompleter.future;
      final circleId = await _circleIdCompleter.future;

      String? uid;
      if (_uidCompleter.isCompleted) {
        uid = await _uidCompleter.future;
      } else {
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
      log('[QuickStatusTaskHandler] Contexto de envío -> circleId=$circleId, uid=${uid ?? 'desconocido'}');

      final statusType = StatusType.values.firstWhere(
        (e) => e.name == id,
        orElse: () => StatusType.fine,
      );

      log('[QuickStatusTaskHandler] Enviando estado: ${statusType.name}');
      final params = SendUserStatusParams(
        circleId: circleId,
        statusType: statusType,
      );

      final result = await sendUserStatus(params);
      result.fold(
        (failure) => log('[QuickStatusTaskHandler] Falló el envío de estado: ${failure.message}'),
        (_) => log('[QuickStatusTaskHandler] Envío de estado exitoso.'),
      );
    } catch (e, st) {
      log('[QuickStatusTaskHandler] Error al procesar el botón: $e');
      log('[QuickStatusTaskHandler] Stack: $st');
    }
  }
}

class QuickStatusManager {
  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zync_quick_status',
        channelName: 'Quick Status Actions',
        channelDescription: 'Notificación para enviar estados rápidamente a tu círculo.',
        onlyAlertOnce: true,
      ),
      // Quitar 'const' porque tu versión del paquete no usa constructores const
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> start(String circleId, {String? uid}) async {
    await _requestPermission();
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Zync Quick Access',
      notificationText: 'Toca un estado para enviarlo a tu círculo.',
      // Sin 'const' en NotificationButton
      notificationButtons: [
        NotificationButton(id: 'sos', text: '🆘'),
        NotificationButton(id: 'location', text: '📍'),
        NotificationButton(id: 'fine', text: '😊'),
        NotificationButton(id: 'worried', text: '😟'),
        NotificationButton(id: 'love', text: '❤️'),
      ],
      callback: startCallback,
    );
    if (uid != null && uid.isNotEmpty) {
      FlutterForegroundTask.sendDataToTask({'circleId': circleId, 'uid': uid});
    } else {
      FlutterForegroundTask.sendDataToTask(circleId);
    }
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> _requestPermission() async {
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }
}