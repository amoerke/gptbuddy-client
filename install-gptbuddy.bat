@echo off
setlocal
title gptbuddy installieren

echo.
echo  gptbuddy wird eingerichtet.
echo  Du wirst gleich nach deiner Client-ID und dem Client-Secret gefragt.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$installer = Join-Path $env:TEMP 'install-gptbuddy.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install.ps1' -OutFile $installer -UseBasicParsing"

if errorlevel 1 (
  echo.
  echo  Die Installation ist fehlgeschlagen. Bitte gib die Fehlermeldung an das IT-Team weiter.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\install-gptbuddy.ps1"
set "INSTALL_RESULT=%ERRORLEVEL%"
del /q "%TEMP%\install-gptbuddy.ps1" >nul 2>&1

if not "%INSTALL_RESULT%"=="0" (
  echo.
  echo  Die Installation ist fehlgeschlagen. Bitte gib die Fehlermeldung an das IT-Team weiter.
  pause
  exit /b %INSTALL_RESULT%
)

echo.
echo  Fertig. Bitte Codex jetzt vollstaendig schliessen und erneut oeffnen.
pause
