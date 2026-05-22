/**
 * R1 Migration — wekerala
 *
 * Dry run (default):
 *   FIREBASE_SERVICE_ACCOUNT='...' npx tsx web/scripts/migrate-r1.ts
 *
 * Emulator (write):
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_SERVICE_ACCOUNT='...' npx tsx web/scripts/migrate-r1.ts --force
 *
 * Production (write):
 *   FIREBASE_SERVICE_ACCOUNT='...' npx tsx web/scripts/migrate-r1.ts --force --allow-production
 */

import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, WriteBatch } from 'firebase-admin/firestore';
import type { Firestore, Timestamp } from 'firebase-admin/firestore';
import { CATEGORY_FIRESTORE_SEED, CategoryId } from '../lib/types/category';
import type { MigrationMeta } from '../lib/types/merchant';

const SCRIPT_VERSION = 'migrate-r1-v1';
const SLUG_REGEX = /^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$/;
const BATCH_SIZE = 400;

// --- shopType → CategoryId (case-insensitive prefix match) ---
const SHOP_TYPE_MAP: [string, CategoryId][] = [
  ['grocery', 'retail'], ['supermarket', 'retail'], ['store', 'retail'],
  ['medical', 'retail'], ['pharmacy', 'retail'], ['hardware', 'retail'],
  ['electronics', 'retail'], ['clothing', 'retail'], ['jewel', 'retail'],
  ['restaurant', 'restaurant'], ['food', 'restaurant'], ['bakery', 'restaurant'],
  ['fast food', 'restaurant'], ['cloud kitchen', 'restaurant'], ['catering', 'restaurant'],
  ['salon', 'salon'], ['beauty', 'salon'], ['spa', 'salon'], ['barber', 'salon'],
  ['clinic', 'clinic'], ['hospital', 'clinic'], ['doctor', 'clinic'],
  ['dental', 'clinic'], ['ayurveda', 'clinic'], ['physio', 'clinic'],
  ['service', 'service'], ['electrician', 'service'], ['plumber', 'service'],
  ['tuition', 'tuition'], ['coaching', 'tuition'], ['classes', 'tuition'],
  ['education', 'tuition'], ['school', 'tuition'],
  ['homestay', 'hotel'], ['resort', 'hotel'], ['accommodation', 'hotel'],
  ['guesthouse', 'hotel'], ['houseboat', 'hotel'],
  ['theater', 'theater'], ['cinema', 'theater'], ['multiplex', 'theater'],
];

function resolveCategory(shopType: string, deliveryEnabled: boolean): CategoryId {
  const key = shopType.toLowerCase().trim();
  if (key === 'hotel') return deliveryEnabled ? 'restaurant' : 'hotel';
  for (const [prefix, cat] of SHOP_TYPE_MAP) {
    if (key.includes(prefix)) return cat;
  }
  return 'retail';
}

function toIso(val: unknown): string {
  if (val && typeof (val as Timestamp).toDate === 'function') {
    return (val as Timestamp).toDate().toISOString();
  }
  if (typeof val === 'string' && val) return val;
  return new Date().toISOString();
}

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 50);
}

function validateSlug(raw: string): string | null {
  const s = slugify(raw);
  return SLUG_REGEX.test(s) ? s : null;
}

async function flushBatch(batch: WriteBatch, db: Firestore): Promise<WriteBatch> {
  await batch.commit();
  return db.batch();
}

async function copySubcollection(
  srcRef: FirebaseFirestore.DocumentReference,
  dstRef: FirebaseFirestore.DocumentReference,
  name: string,
  meta: MigrationMeta,
  db: Firestore,
  dryRun: boolean,
): Promise<number> {
  const snap = await srcRef.collection(name).get();
  if (snap.size === 0) return 0;
  if (!dryRun) {
    let batch = db.batch();
    let ops = 0;
    for (const doc of snap.docs) {
      batch.set(dstRef.collection(name).doc(doc.id), { ...doc.data(), _migrationMeta: meta });
      ops++;
      if (ops >= BATCH_SIZE) {
        batch = await flushBatch(batch, db);
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }
  return snap.size;
}

async function main() {
  const dryRun = !process.argv.includes('--force');
  const allowProduction = process.argv.includes('--allow-production');
  const emulator = process.env.FIRESTORE_EMULATOR_HOST;

  console.log('\nwekerala R1 Migration');
  console.log(`Mode    : ${dryRun ? 'DRY RUN (no writes)' : 'WRITE'}`);
  console.log(`Target  : ${emulator ? `emulator @ ${emulator}` : 'PRODUCTION'}`);

  if (!dryRun && !emulator && !allowProduction) {
    console.error('\nERROR: production write requires --allow-production flag.');
    console.error('Run against emulator first: set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080');
    process.exit(1);
  }

  const saJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!saJson) throw new Error('FIREBASE_SERVICE_ACCOUNT env var not set');
  if (!getApps().length) {
    initializeApp({ credential: cert(JSON.parse(saJson)) });
  }
  const db = getFirestore();

  // --- 1. Seed categories ---
  console.log('\n[1/3] Seeding categories...');
  for (const cat of CATEGORY_FIRESTORE_SEED) {
    if (!dryRun) await db.collection('categories').doc(cat.id).set(cat, { merge: true });
    console.log(`  ${dryRun ? '[dry]' : ' [ok]'} categories/${cat.id}`);
  }

  // --- 2. Load existing slugs to prevent collisions ---
  const takenSlugs = new Set<string>();
  const slugSnap = await db.collection('subdomainMappings').get();
  slugSnap.forEach((d) => takenSlugs.add(d.id));

  // --- 3. Migrate shops → merchants ---
  console.log('\n[2/3] Migrating shops...');
  const shopsSnap = await db.collection('shops').get();
  console.log(`  Found ${shopsSnap.size} shop(s)\n`);

  const stats = { migrated: 0, skipped: 0, errors: 0, requiresPhoneLink: 0 };

  for (const shopDoc of shopsSnap.docs) {
    const s = shopDoc.data();
    const shopId = shopDoc.id;

    try {
      // Slug
      const rawSlug = (s['shopSlug'] as string | undefined) || slugify((s['shopName'] as string) ?? shopId);
      let slug = validateSlug(rawSlug);
      if (!slug) {
        console.warn(`  [skip] shops/${shopId} — invalid slug: "${rawSlug}"`);
        stats.skipped++;
        continue;
      }
      if (takenSlugs.has(slug)) {
        let n = 2;
        while (takenSlugs.has(`${slug}-${n}`)) n++;
        slug = `${slug}-${n}`;
      }
      takenSlugs.add(slug);

      // requiresPhoneLink — per runbook: ownerId user with no phone field
      const ownerId = (s['ownerId'] as string | undefined) ?? '';
      let requiresPhoneLink = false;
      if (ownerId) {
        const userSnap = await db.collection('users').doc(ownerId).get();
        if (userSnap.exists) {
          const phone = userSnap.data()?.['phone'] as string | undefined;
          requiresPhoneLink = !phone;
        }
      }

      // Category + actionMode
      const shopType = (s['shopType'] as string | undefined) ?? '';
      const deliveryEnabled =
        s['deliveryEnabled'] === true ||
        s['deliveryType'] === 'delivery' ||
        s['deliveryType'] === 'both';
      const category = resolveCategory(shopType, deliveryEnabled);

      const now = new Date().toISOString();
      const meta: MigrationMeta = {
        sourceCollection: 'shops',
        sourceId: shopId,
        migratedAt: now,
        migratedBy: SCRIPT_VERSION,
      };

      const merchantRef = db.collection('merchants').doc();
      const merchantId = merchantRef.id;

      const merchantDoc: Record<string, unknown> = {
        merchantId,
        ownerId,
        category,
        name: (s['shopName'] as string) ?? '',
        nameMl: (s['shopNameMl'] as string) ?? '',
        slug,
        district: (s['district'] as string) ?? '',
        phone: (s['ownerPhone'] as string) ?? '',
        actionMode: 'order',
        isActive: (s['isActive'] ?? s['isOpen'] ?? true) as boolean,
        isApproved: (s['isApproved'] ?? s['linkActive'] ?? false) as boolean,
        createdAt: toIso(s['createdAt']),
        updatedAt: now,
        legacyShopId: shopId,
        _migrationMeta: meta,
      };

      // Optional profile fields
      const optionalStr = (key: string, target: string = key) => {
        const v = s[key] as string | undefined;
        if (v) merchantDoc[target] = v;
      };
      optionalStr('address');
      optionalStr('ownerWhatsApp', 'whatsApp');
      optionalStr('bannerImageUrl', 'bannerUrl');
      optionalStr('logoUrl');
      optionalStr('about');
      optionalStr('subscriptionStatus');
      optionalStr('deliveryTimeEstimate');
      if (s['trialStartDate']) merchantDoc['trialStartDate'] = toIso(s['trialStartDate']);
      if (s['trialEndDate']) merchantDoc['trialEndDate'] = toIso(s['trialEndDate']);
      if (s['totalOrders'] !== undefined) merchantDoc['totalOrders'] = s['totalOrders'];
      if (s['isVerified'] !== undefined) merchantDoc['isVerified'] = s['isVerified'];
      if (s['isFeatured'] !== undefined) merchantDoc['isFeatured'] = s['isFeatured'];
      if (Array.isArray(s['serviceTypes']) && (s['serviceTypes'] as unknown[]).length) {
        merchantDoc['serviceTypes'] = s['serviceTypes'];
      }
      if (Array.isArray(s['photos']) && (s['photos'] as unknown[]).length) {
        merchantDoc['photos'] = (s['photos'] as string[]).slice(0, 5);
      }

      // Delivery fields (order mode only)
      if (deliveryEnabled) {
        merchantDoc['deliveryEnabled'] = true;
        merchantDoc['minOrderValue'] = (s['minOrderValue'] as number) ?? 0;
        merchantDoc['deliveryCharge'] = (s['deliveryCharge'] ?? s['deliveryFee'] ?? 0) as number;
        if (Array.isArray(s['paymentMethods'])) merchantDoc['paymentMethods'] = s['paymentMethods'];
        if (s['upiId']) merchantDoc['upiId'] = s['upiId'];
      }

      if (requiresPhoneLink) merchantDoc['requiresPhoneLink'] = true;

      // Write merchant + subdomainMapping atomically
      if (!dryRun) {
        const batch = db.batch();
        batch.set(merchantRef, merchantDoc);
        batch.set(db.collection('subdomainMappings').doc(slug), {
          merchantId,
          createdAt: now,
        });
        await batch.commit();
      }

      // Copy subcollections
      const productCount = await copySubcollection(shopDoc.ref, merchantRef, 'products', meta, db, dryRun);
      const orderCount = await copySubcollection(shopDoc.ref, merchantRef, 'orders', meta, db, dryRun);

      if (requiresPhoneLink) stats.requiresPhoneLink++;
      stats.migrated++;

      const flag = requiresPhoneLink ? ' ⚠ requiresPhoneLink' : '';
      console.log(
        `  ${dryRun ? '[dry]' : ' [ok]'} ${shopId} → ${merchantId}` +
          `  slug:${slug}  products:${productCount}  orders:${orderCount}${flag}`,
      );
    } catch (err) {
      stats.errors++;
      console.error(`  [ERR] shops/${shopId} —`, (err as Error).message);
    }
  }

  // --- Summary ---
  console.log('\n[3/3] Summary');
  console.log(`  Migrated          : ${stats.migrated}`);
  console.log(`  Skipped           : ${stats.skipped}`);
  console.log(`  Errors            : ${stats.errors}`);
  console.log(`  requiresPhoneLink : ${stats.requiresPhoneLink}`);
  if (dryRun) {
    console.log('\n  DRY RUN complete — no data written.');
    console.log('  To write to emulator: set FIRESTORE_EMULATOR_HOST and pass --force');
  }
  if (stats.errors > 0) process.exit(1);
}

main().catch((err) => {
  console.error('\nFATAL:', err.message);
  process.exit(1);
});
