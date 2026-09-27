@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    py -3.12 -m venv .venv 2>nul
    if errorlevel 1 python -m venv .venv
    if errorlevel 1 goto :error
)

".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto :error

echo.
echo Installation terminee. Double-clique sur Lancer.cmd.
pause
exit /b 0

:error
echo.
echo Installation impossible. Verifie la connexion Internet et relance Installer.cmd.
pause
exit /b 1
