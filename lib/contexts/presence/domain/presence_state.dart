import 'package:nunakin_app/contexts/presence/domain/value_objects/status_id.dart';

/// Estado canónico de presencia del usuario.
///
/// Un único valor de este tipo reemplaza las 5 claves de SharedPreferences que
/// hoy dispersan el estado: current_status_id, manual_status_id,
/// pre_silent_status_id, is_silent_mode_active, suppress_next_geofence_check.
sealed class PresenceState {
  const PresenceState();

  /// ID del estado visible a los miembros del círculo en este momento.
  String get visibleStatusId;

  bool get isSilent => this is SilentMode;
  bool get isSOS    => this is SOSActive;
}

/// Estado normal: el usuario está disponible e interactuando.
/// [currentId]     — estado que se muestra al círculo (puede ser auto-actualizado
///                   por geofencing o por selección manual).
/// [lastManualId]  — último estado elegido por el usuario. Necesario para
///                   restaurarlo al salir del Modo Silencio y para el testigo
///                   del modal de selección. Null si el usuario nunca eligió uno.
final class Normal extends PresenceState {
  final String  currentId;
  final String? lastManualId;
  const Normal({required this.currentId, this.lastManualId});

  @override
  String get visibleStatusId => currentId;

  Normal copyWith({String? currentId, String? lastManualId}) => Normal(
        currentId:    currentId    ?? this.currentId,
        lastManualId: lastManualId ?? this.lastManualId,
      );
}

/// El usuario activó Modo Silencio. La app está en background.
/// [preSilentId] — estado que tenía justo antes de activar Silent Mode.
///                 El círculo ve este estado mientras dura el silencio.
/// [enteredAt]   — timestamp para detectar silencio prolongado (> N horas)
///                 en futuros checks automáticos.
final class SilentMode extends PresenceState {
  final String   preSilentId;
  final DateTime enteredAt;
  const SilentMode({required this.preSilentId, required this.enteredAt});

  @override
  String get visibleStatusId => preSilentId;
}

/// Una notificación desde la barra de estado activó un nuevo estado.
/// [notifStatusId]   — estado enviado desde la notificación.
/// [manualBeneathId] — estado manual que el usuario tenía antes de la notificación;
///                     se restaura al descartar la notificación.
final class BackgroundNotificationActive extends PresenceState {
  final String  notifStatusId;
  final String? manualBeneathId;
  const BackgroundNotificationActive({
    required this.notifStatusId,
    this.manualBeneathId,
  });

  @override
  String get visibleStatusId => manualBeneathId ?? notifStatusId;
}

/// El usuario activó SOS.
/// [previousId]  — estado que tenía antes del SOS (para restaurar post-resolución).
/// [latitude], [longitude] — coordenadas GPS capturadas al activar.
final class SOSActive extends PresenceState {
  final String previousId;
  final double latitude;
  final double longitude;
  const SOSActive({
    required this.previousId,
    required this.latitude,
    required this.longitude,
  });

  @override
  String get visibleStatusId => StatusIds.sos;
}
