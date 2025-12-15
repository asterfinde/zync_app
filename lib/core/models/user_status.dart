// lib/core/models/user_status.dart
// REFACTORED: StatusType ahora es una clase que se carga desde Firebase
// Backup del enum original en: backups/user_status_enum_backup_20251129.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Representa un tipo de estado (emoji/estado) que puede ser:
/// - Predefinido: Cargado desde Firebase /predefinedEmojis (16 estados base)
/// - Personalizado: Creado por usuarios en /circles/{id}/customEmojis
class StatusType extends Equatable {
  final String id; // ID único (ej: "available", "busy", "natacion")
  final String emoji; // Emoji unicode (ej: "🟢", "🏊")
  final String label; // Descripción completa (ej: "Disponible", "Natación")
  final String shortLabel; // Descripción corta para grid (ej: "Libre", "Natación")
  final String category; // Categoría (availability, location, activity, transport, emergency, custom)
  final int order; // Orden de visualización
  final bool isPredefined; // true = predefinido global, false = custom del círculo
  final bool canDelete; // true = usuario puede eliminar (solo custom)

  const StatusType({
    required this.id,
    required this.emoji,
    required this.label,
    required this.shortLabel,
    required this.category,
    required this.order,
    this.isPredefined = true,
    this.canDelete = false,
  });

  /// Factory desde Firestore Document
  factory StatusType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StatusType(
      id: doc.id,
      emoji: _sanitizeEmoji(doc.id, data['emoji'] as String),
      label: data['label'] as String,
      shortLabel: data['shortLabel'] as String,
      category: data['category'] as String? ?? 'custom', // Default para custom emojis
      order: data['order'] as int? ?? 999, // Default order alto
      isPredefined: data['isPredefined'] as bool? ?? false,
      canDelete: data['canDelete'] as bool? ?? true,
    );
  }

  /// Factory desde Map (para deserialización)
  factory StatusType.fromMap(Map<String, dynamic> map) {
    return StatusType(
      id: map['id'] as String,
      emoji: _sanitizeEmoji(map['id'] as String, map['emoji'] as String),
      label: map['label'] as String,
      shortLabel: map['shortLabel'] as String,
      category: map['category'] as String,
      order: map['order'] as int,
      isPredefined: map['isPredefined'] as bool? ?? true,
      canDelete: map['canDelete'] as bool? ?? false,
    );
  }

  static String _sanitizeEmoji(String id, String emoji) {
    final e = emoji.trim();
    if (id == 'meeting') {
      // Algunos emojis de "reunión" (burbujas de chat) no están soportados en
      // ciertos dispositivos y se ven como tofu/rectángulo.
      const unsupportedMeetingEmojis = {
        '🗣',
        '🗣️',
        '💬',
        '🗨',
        '🗨️',
      };
      if (unsupportedMeetingEmojis.contains(e)) {
        return '📅';
      }
    }

    final isInvalid = e.isEmpty || e == '?' || e.contains('\uFFFD');
    if (!isInvalid) return emoji;

    switch (id) {
      case 'meeting':
        return '📅';
      default:
        return '❓';
    }
  }

  /// Conversión a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'emoji': emoji,
      'label': label,
      'shortLabel': shortLabel,
      'category': category,
      'order': order,
      'isPredefined': isPredefined,
      'canDelete': canDelete,
    };
  }

  /// Conversión a Map para serialización
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'emoji': emoji,
      'label': label,
      'shortLabel': shortLabel,
      'category': category,
      'order': order,
      'isPredefined': isPredefined,
      'canDelete': canDelete,
    };
  }

  /// Getter para compatibilidad con código que usaba .description
  String get description => label;

  /// Getter para compatibilidad con código que usaba .shortDescription
  String get shortDescription => shortLabel;

  /// Getter para iconName (legacy, mantener por compatibilidad)
  String get iconName => 'ic_status_$id';

  @override
  List<Object?> get props => [id, emoji, label, category, order];

  @override
  String toString() => 'StatusType($id: $emoji $label)';

  /// Método helper para comparar por ID (útil para búsquedas)
  bool hasId(String statusId) => id == statusId;

  /// Estados predefinidos hardcoded como fallback (si Firebase falla)
  static final List<StatusType> fallbackPredefined = [
    // FILA 1: DISPONIBILIDAD
    StatusType(id: 'fine', emoji: '🙂', label: 'Todo bien', shortLabel: 'Bien', category: 'availability', order: 1),
    StatusType(id: 'busy', emoji: '🔴', label: 'Ocupado', shortLabel: 'Ocupado', category: 'availability', order: 2),
    StatusType(id: 'away', emoji: '🟡', label: 'Ausente', shortLabel: 'Ausente', category: 'availability', order: 3),
    StatusType(
        id: 'do_not_disturb',
        emoji: '🔕',
        label: 'No molestar',
        shortLabel: 'No molestar',
        category: 'availability',
        order: 4),

    // FILA 2: UBICACIÓN
    StatusType(id: 'home', emoji: '🏠', label: 'En casa', shortLabel: 'Casa', category: 'location', order: 5),
    StatusType(
        id: 'school', emoji: '🏫', label: 'En el colegio', shortLabel: 'Colegio', category: 'location', order: 6),
    StatusType(id: 'work', emoji: '🏢', label: 'En el trabajo', shortLabel: 'Trabajo', category: 'location', order: 7),
    StatusType(
        id: 'medical', emoji: '🏥', label: 'En consulta', shortLabel: 'Consulta', category: 'location', order: 8),

    // FILA 3: ACTIVIDAD
    StatusType(id: 'meeting', emoji: '👥', label: 'Reunión', shortLabel: 'Reunión', category: 'activity', order: 9),
    StatusType(
        id: 'studying', emoji: '📚', label: 'Estudiando', shortLabel: 'Estudia', category: 'activity', order: 10),
    StatusType(id: 'eating', emoji: '🍽️', label: 'Comiendo', shortLabel: 'Comiendo', category: 'activity', order: 11),
    StatusType(
        id: 'exercising', emoji: '💪', label: 'Ejercicio', shortLabel: 'Ejercicio', category: 'activity', order: 12),

    // FILA 4: TRANSPORTE + SOS
    StatusType(id: 'driving', emoji: '🚗', label: 'En camino', shortLabel: 'Camino', category: 'transport', order: 13),
    StatusType(
        id: 'walking', emoji: '🚶', label: 'Caminando', shortLabel: 'Caminando', category: 'transport', order: 14),
    StatusType(
        id: 'public_transport',
        emoji: '🚌',
        label: 'En transporte',
        shortLabel: 'Transporte',
        category: 'transport',
        order: 15),
    StatusType(id: 'sos', emoji: '🆘', label: 'SOS', shortLabel: 'SOS', category: 'emergency', order: 16),
  ];
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
