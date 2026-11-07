@echo off
REM ========================================================
REM  Mirror - Server Build Script
REM  Author: Dev Fahim (devfahimbd)
REM ========================================================
setlocal enabledelayedexpansion

echo [1/3] Setting up build paths...
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set SERVER_DIR=%PROJECT_ROOT%\server
set BUILD_DIR=%SERVER_DIR%\build
set CLASSES_DIR=%BUILD_DIR%\classes

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%CLASSES_DIR%" mkdir "%CLASSES_DIR%"

REM Find Android SDK platform android.jar
set ANDROID_JAR=E:\src\android\platforms\android-34\android.jar
if not exist "%ANDROID_JAR%" (
    set ANDROID_JAR=%ANDROID_HOME%\platforms\android-34\android.jar
)

REM Find d8 tool
set D8_TOOL=E:\src\android\build-tools\36.0.0\d8.bat
if not exist "%D8_TOOL%" (
    set D8_TOOL=%ANDROID_HOME%\build-tools\34.0.0\d8.bat
)

echo [2/3] Compiling Java sources with javac...
javac -cp "%ANDROID_JAR%" -d "%CLASSES_DIR%" "%SERVER_DIR%\src\main\java\com\devfahim\mirror\server\*.java"
if %errorlevel% neq 0 (
    echo [ERROR] Java compilation failed!
    exit /b %errorlevel%
)

echo [3/3] Dexing classes into mirror-server.jar with d8...
call "%D8_TOOL%" --lib "%ANDROID_JAR%" --output "%BUILD_DIR%" "%CLASSES_DIR%\com\devfahim\mirror\server\*.class"
if %errorlevel% neq 0 (
    echo [ERROR] d8 dexing failed!
    exit /b %errorlevel%
)

jar cvf "%BUILD_DIR%\mirror-server.jar" -C "%BUILD_DIR%" classes.dex
copy /Y "%BUILD_DIR%\mirror-server.jar" "%PROJECT_ROOT%\client\assets\bin\mirror-server.jar"

echo ========================================================
echo  BUILD SUCCESS: mirror-server.jar created successfully!
echo ========================================================

