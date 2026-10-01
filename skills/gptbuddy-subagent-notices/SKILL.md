---
name: gptbuddy-subagent-notices
description: "Schaltet die sichtbaren GPTBuddy-Hinweise für gestartete und beendete Subagents ein oder aus. Nur bei ausdrücklichem Aufruf verwenden."
---

# GPTBuddy Subagent-Hinweise

Aktiviere oder deaktiviere die sichtbaren GPTBuddy-Hinweise auf diesem Windows-Rechner.

Die Einstellung liegt als Benutzer-Umgebungsvariable `GPTBUDDY_SHOW_SUBAGENT_NOTICES` vor. Sie wird erst nach einem vollständigen Neustart von Codex von neuen Codex-Prozessen gelesen.

## Aktivieren

Führe in PowerShell aus:

```powershell
[Environment]::SetEnvironmentVariable("GPTBUDDY_SHOW_SUBAGENT_NOTICES", "true", "User")
```

Teile anschließend mit, dass Codex vollständig neu gestartet werden muss. Prüfe nicht auf Geheimnisse und ändere keine anderen GPTBuddy-Variablen.

## Deaktivieren

Führe in PowerShell aus:

```powershell
[Environment]::SetEnvironmentVariable("GPTBUDDY_SHOW_SUBAGENT_NOTICES", $null, "User")
```

Teile anschließend mit, dass Codex vollständig neu gestartet werden muss.

Die Meldungen erscheinen nur, wenn Codex tatsächlich einen Subagent startet oder beendet. Sie sind System-/Hinweismeldungen, keine regulären Chat-Nachrichten.
