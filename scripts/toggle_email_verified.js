// Script temporal — Grupo C (verificación SOS, PR #243)
// Togglea emailVerified de una cuenta de prueba para probar el gate de SOS.
// No es parte del código fuente de la app — uso único, borrar al cerrar el grupo.
//
// Uso: node scripts/toggle_email_verified.js <email> <true|false>

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'zync-app-a2712',
});

const [, , email, value] = process.argv;

if (!email || !['true', 'false'].includes(value)) {
  console.error('Uso: node scripts/toggle_email_verified.js <email> <true|false>');
  process.exit(1);
}

(async () => {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { emailVerified: value === 'true' });
  const updated = await admin.auth().getUser(user.uid);
  console.log(`${email} (uid ${updated.uid}) emailVerified: ${updated.emailVerified}`);
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e);
  process.exit(1);
});
