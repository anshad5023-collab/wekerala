#!/bin/bash
# weKerala — Full Stack Deployment Script

echo "🚀 Starting weKerala Deployment..."

# 1. Build Android APK
echo "📦 Building Android APK..."
cd wekerala_app
flutter build apk --release --dart-define-from-file=.env
cp build/app/outputs/flutter-apk/app-release.apk ../web/public/wekerala.apk

# 2. Build Windows App (Zipped for download)
echo "📦 Building Windows Executable..."
flutter build windows --release
cd build/windows/x64/runner/Release/
zip -r ../../../../../web/public/wekerala-windows.zip . *
cd ../../../../../

# 3. Deploy Web to Vercel
echo "🌐 Deploying to Vercel..."
cd web
vercel --prod --confirm

echo "✅ Deployment Complete! Latest versions are now available at /wekerala.apk and /wekerala-windows.zip"