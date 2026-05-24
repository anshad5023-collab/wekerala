import { NextRequest, NextResponse } from 'next/server'

// ---------------------------------------------------------------------------
// Firebase Storage upload via service account OAuth2 access token.
//
// WHY service account instead of API key alone:
//   The bucket (shoplink-prod.firebasestorage.app) uses authenticated storage
//   rules. Sending the API key as ?key= only grants access when Storage rules
//   allow public reads/writes. Using a service account access token works
//   regardless of rules and is the correct server-side pattern.
//
// HOW it works:
//   1. Build a signed JWT from the service account credentials.
//   2. Exchange it for a short-lived Google OAuth2 access token.
//   3. Use that token as a Bearer in the Firebase Storage REST upload call.
// ---------------------------------------------------------------------------

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '')
const BUCKET = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ?? `${PROJECT_ID}.firebasestorage.app`

// ---------------------------------------------------------------------------
// JWT / token helpers (no external libraries — pure Node.js crypto via
// the Web Crypto API available in Next.js Edge-compatible runtimes, but we
// use the standard Node.js `crypto` here since this is a Node.js route).
// ---------------------------------------------------------------------------

/** Base64url encode a Buffer or Uint8Array */
function b64url(input: Buffer | Uint8Array): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

/**
 * Create a signed JWT for the Google OAuth2 token endpoint using the
 * service account private key (RS256).
 */
async function createServiceAccountJwt(serviceAccount: {
  client_email: string
  private_key: string
}): Promise<string> {
  const { createSign } = await import('crypto')

  const header = b64url(Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))

  const now = Math.floor(Date.now() / 1000)
  const payload = b64url(
    Buffer.from(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: 'https://www.googleapis.com/auth/devstorage.read_write',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      })
    )
  )

  const signingInput = `${header}.${payload}`

  const sign = createSign('RSA-SHA256')
  sign.update(signingInput)
  // The private key in .env has literal \n — restore real newlines
  const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')
  const signature = b64url(sign.sign(privateKey))

  return `${signingInput}.${signature}`
}

/**
 * Exchange a signed JWT for a Google OAuth2 Bearer access token.
 * The token is valid for ~1 hour; for a serverless function a fresh token
 * per request is fine (no persistent state between invocations).
 */
async function getAccessToken(): Promise<string> {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT
  if (!serviceAccountJson) throw new Error('FIREBASE_SERVICE_ACCOUNT not configured')

  const serviceAccount = JSON.parse(serviceAccountJson) as {
    client_email: string
    private_key: string
  }

  const jwt = await createServiceAccountJwt(serviceAccount)

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!tokenRes.ok) {
    const err = await tokenRes.text()
    throw new Error(`Failed to get access token: ${err}`)
  }

  const tokenData = (await tokenRes.json()) as { access_token: string }
  return tokenData.access_token
}

// ---------------------------------------------------------------------------
// POST /api/upload
// multipart/form-data fields:
//   file    — the image File (required)
//   shopId  — shop document ID used to build the storage path (required)
//   uid     — Firebase Auth UID of the caller (required for ownership check)
// ---------------------------------------------------------------------------

export async function POST(request: NextRequest) {
  // 1. Parse multipart form data
  let formData: FormData
  try {
    formData = await request.formData()
  } catch {
    return NextResponse.json({ error: 'Invalid multipart form data' }, { status: 400 })
  }

  const file = formData.get('file') as File | null
  const shopId = (formData.get('shopId') as string | null)?.trim()
  const uid = (formData.get('uid') as string | null)?.trim()

  // 2. Validate required fields
  if (!file || !shopId) {
    return NextResponse.json({ error: 'Missing file or shopId' }, { status: 400 })
  }

  if (!uid) {
    return NextResponse.json({ error: 'Missing uid' }, { status: 400 })
  }

  // 3. Verify the caller owns this shop (Firestore REST — same pattern as other routes)
  const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY
  if (!API_KEY) {
    return NextResponse.json({ error: 'API key not configured' }, { status: 500 })
  }

  const BASE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`
  const shopRes = await fetch(`${BASE_REST}/shops/${shopId}?key=${API_KEY}`, { cache: 'no-store' })
  if (!shopRes.ok) {
    return NextResponse.json({ error: 'Shop not found' }, { status: 404 })
  }
  const shopJson = (await shopRes.json()) as { fields?: Record<string, { stringValue?: string }> }
  const ownerId = shopJson.fields?.['ownerId']?.stringValue ?? ''
  if (ownerId !== uid) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  // 4. Validate file type
  if (!file.type.startsWith('image/')) {
    return NextResponse.json({ error: 'Only image files are allowed' }, { status: 400 })
  }

  // 5. Validate file size (max 5 MB)
  if (file.size > 5 * 1024 * 1024) {
    return NextResponse.json({ error: 'File too large (max 5 MB)' }, { status: 400 })
  }

  // 6. Upload to Firebase Storage via REST API
  try {
    const bytes = await file.arrayBuffer()
    const buffer = Buffer.from(bytes)

    // Build a unique, organised storage path: shops/{shopId}/images/{timestamp}.{ext}
    const ext = (file.name.split('.').pop() ?? 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '')
    const safeExt = ext || 'jpg'
    const timestamp = Date.now()
    const storagePath = `shops/${shopId}/images/${timestamp}.${safeExt}`
    const encodedPath = encodeURIComponent(storagePath)

    // Get a short-lived access token from the service account
    let accessToken: string
    try {
      accessToken = await getAccessToken()
    } catch (tokenErr) {
      console.error('[Upload] Failed to get access token:', tokenErr)
      return NextResponse.json({ error: 'Storage authentication failed' }, { status: 500 })
    }

    // Firebase Storage REST upload endpoint (media upload)
    // POST https://firebasestorage.googleapis.com/v0/b/{bucket}/o?uploadType=media&name={encoded-path}
    const uploadUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?uploadType=media&name=${encodedPath}`

    const uploadRes = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': file.type,
        'Content-Length': buffer.length.toString(),
      },
      body: buffer,
    })

    if (!uploadRes.ok) {
      const errText = await uploadRes.text()
      console.error('[Upload] Firebase Storage error:', uploadRes.status, errText)
      return NextResponse.json({ error: 'Upload to storage failed' }, { status: 500 })
    }

    await uploadRes.json() // consume the response body (contains metadata)

    // Build the public download URL.
    // alt=media makes Firebase Storage return the raw file bytes (public-readable URL).
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodedPath}?alt=media`

    return NextResponse.json({
      ok: true,
      url: downloadUrl,
      path: storagePath,
    })
  } catch (error) {
    console.error('[Upload] Unexpected error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
}

