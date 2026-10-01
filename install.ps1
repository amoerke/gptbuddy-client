[CmdletBinding()]
param(
    [string]$ClientId,
    [SecureString]$ClientSecret,
    [string]$RouterUrl = "https://gptbuddy.dataminer.cloud/v1/route",
    [string]$Repository = "amoerke/gptbuddy-client",
    [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"

function ConvertTo-PlainText([SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Ensure-Property($Object, [string]$Name, $Value) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

if ($Repository -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
    throw "Repository must have the format owner/repository."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required. Install the current Node.js LTS version and run this installer again."
}

if ([string]::IsNullOrWhiteSpace($ClientId)) {
    $ClientId = Read-Host "gptbuddy Client-ID"
}
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    throw "A Client-ID is required."
}
if ($null -eq $ClientSecret) {
    $ClientSecret = Read-Host "gptbuddy Client-Secret" -AsSecureString
}

$plainSecret = ConvertTo-PlainText $ClientSecret
if ([string]::IsNullOrWhiteSpace($plainSecret)) {
    throw "A Client-Secret is required."
}

$installDirectory = Join-Path $env:LOCALAPPDATA "gptbuddy"
$hookScript = Join-Path $installDirectory "route.js"
$temporaryScript = Join-Path $installDirectory "route.js.download.js"
$configDirectory = Join-Path $installDirectory "config"
$defaultsFile = Join-Path $configDirectory "defaults.json"
$temporaryDefaults = Join-Path $configDirectory "defaults.json.download"
$hooksDirectory = Join-Path $env:USERPROFILE ".codex"
$hooksFile = Join-Path $hooksDirectory "hooks.json"
$hookCommand = "node `"$hookScript`""
$scriptUrl = "https://raw.githubusercontent.com/$Repository/$Ref/hooks/route.js"
$defaultsUrl = "https://raw.githubusercontent.com/$Repository/$Ref/config/defaults.json"

New-Item -ItemType Directory -Force -Path $installDirectory, $configDirectory, $hooksDirectory | Out-Null

try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $temporaryScript -UseBasicParsing
    Invoke-WebRequest -Uri $defaultsUrl -OutFile $temporaryDefaults -UseBasicParsing
    & node --check $temporaryScript
    if ($LASTEXITCODE -ne 0) {
        throw "The downloaded hook script is not valid JavaScript."
    }
    Get-Content -LiteralPath $temporaryDefaults -Raw | ConvertFrom-Json | Out-Null
    Move-Item -LiteralPath $temporaryScript -Destination $hookScript -Force
    Move-Item -LiteralPath $temporaryDefaults -Destination $defaultsFile -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryScript) {
        Remove-Item -LiteralPath $temporaryScript -Force
    }
    if (Test-Path -LiteralPath $temporaryDefaults) {
        Remove-Item -LiteralPath $temporaryDefaults -Force
    }
}

[Environment]::SetEnvironmentVariable("GPTBUDDY_ROUTER_URL", $RouterUrl, "User")
[Environment]::SetEnvironmentVariable("GPTBUDDY_CLIENT_ID", $ClientId, "User")
[Environment]::SetEnvironmentVariable("GPTBUDDY_CLIENT_SECRET", $plainSecret, "User")
$env:GPTBUDDY_ROUTER_URL = $RouterUrl
$env:GPTBUDDY_CLIENT_ID = $ClientId
$env:GPTBUDDY_CLIENT_SECRET = $plainSecret

if (Test-Path -LiteralPath $hooksFile) {
    try {
        $hookConfig = Get-Content -LiteralPath $hooksFile -Raw | ConvertFrom-Json
    }
    catch {
        throw "Existing hooks.json is not valid JSON. It was not changed."
    }
}
else {
    $hookConfig = [pscustomobject]@{}
}

Ensure-Property $hookConfig "hooks" ([pscustomobject]@{})
Ensure-Property $hookConfig.hooks "UserPromptSubmit" @()

$groups = @($hookConfig.hooks.UserPromptSubmit)
$installed = $false
foreach ($group in $groups) {
    foreach ($handler in @($group.hooks)) {
        if ($handler.commandWindows -eq $hookCommand -or $handler.command -eq $hookCommand) {
            $installed = $true
        }
    }
}

if (-not $installed) {
    $handler = [pscustomobject]@{
        type                   = "command"
        command                = $hookCommand
        commandWindows         = $hookCommand
        timeout                = 6
        statusMessage          = "gptbuddy prüft die Aufgabe"
        additionalContextLimit = 300
    }
    $groups += [pscustomobject]@{ hooks = @($handler) }
    $hookConfig.hooks.UserPromptSubmit = $groups
}

$json = $hookConfig | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($hooksFile, "$json`r`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host "gptbuddy was installed successfully."
Write-Host "Restart Codex completely, then review and trust the new hook when prompted."
Write-Host "Installed hook: $hookScript"
