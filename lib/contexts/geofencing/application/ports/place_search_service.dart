/// Puerto de búsqueda de lugares (POIs, negocios, acrónimos, direcciones).
///
/// Reemplaza al geocoder nativo del dispositivo (`geocoding` package), que solo
/// resuelve direcciones y no indexa POIs ni acrónimos (UNALM, óvalos). La
/// implementación usa el Places SDK nativo, que sí los encuentra.
///
/// Tipos en `double` puro (no `LatLng`) para no acoplar el dominio ni a
/// `google_maps_flutter` ni al `LatLng` propio del plugin.
abstract class PlaceSearchService {
  /// Predicciones de autocompletado para [query], restringidas a un cuadro
  /// de ~[radiusMeters] alrededor de ([lat], [lng]). Ordenadas por el ranking
  /// de Google (relevancia + proximidad). Lista vacía si no hay coincidencias.
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required double lat,
    required double lng,
    double radiusMeters,
  });

  /// Resuelve una predicción a coordenadas. `null` si el lugar no tiene
  /// ubicación disponible.
  Future<PlaceLocation?> resolve(String placeId);
}

/// Una sugerencia de lugar devuelta por el autocompletado.
class PlacePrediction {
  /// Id opaco del lugar, requerido por [PlaceSearchService.resolve].
  final String placeId;

  /// Texto principal (nombre del lugar). Ej: "Universidad Nacional Agraria".
  final String primaryText;

  /// Texto secundario (contexto/dirección). Ej: "La Molina, Lima".
  /// Es el desambiguador de homónimos: misma calle, distinto distrito. La
  /// distancia no se expone: Places API (New) devuelve `distanceMeters = 0`
  /// aunque se pase `origin` (no honra el sesgo de proximidad en autocomplete).
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });
}

/// Coordenadas resueltas de un lugar.
class PlaceLocation {
  final double latitude;
  final double longitude;

  const PlaceLocation(this.latitude, this.longitude);
}

/// Error de conectividad transitoria al buscar lugares (DNS/red/timeout, típico
/// tras Doze). El servicio ya reintentó una vez sin éxito. El caller debe
/// mostrar un mensaje amigable y no técnico, no tratarlo como error fatal.
class PlaceSearchNetworkException implements Exception {
  const PlaceSearchNetworkException();
}
