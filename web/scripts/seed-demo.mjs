/**
 * Demo data seed script for ShopLink investor demo.
 * Uses Firebase Anonymous Auth to get a token for Firestore writes.
 * Run: node scripts/seed-demo.mjs
 */

const API_KEY = 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = 'shoplink-prod';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function str(v) { return { stringValue: v }; }
function num(v) { return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v }; }
function bool(v) { return { booleanValue: v }; }
function arr(items) { return { arrayValue: { values: items } }; }

async function getAuthToken() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    }
  );
  const json = await res.json();
  if (!res.ok) throw new Error('Auth failed: ' + JSON.stringify(json));
  return json.idToken;
}

async function createDoc(path, fields, token) {
  const res = await fetch(`${BASE}/${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({ fields }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error('Write failed: ' + JSON.stringify(json));
  return json.name.split('/').pop();
}

async function patchDoc(path, fields, token) {
  const fieldPaths = Object.keys(fields).map(k => `updateMask.fieldPaths=${k}`).join('&');
  await fetch(`${BASE}/${path}?${fieldPaths}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({ fields }),
  });
}

const PRODUCTS = [
  { nameEn: 'Jeerakasala Rice', nameMl: 'ജീരകശാല അരി', price: 120, offerPrice: 99, unit: 'kg', category: 'Grains' },
  { nameEn: 'Ponni Rice 5kg', nameMl: 'പൊന്നി അരി', price: 280, offerPrice: 250, unit: 'kg', category: 'Grains' },
  { nameEn: 'Coconut Oil 1L', nameMl: 'വെളിച്ചെണ്ണ', price: 195, offerPrice: 175, unit: 'litre', category: 'Oil' },
  { nameEn: 'Sunflower Oil 1L', nameMl: 'സൂര്യകാന്തി എണ്ണ', price: 155, offerPrice: 140, unit: 'litre', category: 'Oil' },
  { nameEn: 'Toor Dal 500g', nameMl: 'തുവർ പരിപ്പ്', price: 85, offerPrice: 75, unit: 'kg', category: 'Pulses' },
  { nameEn: 'Moong Dal 500g', nameMl: 'ചെറുപയർ', price: 90, offerPrice: 0, unit: 'kg', category: 'Pulses' },
  { nameEn: 'Fresh Tomato 1kg', nameMl: 'തക്കാളി', price: 45, offerPrice: 38, unit: 'kg', category: 'Vegetables' },
  { nameEn: 'Onion 1kg', nameMl: 'സവോള', price: 35, offerPrice: 0, unit: 'kg', category: 'Vegetables' },
  { nameEn: 'Potato 1kg', nameMl: 'ഉരുളക്കിഴങ്ങ്', price: 40, offerPrice: 35, unit: 'kg', category: 'Vegetables' },
  { nameEn: 'Nendran Banana (dozen)', nameMl: 'നേന്ത്രക്കായ', price: 80, offerPrice: 70, unit: 'piece', category: 'Fruits' },
  { nameEn: 'Fresh Coconut', nameMl: 'ഇളനീർ', price: 30, offerPrice: 0, unit: 'piece', category: 'Fruits' },
  { nameEn: 'Fresh Milk 500ml', nameMl: 'പാൽ', price: 30, offerPrice: 0, unit: 'litre', category: 'Dairy' },
  { nameEn: 'Curd 400g', nameMl: 'തൈര്', price: 35, offerPrice: 0, unit: 'kg', category: 'Dairy' },
  { nameEn: 'Eggs (12 pcs)', nameMl: 'മുട്ട', price: 90, offerPrice: 82, unit: 'piece', category: 'Eggs' },
  { nameEn: 'Turmeric Powder 100g', nameMl: 'മഞ്ഞൾ പൊടി', price: 35, offerPrice: 28, unit: 'kg', category: 'Spices' },
  { nameEn: 'Chilli Powder 100g', nameMl: 'മുളകുപൊടി', price: 40, offerPrice: 35, unit: 'kg', category: 'Spices' },
  { nameEn: 'Wheat Bread', nameMl: 'ബ്രഡ്', price: 42, offerPrice: 0, unit: 'piece', category: 'Bakery' },
  { nameEn: 'Tea Powder 250g', nameMl: 'ചായ പൊടി', price: 115, offerPrice: 99, unit: 'kg', category: 'Beverages' },
  { nameEn: 'Sugar 1kg', nameMl: 'പഞ്ചസാര', price: 58, offerPrice: 0, unit: 'kg', category: 'Grains' },
  { nameEn: 'Lifebuoy Soap', nameMl: 'സോപ്പ്', price: 45, offerPrice: 38, unit: 'piece', category: 'Personal' },
];

async function main() {
  console.log('🔐 Getting Firebase auth token (anonymous)...');
  const token = await getAuthToken();
  console.log('✅ Authenticated');

  console.log('🚀 Creating demo shop...');
  const shopFields = {
    shopName: str("Nair's Supermarket"),
    shopNameMl: str('നായർ സൂപ്പർ മാർക്കറ്റ്'),
    ownerWhatsApp: str('919876543210'),
    logoUrl: str(''),
    bannerImageUrl: str(''),
    isOpen: bool(true),
    categories: arr(['Grains','Vegetables','Fruits','Dairy','Oil','Pulses','Spices','Bakery','Beverages','Personal','Eggs'].map(str)),
    paymentMethods: arr([str('cash'), str('upi')]),
    deliveryEnabled: bool(true),
    minOrderAmount: num(150),
    deliveryCharge: num(30),
    themeColor: str('#22c55e'),
    deliveryTimeEstimate: str('30–45 min'),
    promotionalBanner: str('🎉 Free delivery on orders above ₹500!'),
    shopArea: str('Thrissur, Kerala'),
    shopType: str('Grocery'),
    isApproved: bool(true),
  };

  const shopId = await createDoc('shops', shopFields, token);
  console.log(`✅ Shop created: ${shopId}`);

  for (const p of PRODUCTS) {
    const fields = {
      productId: str(''),
      nameEn: str(p.nameEn),
      nameMl: str(p.nameMl),
      price: num(p.price),
      offerPrice: num(p.offerPrice),
      unit: str(p.unit),
      category: str(p.category),
      imageUrl: str(''),
      isOutOfStock: bool(false),
      variants: arr([]),
    };
    const pid = await createDoc(`shops/${shopId}/products`, fields, token);
    await patchDoc(`shops/${shopId}/products/${pid}`, { productId: str(pid) }, token);
    console.log(`   📦 ${p.nameEn}`);
  }

  console.log('\n🎉 Done! Open the demo shop:');
  console.log(`   https://web-phi-puce-84.vercel.app/?shopId=${shopId}`);
}

main().catch(err => { console.error('\n❌ Error:', err.message); process.exit(1); });
