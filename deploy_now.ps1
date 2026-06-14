Write-Host "?? Starting weKerala Deployment..." -ForegroundColor Cyan

# Build Android
Write-Host "?? Building Android APK..." -ForegroundColor Yellow
Set-Location wekerala_app
flutter build apk --release --dart-define-from-file=.env
if ($?) { 
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "..\web\public\wekerala.apk" -Force 
    Write-Host "? Android Build Success!" -ForegroundColor Green
}

# Build Windows
Write-Host "?? Building Windows Executable..." -ForegroundColor Yellow
flutter build windows --release
if ($?) {
    Set-Location "build\windows\x64\runner\Release\"
    Compress-Archive -Path * -DestinationPath "..\..\..\..\..\..\web\public\wekerala-windows.zip" -Force
    Write-Host "? Windows Build Success!" -ForegroundColor Green
    Set-Location "..\..\..\..\..\..\web"
}

# Deploy Web to Vercel
Write-Host "?? Deploying to Vercel..." -ForegroundColor Green
vercel --prod --confirm

Write-Host "? ALL DONE! You can now download from your website." -ForegroundColor Green
