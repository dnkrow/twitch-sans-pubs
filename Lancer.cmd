@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\streamlink.exe" (
    echo Lance d'abord Installer.cmd.
    pause
    exit /b 1
)

start "" pwsh -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0app.ps1"
