import 'package:geolocator/geolocator.dart';
import 'package:zync_app/core/models/user_status.dart';
import 'dart:developer';

/// Servicio para manejo de GPS y ubicación
/// Point 16: Obtener ubicación GPS cuando se envía estado SOS
class GPSService {
  
  /// Obtener la ubicación actual del usuario
  /// Solicita permisos si es necesario
  static Future<Coordinates?> getCurrentLocation() async {
    try {
      log('[GPSService] Iniciando obtención de ubicación...');
      
      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('[GPSService] ❌ Servicios de ubicación deshabilitados');
        return null;
      }
      
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          log('[GPSService] ❌ Permisos de ubicación denegados');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        log('[GPSService] ❌ Permisos de ubicación denegados permanentemente');
        return null;
      }
      
      // Obtener ubicación con configuración optimizada para SOS (API actualizada)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // Timeout para emergencias
        ),
      );
      
      final coordinates = Coordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      log('[GPSService] ✅ Ubicación obtenida: ${coordinates.latitude}, ${coordinates.longitude}');
      return coordinates;
      
    } catch (e) {
      log('[GPSService] ❌ Error obteniendo ubicación: $e');
      return null;
    }
  }
  
  /// Verificar si la aplicación tiene permisos de ubicación
  static Future<bool> hasLocationPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      log('[GPSService] Error verificando permisos: $e');
      return false;
    }
  }
  
  /// Abrir configuración de la aplicación para permisos
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      log('[GPSService] Error abriendo configuración: $e');
    }
  }
  
  /// Generar URL de Google Maps para las coordenadas
  static String generateGoogleMapsUrl(Coordinates coordinates) {
    return 'https://maps.google.com/?q=${coordinates.latitude},${coordinates.longitude}';
  }
  
  /// Generar enlace con etiqueta personalizada para SOS
  /// Point 16 FIX: URL más compatible con múltiples apps de mapas
  static String generateSOSLocationUrl(Coordinates coordinates, String userName) {
    return 'geo:${coordinates.latitude},${coordinates.longitude}?q=${coordinates.latitude},${coordinates.longitude}(SOS%20-%20$userName)';
  }
  
  /// URLs de fallback para diferentes apps de mapas
  /// Point 16 FIX: URLs más compatibles para Android
  static List<String> generateFallbackMapUrls(Coordinates coordinates, String userName) {
    final lat = coordinates.latitude.toStringAsFixed(6);
    final lng = coordinates.longitude.toStringAsFixed(6);
    
    return [
      // Google Maps app directo (más confiable)
      'google.navigation:q=$lat,$lng',
      // Formato geo: con zoom
      'geo:$lat,$lng?z=16',
      // Google Maps web
      'https://maps.google.com/?q=$lat,$lng',
      // Waze (si está instalado)
      'waze://?ll=$lat,$lng&navigate=yes',
      // Maps genérico de Android
      'geo:0,0?q=$lat,$lng(SOS - $userName)',
    ];
  }
}