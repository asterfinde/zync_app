/// Reglas de validación de zonas geográficas (REGLAS_NEGOCIO.md §7-§9).
///
/// Antes vivían como `static const` en `ZoneService`. Se centralizan aquí
/// para que los use cases (validación) y la UI (slider, contador) compartan
/// la misma fuente.
abstract final class ZoneConstraints {
  /// Máximo de zonas por círculo.
  static const int maxZonesPerCircle = 10;

  /// Radio mínimo de detección, en metros.
  static const double minRadiusMeters = 50.0;

  /// Radio máximo de detección, en metros.
  static const double maxRadiusMeters = 500.0;

  ZoneConstraints._();
}
