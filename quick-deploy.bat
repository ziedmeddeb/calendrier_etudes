@echo off
echo Deploying APK to Firebase App Distribution...
echo.
echo Your APK is ready at: build\app\outputs\flutter-apk\app-release.apk
echo.
echo To deploy, run this command with your details:
echo.
echo .\firebase.bat appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app YOUR_ANDROID_APP_ID --groups "testers" --release-notes "Latest version"
echo.
echo Replace YOUR_ANDROID_APP_ID with your actual Android App ID from Firebase Console
echo.
pause
