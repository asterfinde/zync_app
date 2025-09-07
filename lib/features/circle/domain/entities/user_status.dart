// C:/projects/zync_app/lib/features/circle/domain/entities/user_status.dart

import 'package:equatable/equatable.dart';

enum StatusType {
  fine("😊", "Bien"),
  worried("😟", "Preocupado"), // <-- AÑADIDO
  location("📍", "Ubicación"),
  sos("🆘", "SOS"),
  thinking("💭", "Pensando en ti"), // <-- AÑADIDO
  meeting("⏳", "Reunión"),
  ready("✅?", "Listo"),
  leave("🚶‍♂️💨", "Saliste?"),
  love("❤️", "Amor");

  const StatusType(this.emoji, this.description);
  final String emoji;
  final String description;
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
