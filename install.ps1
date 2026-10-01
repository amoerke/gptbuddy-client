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
    $ClientId = [Environment]::GetEnvironmentVariable("GPTBUDDY_CLIENT_ID", "User")
}
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    $ClientId = Read-Host "gptbuddy Client-ID"
}
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    throw "A Client-ID is required."
}
if ($null -eq $ClientSecret) {
    $savedSecret = [Environment]::GetEnvironmentVariable("GPTBUDDY_CLIENT_SECRET", "User")
    if ([string]::IsNullOrWhiteSpace($savedSecret)) {
        $ClientSecret = Read-Host "gptbuddy Client-Secret" -AsSecureString
    } else {
        $ClientSecret = ConvertTo-SecureString $savedSecret -AsPlainText -Force
    }
}

$plainSecret = ConvertTo-PlainText $ClientSecret
if ([string]::IsNullOrWhiteSpace($plainSecret)) {
    throw "A Client-Secret is required."
}

$installDirectory = Join-Path $env:LOCALAPPDATA "gptbuddy"
$hookScript = Join-Path $installDirectory "route.js"
$temporaryScript = Join-Path $installDirectory "route.js.download.js"
$observerScript = Join-Path $installDirectory "observe-subagent.js"
$temporaryObserver = Join-Path $installDirectory "observe-subagent.download.js"
$watchScript = Join-Path $installDirectory "watch-subagents.ps1"
$temporaryWatch = Join-Path $installDirectory "watch-subagents.download.ps1"
$configDirectory = Join-Path $installDirectory "config"
$defaultsFile = Join-Path $configDirectory "defaults.json"
$temporaryDefaults = Join-Path $configDirectory "defaults.json.download"
$hooksDirectory = Join-Path $env:USERPROFILE ".codex"
$hooksFile = Join-Path $hooksDirectory "hooks.json"
$hookCommand = "node `"$hookScript`""
$observerCommand = "node `"$observerScript`""
$scriptUrl = "https://raw.githubusercontent.com/$Repository/$Ref/hooks/route.js"
$observerUrl = "https://raw.githubusercontent.com/$Repository/$Ref/hooks/observe-subagent.js"
$watchUrl = "https://raw.githubusercontent.com/$Repository/$Ref/watch-subagents.ps1"
$defaultsUrl = "https://raw.githubusercontent.com/$Repository/$Ref/config/defaults.json"

New-Item -ItemType Directory -Force -Path $installDirectory, $configDirectory, $hooksDirectory | Out-Null

try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $temporaryScript -UseBasicParsing
    Invoke-WebRequest -Uri $observerUrl -OutFile $temporaryObserver -UseBasicParsing
    try {
        Invoke-WebRequest -Uri $watchUrl -OutFile $temporaryWatch -UseBasicParsing
    } catch {
        Write-Warning "The optional live monitor could not be downloaded and will be skipped."
    }
    Invoke-WebRequest -Uri $defaultsUrl -OutFile $temporaryDefaults -UseBasicParsing
    & node --check $temporaryScript
    if ($LASTEXITCODE -ne 0) {
        throw "The downloaded hook script is not valid JavaScript."
    }
    & node --check $temporaryObserver
    if ($LASTEXITCODE -ne 0) {
        throw "The downloaded subagent observer is not valid JavaScript."
    }
    Get-Content -LiteralPath $temporaryDefaults -Raw | ConvertFrom-Json | Out-Null
    Move-Item -LiteralPath $temporaryScript -Destination $hookScript -Force
    Move-Item -LiteralPath $temporaryObserver -Destination $observerScript -Force
    if (Test-Path -LiteralPath $temporaryWatch) {
        Move-Item -LiteralPath $temporaryWatch -Destination $watchScript -Force
    }
    Move-Item -LiteralPath $temporaryDefaults -Destination $defaultsFile -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryScript) {
        Remove-Item -LiteralPath $temporaryScript -Force
    }
    if (Test-Path -LiteralPath $temporaryDefaults) {
        Remove-Item -LiteralPath $temporaryDefaults -Force
    }
    if (Test-Path -LiteralPath $temporaryObserver) {
        Remove-Item -LiteralPath $temporaryObserver -Force
    }
    if (Test-Path -LiteralPath $temporaryWatch) {
        Remove-Item -LiteralPath $temporaryWatch -Force
    }
}

[Environment]::SetEnvironmentVariable("GPTBUDDY_ROUTER_URL", $RouterUrl, "User")
[Environment]::SetEnvironmentVariable("GPTBUDDY_CLIENT_ID", $ClientId, "User")
[Environment]::SetEnvironmentVariable("GPTBUDDY_CLIENT_SECRET", $plainSecret, "User")
[Environment]::SetEnvironmentVariable("GPTBUDDY_PLUGIN_ROOT", $installDirectory, "User")
$env:GPTBUDDY_ROUTER_URL = $RouterUrl
$env:GPTBUDDY_CLIENT_ID = $ClientId
$env:GPTBUDDY_CLIENT_SECRET = $plainSecret
$env:GPTBUDDY_PLUGIN_ROOT = $installDirectory

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
function Ensure-CommandHook([string]$EventName, [string]$Command, [string]$StatusMessage, [int]$Timeout, [bool]$Async, [int]$AdditionalContextLimit = -1) {
    Ensure-Property $hookConfig.hooks $EventName @()
    $groups = @($hookConfig.hooks.$EventName)
    foreach ($group in $groups) {
        foreach ($handler in @($group.hooks)) {
            if ($handler.commandWindows -eq $Command -or $handler.command -eq $Command) {
                $handler.timeout = $Timeout
                Ensure-Property $handler "async" $Async
                $handler.async = $Async
                return
            }
        }
    }

    $handler = [ordered]@{
        type = "command"
        command = $Command
        commandWindows = $Command
        timeout = $Timeout
        async = $Async
    }
    if ($StatusMessage) { $handler.statusMessage = $StatusMessage }
    if ($AdditionalContextLimit -ge 0) { $handler.additionalContextLimit = $AdditionalContextLimit }
    $groups += [pscustomobject]@{ hooks = @($handler) }
    $hookConfig.hooks.$EventName = $groups
}

Ensure-CommandHook "UserPromptSubmit" $hookCommand "gptbuddy prueft die Aufgabe" 6 $false 300
Ensure-CommandHook "SubagentStart" $observerCommand "" 3 $false
Ensure-CommandHook "SubagentStop" $observerCommand "" 3 $false

$json = $hookConfig | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($hooksFile, "$json`r`n", (New-Object System.Text.UTF8Encoding($false)))

Write-Host "gptbuddy was installed successfully."
Write-Host "Restart Codex completely, then review and trust the new hook when prompted."
Write-Host "Installed hook: $hookScript"
if (Test-Path -LiteralPath $watchScript) {
    Write-Host "Live subagent monitor: powershell -ExecutionPolicy Bypass -File $watchScript"
}
