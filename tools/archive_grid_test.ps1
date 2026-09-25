# Capture one runtime session without launching the game or changing its settings.
param(
    [Parameter(Mandatory)][string]$VariantDirectory,
    [Parameter(Mandatory)][string]$Outcome,
    [string]$UserFolder = "$env:USERPROFILE/OneDrive/Dokumente/Paradox Interactive/Crusader Kings III",
    [string]$ArchiveRoot = "$PSScriptRoot/../.ck3modding/crash-isolation/sessions",
    [string]$Notes = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_grid_diagnostics.ps1')
Assert-DiDiagnosticOutput $ArchiveRoot
$variant = Get-Content -LiteralPath (Join-Path $VariantDirectory 'DI_grid_manifest.json') -Raw | ConvertFrom-Json
$folder = Join-Path $ArchiveRoot ((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Copy-Item -LiteralPath (Join-Path $VariantDirectory 'DI_grid_manifest.json') -Destination $folder
$logRecords = @(foreach ($name in 'debug.log', 'error.log', 'gui_warnings.log', 'game.log', 'system.log') {
    $path = Join-Path $UserFolder "logs/$name"
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        Copy-Item -LiteralPath $path -Destination $folder
        [ordered]@{ name = $name; lastWriteUtc = $item.LastWriteTimeUtc.ToString('o'); bytes = $item.Length }
    }
})
$loadPath = Join-Path $UserFolder 'dlc_load.json'
if (Test-Path -LiteralPath $loadPath) { Copy-Item -LiteralPath $loadPath -Destination $folder }
$installedGrid = Join-Path $UserFolder 'mod/DI Perks - AGOT 45-Mod Playset/gui/DI_generated_perk_grid.gui'
$installedHash = if (Test-Path -LiteralPath $installedGrid) { (Get-FileHash -LiteralPath $installedGrid).Hash } else { $null }
$eventsStatus = 'captured'
try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = (Get-Date).AddHours(-24) } -ErrorAction Stop |
        Where-Object { $_.Id -in 41, 6008, 1001, 4101 -or $_.ProviderName -match 'WHEA' } |
        ForEach-Object { [ordered]@{ timeUtc = $_.TimeCreated.ToUniversalTime().ToString('o'); id = $_.Id; provider = $_.ProviderName; message = $_.Message } })
    ConvertTo-Json -InputObject $events -Depth 5 | Set-Content -LiteralPath (Join-Path $folder 'system-events.json') -Encoding utf8
} catch { $eventsStatus = $_.Exception.Message }
[ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o'); timeZone = [TimeZoneInfo]::Local.Id
    outcome = $Outcome; notes = $Notes; variant = (Resolve-Path -LiteralPath $VariantDirectory).Path
    installedGridSha256 = $installedHash; matchesVariant = $installedHash -eq $variant.gridSha256
    logFiles = $logRecords; systemEvents = $eventsStatus
    timingNote = 'CK3 text timestamps remain verbatim; correlate against UTC file metadata and Windows events, allowing for buffering.'
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $folder 'session.json') -Encoding utf8
Write-Host "Archived session: $folder"
if ($installedHash -ne $variant.gridSha256) { Write-Warning 'Installed grid does not match the claimed variant; do not attribute this session to that variant.' }
