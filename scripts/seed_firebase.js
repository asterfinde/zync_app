// Script para seed automático de Firestore
// Ejecutar: node scripts/seed_firebase.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Necesitas descargarlo de Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const predefinedEmojis = [
  // Fila 1: DISPONIBILIDAD
  { id: 'available', emoji: '🟢', label: 'Disponible', shortLabel: 'Libre', category: 'availability', order: 1 },
  { id: 'busy', emoji: '🔴', label: 'Ocupado', shortLabel: 'Ocupado', category: 'availability', order: 2 },
  { id: 'away', emoji: '🟡', label: 'Ausente', shortLabel: 'Ausente', category: 'availability', order: 3 },
  { id: 'do_not_disturb', emoji: '🔕', label: 'No molestar', shortLabel: 'No molestar', category: 'availability', order: 4 },
  
  // Fila 2: UBICACIÓN
  { id: 'home', emoji: '🏠', label: 'En casa', shortLabel: 'Casa', category: 'location', order: 5 },
  { id: 'school', emoji: '🏫', label: 'En el colegio', shortLabel: 'Colegio', category: 'location', order: 6 },
  { id: 'work', emoji: '🏢', label: 'En el trabajo', shortLabel: 'Trabajo', category: 'location', order: 7 },
  { id: 'medical', emoji: '🏥', label: 'En consulta', shortLabel: 'Consulta', category: 'location', order: 8 },
  
  // Fila 3: ACTIVIDAD
  { id: 'meeting', emoji: '👥', label: 'Reunión', shortLabel: 'Reunión', category: 'activity', order: 9 },
  { id: 'studying', emoji: '📚', label: 'Estudiando', shortLabel: 'Estudia', category: 'activity', order: 10 },
  { id: 'eating', emoji: '🍽️', label: 'Comiendo', shortLabel: 'Comiendo', category: 'activity', order: 11 },
  { id: 'exercising', emoji: '💪', label: 'Ejercicio', shortLabel: 'Ejercicio', category: 'activity', order: 12 },
  
  // Fila 4: TRANSPORTE + SOS
  { id: 'driving', emoji: '🚗', label: 'En camino', shortLabel: 'Camino', category: 'transport', order: 13 },
  { id: 'walking', emoji: '🚶', label: 'Caminando', shortLabel: 'Caminando', category: 'transport', order: 14 },
  { id: 'public_transport', emoji: '🚌', label: 'En transporte', shortLabel: 'Transporte', category: 'transport', order: 15 },
  { id: 'sos', emoji: '🆘', label: 'SOS', shortLabel: 'SOS', category: 'emergency', order: 16 },
];

async function seedFirestore() {
  console.log('🔥 Iniciando seed de Firestore...\n');
  
  const batch = db.batch();
  const collectionRef = db.collection('predefinedEmojis');
  
  for (const emoji of predefinedEmojis) {
    const docRef = collectionRef.doc(emoji.id);
    batch.set(docRef, emoji);
    console.log(`✅ ${emoji.emoji} ${emoji.label} (${emoji.id})`);
  }
  
  await batch.commit();
  
  console.log('\n✅ ¡16 emojis cargados exitosamente!');
  console.log('🎉 Firestore seed completado\n');
  
  process.exit(0);
}

seedFirestore().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
