@echo off
setlocal
title GPTBuddy Subagent-Hinweise installieren

echo.
echo  GPTBuddy Subagent-Hinweise werden eingerichtet.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$installer = Join-Path $env:TEMP 'install-subagent-notices-skill.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install-subagent-notices-skill.ps1' -OutFile $installer -UseBasicParsing"

if errorlevel 1 (
  echo.
  echo  Die Installation ist fehlgeschlagen. Bitte gib die Fehlermeldung an das IT-Team weiter.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\install-subagent-notices-skill.ps1"
set "INSTALL_RESULT=%ERRORLEVEL%"
del /q "%TEMP%\install-subagent-notices-skill.ps1" >nul 2>&1

if not "%INSTALL_RESULT%"=="0" (
  echo.
  echo  Die Installation ist fehlgeschlagen. Bitte gib die Fehlermeldung an das IT-Team weiter.
  pause
  exit /b %INSTALL_RESULT%
)

echo.
echo  Fertig. Bitte Codex jetzt vollstaendig schliessen und erneut oeffnen.
pause
