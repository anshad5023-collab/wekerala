// One-time migration: assign shopCode (W1001, W1002...) to all existing shops
// Run: node scripts/migrate_shop_codes.js
const admin = require('firebase-admin');
const serviceAccount = require('../functions/service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function migrate() {
  const shopsSnap = await db.collection('shops').get();
  const unassigned = shopsSnap.docs.filter(d => !d.data().shopCode);
  console.log(`Found ${unassigned.length} shops without shopCode`);
  if (unassigned.length === 0) { console.log('Nothing to do.'); process.exit(0); }

  const counterRef = db.collection('counters').doc('shopCode');

  for (const doc of unassigned) {
    const code = await db.runTransaction(async (tx) => {
      const counter = await tx.get(counterRef);
      const next = counter.exists ? (counter.data().next || 1001) : 1001;
      tx.set(counterRef, { next: next + 1 }, { merge: true });
      return `W${next}`;
    });
    await doc.ref.update({ shopCode: code });
    console.log(`${doc.id} → ${code} (${doc.data().shopName || 'unnamed'})`);
  }
  console.log('Migration complete.');
  process.exit(0);
}

migrate().catch(e => { console.error(e); process.exit(1); });
