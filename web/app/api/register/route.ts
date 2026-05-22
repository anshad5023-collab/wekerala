import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const ALLOWED_COLLECTIONS = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty'];

function toFVal(v: unknown): unknown {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFVal) } };
  if (typeof v === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, toFVal(val)])
        ),
      },
    };
  }
  return { nullValue: null };
}

function toFields(data: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toFVal(v)]));
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json() as Record<string, unknown>;
    const str = (k: string) => ((body[k] as string) ?? '').trim();
    const arr = (k: string): string[] => Array.isArray(body[k]) ? (body[k] as string[]) : [];
    const num = (k: string): number | undefined => typeof body[k] === 'number' ? (body[k] as number) : undefined;
    const bool = (k: string): boolean => Boolean(body[k]);

    const collection = str('collection');
    const name = str('name');

    if (!collection || !ALLOWED_COLLECTIONS.includes(collection)) {
      return NextResponse.json({ error: 'Invalid collection' }, { status: 400 });
    }
    if (!name) {
      return NextResponse.json({ error: 'name is required' }, { status: 400 });
    }

    const data: Record<string, unknown> = {
      name,
      phone: str('phone'),
      district: str('district'),
      location: str('location'),
      description: str('description'),
      externalUrl: str('externalUrl'),
      ownerId: str('ownerId'),
      businessType: str('businessType') || collection,
      isApproved: false,
      createdAt: new Date().toISOString(),
    };

    switch (collection) {
      case 'services':
        data.serviceType = str('serviceType');
        data.experience = str('experience');
        data.priceRange = str('priceRange');
        data.availability = str('availability');
        data.serviceAreas = arr('serviceAreas');
        break;
      case 'theaters':
        data.theaterType = str('theaterType');
        data.screens = num('screens') ?? 1;
        data.ticketPriceRange = str('ticketPriceRange');
        data.facilities = arr('facilities');
        data.bookingUrl = str('bookingUrl');
        break;
      case 'hotels':
        data.hotelCategory = str('hotelCategory');
        data.pricePerNight = str('pricePerNight');
        data.amenities = arr('amenities');
        data.totalRooms = num('totalRooms');
        data.checkIn = str('checkIn');
        data.checkOut = str('checkOut');
        break;
      case 'restaurants':
        data.cuisineTypes = arr('cuisineTypes');
        data.diningOptions = arr('diningOptions');
        data.isVeg = str('isVeg');
        data.avgCostForTwo = str('avgCostForTwo');
        data.specialities = arr('specialities');
        break;
      case 'beauty':
        data.serviceList = arr('serviceList');
        data.gender = str('gender');
        data.homeVisitAvailable = bool('homeVisitAvailable');
        data.appointmentRequired = bool('appointmentRequired');
        data.priceRange = str('priceRange');
        break;
    }

    const fields = toFields(data);

    const res = await fetch(`${BASE}/${collection}?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error('Firestore create error:', err);
      return NextResponse.json({ error: 'Failed to create listing' }, { status: 500 });
    }

    const created = await res.json();
    const id = (created.name as string).split('/').pop() ?? '';

    return NextResponse.json({ success: true, id });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
