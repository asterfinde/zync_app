// Script temporal — Paso 7 (verificación Security Rules DT-RULES-CIRCLES-OPEN)
// Crea/resetea las 2 cuentas de prueba para el batch de verificación en device.
// No es parte del código fuente de la app — uso único, borrar al cerrar el paso.

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'zync-app-a2712',
});

const auth = admin.auth();
const db = admin.firestore();

const ACCOUNTS = [
  { email: 'nk-test-creator@nunakin.test', nickname: 'TestCreator' },
  { email: 'nk-test-joiner@nunakin.test', nickname: 'TestJoiner' },
];
const PASSWORD = 'TestPass123!';

async function getOrCreateUser(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      return await auth.createUser({ email, password: PASSWORD, emailVerified: true });
    }
    throw e;
  }
}

async function cleanSlate(uid, nickname) {
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  const data = snap.exists ? snap.data() : {};

  // Si esta cuenta ya tenía un círculo propio de una corrida anterior (era
  // creadora), borrarlo junto con su circleInvites para no arrastrar estado.
  const circleId = data?.circleId;
  if (circleId) {
    const circleDoc = await db.collection('circles').doc(circleId).get();
    if (circleDoc.exists && circleDoc.data().creatorId === uid) {
      const code = circleDoc.data().invitation_code;
      const joinReqs = await db.collection('circles').doc(circleId).collection('joinRequests').get();
      const batch = db.batch();
      joinReqs.docs.forEach((d) => batch.delete(d.reference));
      batch.delete(db.collection('circles').doc(circleId));
      if (code) batch.delete(db.collection('circleInvites').doc(code));
      await batch.commit();
      console.log(`  círculo propio previo ${circleId} (código ${code}) borrado`);
    }
  }

  await userRef.set(
    {
      nickname,
      email: ACCOUNTS.find((a) => a.nickname === nickname).email,
      circleId: admin.firestore.FieldValue.delete(),
      pendingCircleId: admin.firestore.FieldValue.delete(),
    },
    { merge: true }
  );
  console.log(`  users/${uid} reseteado (sin circleId, sin pendingCircleId)`);
}

(async () => {
  for (const { email, nickname } of ACCOUNTS) {
    console.log(`\n${nickname} (${email})`);
    const user = await getOrCreateUser(email);
    console.log(`  uid: ${user.uid} | emailVerified: ${user.emailVerified}`);
    if (!user.emailVerified) {
      await auth.updateUser(user.uid, { emailVerified: true });
      console.log('  emailVerified forzado a true');
    }
    await cleanSlate(user.uid, nickname);
  }
  console.log('\nListo. Ambas cuentas creadas/reseteadas con estado limpio.');
  process.exit(0);
})().catch((e) => {
  console.error('ERROR:', e);
  process.exit(1);
});
