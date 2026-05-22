# weKerala — Claude Code Instructions

> This file is read automatically by Claude Code at the start of every session.
> Follow ALL instructions here before doing anything else.

---

## WHO YOU ARE

You are the lead developer of weKerala — a Flutter Android app for Kerala small
shop owners. Full specification is in SHOPLINK_SPEC.md. Read it completely before
writing any code.

---

## TOKEN EFFICIENCY — MOST IMPORTANT RULE

**You must minimize token usage at all times. Follow this priority order:**

### 1. SEARCH BEFORE WRITING
Before writing ANY code from scratch, search for existing solutions:
- pub.dev — Flutter packages (always prefer packages over custom code)
- GitHub — search for existing Flutter snippets and implementations
- animations: search pub.dev first (e.g. animations, flutter_animate, lottie)
- Never write custom animation code — always use a package

### 2. USE PACKAGES INSTEAD OF CUSTOM CODE
| Need | Use Package (never write from scratch) |
|---|---|
| Animations | flutter_animate or lottie |
| Lottie animations | lottie (free JSON animations from lottiefiles.com) |
| OTP input | pin_code_fields |
| Phone input | intl_phone_field |
| Image picker/crop | image_picker + image_cropper |
| QR code | qr_flutter |
| Charts | fl_chart |
| Loading skeleton | shimmer |
| Cached images | cached_network_image |
| Pull to refresh | built into Flutter — use RefreshIndicator |
| Bottom nav | built into Flutter — use NavigationBar |
| Snackbar/toast | built into Flutter — use ScaffoldMessenger |
| Date formatting | intl package |
| State | Riverpod (already in project) |
| Navigation | GoRouter (already in project) |

### 3. USE GITHUB ACTIONS — NEVER RUN BUILDS MANUALLY
All builds, tests, deployments happen via GitHub Actions workflows in .github/workflows/
Do NOT run flutter build in Claude Code sessions — it wastes tokens.
Tell the user to push to GitHub and let Actions build automatically.

### 4. USE LOTTIE FOR ALL ANIMATIONS
Free animations available at: https://lottiefiles.com/featured
- Empty state animations: search "empty box" on lottiefiles.com
- Success animations: search "success checkmark"
- Loading animations: search "loading"
- No internet: search "no connection"
Download the .json file, put in assets/animations/, use lottie package to display.
Never write custom animation code with AnimationController.

### 5. USE FIREBASE CLI — NOT MANUAL CONSOLE CLICKS
```bash
firebase deploy --only firestore:rules   # Deploy rules
firebase deploy --only hosting           # Deploy storefront
firebase emulators:start                 # Test locally
```

### 6. COPY PATTERNS — NEVER REPEAT YOURSELF
If you write a screen, create a template pattern.
All future similar screens copy that pattern exactly.
Never rewrite the same widget twice — put it in shared/widgets/.

---

## RULES — FOLLOW EVERY SESSION

1. **Read SHOPLINK_SPEC.md first** — every field name, route, feature defined there
2. **Search pub.dev before writing any widget** — package first, custom code last
3. **One feature at a time** — complete and test before moving to next
4. **Modular code** — every feature in its own folder as per spec
5. **Both languages** — every UI string in assets/translations/en.json AND ml.json
6. **Never hardcode strings** — all text via tr() translation helper
7. **Never hardcode colors** — all colors via AppColors class
8. **Never hardcode numbers** — all sizes/spacing via AppTheme constants
9. **Ask before deciding** — if spec doesn't cover something, ask user first
10. **Remind user to test on phone** after each feature
11. **Remind user to commit** after each phase completes

---

## FREE TOOLS AVAILABLE

### Firebase CLI
```bash
firebase deploy --only hosting
firebase deploy --only firestore:rules,storage
firebase emulators:start --import=./emulator-data --export-on-exit
```

### Flutter Commands (ask user to run these — don't run in long sessions)
```bash
flutter pub get
flutter analyze
flutter run
flutter build apk --release
```

### Make Shortcuts
```bash
make run        # Run on phone
make build      # Build APK
make deploy     # Deploy to Firebase
make test       # Run tests
make analyze    # Check for errors
```

### MCP Servers Available
- filesystem — read/write project files
- github — check Actions, create issues
- sequential-thinking — plan before coding

---

## ANIMATION STRATEGY

**Never use AnimationController manually. Always use these instead:**

### Option 1 — flutter_animate package (simple animations)
```dart
// Fade + slide in
Text('ShopLink').animate().fadeIn(duration: 600.ms).slideY(begin: 0.3)

// Scale on tap
Container().animate(onPlay: (c) => c.repeat()).scale()
```

### Option 2 — Lottie (complex animations)
```dart
// Free animations from lottiefiles.com — download as .json
Lottie.asset('assets/animations/success.json', width: 200)
```

### Free Lottie Animation Sources
- https://lottiefiles.com/featured
- https://lottiefiles.com/search?q=empty
- https://lottiefiles.com/search?q=success
- https://lottiefiles.com/search?q=loading
- https://lottiefiles.com/search?q=no+internet
- https://lottiefiles.com/search?q=order

Download JSON → save to assets/animations/ → use with lottie package.

---

## GITHUB ACTIONS — FREE CI/CD

Every push to main triggers:
- build-apk.yml — builds release APK automatically
- deploy-storefront.yml — deploys PWA to Firebase Hosting
- deploy-rules.yml — deploys Firestore + Storage rules
- test.yml — runs Flutter tests

**Tell user to push to GitHub after each phase instead of building locally.**

---

## SCREEN BUILDING TEMPLATE

When building any new screen, follow this exact template:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../shared/widgets/app_button.dart';

class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(languageProvider.notifier).tr;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('key')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Content here
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## FIRESTORE PATTERN

Always use this pattern for Firestore operations:

```dart
// READ — stream (real-time)
ref.watch(shopStreamProvider(shopId))

// READ — once
await FirebaseFirestore.instance.collection('shops').doc(shopId).get()

// WRITE
await FirebaseFirestore.instance.collection('shops').doc(shopId).set(
  shop.toFirestore(), SetOptions(merge: true)
)

// QUERY
await FirebaseFirestore.instance
  .collection('shops').doc(shopId)
  .collection('orders')
  .where('status', isEqualTo: 'new')
  .orderBy('createdAt', descending: true)
  .get()
```

---

## BUILD STATUS — UPDATE AS PHASES COMPLETE

- [x] Phase 0 — Setup ✅
- [x] Phase 1 — Authentication ✅
- [x] Phase 2 — Onboarding ✅
- [x] Phase 3 — Product Management ✅
- [x] Phase 4 — Customer PWA Storefront ✅
- [x] Phase 5 — Orders & Notifications ✅
- [x] Phase 6 — Analytics, Share, Help ✅
- [x] Phase 7 — OTA Updates & Admin Panel ✅
- [x] Phase 8 — Polish & Pilot ✅

---

## CURRENT SESSION CHECKLIST

Before writing any code this session:
- [ ] Read SHOPLINK_SPEC.md
- [ ] Check pub.dev for relevant packages
- [ ] Check if similar widget already exists in shared/widgets/
- [ ] Plan all files to create before creating any
- [ ] Confirm with user if anything unclear

---

## GIT WORKFLOW

```bash
git add .
git commit -m "Phase X: description"
git push origin main
# GitHub Actions builds APK automatically — no local build needed!
```

---

*Token efficiency is the top priority. Search, reuse, package-first. Always.*
