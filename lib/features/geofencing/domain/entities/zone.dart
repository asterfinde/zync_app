// lib/features/geofencing/domain/entities/zone.dart

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa una zona geográfica configurada por el círculo
/// Para detectar entradas/salidas automáticamente
class Zone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String circleId;
  final String createdBy; // userId del creador
  final DateTime createdAt;
  final ZoneType type;
  final bool isPredefined; // true para 4 zonas predefinidas (🏠🏫🎓💼), false para custom (📍)

  const Zone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.circleId,
    required this.createdBy,
    required this.createdAt,
    this.type = ZoneType.custom,
    this.isPredefined = false,
  });

  /// Factory desde Firestore DocumentSnapshot
  factory Zone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Zone(
      id: doc.id,
      name: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      radiusMeters: (data['radiusMeters'] as num).toDouble(),
      circleId: data['circleId'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: ZoneType.fromString(data['type'] as String? ?? 'custom'),
      isPredefined: data['isPredefined'] as bool? ?? false,
    );
  }

  /// Factory desde Map (para testing)
  factory Zone.fromMap(Map<String, dynamic> map, String id) {
    return Zone(
      id: id,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
      circleId: map['circleId'] as String,
      createdBy: map['createdBy'] as String,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      type: ZoneType.fromString(map['type'] as String? ?? 'custom'),
      isPredefined: map['isPredefined'] as bool? ?? false,
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'circleId': circleId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type.value,
      'isPredefined': isPredefined,
    };
  }

  /// Verificar si una ubicación está dentro de esta zona
  bool containsLocation(double lat, double lng) {
    final distance = _calculateDistance(lat, lng, latitude, longitude);
    return distance <= radiusMeters;
  }

  /// Calcular distancia en metros usando fórmula de Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // metros

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  Zone copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? circleId,
    String? createdBy,
    DateTime? createdAt,
    ZoneType? type,
    bool? isPredefined,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      circleId: circleId ?? this.circleId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      isPredefined: isPredefined ?? this.isPredefined,
    );
  }

  @override
  String toString() {
    return 'Zone(id: $id, name: $name, lat: $latitude, lng: $longitude, radius: ${radiusMeters}m, type: ${type.value}, isPredefined: $isPredefined)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Zone &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusMeters == radiusMeters &&
        other.circleId == circleId &&
        other.createdBy == createdBy &&
        other.type == type &&
        other.isPredefined == isPredefined;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      latitude,
      longitude,
      radiusMeters,
      circleId,
      createdBy,
      type,
      isPredefined,
    );
  }
}

/// Tipo de zona para determinar emoji y color
enum ZoneType {
  home('home', '🏠', 0xFF4CAF50), // Verde - Predefinida
  school('school', '🏫', 0xFF2196F3), // Azul - Predefinida
  university('university', '🎓', 0xFF9C27B0), // Morado - Predefinida
  work('work', '💼', 0xFFFF9800), // Naranja - Predefinida
  custom('custom', '📍', 0xFF9E9E9E); // Gris - Personalizada

  final String value;
  final String emoji;
  final int color;

  const ZoneType(this.value, this.emoji, this.color);

  static ZoneType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'home':
        return ZoneType.home;
      case 'school':
        return ZoneType.school;
      case 'university':
        return ZoneType.university;
      case 'work':
        return ZoneType.work;
      case 'custom':
      default:
        return ZoneType.custom;
    }
  }

  /// Verificar si es zona predefinida (4 tipos) o personalizada
  bool get isPredefinedType {
    return this == ZoneType.home || this == ZoneType.school || this == ZoneType.university || this == ZoneType.work;
  }
}
