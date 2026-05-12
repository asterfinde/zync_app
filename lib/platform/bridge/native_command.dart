/// Comandos enviados desde Flutter al lado nativo vía [NativeBridge.invoke].
///
/// Cada subclase declara el tipo de retorno en [T].
sealed class NativeCommand<T> {
  const NativeCommand();
}

/// Activa el Modo Silencio (tile de notificación + prefs nativos).
class ActivateSilentMode extends NativeCommand<void> {
  const ActivateSilentMode();
}

/// Desactiva el Modo Silencio y restaura el estado previo.
class DeactivateSilentMode extends NativeCommand<void> {
  const DeactivateSilentMode();
}

/// Solicita las coordenadas GPS actuales del dispositivo.
class GetCurrentLocation extends NativeCommand<({double lat, double lng})> {
  const GetCurrentLocation();
}

/// Persiste el UID y email del usuario autenticado en el lado nativo.
///
/// Necesario para que [StatusUpdateWorker] y [GeofencingService] Kotlin
/// operen en background sin acceso al estado Dart.
class SetUserSession extends NativeCommand<void> {
  final String uid;
  final String email;
  const SetUserSession({required this.uid, required this.email});
}

/// Borra la sesión persistida en el lado nativo (logout).
class ClearSession extends NativeCommand<void> {
  const ClearSession();
}
