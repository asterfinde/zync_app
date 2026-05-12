/// Eventos emitidos por el lado nativo hacia Flutter vía [NativeBridge.events].
sealed class NativeEvent {
  const NativeEvent();
}

/// El usuario seleccionó un estado desde la notificación persistente en barra.
class StatusUpdatedFromNotification extends NativeEvent {
  final String statusId;
  const StatusUpdatedFromNotification(this.statusId);
}

/// El usuario desactivó el Modo Silencio desde el tile de notificación nativa.
class SilentDeactivatedByUser extends NativeEvent {
  const SilentDeactivatedByUser();
}

/// El dispositivo cruzó hacia el interior de una zona configurada.
class GeofenceEntered extends NativeEvent {
  final String zoneId;
  const GeofenceEntered(this.zoneId);
}

/// El dispositivo salió de una zona configurada.
class GeofenceExited extends NativeEvent {
  final String zoneId;
  const GeofenceExited(this.zoneId);
}

/// El lado nativo recibió confirmación de cierre de sesión.
class SessionCleared extends NativeEvent {
  const SessionCleared();
}
