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
        // ════════════════════════════════════════════════════════════
        // [FIX AUTH-20260513-002] Fallback correcto para NativeBridge en transición
        // Fecha: 2026-05-13
        // PROBLEMA: PR #164 usó .timeout() asumiendo que nunakin/bridge se colgaba.
        //   En realidad, sin handler registrado (USE_LEGACY_BRIDGE=true), Flutter
        //   lanza MissingPluginException inmediatamente — el onTimeout nunca se ejecuta.
        // SOLUCIÓN: try/catch(MissingPluginException) → fallback a zync/keep_alive.
        //   Cubre también el stub BridgeRouter (result.notImplemented → mismo exception).
        // ════════════════════════════════════════════════════════════
        try {
          await _channel.invokeMethod<void>('activateSilentMode');
        } on MissingPluginException {
          await const MethodChannel(legacyChannelName).invokeMethod<void>('activate');
        }
        return null as T;
      case DeactivateSilentMode():
        try {
          await _channel.invokeMethod<void>('deactivateSilentMode');
        } on MissingPluginException {
          await const MethodChannel(legacyChannelName).invokeMethod<void>('deactivate');
        }
        return null as T;
      // TODO(sem3-día3+): GetCurrentLocation, SetUserSession, ClearSession
      default:
        throw UnimplementedError('AndroidNativeBridge.invoke: $cmd');
    }
  }

  void dispose() => _eventController.close();
}
