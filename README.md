# gptbuddy

`gptbuddy` ist ein konservativer Modell-Router für Codex. Bei jedem gesendeten Prompt ruft der lokale Hook den zentralen Router unter `https://gptbuddy.dataminer.cloud/v1/route` auf. Jev von TypeSafe AI klassifiziert die Aufgabe; die Entscheidung, ob Codex einen Subagenten verwendet, bleibt immer bei Codex.

Der Router ist fehlertolerant: Fehlen Zugangsdaten, tritt ein Fehler auf oder ist die Entscheidung unsicher, bleibt die Aufgabe in der Hauptsitzung.

## Für Teammitglieder: Installation per Doppelklick

Voraussetzung ist lediglich eine aktuelle Node.js-LTS-Installation. Alle weiteren Schritte erledigt die Batch-Datei.

1. Lade [install-gptbuddy.bat](https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install-gptbuddy.bat) herunter.
2. Öffne die Datei per Doppelklick.
3. Gib die vom IT-Team erhaltene **Client-ID** und das **Client-Secret** ein.
4. Schließe Codex vollständig und öffne es erneut. Bestätige den Hook, falls Codex danach fragt.

Fertig. Die Installation kann bei Bedarf erneut ausgeführt werden und behält die bereits gespeicherten Zugangsdaten bei. Sie verändert keine vorhandenen, fremden Hook-Einträge.

> Die Client-ID und das Client-Secret niemals in Chat, Tickets oder Repository-Dateien einfügen.

### Optional: Hinweise über verwendete Subagents einschalten

Damit Codex beim Start oder Ende eines Subagents Rolle und Modell als Hinweis anzeigen kann:

1. Lade [install-subagent-notices-skill.bat](https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install-subagent-notices-skill.bat) herunter.
2. Öffne die Datei per Doppelklick.
3. Starte Codex vollständig neu.
4. Schreibe in Codex:

   ```text
   $gptbuddy-subagent-notices Aktiviere die Hinweise.
   ```

Zum Ausschalten genügt später:

```text
$gptbuddy-subagent-notices Deaktiviere die Hinweise.
```

Die Hinweise erscheinen nur, wenn Codex tatsächlich einen Subagent startet oder beendet. Sie sind Systemhinweise, keine regulären Chat-Nachrichten.

### Optional: Subagenten live in PowerShell beobachten

Nach der Hauptinstallation können technisch Interessierte ein separates PowerShell-Fenster öffnen und diesen Befehl ausführen:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\gptbuddy\watch-subagents.ps1"
```

Der Monitor zeigt nur Zeit, Subagentenprofil, Modell und technische ID – keine Prompt-Inhalte.

## Was installiert wird

- Ein signierter `UserPromptSubmit`-Hook für den zentralen Router.
- Ein lokaler Beobachter für gestartete und beendete Subagents.
- Die Standardkonfiguration unter `%LOCALAPPDATA%\gptbuddy\`.
- Benutzer-Umgebungsvariablen für Router-URL, Client-ID und Client-Secret.

Der Jev-Schlüssel verbleibt ausschließlich auf dem VPS. Auf Teamgeräten liegt nur ein rotierbarer Zugangsschlüssel zum Router.

## Hilfe bei Problemen

Nach der Installation kann der Router in PowerShell getestet werden:

```powershell
node "$env:LOCALAPPDATA\gptbuddy\route.js" --test "Erkläre kurz, was ein HTTP-Statuscode ist."
```

Eine erfolgreiche Antwort enthält `"reason": "jev"`. Bei Problemen gib die vollständige Fehlermeldung an das IT-Team weiter, aber keine Client-Secrets.

## Erweiterte Installation und Verwaltung

Diese Varianten sind für Administration, Entwicklung oder Fehlersuche gedacht – Teammitglieder sollten die Batch-Dateien oben verwenden.

### PowerShell-Installation des Routers

```powershell
$installer = Join-Path $env:TEMP "install-gptbuddy.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install.ps1 -OutFile $installer
& $installer
```

Für eine bestimmte veröffentlichte Version kann ein Release-Tag verwendet werden:

```powershell
.\install.ps1 -Repository amoerke/gptbuddy-client -Ref v0.1.0
```

### Nur den Hinweis-Skill über PowerShell installieren

```powershell
$installer = Join-Path $env:TEMP "install-subagent-notices-skill.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install-subagent-notices-skill.ps1 -OutFile $installer
& $installer
```

Der Skill ändert ausschließlich `GPTBUDDY_SHOW_SUBAGENT_NOTICES` für den angemeldeten Windows-Benutzer; Router-Zugangsdaten bleiben unberührt.

### Manuelle Plugin-Installation in Codex

1. Lege dieses Verzeichnis in einem lokalen oder Repository-Marktplatz ab.
2. Aktiviere das Plugin für das vertrauenswürdige Projekt und bestätige den Hook.
3. Verteile `GPTBUDDY_CLIENT_ID` und `GPTBUDDY_CLIENT_SECRET` je Gerät oder Team über die Geräteverwaltung. Optional kann `GPTBUDDY_ROUTER_URL` gesetzt werden; voreingestellt ist `https://gptbuddy.dataminer.cloud/v1/route`.
4. Kopiere `codex/gptbuddy-fast.toml` und `codex/gptbuddy-standard.toml` neben die Codex-Konfiguration, in der die Rollen definiert sind. Übernimm anschließend `codex/config.toml.example` und passe die Modell-IDs an das Konto an.

### Lokale Diagnose im Plugin-Verzeichnis

```powershell
node hooks/route.js --status
node hooks/route.js --test "Explain this JavaScript expression: a ?? b"
node hooks/route.js --disable
node hooks/route.js --enable
```

Beim ersten Aufruf wird `config/defaults.json` in den beschreibbaren Datenordner des Plugins kopiert. Setze `GPTBUDDY_DATA_DIR` auf ein beschreibbares Verzeichnis, wenn das Skript außerhalb von Codex läuft. Codex stellt Hooks `PLUGIN_DATA` bereit.

## Datenschutz

An das Routing-Modell wird ausschließlich der aktuelle Prompt gesendet, gekürzt auf die konfigurierte Höchstlänge. Repository-Dateien, Shell-Ausgaben und Gesprächsverlauf werden nicht übermittelt. Das Entscheidungsprotokoll ist standardmäßig deaktiviert. Wenn es aktiviert wird, speichert es nur einen Prompt-Hash und Metadaten – niemals den Prompt selbst.

## Evaluation

Die enthaltene `data/eval.jsonl` ist ein erster Testdatensatz. Kalibriere die Schwellenwerte zunächst im Shadow-Modus, bevor du dich auf Delegationen verlässt. Ein sinnvolles Produktionsziel ist hohe Präzision: Eine nicht erfolgte Delegation kostet nur Zeit, eine schlechte Delegation kann hingegen wichtigen Kontext verlieren.

## Geltungsbereich in ChatGPT

Diese lokale Hook-Implementierung funktioniert in Codex und ChatGPT Work nur dort, wo das Hook-Skript vorhanden und als vertrauenswürdig eingestuft ist. Normale ChatGPT-Chats führen keine Prompt-Hooks aus. Eine spätere Version für normale ChatGPT-Chats benötigt daher einen gehosteten MCP-Dienst mit OAuth und expliziten Nutzeraktionen statt lokaler Prompt-Überwachung.
