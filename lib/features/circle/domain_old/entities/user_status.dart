// lib/features/circle/domain/entities/user_status.dart

import 'package:equatable/equatable.dart';

enum StatusType {
  // Fila 1: Estados de disponibilidad básica
  available("🟢", "Disponible", "ic_status_available"),
  busy("🔴", "Ocupado", "ic_status_busy"),
  away("🟡", "Ausente", "ic_status_away"),
  focus("🎯", "Concentrado", "ic_status_focus"),
  
  // Fila 2: Estados emocionales/físicos
  happy("😊", "Feliz", "ic_status_happy"),
  tired("😴", "Cansado", "ic_status_tired"),
  stressed("😰", "Estresado", "ic_status_stressed"),
  sad("😢", "Triste", "ic_status_sad"),
  
  // Fila 3: Estados de actividad/ubicación
  traveling("✈️", "Viajando", "ic_status_traveling"),
  meeting("👥", "Reunión", "ic_status_meeting"),
  studying("📚", "Estudiando", "ic_status_studying"),
  eating("🍽️", "Comiendo", "ic_status_eating"),
  
  // Estados heredados (compatibilidad)
  fine("�", "Bien", "ic_status_fine"),
  sos("🆘", "SOS", "ic_status_sos"),
  ready("✅", "Listo", "ic_status_ready"),
  leave("�‍♂️", "Saliendo", "ic_status_leave"),
  sleepy("😴", "Con sueño", "ic_status_sleepy"),
  excited("🎉", "Emocionado", "ic_status_excited"),
  thinking("🤔", "Pensando", "ic_status_thinking"),
  worried("😰", "Preocupado", "ic_status_worried");

  const StatusType(this.emoji, this.description, this.iconName);
  final String emoji;
  final String description;
  final String iconName;
  
  // Versión corta para el grid del modal
  String get shortDescription {
    switch (this) {
      // Fila 1: Estados de disponibilidad básica
      case StatusType.available:
        return 'Libre';
      case StatusType.busy:
        return 'Ocupado';
      case StatusType.away:
        return 'Ausente';
      case StatusType.focus:
        return 'Concentr';
        
      // Fila 2: Estados emocionales/físicos
      case StatusType.happy:
        return 'Feliz';
      case StatusType.tired:
        return 'Cansado';
      case StatusType.stressed:
        return 'Estrés';
      case StatusType.sad:
        return 'Triste';
        
      // Fila 3: Estados de actividad/ubicación
      case StatusType.traveling:
        return 'Viajando';
      case StatusType.meeting:
        return 'Reunión';
      case StatusType.studying:
        return 'Estudia';
      case StatusType.eating:
        return 'Comiendo';
        
      // Estados heredados (compatibilidad)
      case StatusType.fine:
        return 'Bien';
      case StatusType.sos:
        return 'SOS';
      case StatusType.ready:
        return 'Listo';
      case StatusType.leave:
        return 'Salir';
      case StatusType.sleepy:
        return 'Sueño';
      case StatusType.excited:
        return 'Emoción';
      case StatusType.thinking:
        return 'Pienso';
      case StatusType.worried:
        return 'Preocup';
    }
  }
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
