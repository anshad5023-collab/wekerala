const fs = require('fs');
const path = require('path');

function write(filePath, content) {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(filePath, content);
  console.log('Created:', filePath);
}

// ═══════════════════════════════════════════════════════
// 1. CLAUDE.md — Auto-read by Claude Code every session
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/CLAUDE.md', `# ShopLink — Claude Code Instructions

> This file is read automatically by Claude Code at the start of every session.
> Follow ALL instructions here before doing anything else.

---

## WHO YOU ARE IN THIS PROJECT

You are the lead developer of ShopLink — a Flutter Android app for Kerala small shop owners.
Full specification is in SHOPLINK_SPEC.md. Read it completely before writing any code.

---

## RULES — FOLLOW EVERY SESSION

1. **Read SHOPLINK_SPEC.md first** — every field name, route, and feature is defined there
2. **Never hardcode values** — all config goes in lib/core/constants/app_config.dart and loads from .env
3. **One feature at a time** — complete and test before moving to next
4. **Use free tools first** — see FREE TOOLS section below
5. **Modular code** — every feature in its own folder as defined in the spec
6. **Both languages** — every UI string must have English and Malayalam versions in assets/translations/
7. **Test on real device** — remind the user to test on phone after each feature
8. **Commit after each phase** — remind user: git add . && git commit -m "Phase X complete"
9. **Ask before deciding** — if the spec doesn't cover something, ask the user before implementing

---

## FREE TOOLS TO USE (saves tokens — use these instead of writing from scratch)

### Firebase CLI (already configured in this project)
\`\`\`bash
firebase deploy --only hosting        # Deploy storefront
firebase deploy --only firestore:rules # Deploy security rules
firebase deploy --only storage        # Deploy storage rules
firebase emulators:start              # Local testing without real Firebase
\`\`\`

### FlutterFire CLI
\`\`\`bash
flutterfire configure                 # Reconfigure Firebase if needed
\`\`\`

### GitHub Actions (see .github/workflows/)
- build-apk.yml         — Builds release APK automatically on every push
- deploy-storefront.yml — Deploys PWA storefront to Firebase Hosting
- deploy-rules.yml      — Deploys Firestore + Storage rules
- test.yml              — Runs Flutter tests

### Make commands (see Makefile)
\`\`\`bash
make setup      # First time setup — installs all dependencies
make run        # Run app on connected phone
make build      # Build release APK
make deploy     # Deploy storefront + rules to Firebase
make test       # Run all tests
make clean      # Clean build cache
\`\`\`

### Free APIs in use
- Unsplash API (product images) — key in .env
- Google Sheets API (product import) — key in .env
- Firebase all services — project config in .env

---

## ENVIRONMENT VARIABLES

All secrets come from .env file. Never hardcode. Use flutter_dotenv to load.
See .env.example for all required variables.

In code, access like:
\`\`\`dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
final apiKey = dotenv.env['UNSPLASH_API_KEY']!;
\`\`\`

---

## CURRENT BUILD STATUS

Track progress here. Update this section as phases complete.

- [ ] Phase 0 — Setup
- [ ] Phase 1 — Authentication
- [ ] Phase 2 — Onboarding
- [ ] Phase 3 — Product Management
- [ ] Phase 4 — Customer PWA Storefront
- [ ] Phase 5 — Orders & Notifications
- [ ] Phase 6 — Analytics, Share, Help
- [ ] Phase 7 — OTA Updates & Admin Panel
- [ ] Phase 8 — Polish & Pilot

---

## GIT WORKFLOW

\`\`\`bash
git add .
git commit -m "Phase X: description of what was built"
git push origin main
\`\`\`

Pushing to main triggers GitHub Actions automatically.

---

## WHEN STUCK

1. Check SHOPLINK_SPEC.md — the answer is probably there
2. Check .env.example — missing environment variable?
3. Run: firebase emulators:start — test without real Firebase
4. Run: flutter analyze — find code issues
5. Ask the user for clarification — do not guess

---

*Read SHOPLINK_SPEC.md now before doing anything else.*
`);

// ═══════════════════════════════════════════════════════
// 2. .env.example
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.env.example', `# ============================================================
# ShopLink Environment Variables
# ============================================================
# INSTRUCTIONS:
# 1. Copy this file and rename it to .env
# 2. Fill in all values below
# 3. NEVER commit .env to git (it is in .gitignore)
# 4. Share .env only with trusted team members directly
# ============================================================

# ── Firebase Configuration ──────────────────────────────────
# Get these from: Firebase Console > Project Settings > Your Apps > Flutter
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=
FIREBASE_PROJECT_ID=
FIREBASE_STORAGE_BUCKET=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_APP_ID=
FIREBASE_MEASUREMENT_ID=

# ── Unsplash API (Free — product auto-images) ────────────────
# Get from: https://unsplash.com/developers > New Application
# Free tier: 50 requests/hour (enough for development)
UNSPLASH_ACCESS_KEY=
UNSPLASH_SECRET_KEY=

# ── Google APIs (Free — Sheets import) ──────────────────────
# Get from: https://console.cloud.google.com > APIs > Credentials
# Enable: Google Sheets API
GOOGLE_SHEETS_API_KEY=

# ── Admin Panel ──────────────────────────────────────────────
# Set these yourself — used to log into admin.shoplink.in
ADMIN_EMAIL=
ADMIN_PASSWORD=

# ── App Config ───────────────────────────────────────────────
# Your UPI ID where shop owners pay ₹99/month
SHOPLINK_UPI_ID=

# Your WhatsApp number for owner support (include country code, no +)
SUPPORT_WHATSAPP=91XXXXXXXXXX

# Base URL of the storefront (Firebase Hosting URL)
STOREFRONT_BASE_URL=https://shoplink-prod.web.app

# Admin panel URL
ADMIN_URL=https://admin-shoplink-prod.web.app

# ── APK / OTA Updates ────────────────────────────────────────
# Current app version — update this before each release
APP_VERSION=1.0.0

# Firebase Storage path where APK is uploaded for OTA
APK_STORAGE_PATH=apk/shoplink-latest.apk

# ── Development Flags ─────────────────────────────────────────
# Set to true during development, false for production builds
USE_FIREBASE_EMULATOR=false
DEBUG_MODE=true
`);

// ═══════════════════════════════════════════════════════
// 3. .gitignore
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.gitignore', `# Environment — NEVER commit this
.env
*.env
!.env.example

# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.g.dart
*.freezed.dart

# Android
android/local.properties
android/key.properties
android/*.jks
android/app/google-services.json

# Firebase
.firebase/
firebase-debug.log
firestore-debug.log
storage-debug.log

# VS Code
.vscode/settings.json
.vscode/launch.json

# MacOS / Windows
.DS_Store
Thumbs.db

# APK files (too large for git)
*.apk
*.aab
`);

// ═══════════════════════════════════════════════════════
// 4. Makefile
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/Makefile', `# ShopLink — Developer Shortcuts
# Usage: make <command>

.PHONY: setup run build deploy test clean emulator

# First-time setup
setup:
	flutter pub get
	dart run build_runner build --delete-conflicting-outputs
	firebase login
	@echo "✅ Setup complete. Now run: make run"

# Run on connected Android phone
run:
	flutter run --dart-define-from-file=.env

# Run with hot reload in debug mode
dev:
	flutter run --debug --dart-define-from-file=.env

# Build release APK
build:
	flutter build apk --release --dart-define-from-file=.env
	@echo "✅ APK built: build/app/outputs/flutter-apk/app-release.apk"

# Build and copy APK to desktop for easy sharing
build-share:
	flutter build apk --release --dart-define-from-file=.env
	cp build/app/outputs/flutter-apk/app-release.apk ~/Desktop/ShopLink.apk
	@echo "✅ APK copied to Desktop"

# Deploy storefront + rules to Firebase
deploy:
	firebase deploy --only hosting,firestore:rules,storage
	@echo "✅ Deployed to Firebase"

# Deploy only the PWA storefront
deploy-hosting:
	firebase deploy --only hosting

# Deploy only Firestore rules
deploy-rules:
	firebase deploy --only firestore:rules,storage

# Run Flutter tests
test:
	flutter test

# Run Flutter analyzer
analyze:
	flutter analyze

# Start Firebase emulators for local testing
emulator:
	firebase emulators:start --import=./emulator-data --export-on-exit

# Generate Riverpod code
codegen:
	dart run build_runner build --delete-conflicting-outputs

# Watch and auto-generate Riverpod code
codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs

# Clean build cache
clean:
	flutter clean
	flutter pub get
	@echo "✅ Clean complete"

# Upload APK to Firebase Storage for OTA
upload-apk:
	firebase storage:upload build/app/outputs/flutter-apk/app-release.apk apk/shoplink-latest.apk
	@echo "✅ APK uploaded for OTA distribution"

# Update version in Firebase Remote Config (triggers OTA on user devices)
release VERSION:
	firebase remoteconfig:set latestApkVersion=$(VERSION)
	@echo "✅ Version $(VERSION) set in Remote Config — users will see update prompt"
`);

// ═══════════════════════════════════════════════════════
// 5. GitHub Actions — Build APK
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.github/workflows/build-apk.yml', `name: Build Release APK

on:
  push:
    branches: [main]
    tags:
      - 'v*'
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
          channel: 'stable'
          cache: true

      - name: Create .env file
        run: |
          cat > .env << EOF
          FIREBASE_API_KEY=\${{ secrets.FIREBASE_API_KEY }}
          FIREBASE_AUTH_DOMAIN=\${{ secrets.FIREBASE_AUTH_DOMAIN }}
          FIREBASE_PROJECT_ID=\${{ secrets.FIREBASE_PROJECT_ID }}
          FIREBASE_STORAGE_BUCKET=\${{ secrets.FIREBASE_STORAGE_BUCKET }}
          FIREBASE_MESSAGING_SENDER_ID=\${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}
          FIREBASE_APP_ID=\${{ secrets.FIREBASE_APP_ID }}
          UNSPLASH_ACCESS_KEY=\${{ secrets.UNSPLASH_ACCESS_KEY }}
          GOOGLE_SHEETS_API_KEY=\${{ secrets.GOOGLE_SHEETS_API_KEY }}
          SHOPLINK_UPI_ID=\${{ secrets.SHOPLINK_UPI_ID }}
          SUPPORT_WHATSAPP=\${{ secrets.SUPPORT_WHATSAPP }}
          STOREFRONT_BASE_URL=\${{ secrets.STOREFRONT_BASE_URL }}
          APP_VERSION=\${{ github.ref_name }}
          USE_FIREBASE_EMULATOR=false
          DEBUG_MODE=false
          EOF

      - name: Create google-services.json
        run: echo '\${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code (Riverpod)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze code
        run: flutter analyze

      - name: Run tests
        run: flutter test

      - name: Build release APK
        run: flutter build apk --release --dart-define-from-file=.env

      - name: Upload APK as artifact
        uses: actions/upload-artifact@v4
        with:
          name: ShopLink-APK-\${{ github.sha }}
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 30

      - name: Upload APK to Firebase Storage (on tag only)
        if: startsWith(github.ref, 'refs/tags/')
        uses: FirebaseExtended/action-hosting-deploy@v0
        env:
          FIREBASE_CLI_EXPERIMENTS: webframeworks
        run: |
          npm install -g firebase-tools
          firebase storage:upload \\
            build/app/outputs/flutter-apk/app-release.apk \\
            apk/shoplink-latest.apk \\
            --project \${{ secrets.FIREBASE_PROJECT_ID }}
          firebase remoteconfig:set latestApkVersion=\${{ github.ref_name }} \\
            --project \${{ secrets.FIREBASE_PROJECT_ID }}
        env:
          FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
`);

// ═══════════════════════════════════════════════════════
// 6. GitHub Actions — Deploy Storefront
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.github/workflows/deploy-storefront.yml', `name: Deploy Customer Storefront

on:
  push:
    branches: [main]
    paths:
      - 'storefront/**'
      - 'firebase.json'
      - '.firebaserc'

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Firebase CLI
        run: npm install -g firebase-tools

      - name: Deploy to Firebase Hosting
        run: firebase deploy --only hosting --project \${{ secrets.FIREBASE_PROJECT_ID }}
        env:
          FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
`);

// ═══════════════════════════════════════════════════════
// 7. GitHub Actions — Deploy Rules
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.github/workflows/deploy-rules.yml', `name: Deploy Firebase Rules

on:
  push:
    branches: [main]
    paths:
      - 'firestore.rules'
      - 'storage.rules'

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Firebase CLI
        run: npm install -g firebase-tools

      - name: Deploy Firestore Rules
        run: firebase deploy --only firestore:rules,storage --project \${{ secrets.FIREBASE_PROJECT_ID }}
        env:
          FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
`);

// ═══════════════════════════════════════════════════════
// 8. GitHub Actions — Flutter Tests
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.github/workflows/test.yml', `name: Flutter Tests

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Create minimal .env for tests
        run: |
          cat > .env << EOF
          FIREBASE_API_KEY=test
          FIREBASE_PROJECT_ID=test-project
          FIREBASE_STORAGE_BUCKET=test.appspot.com
          UNSPLASH_ACCESS_KEY=test
          GOOGLE_SHEETS_API_KEY=test
          SHOPLINK_UPI_ID=test@upi
          SUPPORT_WHATSAPP=911234567890
          STOREFRONT_BASE_URL=https://test.web.app
          APP_VERSION=0.0.1
          USE_FIREBASE_EMULATOR=true
          DEBUG_MODE=true
          EOF

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
`);

// ═══════════════════════════════════════════════════════
// 9. MCP Configuration for Claude Code
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.claude/mcp.json', `{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."],
      "description": "Read and write project files"
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "\${GITHUB_TOKEN}"
      },
      "description": "GitHub — create issues, PRs, check Actions status"
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "description": "Break complex tasks into steps before coding"
    }
  }
}
`);

// ═══════════════════════════════════════════════════════
// 10. Claude Code settings
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/.claude/settings.json', `{
  "model": "claude-sonnet-4-6",
  "context": {
    "files": [
      "CLAUDE.md",
      "SHOPLINK_SPEC.md",
      ".env.example"
    ]
  },
  "tools": {
    "bash": true,
    "filesystem": true,
    "mcp": true
  }
}
`);

// ═══════════════════════════════════════════════════════
// 11. firebase.json
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/firebase.json', `{
  "hosting": [
    {
      "target": "storefront",
      "public": "storefront/build",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        { "source": "**", "destination": "/index.html" }
      ],
      "headers": [
        {
          "source": "**/*.@(js|css|wasm)",
          "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
        },
        {
          "source": "**",
          "headers": [
            { "key": "X-Frame-Options", "value": "DENY" },
            { "key": "X-Content-Type-Options", "value": "nosniff" }
          ]
        }
      ]
    },
    {
      "target": "admin",
      "public": "admin/build",
      "ignore": ["firebase.json", "**/.*"],
      "rewrites": [
        { "source": "**", "destination": "/index.html" }
      ]
    }
  ],
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "hosting": { "port": 5000 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
`);

// ═══════════════════════════════════════════════════════
// 12. firestore.rules
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/firestore.rules', `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── Users ──────────────────────────────────────────
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // ── Shops ──────────────────────────────────────────
    match /shops/{shopId} {
      // Storefront is public — anyone can read shop info
      allow read: if true;
      // Only the owner can modify shop details
      allow write: if request.auth != null &&
                      request.auth.uid == resource.data.ownerId;

      // ── Products (under shop) ───────────────────────
      match /products/{productId} {
        // Public read — customers browse products
        allow read: if true;
        // Only shop owner can modify products
        allow write: if request.auth != null &&
                        request.auth.uid == get(
                          /databases/$(database)/documents/shops/$(shopId)
                        ).data.ownerId;
      }

      // ── Orders (under shop) ─────────────────────────
      match /orders/{orderId} {
        // Anyone can create an order (customers place orders)
        allow create: if true;
        // Only shop owner can read and update order status
        allow read, update: if request.auth != null &&
                               request.auth.uid == get(
                                 /databases/$(database)/documents/shops/$(shopId)
                               ).data.ownerId;
      }
    }

    // ── Admin Config (read-only for app) ───────────────
    match /admin/{document=**} {
      allow read: if true;
      allow write: if false; // Only via Firebase Console or Admin SDK
    }
  }
}
`);

// ═══════════════════════════════════════════════════════
// 13. storage.rules
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/storage.rules', `rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Shop images — owner can upload, everyone can read
    match /shops/{shopId}/{allImages=**} {
      allow read: if true;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024  // Max 5MB
                   && request.resource.contentType.matches('image/.*');
    }

    // APK files — anyone can download, no upload from app
    match /apk/{fileName} {
      allow read: if true;
      allow write: if false; // Only uploaded via Firebase CLI / GitHub Actions
    }
  }
}
`);

// ═══════════════════════════════════════════════════════
// 14. firestore.indexes.json
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/firestore.indexes.json', `{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "shopId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "shopId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "shopId", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "isHidden", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
`);

// ═══════════════════════════════════════════════════════
// 15. Setup Guide (HOW_TO_SETUP.md)
// ═══════════════════════════════════════════════════════
write('/home/claude/shoplink_project/HOW_TO_SETUP.md', `# ShopLink — Complete Setup Guide
## Do this ONCE before starting Claude Code

---

## STEP 1 — Install Required Software (Windows)

Open PowerShell as Administrator and run each:

\`\`\`powershell
# 1. Install Git
winget install Git.Git

# 2. Install Node.js (for Firebase CLI)
winget install OpenJS.NodeJS.LTS

# 3. Install Flutter
winget install Google.Flutter

# 4. Install Java 17 (for Android builds)
winget install EclipseAdoptium.Temurin.17.JDK

# Restart PowerShell after installing
\`\`\`

Verify everything works:
\`\`\`powershell
git --version       # Should show: git version 2.x
node --version      # Should show: v20.x
flutter --version   # Should show: Flutter 3.x
java --version      # Should show: openjdk 17
\`\`\`

---

## STEP 2 — Install Firebase CLI and Claude Code

\`\`\`powershell
npm install -g firebase-tools
npm install -g @anthropic-ai/claude-code
npm install -g flutterfire_cli

# Verify
firebase --version
claude --version
\`\`\`

---

## STEP 3 — Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project" → Name it: **shoplink-prod**
3. Disable Google Analytics (not needed for MVP)
4. Click "Create project"

Enable these services in Firebase Console:
- **Authentication** → Sign-in methods → Phone → Enable
- **Firestore Database** → Create database → Start in production mode → Region: asia-south1
- **Storage** → Get started → Region: asia-south1
- **Hosting** → Get started (follow steps)
- **Cloud Messaging** → Already enabled by default

---

## STEP 4 — Set Up GitHub Repository

1. Go to https://github.com/new
2. Create repository named: **shoplink**
3. Set to Private
4. Do NOT initialize with README (we have our files)

\`\`\`powershell
cd Desktop
mkdir shoplink
cd shoplink
git init
git remote add origin https://github.com/YOUR_USERNAME/shoplink.git
\`\`\`

---

## STEP 5 — Copy Project Files

Copy all files from this folder into your shoplink project folder:
- CLAUDE.md
- SHOPLINK_SPEC.md
- HOW_TO_SETUP.md
- .env.example
- .gitignore
- Makefile
- firebase.json
- firestore.rules
- firestore.indexes.json
- storage.rules
- .github/ (folder)
- .claude/ (folder)

---

## STEP 6 — Create Flutter Project Inside shoplink Folder

\`\`\`powershell
# Inside your shoplink folder:
flutter create . --org com.shoplink --project-name shoplink
\`\`\`

---

## STEP 7 — Connect Firebase to Flutter

\`\`\`powershell
firebase login
flutterfire configure --project=shoplink-prod
\`\`\`

Select Android when asked. This creates android/app/google-services.json automatically.

---

## STEP 8 — Create Your .env File

1. Copy .env.example → rename to .env
2. Fill in ALL values:

| Variable | Where to get it |
|---|---|
| FIREBASE_API_KEY | Firebase Console > Project Settings > Your apps |
| FIREBASE_AUTH_DOMAIN | Same place |
| FIREBASE_PROJECT_ID | shoplink-prod |
| FIREBASE_STORAGE_BUCKET | Same place |
| FIREBASE_MESSAGING_SENDER_ID | Same place |
| FIREBASE_APP_ID | Same place |
| UNSPLASH_ACCESS_KEY | https://unsplash.com/developers → New App |
| GOOGLE_SHEETS_API_KEY | https://console.cloud.google.com → APIs → Sheets API → Credentials |
| SHOPLINK_UPI_ID | Your own UPI ID (e.g. yourname@gpay) |
| SUPPORT_WHATSAPP | Your WhatsApp number with country code (e.g. 919876543210) |
| STOREFRONT_BASE_URL | https://shoplink-prod.web.app |
| ADMIN_EMAIL | Email you want for admin login |
| ADMIN_PASSWORD | Strong password for admin |

---

## STEP 9 — Add GitHub Secrets

Go to: GitHub → Your repo → Settings → Secrets and variables → Actions → New secret

Add ALL of these secrets (same values as your .env file):

- FIREBASE_API_KEY
- FIREBASE_AUTH_DOMAIN
- FIREBASE_PROJECT_ID
- FIREBASE_STORAGE_BUCKET
- FIREBASE_MESSAGING_SENDER_ID
- FIREBASE_APP_ID
- UNSPLASH_ACCESS_KEY
- GOOGLE_SHEETS_API_KEY
- SHOPLINK_UPI_ID
- SUPPORT_WHATSAPP
- STOREFRONT_BASE_URL
- GOOGLE_SERVICES_JSON  ← Paste entire contents of android/app/google-services.json
- FIREBASE_TOKEN  ← Get by running: firebase login:ci

---

## STEP 10 — First Commit

\`\`\`powershell
git add .
git commit -m "Initial project setup"
git push -u origin main
\`\`\`

Go to GitHub → Actions tab → You should see the workflow running.

---

## STEP 11 — Start Claude Code

\`\`\`powershell
# In VS Code terminal, inside shoplink folder:
claude

# Claude Code will automatically read CLAUDE.md
# Then paste this message:
\`\`\`

\`\`\`
We are building ShopLink. You have already read CLAUDE.md and SHOPLINK_SPEC.md.
Today's task: Phase 0 — create the exact Flutter folder structure from the spec
and set up pubspec.yaml with all required packages.
Ask me before making any decision not covered in the spec.
\`\`\`

---

## DAILY WORKFLOW (after setup is done)

\`\`\`powershell
# 1. Open VS Code in shoplink folder
code .

# 2. Start Claude Code
claude

# 3. Tell Claude Code what phase to work on today
# Claude Code reads CLAUDE.md automatically

# 4. Test on phone
flutter run --dart-define-from-file=.env

# 5. Commit when done
git add .
git commit -m "Phase X: what was built"
git push
# GitHub Actions builds APK automatically!
\`\`\`

---

## WHEN YOU WANT TO SHARE APK WITH A SHOP OWNER

\`\`\`powershell
make build-share
# APK appears on your Desktop as ShopLink.apk
# Send via WhatsApp
\`\`\`

---

*You are ready. Start Claude Code and build ShopLink.*
`);

console.log('\n✅ All files generated successfully!\n');
