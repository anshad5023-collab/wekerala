import { NextRequest, NextResponse } from 'next/server';

function parseCSV(csv: string): Record<string, string>[] {
  const lines = csv.split('\n').filter((l) => l.trim());
  if (lines.length < 2) return [];
  const headers = lines[0].split(',').map((h) => h.trim().replace(/^"|"$/g, '').toLowerCase());
  return lines.slice(1).map((line) => {
    const values = line.split(',').map((v) => v.trim().replace(/^"|"$/g, ''));
    return Object.fromEntries(headers.map((h, i) => [h, values[i] ?? '']));
  }).filter((row) => row['name']);
}

export async function GET(req: NextRequest) {
  const url = req.nextUrl.searchParams.get('url');
  if (!url) return NextResponse.json({ error: 'Missing url' }, { status: 400 });

  const match = url.match(/\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/);
  if (!match) return NextResponse.json({ error: 'Invalid Google Sheets URL' }, { status: 400 });

  const sheetId = match[1];
  const csvUrl = `https://docs.google.com/spreadsheets/d/${sheetId}/export?format=csv`;

  try {
    const res = await fetch(csvUrl);
    if (!res.ok) return NextResponse.json({ error: 'Could not fetch sheet — make sure it is set to "Anyone with the link can view".' }, { status: 400 });

    const csv = await res.text();
    const rows = parseCSV(csv);
    const products = rows.map((row) => ({
      name:        row['name'] ?? '',
      price:       row['price'] ?? '0',
      category:    row['category'] ?? '',
      description: row['description'] ?? '',
      imageUrl:    row['imageurl'] ?? row['image url'] ?? row['image'] ?? '',
    })).filter((p) => p.name);

    return NextResponse.json({ products });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Failed to import sheet' }, { status: 500 });
  }
}
