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

/// Registra una zona geográfica circular en el handler nativo.
///
/// El handler la almacena en memoria para que el futuro
/// `GeofencingBroadcastReceiver` (Sem 4) la consulte al recibir transiciones
/// del OS Android.
class RegisterZone extends NativeCommand<void> {
  final String zoneId;
  final double lat;
  final double lng;
  final double radiusMeters;
  const RegisterZone({
    required this.zoneId,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });
}

/// Elimina el registro de una zona geográfica.
class UnregisterZone extends NativeCommand<void> {
  final String zoneId;
  const UnregisterZone({required this.zoneId});
}

/// Actualiza el badge count del ícono de la aplicación.
///
/// El handler nativo persiste el valor en SharedPrefs para que la
/// notificación persistente pueda reflejarlo via `setNumber(count)`.
class SetBadgeCount extends NativeCommand<void> {
  final int count;
  const SetBadgeCount(this.count);
}
