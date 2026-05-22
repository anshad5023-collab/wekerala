const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v) return parseFields(v.mapValue.fields ?? {});
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

export async function restGetDoc(path: string): Promise<{ data: Record<string, unknown>; id: string } | null> {
  const res = await fetch(`${BASE}/${path}?key=${API_KEY}`);
  if (res.status === 404 || res.status === 403) return null;
  if (!res.ok) throw new Error(`Firestore error ${res.status}`);
  const json = await res.json();
  return { data: parseFields(json.fields ?? {}), id: (json.name as string).split('/').pop()! };
}

export async function restListDocs(path: string): Promise<Array<{ data: Record<string, unknown>; id: string }>> {
  const res = await fetch(`${BASE}/${path}?key=${API_KEY}`);
  if (!res.ok) throw new Error(`Firestore error ${res.status}`);
  const json = await res.json();
  if (!Array.isArray(json.documents)) return [];
  return (json.documents as Array<{ name: string; fields: Record<string, FVal> }>).map((doc) => ({
    data: parseFields(doc.fields ?? {}),
    id: (doc.name as string).split('/').pop()!,
  }));
}

function toFVal(v: unknown): FVal {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (v === null || v === undefined) return { nullValue: null };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFVal) } };
  if (typeof v === 'object')
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, toFVal(val)])
        ),
      },
    };
  return { nullValue: null };
}

export async function restAddDoc(path: string, data: Record<string, unknown>): Promise<string> {
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toFVal(v)]));
  const res = await fetch(`${BASE}/${path}?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) throw new Error(`Firestore error ${res.status}`);
  const json = await res.json();
  return (json.name as string).split('/').pop()!;
}
