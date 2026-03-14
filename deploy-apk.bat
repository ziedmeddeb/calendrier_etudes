@echo off
echo ========================================
echo    Flutter APK Deployment Script
echo ========================================
echo.

echo Step 1: Building APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo Error: Failed to build APK
    pause
    exit /b 1
)

echo.
echo Step 2: APK built successfully!
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo.

echo Step 3: Deploying to Firebase App Distribution...
echo.
echo Please make sure you have:
echo 1. Logged in to Firebase: .\firebase.bat login
echo 2. Your Firebase project ID
echo 3. Your Android App ID from Firebase Console
echo.

set /p PROJECT_ID=calendrier-etudes-b4438
set /p APP_ID=1:520666554418:android:ef51f40502f6124a865c2b
set /p RELEASE_NOTES="Enter release notes: "

echo.
echo Deploying APK...
.\firebase.bat appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app %APP_ID% --groups "testers" --release-notes "%RELEASE_NOTES%"

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo    APK deployed successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo    Deployment failed!
    echo ========================================
)

echo.
pause
