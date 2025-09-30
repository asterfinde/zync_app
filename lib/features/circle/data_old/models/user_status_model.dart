// lib/features/circle/data/models/user_status_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';

class CoordinatesModel extends Coordinates {
  const CoordinatesModel({required super.latitude, required super.longitude});

  factory CoordinatesModel.fromMap(Map<String, dynamic> map) {
    return CoordinatesModel(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
  
  // MÉTODO AÑADIDO: Convierte el modelo a la entidad de dominio.
  Coordinates toEntity() {
    return Coordinates(latitude: latitude, longitude: longitude);
  }
}

class UserStatusModel extends UserStatus {
  const UserStatusModel({
    required super.id,
    required super.userId,
    required super.statusType,
    required super.timestamp,
    super.coordinates,
  });

  factory UserStatusModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserStatusModel(
      id: docId,
      userId: map['userId'] as String? ?? docId,
      statusType: StatusType.values.byName(map['statusType'] as String? ?? 'fine'),
      timestamp: map['timestamp'] == null
          ? DateTime.now()
          : (map['timestamp'] as Timestamp).toDate(),
      coordinates: map['coordinates'] != null
          ? CoordinatesModel.fromMap(map['coordinates'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'statusType': statusType.name,
      'timestamp': timestamp,
      'coordinates': (coordinates as CoordinatesModel?)?.toMap(),
    };
  }

  // CORRECCIÓN: Se añade el método 'toEntity' que faltaba.
  // Este método "traduce" el modelo de la capa de datos a la entidad
  // que la capa de dominio y presentación esperan.
  UserStatus toEntity() {
    return UserStatus(
      id: id,
      userId: userId,
      statusType: statusType,
      timestamp: timestamp,
      coordinates: (coordinates as CoordinatesModel?)?.toEntity(),
    );
  }
}