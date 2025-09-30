// TEMPORAL: Widget comentado durante refactoring
// TODO: Migrar a nueva arquitectura después del MVP

import 'package:flutter/material.dart';

class QuickStatusSendDialog extends StatelessWidget {
  final dynamic statusType; // Temporal

  const QuickStatusSendDialog({super.key, required this.statusType});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Status'),
      content: const Text('This feature is temporarily disabled during architecture refactoring.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
