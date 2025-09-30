// lib/features/circle/domain/entities/user_status.dart

import 'package:equatable/equatable.dart';

enum StatusType {
  fine("😊", "Bien", "ic_status_fine"),
  sos("🆘", "SOS", "ic_status_sos"),
  meeting("⏳", "Reunión", "ic_status_meeting"),
  ready("✅", "Listo", "ic_status_ready"),
  leave("🚶‍♂️", "Saliendo", "ic_status_leave"),
  // 🚀 TAREA 3: Estados adicionales completados
  happy("😄", "Feliz", "ic_status_happy"),
  sad("😢", "Mal", "ic_status_sad"),
  busy("🔥", "Ocupado", "ic_status_busy"),
  sleepy("😴", "Con sueño", "ic_status_sleepy"),
  excited("🎉", "Emocionado", "ic_status_excited"),
  thinking("🤔", "Pensando", "ic_status_thinking"),
  worried("😰", "Preocupado", "ic_status_worried");

  const StatusType(this.emoji, this.description, this.iconName);
  final String emoji;
  final String description;
  final String iconName;
}

// Clase auxiliar para las coordenadas, como discutimos.
class Coordinates extends Equatable {
  final double latitude;
  final double longitude;

  const Coordinates({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}

class UserStatus extends Equatable {
  final String id; // ID único del evento de estado
  final String userId; // ID del usuario que publica el estado
  final StatusType statusType; // El tipo de estado, usando el enum de arriba
  final DateTime timestamp; // La fecha y hora exactas
  final Coordinates? coordinates; // La ubicación opcional

  const UserStatus({
    required this.id,
    required this.userId,
    required this.statusType,
    required this.timestamp,
    this.coordinates,
  });

  @override
  List<Object?> get props => [id, userId, statusType, timestamp, coordinates];
}
