#!/usr/bin/env node

// delete_all_auth_users.js
const admin = require('firebase-admin');

// Inicializa con tu archivo de credenciales de servicio
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});

async function deleteAllUsers(nextPageToken) {
  const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
  const uids = listUsersResult.users.map(user => user.uid);
  if (uids.length > 0) {
    await admin.auth().deleteUsers(uids);
    console.log(`Eliminados ${uids.length} usuarios`);
  }
  if (listUsersResult.pageToken) {
    await deleteAllUsers(listUsersResult.pageToken);
  }
}

deleteAllUsers().then(() => {
  console.log('¡Todos los usuarios de Auth han sido eliminados!');
  process.exit(0);
}).catch(err => {
  console.error('Error eliminando usuarios:', err);
  process.exit(1);
});
