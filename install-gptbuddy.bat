@echo off
setlocal
title gptbuddy installieren

echo.
echo  gptbuddy wird eingerichtet.
echo  Du wirst gleich nach deiner Client-ID und dem Client-Secret gefragt.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference = 'Stop'; $installer = Join-Path $env:TEMP 'install-gptbuddy.ps1'; try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install.ps1' -OutFile $installer; & $installer } finally { if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force } } }"

if errorlevel 1 (
  echo.
  echo  Die Installation ist fehlgeschlagen. Bitte gib die Fehlermeldung an das IT-Team weiter.
  pause
  exit /b 1
)

echo.
echo  Fertig. Bitte Codex jetzt vollstaendig schliessen und erneut oeffnen.
pause
