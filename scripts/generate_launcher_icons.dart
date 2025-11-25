// Script para generar iconos temporales de texto para launcher shortcuts
// Estos son placeholders - idealmente deberían reemplazarse con iconos diseñados

import 'dart:io';

void main() {
  final iconsDir = Directory('assets/launcher');
  if (!iconsDir.existsSync()) {
    iconsDir.createSync(recursive: true);
  }

  // Lista de estados con sus emojis (de user_status.dart)
  final statusIcons = {
    'available.png': '🟢',
    'busy.png': '🔴',
    'away.png': '🟡',
    'focus.png': '🎯',
    'happy.png': '😊',
    'tired.png': '😴',
    'stressed.png': '😰',
    'sad.png': '😢',
    'traveling.png': '✈️',
    'meeting.png': '👥',
    'studying.png': '📚',
    'eating.png': '🍽️',
  };

  print('📝 Generando placeholders para launcher shortcuts...');
  print('⚠️  NOTA: Estos son archivos temporales de texto con emojis.');
  print('⚠️  Para producción, reemplaza con iconos PNG reales (192x192px).\n');

  for (var entry in statusIcons.entries) {
    final file = File('${iconsDir.path}/${entry.key}');
    // Crear archivo de texto con el emoji como contenido temporal
    file.writeAsStringSync('${entry.value}\n');
    print('✅ ${entry.key} -> ${entry.value}');
  }

  print('\n✨ Placeholders creados en assets/launcher/');
  print('📍 Ubicación: ${iconsDir.absolute.path}');
}
