import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;

import 'package:nunakin_app/contexts/geofencing/application/ports/place_search_service.dart';

/// Implementación de [PlaceSearchService] sobre el Places SDK nativo
/// (`flutter_google_places_sdk`).
///
/// Usa la key Android-restringida (package + SHA-1) ya configurada para Maps:
/// el SDK nativo es el único modo donde esa restricción protege la key
/// (las requests HTTP no se pueden atar a la firma del APK). La key se obtiene
/// del lado nativo vía [MethodChannel] — nunca vive en código Dart ni en git.
class PlacesSdkSearchService implements PlaceSearchService {
  /// Canal que expone `BuildConfig.MAPS_API_KEY` (inyectada desde
  /// `local.properties` en build.gradle.kts). Definido en `MainActivity.kt`.
  static const _configChannel = MethodChannel('nunakin/config');

  /// Locale para biasear etiquetas de resultado hacia español de Perú.
  static const _locale = Locale('es', 'PE');

  /// País al que se restringe el autocompletado.
  static const _country = 'pe';

  places.FlutterGooglePlacesSdk? _client;

  /// Inicializa el cliente del SDK una sola vez, leyendo la key del canal
  /// nativo. Lanza [StateError] si la key no está disponible (build sin
  /// `GOOGLE_MAPS_API_KEY` en `local.properties`).
  Future<places.FlutterGooglePlacesSdk> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;

    final apiKey =
        await _configChannel.invokeMethod<String>('getMapsApiKey');
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      throw StateError(
        'Maps API key no disponible — revisa GOOGLE_MAPS_API_KEY en local.properties',
      );
    }

    // useNewApi: true → usa Places API (New), la habilitada/restringida en GCP.
    final client = places.FlutterGooglePlacesSdk(
      apiKey,
      locale: _locale,
      useNewApi: true,
    );
    _client = client;
    return client;
  }

  @override
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required double lat,
    required double lng,
    double radiusMeters = 50 * 1000.0,
  }) async {
    final client = await _ensureClient();

    final response = await _withRetry(() => client.findAutocompletePredictions(
          query,
          countries: const [_country],
          // Sesión fresca por búsqueda: evita reusar un session token ya
          // consumido por el fetchPlace previo o expirado tras inactividad
          // (~3 min TTL), que la New API rechaza con API_ERROR_AUTOCOMPLETE. El
          // fetchPlace de la selección reutiliza este token y cierra la sesión.
          newSessionToken: true,
          origin: places.LatLng(lat: lat, lng: lng),
          locationRestriction: _boundsAround(lat, lng, radiusMeters),
        ));

    return response.predictions
        .map((p) => PlacePrediction(
              placeId: p.placeId,
              primaryText: p.primaryText,
              secondaryText: p.secondaryText,
            ))
        .toList();
  }

  @override
  Future<PlaceLocation?> resolve(String placeId) async {
    final client = await _ensureClient();

    final response = await _withRetry(() => client.fetchPlace(
          placeId,
          fields: const [places.PlaceField.Location],
        ));

    final latLng = response.place?.latLng;
    if (latLng == null) {
      developer.log('fetchPlace sin coordenadas para $placeId',
          name: 'PlacesSearch');
      return null;
    }
    return PlaceLocation(latLng.lat, latLng.lng);
  }

  /// Ejecuta [op] y, si falla con un error de red transitorio (típico tras
  /// Doze: la radio despierta y el primer request falla DNS), reintenta UNA vez
  /// tras una breve espera. Best-effort idempotente — autocomplete y fetchPlace
  /// son lecturas, sin acción irreversible (§protocolo caminos negativos).
  /// Si el reintento también falla por red, lanza [PlaceSearchNetworkException]
  /// para que el caller muestre un mensaje amigable.
  Future<T> _withRetry<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PlatformException catch (e) {
      if (!_isTransientNetworkError(e)) rethrow;
      developer.log('Reintentando tras error de red transitorio: ${e.message}',
          name: 'PlacesSearch');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        return await op();
      } on PlatformException catch (e2) {
        if (_isTransientNetworkError(e2)) {
          throw const PlaceSearchNetworkException();
        }
        rethrow;
      }
    }
  }

  /// `true` si el error es de conectividad transitoria (DNS/red/timeout), no de
  /// autorización ni de la request.
  static bool _isTransientNetworkError(PlatformException e) {
    final m = (e.message ?? '').toLowerCase();
    return m.contains('unable to resolve host') ||
        m.contains('network') ||
        m.contains('timeout') ||
        m.startsWith('7:');
  }

  /// Cuadro delimitador aproximado de lado 2·[radiusMeters] centrado en
  /// ([lat], [lng]). El SDK acepta `LatLngBounds` (rectángulo), no un círculo;
  /// el filtro circular fino de 50 km se aplica luego en el caller (§10).
  places.LatLngBounds _boundsAround(double lat, double lng, double radiusM) {
    const metersPerDegLat = 111320.0;
    final latDelta = radiusM / metersPerDegLat;
    final lngDelta =
        radiusM / (metersPerDegLat * math.cos(lat * math.pi / 180.0).abs());
    return places.LatLngBounds(
      southwest: places.LatLng(lat: lat - latDelta, lng: lng - lngDelta),
      northeast: places.LatLng(lat: lat + latDelta, lng: lng + lngDelta),
    );
  }
}
