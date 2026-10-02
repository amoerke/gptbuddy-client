[CmdletBinding()]
param(
    [string]$Repository = "amoerke/gptbuddy-client",
    [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"

if ($Repository -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
    throw "Repository must have the format owner/repository."
}

$skillRoot = Join-Path $env:USERPROFILE ".codex\skills\gptbuddy-subagent-notices"
$metadataRoot = Join-Path $skillRoot "agents"
$skillFile = Join-Path $skillRoot "SKILL.md"
$metadataFile = Join-Path $metadataRoot "openai.yaml"
# Keep temporary files inside the verified destination. Some Windows profile
# configurations expose an obsolete 8.3 TEMP path, which can fail on cleanup.
$temporarySkill = Join-Path $skillRoot ".SKILL.md.download"
$temporaryMetadata = Join-Path $metadataRoot ".openai.yaml.download"
$rawRoot = "https://raw.githubusercontent.com/$Repository/$Ref/skills/gptbuddy-subagent-notices"

New-Item -ItemType Directory -Force -Path $skillRoot, $metadataRoot | Out-Null

try {
    Invoke-WebRequest -Uri "$rawRoot/SKILL.md" -OutFile $temporarySkill -UseBasicParsing
    Invoke-WebRequest -Uri "$rawRoot/agents/openai.yaml" -OutFile $temporaryMetadata -UseBasicParsing

    $skillContent = Get-Content -LiteralPath $temporarySkill -Raw
    if ($skillContent -notmatch "(?m)^name:\s*gptbuddy-subagent-notices\s*$") {
        throw "The downloaded skill does not have the expected identity."
    }

    Move-Item -LiteralPath $temporarySkill -Destination $skillFile -Force
    Move-Item -LiteralPath $temporaryMetadata -Destination $metadataFile -Force
}
finally {
    if (Test-Path -LiteralPath $temporarySkill) {
        Remove-Item -LiteralPath $temporarySkill -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporaryMetadata) {
        Remove-Item -LiteralPath $temporaryMetadata -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "The gptbuddy-subagent-notices skill was installed successfully."
Write-Host "Restart Codex completely, then invoke `$gptbuddy-subagent-notices to enable or disable notices."
