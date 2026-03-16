// Script para limpiar y reconstruir emojis predefinidos en Firebase
// Elimina estados legacy (available, leave, sad, ready) y garantiza los 16 correctos
//
// USO:
// dart run scripts/fix_firebase_emojis.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/core/models/user_status.dart';

Future<void> main() async {
  print('🔧 Iniciando reparación de emojis en Firebase...\n');

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;

  print('📡 Conectado a Firebase proyecto: zync-app-a2712\n');

  // PASO 1: Eliminar TODOS los estados predefinidos existentes
  print('🗑️  PASO 1: Limpiando colección /predefinedEmojis...');
  final existingDocs = await firestore.collection('predefinedEmojis').get();

  for (final doc in existingDocs.docs) {
    print('   ❌ Eliminando: ${doc.id} (${doc.data()['emoji']} ${doc.data()['label']})');
    await doc.reference.delete();
  }
  print('✅ Colección limpiada: ${existingDocs.docs.length} documentos eliminados\n');

  // PASO 2: Crear los 16 estados correctos
  print('📝 PASO 2: Creando 16 estados predefinidos correctos...\n');

  final correctStatuses = StatusType.fallbackPredefined;

  for (final status in correctStatuses) {
    final data = status.toFirestore();
    await firestore.collection('predefinedEmojis').doc(status.id).set(data);

    print('   ✅ ${status.order.toString().padLeft(2)}/16: ${status.emoji} ${status.label.padRight(20)} [${status.id}]');
  }

  print('\n✅ Todos los estados predefinidos creados correctamente\n');

  // PASO 3: Migrar usuarios con estados legacy
  print('🔄 PASO 3: Migrando usuarios con estados legacy...');

  final usersSnapshot = await firestore.collection('users').get();
  int migratedCount = 0;

  for (final userDoc in usersSnapshot.docs) {
    final data = userDoc.data();
    final statusType = data['statusType'] as String?;

    if (statusType == null) continue;

    String? newStatus;
    switch (statusType) {
      case 'available':
        newStatus = 'fine';
        break;
      case 'leave':
        newStatus = 'away';
        break;
      case 'ready':
        newStatus = 'fine';
        break;
      case 'sad':
        newStatus = 'do_not_disturb';
        break;
    }

    if (newStatus != null) {
      await userDoc.reference.update({'statusType': newStatus});
      print('   🔄 Usuario ${userDoc.id}: $statusType → $newStatus');
      migratedCount++;
    }
  }

  print('✅ $migratedCount usuarios migrados\n');

  // RESUMEN FINAL
  print('════════════════════════════════════════════════════════════');
  print('✅ REPARACIÓN COMPLETADA');
  print('════════════════════════════════════════════════════════════');
  print('   🗑️  Estados legacy eliminados');
  print('   ✅ 16 estados predefinidos correctos creados');
  print('   🔄 $migratedCount usuarios migrados');
  print('\n💡 Los modales ahora mostrarán los 16 estados correctos');
  print('════════════════════════════════════════════════════════════\n');
}
