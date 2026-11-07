@echo off
REM ========================================================
REM  Mirror - Complete Build All Script
REM  Author: Dev Fahim (devfahimbd)
REM ========================================================
setlocal enabledelayedexpansion

echo ========================================================
echo  [1/3] Building Android Mirror Server JAR...
echo ========================================================
call "%~dp0build_server.bat"
if %errorlevel% neq 0 (
    echo [ERROR] Server build failed!
    exit /b %errorlevel%
)

echo ========================================================
echo  [2/3] Building Android Companion APK...
echo ========================================================
cd "%~dp0..\mobile"
call flutter pub get
call flutter build apk --release
if %errorlevel% neq 0 (
    echo [ERROR] Mobile APK build failed!
    exit /b %errorlevel%
)
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0..\release\mirror.apk"

echo ========================================================
echo  [3/3] Building Windows Desktop Client EXE...
echo ========================================================
cd "%~dp0..\client"
call flutter pub get
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Windows Client build failed!
    exit /b %errorlevel%
)
powershell -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath '%~dp0..\release\Mirror-v1.0-Windows-x64.zip' -Force"
copy /Y "build\windows\x64\runner\Release\mirror.exe" "%~dp0..\release\mirror.exe"

echo ========================================================
echo  SUCCESS: All components built into release\ folder!
echo ========================================================
