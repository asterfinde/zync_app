// Script temporal — Grupo B (device-test Sem 9)
// Limpia circleId/pendingCircleId de UNA cuenta de prueba puntual, sin tocar
// el circulo (a diferencia de create_test_accounts.js, que borra el circulo
// completo si el uid es su creatorId). Uso solo para corregir estado de test
// quedado inconsistente por reintentos de escritura en cola durante debugging.
// No es parte del codigo fuente de la app — uso unico, borrar al cerrar el grupo.
//
// Uso: node scripts/reset_test_user_circle.js <uid>

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'zync-app-a2712',
});

const [, , uid] = process.argv;

if (!uid) {
  console.error('Uso: node scripts/reset_test_user_circle.js <uid>');
  process.exit(1);
}

(async () => {
  const userRef = admin.firestore().collection('users').doc(uid);
  await userRef.update({
    circleId: admin.firestore.FieldValue.delete(),
    pendingCircleId: admin.firestore.FieldValue.delete(),
  });
  const updated = await userRef.get();
  console.log(`users/${uid} tras reset:`, JSON.stringify(updated.data()));
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e);
  process.exit(1);
});
