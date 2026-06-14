# weKerala Windows Deployment Script
Write-Host "🚀 Starting weKerala Deployment..." -ForegroundColor Cyan

# 1. Build Android APK
Write-Host "📦 Building Android APK..." -ForegroundColor Yellow
Set-Location wekerala_app
flutter build apk --release --dart-define-from-file=.env
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "..\web\public\wekerala.apk" -Force

# 2. Build Windows App
Write-Host "📦 Building Windows Executable..." -ForegroundColor Yellow
flutter build windows --release
Set-Location "build\windows\x64\runner\Release\"
Compress-Archive -Path * -DestinationPath "..\..\..\..\..\..\web\public\wekerala-windows.zip" -Force

# 3. Deploy Web to Vercel
Write-Host "🌐 Deploying to Vercel..." -ForegroundColor Green
Set-Location "..\..\..\..\..\..\web"
vercel --prod --confirm

# 4. Deploy Firestore Indexes
Write-Host "🔥 Deploying Firestore Indexes..." -ForegroundColor Yellow
firebase deploy --only firestore:indexes --project shoplink-prod

Write-Host "✅ DONE!" -ForegroundColor Green
Write-Host "Your app is now downloadable at: your-website.com/wekerala.apk"
Write-Host "Your Windows app is at: your-website.com/wekerala-windows.zip"
Set-Location ..