import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { arrayValue: { values?: FVal[] } }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

type Suggestion = { label: string; type: 'tag' | 'business'; collection?: string; id?: string };

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get('q') ?? '';
  if (q.length < 2) return NextResponse.json({ suggestions: [] });

  const lower = q.toLowerCase();

  const [tagsRes, shopsRes, servicesRes, doctorsRes, homeRes] = await Promise.all([
    fetch(`${BASE}/serviceTags?pageSize=500&key=${API_KEY}`),
    fetch(`${BASE}/shops?pageSize=200&key=${API_KEY}`),
    fetch(`${BASE}/services?pageSize=200&key=${API_KEY}`),
    fetch(`${BASE}/doctors?pageSize=200&key=${API_KEY}`),
    fetch(`${BASE}/homeServices?pageSize=200&key=${API_KEY}`),
  ]);

  const suggestions: Suggestion[] = [];

  if (tagsRes.ok) {
    const json = await tagsRes.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];
    for (const doc of docs) {
      const f = parseFields(doc.fields ?? {});
      const name = (f['name'] as string) ?? '';
      if (name.toLowerCase().startsWith(lower)) {
        suggestions.push({ label: name, type: 'tag' });
      }
      if (suggestions.filter((s) => s.type === 'tag').length >= 4) break;
    }
  }

  const businessCollections: Array<{ res: Response; collection: string }> = [
    { res: shopsRes, collection: 'shops' },
    { res: servicesRes, collection: 'services' },
    { res: doctorsRes, collection: 'doctors' },
    { res: homeRes, collection: 'homeServices' },
  ];

  for (const { res, collection } of businessCollections) {
    if (!res.ok) continue;
    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];
    for (const doc of docs) {
      const f = parseFields(doc.fields ?? {});
      const name = (f['name'] as string) ?? (f['shopName'] as string) ?? (f['businessName'] as string) ?? '';
      const id = (doc.name as string).split('/').pop() ?? '';
      if (name.toLowerCase().startsWith(lower)) {
        suggestions.push({ label: name, type: 'business', collection, id });
      }
    }
  }

  const tagSuggestions = suggestions.filter((s) => s.type === 'tag').slice(0, 4);
  const bizSuggestions = suggestions.filter((s) => s.type === 'business').slice(0, 8 - tagSuggestions.length);

  return NextResponse.json({ suggestions: [...tagSuggestions, ...bizSuggestions].slice(0, 8) });
}
