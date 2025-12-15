// lib/features/geofencing/domain/entities/zone_event.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de evento de zona geográfica
enum ZoneEventType {
  entry('entry', 'Entrada'),
  exit('exit', 'Salida');

  final String value;
  final String label;
  const ZoneEventType(this.value, this.label);

  static ZoneEventType fromString(String value) {
    return ZoneEventType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ZoneEventType.entry,
    );
  }
}

/// Entidad que representa un evento de entrada/salida de zona
class ZoneEvent {
  final String id;
  final String zoneId;
  final String userId;
  final ZoneEventType eventType;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? zoneName; // Opcional, para facilitar UI

  const ZoneEvent({
    required this.id,
    required this.zoneId,
    required this.userId,
    required this.eventType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.zoneName,
  });

  /// Serializar a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'zoneId': zoneId,
      'userId': userId,
      'eventType': eventType.value,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
      if (zoneName != null) 'zoneName': zoneName,
    };
  }

  /// Deserializar desde Firestore
  factory ZoneEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ZoneEvent(
      id: doc.id,
      zoneId: data['zoneId'] as String,
      userId: data['userId'] as String,
      eventType: ZoneEventType.fromString(data['eventType'] as String),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      zoneName: data['zoneName'] as String?,
    );
  }

  /// Crear copia con modificaciones
  ZoneEvent copyWith({
    String? id,
    String? zoneId,
    String? userId,
    ZoneEventType? eventType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? zoneName,
  }) {
    return ZoneEvent(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoneName: zoneName ?? this.zoneName,
    );
  }

  @override
  String toString() {
    return 'ZoneEvent(id: $id, zoneId: $zoneId, userId: $userId, eventType: ${eventType.label}, timestamp: $timestamp, location: ($latitude, $longitude))';
  }
}
