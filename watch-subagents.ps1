$logPath = Join-Path $env:LOCALAPPDATA "gptbuddy\.gptbuddy-data\subagents.jsonl"

Write-Host "Warte auf gestartete oder beendete Subagenten ..."
while (-not (Test-Path -LiteralPath $logPath)) {
  Start-Sleep -Seconds 1
}

Get-Content -LiteralPath $logPath -Wait | ForEach-Object {
  try {
    $event = $_ | ConvertFrom-Json
    "[{0}] {1}: Typ={2}; Modell={3}; ID={4}" -f $event.timestamp, $event.event, $event.agent_type, $event.model, $event.agent_id
  } catch {
    Write-Warning "Ungültiger Protokolleintrag übersprungen."
  }
}
