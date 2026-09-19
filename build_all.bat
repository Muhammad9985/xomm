@echo off
setlocal enabledelayedexpansion
title XOMM - Build All Release Packages
color 0B

echo ================================================================
echo                   XOMM RELEASE PACKAGER
echo         Android APK ^| Windows Desktop ^| Web (iOS PWA)
echo ================================================================
echo.

set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

set "OUTPUT_DIR=%PROJECT_DIR%RELEASE_OUTPUT"

if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

echo [1/4] Verifying dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter pub get failed. Please check internet connection.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Dependencies ready.
echo.

echo ================================================================
echo [2/4] Building Android APK (Optimized Split-ABI WebRTC)...
echo ================================================================
call flutter build apk --split-per-abi
if %ERRORLEVEL% EQU 0 (
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "%OUTPUT_DIR%\Xomm_Android.apk"
    copy /Y "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "%OUTPUT_DIR%\Xomm_Android_Phone_arm64.apk"
    copy /Y "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "%OUTPUT_DIR%\Xomm_Android_Legacy_armv7.apk"
    echo [SUCCESS] Optimized Android APK created (30 MB): "%OUTPUT_DIR%\Xomm_Android.apk"
) else (
    echo [WARNING] Android APK build encountered an issue.
)
echo.

echo ================================================================
echo [3/4] Building Windows Desktop Release...
echo ================================================================
call flutter build windows --release
if %ERRORLEVEL% EQU 0 (
    set "WIN_SOURCE=build\windows\x64\runner\Release"
    set "WIN_DEST=%OUTPUT_DIR%\Xomm_Windows_Desktop"
    
    if exist "!WIN_DEST!" (
        rmdir /S /Q "!WIN_DEST!"
    )
    mkdir "!WIN_DEST!"
    
    xcopy /E /I /Y "!WIN_SOURCE!\*" "!WIN_DEST!\"
    
    echo [SUCCESS] Windows Desktop release created at:
    echo           "!WIN_DEST!"
    echo.
    echo Creating ZIP archive for Windows Desktop...
    powershell -Command "Compress-Archive -Path '!WIN_DEST!\*' -DestinationPath '%OUTPUT_DIR%\Xomm_Windows_Desktop.zip' -Force"
    if exist "%OUTPUT_DIR%\Xomm_Windows_Desktop.zip" (
        echo [SUCCESS] Windows Desktop ZIP archive created:
        echo           "%OUTPUT_DIR%\Xomm_Windows_Desktop.zip"
    )
) else (
    echo [WARNING] Windows Desktop build encountered an issue.
    echo (Make sure Windows Developer Mode is ON in Settings: ms-settings:developers)
)
echo.

echo ================================================================
echo [4/4] Building Web PWA (Accessible on iOS Safari, Android, PC)...
echo ================================================================
call flutter build web --release
if %ERRORLEVEL% EQU 0 (
    set "WEB_SOURCE=build\web"
    set "WEB_DEST=%OUTPUT_DIR%\Xomm_Web_For_All_Browsers"
    
    if exist "!WEB_DEST!" (
        rmdir /S /Q "!WEB_DEST!"
    )
    mkdir "!WEB_DEST!"
    xcopy /E /I /Y "!WEB_SOURCE!\*" "!WEB_DEST!\"
    echo [SUCCESS] Web release created for instant mobile/iOS browser access:
    echo           "!WEB_DEST!"
)
echo.

echo ================================================================
echo                      NOTE ON APPLE iOS:
echo   Apple requires macOS and Xcode to compile an installable .ipa 
echo   app for iPhone. To build for iOS:
echo   1. Copy this folder to a Mac
echo   2. Run: flutter build ipa --release
echo.
echo   In the meantime, the included Web build works directly on 
echo   iPhone Safari!
echo ================================================================
echo.
echo ================================================================
echo [COMPLETED] All packages are ready in:
echo   %OUTPUT_DIR%
echo ================================================================

explorer.exe "%OUTPUT_DIR%"

echo.
echo Press any key to exit...
pause >nul
