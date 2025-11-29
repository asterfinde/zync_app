// ==============================================================================
// 🧪 MOCK DATA - Point 17 Testing
// ==============================================================================
// Datos mock estáticos para testing de lista de miembros
// Incluye usuario SOS con GPS para validar Point 16
// ==============================================================================

import '../core/models/user_status.dart';

class MockData {
  /// ID del usuario actual (para testing de updates)
  static const String currentUserId = 'mock_user_1';

  /// Obtener lista de miembros mock
  static List<Map<String, dynamic>> getMockMembers() {
    return [
      // Usuario 1: Current user (fine) - Para testing de updates
      {
        'userId': 'mock_user_1',
        'nickname': 'Tú (Current User)',
        'email': 'current@test.com',
        'name': 'Usuario Actual',
        'status': 'fine',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now(),
      },

      // Usuario 2: SOS + GPS - Para validar Point 16
      {
        'userId': 'mock_user_2',
        'nickname': 'Usuario SOS',
        'email': 'sos@test.com',
        'name': 'Usuario en Emergencia',
        'status': 'sos',
        'gpsLatitude': -12.0464, // Lima, Perú - Plaza de Armas
        'gpsLongitude': -77.0428,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 2)),
      },

      // Usuario 3: Busy
      {
        'userId': 'mock_user_3',
        'nickname': 'Carlos',
        'email': 'carlos@test.com',
        'name': 'Carlos Rodriguez',
        'status': 'busy',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 5)),
      },

      // Usuario 4: Happy
      {
        'userId': 'mock_user_4',
        'nickname': 'María',
        'email': 'maria@test.com',
        'name': 'María González',
        'status': 'happy',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 10)),
      },

      // Usuario 5: Meeting
      {
        'userId': 'mock_user_5',
        'nickname': 'Juan',
        'email': 'juan@test.com',
        'name': 'Juan Pérez',
        'status': 'meeting',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 15)),
      },

      // Usuario 6: Tired
      {
        'userId': 'mock_user_6',
        'nickname': 'Ana',
        'email': 'ana@test.com',
        'name': 'Ana López',
        'status': 'tired',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 20)),
      },

      // Usuario 7: Away
      {
        'userId': 'mock_user_7',
        'nickname': 'Pedro',
        'email': 'pedro@test.com',
        'name': 'Pedro Martínez',
        'status': 'away',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 25)),
      },

      // Usuario 8: Focus
      {
        'userId': 'mock_user_8',
        'nickname': 'Laura',
        'email': 'laura@test.com',
        'name': 'Laura Sánchez',
        'status': 'focus',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 30)),
      },

      // Usuario 9: Studying
      {
        'userId': 'mock_user_9',
        'nickname': 'Diego',
        'email': 'diego@test.com',
        'name': 'Diego Fernández',
        'status': 'studying',
        'gpsLatitude': null,
        'gpsLongitude': null,
        'lastUpdate': DateTime.now().subtract(Duration(minutes: 35)),
      },
    ];
  }

  /// Obtener emoji para un status específico
  static String getEmojiForStatus(String status) {
    try {
      final statusType = StatusType.fallbackPredefined.firstWhere(
        (e) => e.id == status,
        orElse: () => StatusType.fallbackPredefined.first,
      );
      return statusType.emoji;
    } catch (e) {
      return '❓'; // Fallback si status no encontrado
    }
  }

  /// Obtener nombre legible del status
  static String getStatusLabel(String status) {
    final labels = {
      'fine': 'Todo bien',
      'sos': 'EMERGENCIA SOS',
      'meeting': 'En reunión',
      'ready': 'Listo',
      'leave': 'Saliendo',
      'happy': 'Feliz',
      'sad': 'Triste',
      'busy': 'Ocupado',
      'sleepy': 'Con sueño',
      'excited': 'Emocionado',
      'thinking': 'Pensando',
      'worried': 'Preocupado',
      'available': 'Disponible',
      'away': 'Ausente',
      'focus': 'Concentrado',
      'tired': 'Cansado',
      'stressed': 'Estresado',
      'traveling': 'Viajando',
      'studying': 'Estudiando',
      'eating': 'Comiendo',
    };
    return labels[status] ?? status;
  }

  /// Verificar si un usuario tiene GPS (solo SOS)
  static bool hasGPS(Map<String, dynamic> member) {
    return member['gpsLatitude'] != null && member['gpsLongitude'] != null;
  }

  /// Obtener URL de Google Maps para un miembro con GPS
  static String getGoogleMapsUrl(Map<String, dynamic> member) {
    if (!hasGPS(member)) return '';
    final lat = member['gpsLatitude'];
    final lng = member['gpsLongitude'];
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  /// Formatear coordenadas GPS
  static String formatGPS(double? lat, double? lng) {
    if (lat == null || lng == null) return 'Sin ubicación';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Obtener tiempo transcurrido desde última actualización
  static String getTimeAgo(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return 'Hace ${difference.inDays} d';
    }
  }
}
