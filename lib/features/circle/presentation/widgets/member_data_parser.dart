import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/user_status.dart';

/// Helper puro para parsear y comparar datos de miembros desde Firestore.
/// Extraído de in_circle_view.dart en Sem 5 Día 5.
class MemberDataParser {
  final List<StatusType>? predefinedEmojis;
  final VoidCallback? onMissingEmoji;

  const MemberDataParser({
    required this.predefinedEmojis,
    this.onMissingEmoji,
  });

  /// PM3/PM4 FIX: Migrar estados del sistema viejo (enum) al nuevo (class)
  static String migrateOldStatus(String? oldStatus) {
    if (oldStatus == null) return 'fine';
    switch (oldStatus) {
      case 'available':
        return 'fine';
      case 'leave':
        return 'away';
      case 'ready':
        return 'fine';
      case 'sad':
        return 'do_not_disturb';
      default:
        return oldStatus;
    }
  }

  Map<String, dynamic> parse(dynamic statusData) {
    if (statusData is! Map<String, dynamic>) {
      return {
        'emoji': '❓',
        'status': 'unknown',
        'hasGPS': false,
        'coordinates': null,
        'lastUpdate': null,
        'autoUpdated': false,
        'zoneName': null,
        'displayText': null,
        'showManualBadge': false,
        'locationInfo': null,
      };
    }

    final rawStatusType = statusData['statusType'] as String?;
    final statusType = migrateOldStatus(rawStatusType);
    final autoUpdated = statusData['autoUpdated'] as bool? ?? false;
    final customEmoji = statusData['customEmoji'] as String?;
    final zoneName = statusData['zoneName'] as String?;
    final manualOverride = statusData['manualOverride'] as bool?;
    final locationUnknown = statusData['locationUnknown'] as bool?;

    String emoji = '😊';
    String? displayText;
    bool showManualBadge = false;
    String? locationInfo;

    // CASO 1: Actualización automática con customEmoji (entrada a zona)
    if (autoUpdated && customEmoji != null) {
      emoji = customEmoji;
      displayText = zoneName;
      showManualBadge = false;
      locationInfo = null;
    }
    // CASO 1.5: Override manual mientras sigue dentro de una zona
    else if (!autoUpdated && customEmoji != null) {
      final resolved = _resolveStatusEnum(statusType);
      emoji = resolved.emoji;
      displayText = resolved.label;
      showManualBadge = manualOverride == true;
      locationInfo = locationUnknown == true ? '❓ Ubicación desconocida' : null;
    }
    // CASO 2: Estado manual (sin customEmoji)
    else if (customEmoji == null) {
      final resolved = _resolveStatusEnum(statusType);
      emoji = resolved.emoji;
      displayText = resolved.label;
      showManualBadge = manualOverride == true;
      locationInfo = locationUnknown == true ? '❓ Ubicación desconocida' : null;
    }

    final coordinates = statusData['coordinates'] as Map<String, dynamic>?;
    final timestamp = statusData['timestamp'];
    DateTime? lastUpdate;
    if (timestamp is Timestamp) {
      lastUpdate = timestamp.toDate();
    }

    return {
      'emoji': emoji,
      'status': statusType,
      'coordinates': coordinates,
      'hasGPS': coordinates != null && statusType == 'sos',
      'lastUpdate': lastUpdate,
      'autoUpdated': autoUpdated,
      'zoneName': zoneName,
      'displayText': displayText,
      'showManualBadge': showManualBadge,
      'locationInfo': locationInfo,
    };
  }

  StatusType _resolveStatusEnum(String statusType) {
    final emojis = predefinedEmojis ?? StatusType.fallbackPredefined;
    try {
      return emojis.firstWhere(
        (s) => s.id == statusType,
        orElse: () {
          debugPrint("[MemberDataParser] Status '$statusType' no encontrado");
          onMissingEmoji?.call();
          return emojis.firstWhere(
            (s) => s.id == 'fine',
            orElse: () => StatusType.fallbackPredefined.first,
          );
        },
      );
    } catch (e) {
      debugPrint('[MemberDataParser] Error parsing status enum: $e');
      return StatusType.fallbackPredefined.first;
    }
  }

  static bool hasChanged(
    Map<String, dynamic>? oldData,
    Map<String, dynamic> newData,
  ) {
    if (oldData == null) return true;
    return oldData['emoji'] != newData['emoji'] ||
        oldData['status'] != newData['status'] ||
        oldData['autoUpdated'] != newData['autoUpdated'] ||
        oldData['zoneName'] != newData['zoneName'] ||
        oldData['displayText'] != newData['displayText'] ||
        oldData['showManualBadge'] != newData['showManualBadge'] ||
        oldData['locationInfo'] != newData['locationInfo'] ||
        oldData['lastUpdate']?.millisecondsSinceEpoch !=
            newData['lastUpdate']?.millisecondsSinceEpoch ||
        oldData['coordinates']?.toString() !=
            newData['coordinates']?.toString();
  }
}
