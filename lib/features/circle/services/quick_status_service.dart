// TEMPORAL: Archivo comentado durante refactoring
// BACKUP: quick_status_service_backup.dart  
// TODO: Migrar a nueva arquitectura después del MVP

import 'dart:developer';

class QuickStatusService {
  static const QuickStatusService _instance = QuickStatusService._internal();
  factory QuickStatusService() => _instance;
  const QuickStatusService._internal();

  Future<void> startService() async {
    log('[QuickStatusService] Service temporarily disabled during refactoring');
  }

  Future<void> stopService() async {
    log('[QuickStatusService] Service temporarily disabled during refactoring');
  }
}

// Enum temporal para compatibilidad
enum StatusType { fine, help, emergency }

class QuickStatusTaskHandler {
  Future<void> onStart() async {
    log('[QuickStatusTaskHandler] Handler temporarily disabled during refactoring');
  }
}
