import 'package:nunakin_app/platform/bridge/native_command.dart';
import 'package:nunakin_app/platform/bridge/native_event.dart';

/// Contrato del canal nativo unificado.
///
/// Reemplaza los 7 MethodChannels individuales por un único punto de entrada
/// tipado. La implementación concreta ([AndroidNativeBridge]) vive en
/// infrastructure y es la única clase autorizada a mencionar [MethodChannel].
abstract class NativeBridge {
  /// Stream de eventos emitidos por el lado nativo (Kotlin → Flutter).
  Stream<NativeEvent> get events;

  /// Envía un comando al lado nativo y espera su resultado.
  ///
  /// [T] es el tipo de retorno declarado por [NativeCommand<T>].
  Future<T> invoke<T>(NativeCommand<T> cmd);
}
