import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nunakin_app/platform/bridge/native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

/// Implementación Android de [NativeBridge].
///
/// Día 1: stub que compila.
/// Día 2: handlers para `ActivateSilentMode` / `DeactivateSilentMode` vía
///        canal `nunakin/bridge` (registrado en `MainActivity.setupBridgeRouter`).
/// Días 3-5: handlers restantes (status, sos, location, session, geofencing, badge).
class AndroidNativeBridge implements NativeBridge {
  @visibleForTesting
  static const channelName = 'nunakin/bridge';

  final MethodChannel _channel;
  final _eventController = StreamController<NativeEvent>.broadcast();

  AndroidNativeBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  @override
  Stream<NativeEvent> get events => _eventController.stream;

  @visibleForTesting
  static const legacyChannelName = 'zync/keep_alive';

  @override
  Future<T> invoke<T>(NativeCommand<T> cmd) async {
    switch (cmd) {
      case ActivateSilentMode():
        await _channel
            .invokeMethod<void>('activateSilentMode')
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => const MethodChannel(legacyChannelName)
                  .invokeMethod<void>('activate'),
            );
        return null as T;
      case DeactivateSilentMode():
        await _channel
            .invokeMethod<void>('deactivateSilentMode')
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => const MethodChannel(legacyChannelName)
                  .invokeMethod<void>('deactivate'),
            );
        return null as T;
      // TODO(sem3-día3+): GetCurrentLocation, SetUserSession, ClearSession
      default:
        throw UnimplementedError('AndroidNativeBridge.invoke: $cmd');
    }
  }

  void dispose() => _eventController.close();
}
