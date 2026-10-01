# gptbuddy

`gptbuddy` ist ein konservativer Modell-Router für Codex. Bei jedem gesendeten Prompt ruft der lokale Hook den zentralen Router unter `https://gptbuddy.dataminer.cloud/v1/route` auf. Dieser klassifiziert mit Jev von TypeSafe AI, ohne dass ein Jev- oder OpenAI-Schlüssel auf einem Teamgerät liegt. Die Entscheidung über eine Delegation trifft weiterhin Codex.

Der Router ist bewusst fehlertolerant ausgelegt: Ohne Geräte-Zugangsdaten, bei Zeitüberschreitung, ungültiger Antwort, geringer Konfidenz, Slash-Befehl oder kurzem Prompt bleibt die Aufgabe immer in der Hauptsitzung.

## Enthaltene Bestandteile

- Ein portables Plugin-Manifest und ein Codex-Kompatibilitätsmanifest.
- Ein `UserPromptSubmit`-Hook.
- Ein abhängigkeitfreier Node.js-Hook, der signiert mit dem zentralen Router spricht; es ist keine Paketinstallation nötig.
- Ein Skill, der eine sichere Routing-Empfehlung in eine benannte Codex-Subagentenrolle überführt.
- Konservative Standardregeln, lokale Konfiguration, optionales Entscheidungsprotokoll nur mit Metadaten und ein erster Evaluationssatz.

## Einfache Installation unter Windows

Für Teammitglieder ist der Installer der vorgesehene Weg. Vor der Veröffentlichung muss das Repository unter `amoerke/gptbuddy-client` liegen oder der Standardwert `Repository` in `install.ps1` angepasst werden.

1. Lade `install.ps1` aus dem GitHub-Repository herunter und führe es in PowerShell aus.
2. Gib die dir zugeteilte gptbuddy-Client-ID und das zugehörige Client-Secret ein. Beide Werte werden nicht angezeigt und nicht in einer Repository-Datei gespeichert.
3. Starte Codex vollständig neu und bestätige den Hook bei der ersten Sicherheitsprüfung.

Der Installer lädt die aktuelle `route.js` und ihre Standardkonfiguration, legt sie unter `%LOCALAPPDATA%\gptbuddy\` ab, ergänzt die bestehende persönliche Codex-Hook-Konfiguration und speichert die benötigten Werte als Benutzer-Umgebungsvariablen. Der Hook erkennt diesen Installationsort selbstständig. Er lässt andere Hook-Einträge unverändert und kann gefahrlos erneut ausgeführt werden.

Nach der Veröffentlichung lautet der Team-Befehl:

```powershell
$installer = Join-Path $env:TEMP "install-gptbuddy.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/amoerke/gptbuddy-client/main/install.ps1 -OutFile $installer
& $installer
```

Alternativ lädt ein Teammitglied einfach `install-gptbuddy.bat` herunter und öffnet die Datei per Doppelklick. Die Batch-Datei führt denselben Installer aus und fragt Client-ID sowie Client-Secret ab.

Beispiel für eine explizite Installation mit einem bestimmten Release-Tag:

```powershell
.\install.ps1 -Repository amoerke/gptbuddy-client -Ref v0.1.0
```

## Manuelle Installation in Codex

1. Lege dieses Verzeichnis in einem lokalen Plugin-Marktplatz oder Repository-Marktplatz ab.
2. Aktiviere das Plugin für das vertrauenswürdige Projekt.
3. Prüfe und vertraue dem Hook, bevor du ihn aktivierst. Hooks führen einen lokalen Befehl aus.
4. Verteile über die Geräteverwaltung je Gerät oder Team die Umgebungsvariablen `GPTBUDDY_CLIENT_ID` und `GPTBUDDY_CLIENT_SECRET`. Der Secret-Wert muss zur Serverkonfiguration passen. Optional kann `GPTBUDDY_ROUTER_URL` gesetzt werden; voreingestellt ist `https://gptbuddy.dataminer.cloud/v1/route`.
5. Kopiere `codex/gptbuddy-fast.toml` und `codex/gptbuddy-standard.toml` neben die Codex-Konfiguration, in der die Rollen definiert sind. Übernimm anschließend `codex/config.toml.example` in diese Konfiguration und passe die Modell-IDs an die für dein Konto verfügbaren Modelle an.

Der Jev-Schlüssel bleibt ausschließlich auf dem VPS. Die Teamgeräte erhalten nur einen rotierbaren Zugangsschlüssel zum Router.

## Steuerung und Diagnose

Führe diese Befehle im Plugin-Stammverzeichnis aus:

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
