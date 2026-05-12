import 'dart:async';
import 'package:nunakin_app/platform/bridge/native_bridge.dart';
import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

/// Implementación Android de [NativeBridge].
///
/// Día 1: stub que compila. Días 2-5: handlers reales migrados desde los
/// 7 MethodChannels individuales de MainActivity.kt.
class AndroidNativeBridge implements NativeBridge {
  final _eventController = StreamController<NativeEvent>.broadcast();

  @override
  Stream<NativeEvent> get events => _eventController.stream;

  @override
  Future<T> invoke<T>(NativeCommand<T> cmd) {
    // TODO(sem3-día2): implementar por tipo de comando via nunakin/bridge
    throw UnimplementedError('AndroidNativeBridge.invoke: $cmd');
  }

  void dispose() => _eventController.close();
}
