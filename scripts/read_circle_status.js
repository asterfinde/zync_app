// Script temporal — Grupos B y C (device-test Sem 9)
// Lee un círculo completo (creatorId, members, memberStatus) para verificar
// resultados de tests de SOS y de salida/sucesión de círculo.
// Solo lectura. No es parte del código fuente de la app — uso único, borrar al cerrar el batch.
//
// Uso: node scripts/read_circle_status.js <circleId>

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'zync-app-a2712',
});

const [, , circleId] = process.argv;

if (!circleId) {
  console.error('Uso: node scripts/read_circle_status.js <circleId>');
  process.exit(1);
}

(async () => {
  const doc = await admin.firestore().collection('circles').doc(circleId).get();
  if (!doc.exists) {
    console.error(`Círculo ${circleId} no existe.`);
    process.exit(1);
  }
  const data = doc.data();
  console.log('creatorId:', data.creatorId);
  console.log('members:', JSON.stringify(data.members));
  console.log('memberStatus:', JSON.stringify(data.memberStatus, null, 2));
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e);
  process.exit(1);
});
