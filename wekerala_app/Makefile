# ShopLink — Developer Shortcuts
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
