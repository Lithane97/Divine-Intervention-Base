# Generate and verify staged variants. Does not install files or launch CK3.
param(
    [string]$OutputRoot = "$PSScriptRoot/../.ck3modding/crash-isolation",
    [string]$GameDir = 'H:/SteamLibrary/steamapps/common/Crusader Kings III/game',
    [string]$UserFolder = "$env:USERPROFILE/OneDrive/Dokumente/Paradox Interactive/Crusader Kings III",
    [string]$BloodlinesDir = 'H:/SteamLibrary/steamapps/workshop/content/1158310/3522779004'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_grid_diagnostics.ps1')
Assert-DiDiagnosticOutput $OutputRoot
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$generator = Join-Path $PSScriptRoot 'generate_mod_perks.ps1'
$common = @{ SubMod = 'A Game of Thrones'; SubModExtraDirs = @($BloodlinesDir)
    SubModName = 'DI Perks - AGOT 45-Mod Playset'; GameDir = $GameDir; UserFolder = $UserFolder }
function Get-GameplayHashes([string]$Dir) {
    $result = @{}
    foreach ($part in 'common', 'localization') {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Dir $part) -File -Recurse) {
            $result[[IO.Path]::GetRelativePath($Dir, $file.FullName)] = (Get-FileHash -LiteralPath $file.FullName).Hash
        }
    }
    return $result
}
function Assert-GameplayEqual($Reference, [string]$Dir) {
    $actual = Get-GameplayHashes $Dir
    if ($actual.Count -ne $Reference.Count) { throw "Gameplay file count changed: $Dir" }
    foreach ($key in $Reference.Keys) { if ($actual[$key] -ne $Reference[$key]) { throw "Non-GUI content changed: $Dir/$key" } }
}
$launcherPath = Join-Path $UserFolder 'mod/DI Perks - AGOT 45-Mod Playset.mod'
$launcherBefore = if (Test-Path -LiteralPath $launcherPath) { (Get-FileHash -LiteralPath $launcherPath).Hash } else { 'absent' }
$fullDir = Join-Path $OutputRoot 'agot-full'
& $generator @common -TargetFolder $fullDir *> (Join-Path $OutputRoot 'agot-full.log')
$manifest = Get-Content -LiteralPath (Join-Path $fullDir 'DI_grid_manifest.json') -Raw | ConvertFrom-Json
$baseline = Get-GameplayHashes $fullDir
# An ungated five-perk track is available regardless of enabled DLC.
$first = $manifest.availableTracks | Where-Object { $_.perks.Count -eq 5 -and -not $_.dlcGate } | Select-Object -First 1
if (-not $first) { throw 'No ungated five-perk track exists; select a DLC-supported track explicitly.' }
$order = @($first.key) + @($manifest.trackKeys | Where-Object { $_ -ne $first.key })
$cases = [ordered]@{ 'agot-empty' = @{ DiagnosticEmptyGrid = $true } }
foreach ($n in 1, 5, 20, 50) {
    $cases["agot-$n-tracks"] = @{ DiagnosticGridTracks = @($order | Select-Object -First $n) }
}
$cases['agot-1-tracks-owned-off'] = @{ DiagnosticGridTracks = @($first.key); DiagnosticDisableOwnedState = $true }
$cases['agot-full-owned-off'] = @{ DiagnosticDisableOwnedState = $true }
$gridPaths = @((Join-Path $fullDir 'gui/DI_generated_perk_grid.gui'))
foreach ($case in $cases.GetEnumerator()) {
    $dir = Join-Path $OutputRoot $case.Key
    $options = $case.Value
    & $generator @common @options -TargetFolder $dir *> (Join-Path $OutputRoot "$($case.Key).log")
    Assert-GameplayEqual $baseline $dir
    $m = Get-Content -LiteralPath (Join-Path $dir 'DI_grid_manifest.json') -Raw | ConvertFrom-Json
    $expectedCells = if ($options.DiagnosticEmptyGrid) { 0 } elseif ($options.DiagnosticGridTracks) {
        ($manifest.availableTracks | Where-Object key -in $options.DiagnosticGridTracks | ForEach-Object { $_.perks.Count } | Measure-Object -Sum).Sum
    } else { $manifest.cellCount }
    if ($m.cellCount -ne $expectedCells) { throw "Wrong emitted cell count: $($case.Key)" }
    if ($options.DiagnosticDisableOwnedState -and ($m.ownershipBindingCount -ne 0 -or $m.hasPerkCallCount -ne 0)) { throw 'Owned-state bindings remain' }
    # Dependencies remain identical; only the staged descriptor path may differ.
    $normalDesc = (Get-Content -LiteralPath (Join-Path $fullDir 'descriptor.mod') -Raw) -replace '(?m)^path=.*', ''
    $variantDesc = (Get-Content -LiteralPath (Join-Path $dir 'descriptor.mod') -Raw) -replace '(?m)^path=.*', ''
    if ($normalDesc -cne $variantDesc) { throw "Descriptor fields changed: $($case.Key)" }
    $gridPaths += Join-Path $dir 'gui/DI_generated_perk_grid.gui'
    Write-Host "[OK] $($case.Key): $($m.cellCount) cells; effects, localization and dependencies unchanged"
}
# Repeat the full generation to verify deterministic grid and manifest output.
$hashBefore = (Get-FileHash -LiteralPath (Join-Path $fullDir 'DI_grid_manifest.json')).Hash
& $generator @common -TargetFolder $fullDir *> (Join-Path $OutputRoot 'agot-full-repeat.log')
if ((Get-FileHash -LiteralPath (Join-Path $fullDir 'DI_grid_manifest.json')).Hash -ne $hashBefore) { throw 'Grid/manifest generation is nondeterministic' }
Assert-GameplayEqual $baseline $fullDir
$launcherAfter = if (Test-Path -LiteralPath $launcherPath) { (Get-FileHash -LiteralPath $launcherPath).Hash } else { 'absent' }
if ($launcherAfter -ne $launcherBefore) { throw 'Staging changed the launcher descriptor' }
& (Join-Path $PSScriptRoot 'test_grid_diagnostics.ps1') -GridPaths $gridPaths
Write-Host "[OK] Diagnostic suite staged at $OutputRoot; first track: $($first.key). No files installed."
