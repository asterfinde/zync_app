import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RULES_PATH = path.join(__dirname, '..', 'firestore.rules.proposed');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'zync-rules-test',
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8089,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Helper: siembra datos con privilegios de admin (sin pasar por las reglas)
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await fn(context.firestore());
  });
}

// ─── predefinedEmojis ────────────────────────────────────────────────────

test('predefinedEmojis: usuario autenticado puede leer', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'predefinedEmojis/happy'), { emoji: '😀' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(alice, 'predefinedEmojis/happy')));
});

test('predefinedEmojis: escritura siempre denegada (incluso autenticado)', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, 'predefinedEmojis/new'), { emoji: '😀' }));
});

// ─── users ───────────────────────────────────────────────────────────────

test('users: el propio usuario puede escribir su documento', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, 'users/alice'), { circleId: null }));
});

test('users: NO puede escribir el documento de otro usuario', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, 'users/bob'), { circleId: 'c1' }));
});

test('users: mismo circleId puede leer el doc de otro miembro (nickname)', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users/alice'), { circleId: 'c1' });
    await setDoc(doc(db, 'users/bob'), { circleId: 'c1' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(alice, 'users/bob')));
});

test('users: circleId distinto NO puede leer el doc de otro usuario', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users/alice'), { circleId: 'c1' });
    await setDoc(doc(db, 'users/mallory'), { circleId: 'other-circle' });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(mallory, 'users/alice')));
});

// ─── circleInvites ───────────────────────────────────────────────────────

test('circleInvites: cualquier autenticado puede leer un codigo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circleInvites/ABC123'), { circleId: 'c1' });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertSucceeds(getDoc(doc(mallory, 'circleInvites/ABC123')));
});

test('circleInvites: no autenticado NO puede leer', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circleInvites/ABC123'), { circleId: 'c1' });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'circleInvites/ABC123')));
});

test('circleInvites: cualquier autenticado puede crear una entrada', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(alice, 'circleInvites/NEWCODE'), { circleId: 'c1' }));
});

test('circleInvites: solo el creador del circulo puede borrar la entrada', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circleInvites/ABC123'), { circleId: 'c1' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(deleteDoc(doc(bob, 'circleInvites/ABC123')));
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(deleteDoc(doc(alice, 'circleInvites/ABC123')));
});

// ─── circles (documento principal) ──────────────────────────────────────

test('circles: un miembro puede leer el documento del circulo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice', 'bob'] });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(bob, 'circles/c1')));
});

test('circles: un NO-miembro NO puede leer el documento del circulo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(mallory, 'circles/c1')));
});

test('circles: el creador puede crear un circulo nuevo con members=[self]', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(alice, 'circles/c1'), { creatorId: 'alice', members: ['alice'], name: 'Familia' })
  );
});

test('circles: NO se puede crear un circulo con otro creatorId', async () => {
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(mallory, 'circles/c1'), { creatorId: 'alice', members: ['mallory'], name: 'Falso' })
  );
});

test('circles: NO se puede crear ya con otros miembros de entrada', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    setDoc(doc(alice, 'circles/c1'), { creatorId: 'alice', members: ['alice', 'bob'], name: 'Familia' })
  );
});

test('circles: un miembro puede actualizar el documento (ej. status)', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice', 'bob'] });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertSucceeds(updateDoc(doc(bob, 'circles/c1'), { 'memberStatus.bob': { statusType: 'fine' } }));
});

test('circles: un NO-miembro NO puede actualizar el documento', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(updateDoc(doc(mallory, 'circles/c1'), { name: 'Hackeado' }));
});

test('circles: solo el creador puede borrar el circulo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice', 'bob'] });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(deleteDoc(doc(bob, 'circles/c1')));
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(deleteDoc(doc(alice, 'circles/c1')));
});

// ─── joinRequests ────────────────────────────────────────────────────────

test('joinRequests: un NO-miembro puede crear su PROPIA solicitud', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertSucceeds(
    setDoc(doc(mallory, 'circles/c1/joinRequests/mallory'), { status: 'pending' })
  );
});

test('joinRequests: NO puede crear una solicitud a nombre de OTRO uid', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(mallory, 'circles/c1/joinRequests/bob'), { status: 'pending' })
  );
});

test('joinRequests: el solicitante puede leer su PROPIA solicitud (para detectar aprobacion)', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circles/c1/joinRequests/mallory'), { status: 'pending' });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertSucceeds(getDoc(doc(mallory, 'circles/c1/joinRequests/mallory')));
});

test('joinRequests: el solicitante NO puede leer la solicitud de otro usuario', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circles/c1/joinRequests/bob'), { status: 'pending' });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(mallory, 'circles/c1/joinRequests/bob')));
});

test('joinRequests: el creador (miembro) puede leer cualquier solicitud del circulo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circles/c1/joinRequests/mallory'), { status: 'pending' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(alice, 'circles/c1/joinRequests/mallory')));
});

test('joinRequests: el creador puede aprobar (update) una solicitud', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circles/c1/joinRequests/mallory'), { status: 'pending' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(alice, 'circles/c1/joinRequests/mallory'), { status: 'approved' }));
});

test('joinRequests: el propio solicitante NO puede aprobarse a si mismo', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
    await setDoc(doc(db, 'circles/c1/joinRequests/mallory'), { status: 'pending' });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(updateDoc(doc(mallory, 'circles/c1/joinRequests/mallory'), { status: 'approved' }));
});

// ─── subcolecciones (zones, customEmojis, statusEvents, members) ───────

for (const sub of ['zones', 'zone_events', 'customEmojis', 'members', 'statusEvents']) {
  test(`${sub}: un miembro puede leer y escribir`, async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice', 'bob'] });
    });
    const bob = testEnv.authenticatedContext('bob').firestore();
    await assertSucceeds(setDoc(doc(bob, `circles/c1/${sub}/item1`), { data: 'x' }));
    await assertSucceeds(getDoc(doc(bob, `circles/c1/${sub}/item1`)));
  });

  test(`${sub}: un NO-miembro NO puede leer ni escribir`, async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'circles/c1'), { creatorId: 'alice', members: ['alice'] });
      await setDoc(doc(db, `circles/c1/${sub}/item1`), { data: 'x' });
    });
    const mallory = testEnv.authenticatedContext('mallory').firestore();
    await assertFails(getDoc(doc(mallory, `circles/c1/${sub}/item1`)));
    await assertFails(setDoc(doc(mallory, `circles/c1/${sub}/item2`), { data: 'y' }));
  });
}

// ─── El hallazgo original — debe seguir BLOQUEADO tras el fix ───────────

test('HALLAZGO ORIGINAL: un usuario ajeno YA NO puede leer un circulo cualquiera', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'circles/c1'), {
      creatorId: 'alice',
      members: ['alice'],
      invitation_code: 'ABC123',
    });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(mallory, 'circles/c1')));
});
