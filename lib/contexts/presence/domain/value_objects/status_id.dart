/// IDs canónicos de estado de presencia.
///
/// Fuente única de verdad para Dart. Mirror en StatusIds.kt.
/// Los IDs deben coincidir exactamente con los valores en Firestore.
abstract final class StatusIds {
  static const fine            = 'fine';
  static const home            = 'home';
  static const school          = 'school';
  static const work            = 'work';
  static const university      = 'university';
  static const sos             = 'sos';
  static const doNotDisturb    = 'do_not_disturb';
  static const publicTransport = 'public_transport';

  /// Estados que no pueden seleccionarse manualmente cuando hay
  /// una zona de ese tipo configurada en el círculo.
  static const Set<String> blockedManualSelectionIfZoneConfigured = {
    home, school, work, university,
  };

  StatusIds._();
}
