@echo off
REM ========================================================
REM  Mirror - Run Windows Desktop Client
REM  Author: Dev Fahim (devfahimbd)
REM ========================================================
set EXE_PATH=%~dp0..\client\build\windows\x64\runner\Release\mirror.exe
if exist "%EXE_PATH%" (
    start "" "%EXE_PATH%"
) else (
    echo [ERROR] mirror.exe not found! Running build first...
    cd "%~dp0..\client"
    call flutter run -d windows
)
