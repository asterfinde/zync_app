class WidgetStatus {
  final String emoji;
  final String statusType;
  final String label;
  final DateTime updatedAt;
  final bool isSelected;

  const WidgetStatus({
    required this.emoji,
    required this.statusType,
    required this.label,
    required this.updatedAt,
    this.isSelected = false,
  });

  factory WidgetStatus.fromMap(Map<String, dynamic> map) {
    return WidgetStatus(
      emoji: map['emoji'] ?? '',
      statusType: map['status'] ?? '',
      label: map['label'] ?? '',
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      isSelected: map['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'status': statusType,
      'label': label,
      'updatedAt': updatedAt.toIso8601String(),
      'isSelected': isSelected,
    };
  }
}

class WidgetConfiguration {
  final List<WidgetStatus> emojis;
  final bool isEnabled;
  final String appName;
  final DateTime lastUpdate;
  final WidgetState state;

  const WidgetConfiguration({
    required this.emojis,
    required this.isEnabled,
    required this.appName,
    required this.lastUpdate,
    required this.state,
  });

  factory WidgetConfiguration.defaultConfig() {
    return WidgetConfiguration(
      emojis: [
        WidgetStatus(emoji: '🚶‍♂️', statusType: 'away', label: 'Saliendo', updatedAt: DateTime.now()),
        WidgetStatus(emoji: '🔥', statusType: 'busy', label: 'Ocupado', updatedAt: DateTime.now()),
        WidgetStatus(emoji: '😊', statusType: 'good', label: 'Bien', updatedAt: DateTime.now()),
        WidgetStatus(emoji: '😢', statusType: 'bad', label: 'Mal', updatedAt: DateTime.now()),
        WidgetStatus(emoji: '🙂', statusType: 'fine', label: 'Todo bien', updatedAt: DateTime.now()),
        WidgetStatus(emoji: '🆘', statusType: 'emergency', label: 'SOS', updatedAt: DateTime.now()),
      ],
      isEnabled: true,
      appName: 'Zync',
      lastUpdate: DateTime.now(),
      state: WidgetState.normal,
    );
  }
}

enum WidgetState {
  normal,
  processing,
  success,
  error,
}
