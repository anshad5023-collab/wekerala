import { NextRequest, NextResponse } from 'next/server';
import { restGetDoc, restAddDoc } from '@/lib/firestore-rest';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal = { stringValue: string } | { booleanValue: boolean } | { nullValue: null };

export async function GET(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  if (!uid) return NextResponse.json({ error: 'uid required' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}/users/${uid}/addresses?key=${API_KEY}&pageSize=20`);
    if (!res.ok) return NextResponse.json({ addresses: [] });
    const json = await res.json() as { documents?: Array<{ name: string; fields: Record<string, FVal> }> };
    const addresses = (json.documents ?? []).map((doc) => ({
      id: doc.name.split('/').pop()!,
      label: (doc.fields.label as { stringValue: string })?.stringValue ?? '',
      address: (doc.fields.address as { stringValue: string })?.stringValue ?? '',
      isDefault: (doc.fields.isDefault as { booleanValue: boolean })?.booleanValue ?? false,
    }));
    return NextResponse.json({ addresses });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ addresses: [] });
  }
}

export async function POST(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  if (!uid) return NextResponse.json({ error: 'uid required' }, { status: 400 });

  try {
    const body = await req.json() as { label?: string; address?: string; isDefault?: boolean };
    const { label = 'Home', address, isDefault = false } = body;
    if (!address?.trim()) return NextResponse.json({ error: 'address required' }, { status: 400 });

    const id = await restAddDoc(`users/${uid}/addresses`, {
      label,
      address: address.trim(),
      isDefault,
      createdAt: new Date().toISOString(),
    });
    return NextResponse.json({ ok: true, id });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  const id = req.nextUrl.searchParams.get('id');
  if (!uid || !id) return NextResponse.json({ error: 'uid and id required' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}/users/${uid}/addresses/${id}?key=${API_KEY}`, { method: 'DELETE' });
    if (!res.ok) return NextResponse.json({ error: 'Failed to delete' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
