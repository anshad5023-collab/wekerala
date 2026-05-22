import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

export async function POST(req: NextRequest) {
  try {
    const { shopId, product } = await req.json() as { shopId: string; product: Record<string, string> };
    if (!shopId || !product?.name) {
      return NextResponse.json({ error: 'Missing shopId or product name' }, { status: 400 });
    }

    const productId = crypto.randomUUID();
    const fields = {
      name:        { stringValue: product.name },
      price:       { doubleValue: Number(product.price) || 0 },
      category:    { stringValue: product.category ?? '' },
      description: { stringValue: product.description ?? '' },
      imageUrl:    { stringValue: product.imageUrl ?? '' },
      available:   { booleanValue: true },
      createdAt:   { stringValue: new Date().toISOString() },
    };

    const res = await fetch(`${BASE}/shops/${shopId}/products/${productId}?key=${API_KEY}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) {
      const err = await res.text();
      return NextResponse.json({ error: err }, { status: 500 });
    }

    return NextResponse.json({ id: productId, success: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Failed to save product' }, { status: 500 });
  }
}
