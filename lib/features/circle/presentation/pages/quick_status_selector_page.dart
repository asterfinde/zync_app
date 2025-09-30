// TEMPORAL: Archivo comentado durante refactoring
// BACKUP: quick_status_selector_page_backup.dart
// TODO: Migrar a nueva arquitectura después del MVP

import 'package:flutter/material.dart';

class QuickStatusSelectorPage extends StatelessWidget {
  const QuickStatusSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Status'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Quick Status Feature',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Under Maintenance',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'This feature is being migrated to the new architecture.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
