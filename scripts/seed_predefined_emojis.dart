// scripts/seed_predefined_emojis.dart
// Script para cargar los 16 estados predefinidos a Firebase

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zync_app/firebase_options.dart';

/// Estados predefinidos organizados por categoría
/// Grid 4x4 (16 estados totales)
final predefinedEmojis = [
  // FILA 1: ✅ DISPONIBILIDAD (4 estados)
  {
    'id': 'fine',
    'emoji': '🙂',
    'label': 'Todo bien',
    'shortLabel': 'Bien',
    'category': 'availability',
    'order': 1,
  },
  {
    'id': 'busy',
    'emoji': '🔴',
    'label': 'Ocupado',
    'shortLabel': 'Ocupado',
    'category': 'availability',
    'order': 2,
  },
  {
    'id': 'away',
    'emoji': '🟡',
    'label': 'Ausente',
    'shortLabel': 'Ausente',
    'category': 'availability',
    'order': 3,
  },
  {
    'id': 'do_not_disturb',
    'emoji': '🔕',
    'label': 'No molestar',
    'shortLabel': 'No molestar',
    'category': 'availability',
    'order': 4,
  },

  // FILA 2: 📍 UBICACIÓN (4 estados)
  {
    'id': 'home',
    'emoji': '🏠',
    'label': 'En casa',
    'shortLabel': 'Casa',
    'category': 'location',
    'order': 5,
  },
  {
    'id': 'school',
    'emoji': '🏫',
    'label': 'En el colegio',
    'shortLabel': 'Colegio',
    'category': 'location',
    'order': 6,
  },
  {
    'id': 'work',
    'emoji': '🏢',
    'label': 'En el trabajo',
    'shortLabel': 'Trabajo',
    'category': 'location',
    'order': 7,
  },
  {
    'id': 'medical',
    'emoji': '🏥',
    'label': 'En consulta',
    'shortLabel': 'Consulta',
    'category': 'location',
    'order': 8,
  },

  // FILA 3: 💤 ACTIVIDAD (4 estados)
  {
    'id': 'meeting',
    'emoji': '👥',
    'label': 'Reunión',
    'shortLabel': 'Reunión',
    'category': 'activity',
    'order': 9,
  },
  {
    'id': 'studying',
    'emoji': '📚',
    'label': 'Estudiando',
    'shortLabel': 'Estudia',
    'category': 'activity',
    'order': 10,
  },
  {
    'id': 'eating',
    'emoji': '🍽️',
    'label': 'Comiendo',
    'shortLabel': 'Comiendo',
    'category': 'activity',
    'order': 11,
  },
  {
    'id': 'exercising',
    'emoji': '💪',
    'label': 'Ejercicio',
    'shortLabel': 'Ejercicio',
    'category': 'activity',
    'order': 12,
  },

  // FILA 4: 🚗 TRANSPORTE (3) + SOS (1)
  {
    'id': 'driving',
    'emoji': '🚗',
    'label': 'En camino',
    'shortLabel': 'Camino',
    'category': 'transport',
    'order': 13,
  },
  {
    'id': 'walking',
    'emoji': '🚶',
    'label': 'Caminando',
    'shortLabel': 'Caminando',
    'category': 'transport',
    'order': 14,
  },
  {
    'id': 'public_transport',
    'emoji': '🚌',
    'label': 'En transporte',
    'shortLabel': 'Transporte',
    'category': 'transport',
    'order': 15,
  },
  {
    'id': 'sos',
    'emoji': '🆘',
    'label': 'SOS',
    'shortLabel': 'SOS',
    'category': 'emergency',
    'order': 16,
  },
];

void main() async {
  print('════════════════════════════════════════');
  print('  Seed: Emojis Predefinidos a Firebase');
  print('════════════════════════════════════════');
  print('');

  // Inicializar Firebase
  print('[1/3] Inicializando Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✓ Firebase inicializado\n');

  // Obtener referencia a Firestore
  final firestore = FirebaseFirestore.instance;
  final collection = firestore.collection('predefinedEmojis');

  // Cargar emojis
  print('[2/3] Cargando ${predefinedEmojis.length} emojis predefinidos...');

  int loaded = 0;
  for (var emoji in predefinedEmojis) {
    try {
      await collection.doc(emoji['id'] as String).set({
        ...emoji,
        'isPredefined': true,
        'canDelete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      loaded++;
      print('  ✓ ${emoji['emoji']} ${emoji['label']} (${emoji['id']})');
    } catch (e) {
      print('  ✗ Error cargando ${emoji['id']}: $e');
    }
  }

  print('');
  print('[3/3] Verificando carga...');
  final snapshot = await collection.get();
  print('✓ Total documentos en Firebase: ${snapshot.docs.length}\n');

  print('════════════════════════════════════════');
  print('  ✅ Seed completado: $loaded/${predefinedEmojis.length} emojis');
  print('════════════════════════════════════════');
  print('');
  print('Grid organizado:');
  print('  Fila 1: ✅ DISPONIBILIDAD (4)');
  print('  Fila 2: 📍 UBICACIÓN (4)');
  print('  Fila 3: 💤 ACTIVIDAD (4)');
  print('  Fila 4: 🚗 TRANSPORTE (3) + 🆘 SOS (1)');
  print('');
}
