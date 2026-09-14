# =============================================================================
# DI Dynasty Perk Editor - Mod Support Generator (Phase 3)
# =============================================================================
# Discovers installed CK3 mods that add dynasty perks/tracks and generates
# editor support ("DI Perks" compatch) for them.
#
# Model (v15): CK3 GUI type registration is first-loaded-wins, so a compatch
# "extension" type can never replace the base mod's grid. -SubMod therefore
# emits a COMPLETE same-path override of gui/DI_generated_perk_grid.gui
# (compatch must load AFTER the base mod in the playset).
#   - Use -SubMod to generate a compatch for a single perk mod.
#   - Use -Playset (F4) to merge several perk mods from a playset into ONE
#     combined compatch. This is the recommended way to show several perk mods
#     together. Only one DI Perks compatch may be active in a modlist at once.
#   - Run with no args for the interactive menu (F2).
#
# Tools:
#   tools/generate_perk_editor.ps1  <-- vanilla+DLC generator (ships in base mod)
#   tools/generate_mod_perks.ps1    <-- THIS tool: perk-mod support generator
#   tools/_perk_parser.ps1          <-- shared parser (dot-sourced by both)
#
# Usage:
#   pwsh -File tools/generate_mod_perks.ps1 -Scan
#   pwsh -File tools/generate_mod_perks.ps1 -SubMod "Hiraeth"
#   pwsh -File tools/generate_mod_perks.ps1 -Playset "IronyModManager"
#   pwsh -File tools/generate_mod_perks.ps1 -Playset "IronyModManager" -TargetFolder "C:\temp\out"
#   pwsh -File tools/generate_mod_perks.ps1            (interactive menu)
#
# The shared parser (tools/_perk_parser.ps1) is dot-sourced so counts match the
# vanilla generator. Mods are enumerated from mods_registry.json (primary) + a
# directory scan. Playsets are read from the launcher's launcher-v2.sqlite via a
# temp copy (Python sqlite3), so the live DB is never locked.
# =============================================================================

param(
    [switch]$DiagnosticEmptyGrid,
    [string[]]$DiagnosticGridTracks = @(),
    [switch]$DiagnosticDisableOwnedState,
    [switch]$Scan,                      # F1: list installed perk mods (read-only)
    [string]$SubMod = "",               # F3: standalone compatch for one perk mod
    [string]$SubModName = "",           # override the compatch display name (default "DI Perks - <mod name>")
    [string[]]$SubModExtraDirs = @(),   # F3: extra ordered perk-mod dirs to merge (engine load order; later wins)
    [switch]$Open,                      # open the output folder in Explorer after generation
    [string]$Playset,                   # F4: combined compatch from a playset's enabled mods
    [string]$PlaysetJson = "",          # F3b: launcher playset EXPORT json -> merged compatch via the -SubMod route
    [string]$PlaysetMods = "",      # F4: comma/semicolon-separated perk mod names to combine
    [string]$SubMods = "",          # F4: alias for $PlaysetMods (explicit list to combine)
    [string]$CombinedName = "",         # F4: name for the combined compatch (auto if empty)
    [string]$TargetFolder = "",         # emit files here (default: mod/DI Perks - <Name>)
    [string]$ModDir      = "$PSScriptRoot\..",  # base DI mod dir (descriptor name for dependency)
    [string]$ModsRegistry = "$env:USERPROFILE\OneDrive\Dokumente\Paradox Interactive\Crusader Kings III\mods_registry.json",
    [string]$UserFolder   = "$env:USERPROFILE\OneDrive\Dokumente\Paradox Interactive\Crusader Kings III",
    [string[]]$ExtraScanDirs = @(),     # extra dirs to scan for common/dynasty_perks
    [string]$GameDir = "H:\SteamLibrary\steamapps\common\Crusader Kings III\game",
    [string[]]$LocDirs = @("H:\SteamLibrary\steamapps\common\Crusader Kings III\game\localization\english"),
    [string]$Python = "python",
    [switch]$WhatIf,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_grid_diagnostics.ps1")
. (Join-Path $PSScriptRoot "_grid_order.ps1")
$diagnostic = $DiagnosticEmptyGrid -or $DiagnosticGridTracks.Count -gt 0 -or $DiagnosticDisableOwnedState
if ($diagnostic) {
    if (-not $SubMod -and -not $PlaysetJson) { throw 'Diagnostic grid options require the SubMod route (-SubMod or -PlaysetJson).' }
    if ($Scan -or $Playset -or $PlaysetMods -or $SubMods -or $Open) { throw 'Diagnostic grid options cannot be combined with other generation routes or -Open.' }
    Assert-DiDiagnosticOutput $TargetFolder
}
if ($DiagnosticEmptyGrid -and $DiagnosticGridTracks.Count) { throw 'DiagnosticEmptyGrid and DiagnosticGridTracks are mutually exclusive.' }

# --- Shared parser (dot-sourced) ------------------------------------------------
. (Join-Path $PSScriptRoot "_perk_parser.ps1")

# --- Shared vanilla-look grid writers (definitions only; used by -SubMod) --------
. (Join-Path $PSScriptRoot "_grid_templates.ps1")

# --- Candidate resolution --------------------------------------------------------
# Returns @{ Name; Path; Source; SteamId } for every folder that could hold a CK3 mod.
function Get-ModCandidates {
    $cands = [System.Collections.Generic.List[object]]::new()

    # Primary: the launcher's own registry.
    if ($ModsRegistry -and (Test-Path $ModsRegistry)) {
        try {
            $reg = Get-Content $ModsRegistry -Raw | ConvertFrom-Json
            foreach ($p in $reg.PSObject.Properties) {
                $v = $p.Value
                if (-not $v.dirPath) { continue }
                # Skip already-generated DI Perks compatch entries - they are not source
                # perk mods (they redefine di_perk_grid_extension, not real perks).
                if ($v.displayName -like 'DI Perks*' -or $v.dirPath -like '*DI Perks - *') { continue }
                $cands.Add([pscustomobject]@{
                    Name    = $v.displayName
                    Path    = $v.dirPath
                    Source  = if ($v.source) { $v.source } else { $p.Name }
                    SteamId = if ($v.steamId) { $v.steamId } else { $p.Name }
                })
            }
        } catch {
            Write-Warning "Could not read mods_registry.json ($ModsRegistry): $_"
        }
    } else {
        Write-Warning "mods_registry.json not found at $ModsRegistry"
    }

    # Secondary: local mod/ folder + extra scan dirs.
    $localDir = Join-Path $UserFolder "mod"
    if (Test-Path $localDir) {
        Get-ChildItem $localDir -Directory | ForEach-Object {
            # Skip already-generated DI Perks compatch output dirs - they are not source
            # perk mods (they redefine di_perk_grid_extension, not real perks).
            if ($_.Name -like "DI Perks*") { return }
            $cands.Add([pscustomobject]@{ Name = $_.Name; Path = $_.FullName; Source = "local"; SteamId = $null })
        }
    }
    foreach ($d in $ExtraScanDirs) {
        if (Test-Path $d) {
            $cands.Add([pscustomobject]@{ Name = $d; Path = $d; Source = "extra"; SteamId = $null })
        }
    }
    return ($cands | Sort-Object Path -Unique)
}

# --- F1: scan for installed perk mods ---------------------------------------------
function Invoke-DiScan {
    $cands = Get-ModCandidates
    $results = @()
    foreach ($c in $cands) {
        $perkDir = Join-Path $c.Path "common\dynasty_perks"
        if (-not (Test-Path $perkDir)) { continue }
        $perks = Get-Perks -Directories $perkDir
        $trackMap = Group-PerksByTrack $perks
        $legacyDir = Join-Path $c.Path "common\dynasty_legacies"
        $gates = @{}
        if (Test-Path $legacyDir) { $gates = Get-TrackDlcGates -Directories $legacyDir }
        $results += [pscustomobject]@{
            Name = $c.Name; Source = $c.Source; SteamId = $c.SteamId; Path = $c.Path
            PerkCount = $perks.Count; TrackCount = $trackMap.Count
            GatedTracks = ($gates.Values | Where-Object { $_ }).Count
        }
    }
    return $results
}
function Show-ScanTable {
    param($Results)
    if (-not $Results -or $Results.Count -eq 0) { Write-Host "No perk mods found."; return }
    Write-Host ""
    foreach ($r in $Results) {
        Write-Host ("{0,-5} {1,-6} {2}" -f "[$($r.PerkCount) perks]", "$($r.TrackCount) tracks", $r.Name)
        Write-Host ("      source: {0}" -f $r.Source)
        Write-Host ("      perk dir: {0}\common\dynasty_perks" -f $r.Path)
    }
    Write-Host ""
    Write-Host "$($Results.Count) perk mod(s) found."
}

# --- Vanilla perk-key set (for duplicate-key exclusion) ---------------------------
function Get-VanillaPerkSet {
    param([string]$GameDir)
    $perkDir = Join-Path $GameDir "common\dynasty_perks"
    return Get-Perks -Directories $perkDir
}

# --- Base DI mod display name -----------------------------------------------------
function Get-BaseDiName {
    $baseDesc = Join-Path $ModDir "descriptor.mod"
    $name = "Divine Intervention Cheat Menu Dynasty Legacy Perk Test"
    if (Test-Path $baseDesc) {
        $m = Select-String -Path $baseDesc -Pattern 'name="([^"]+)"' | Select-Object -First 1
        if ($m) { $name = $m.Matches[0].Groups[1].Value }
    }
    return $name
}

# --- Emit a descriptor + auto-register the launcher .mod ---------------------------
function Write-Descriptor {
    param([string]$OutDir, [string]$ModName, [string[]]$Depends, [string]$UserFolder, [bool]$WriteLauncher)
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    $depsBlock = ($Depends | ForEach-Object { "`t`"$_`"" }) -join "`n"
    # Internal descriptor.mod must never carry path=; it belongs only in the
    # external launcher registration .mod written below.
    $desc = @"
version="0.1.0"
tags={
	"Utilities"
}
name="$ModName"
supported_version="1.19.*"
dependencies = {
$depsBlock
}
"@
    $launcherDesc = $desc + "path=`"$($OutDir -replace '[\\/]','/')`"`n"
    $internalPath = Join-Path $OutDir "descriptor.mod"
    if (-not (Test-Path -LiteralPath $internalPath)) {
        [System.IO.File]::WriteAllText($internalPath, $desc, $utf8Bom)
    } else {
        # F7: regeneration must refresh generator-owned fields (name, version,
        # supported_version, dependencies) in the EXISTING internal
        # descriptor too - previously a changed dependency set left it stale while
        # only the launcher .mod was rewritten. Any path= line is removed (it
        # belongs only in the launcher .mod). User-owned lines (tags,
        # remote_file_id, ...) are preserved.
        $t = [System.IO.File]::ReadAllText($internalPath)
        $t = [regex]::Replace($t, '(?m)^version\s*=\s*"[^"]*"', 'version="0.1.0"')
        $t = [regex]::Replace($t, '(?m)^name\s*=\s*"[^"]*"', "name=`"$ModName`"")
        $t = [regex]::Replace($t, '(?m)^supported_version\s*=\s*"[^"]*"', 'supported_version="1.19.*"')
        $t = [regex]::Replace($t, '(?m)^path\s*=\s*"[^"]*"\r?\n?', '')
        $t = [regex]::Replace($t, '(?s)dependencies\s*=\s*\{.*?\r?\n\}', "dependencies = {`n$depsBlock`n}")
        $missing = @($Depends | Where-Object { $t -notmatch [regex]::Escape("`"$_`"") })
        if ($missing.Count -gt 0) { Write-Warning "Internal descriptor is missing dependency entries after update: $($missing -join ', ')" }
        [System.IO.File]::WriteAllText($internalPath, $t, $utf8Bom)
        Write-Host "Updated internal descriptor fields: $internalPath"
    }
    if ($WriteLauncher) {
        $launcherModDir = Join-Path $UserFolder "mod"
        if (-not (Test-Path $launcherModDir)) { New-Item -ItemType Directory -Force -Path $launcherModDir | Out-Null }
        [System.IO.File]::WriteAllText((Join-Path $launcherModDir "$ModName.mod"), $launcherDesc, $utf8Bom)
        Write-Host "Registered launcher mod: $($launcherModDir)\$ModName.mod"
    }
}

# --- Helper: snapshot of vanilla files NOT shadowed by same-name mod files --------
# CK3 file override rule: a mod file with the same relative name replaces the
# vanilla file entirely. Returns a temp dir holding the surviving vanilla files
# (caller removes it). Parsing order [modDir, snapshot] then gives first-seen-wins
# key precedence to the mod on top of the correct file-level replacement.
function Get-VanillaSurvivorSnapshot {
    param([string]$ModDir, [string]$VanillaDir, [string]$Tag)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("di_merge_" + $Tag + "_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    if (Test-Path $VanillaDir) {
        $modNames = @{}
        Get-ChildItem $ModDir -Filter '*.txt' | ForEach-Object { $modNames[$_.Name] = $true }
        foreach ($vf in (Get-ChildItem $VanillaDir -Filter '*.txt')) {
            if (-not $modNames.ContainsKey($vf.Name)) {
                Copy-Item -LiteralPath $vf.FullName -Destination (Join-Path $tmp $vf.Name)
            }
        }
    }
    return $tmp
}

# --- F3: standalone compatch for ONE perk mod --------------------------------------
# v15: the grid is a COMPLETE same-path override of the base mod's
# gui/DI_generated_perk_grid.gui, computed from mod files + vanilla game files
# (mod same-name files replace vanilla files; new hth_*-style keys are added).
# Non-free mode gates on the defines formula (250 + 500 x unlocked perks) via
# dynasty_num_unlocked_perks; free mode grants first and refunds the exact charge.
function Write-SubModSguiBlocks {
    param($Sb, $PerkMap, $Tracks)
    foreach ($k in $PerkMap.Keys) {
        [void]$Sb.AppendLine("DI_perk_add_$k = {")
        [void]$Sb.AppendLine("    scope = character")
        [void]$Sb.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { NOT = { has_dynasty_perk = $k } } }")
        [void]$Sb.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        [void]$Sb.AppendLine("        if = {")
        [void]$Sb.AppendLine("            limit = { NOT = { has_dynasty_perk = $k } }")
        [void]$Sb.AppendLine("            if = {")
        [void]$Sb.AppendLine("                limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
        [void]$Sb.AppendLine("                save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
        [void]$Sb.AppendLine("                add_dynasty_perk = $k")
        [void]$Sb.AppendLine("                add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige }")
        [void]$Sb.AppendLine("            }")
        [void]$Sb.AppendLine("            else_if = {")
        [void]$Sb.AppendLine("                limit = { dynasty_prestige >= { value = 250 add = { value = dynasty_num_unlocked_perks multiply = 500 } } }")
        [void]$Sb.AppendLine("                add_dynasty_perk = $k")
        [void]$Sb.AppendLine("            }")
        [void]$Sb.AppendLine("        }")
        [void]$Sb.AppendLine("    } }")
        [void]$Sb.AppendLine("}")
        [void]$Sb.AppendLine("")
        [void]$Sb.AppendLine("DI_perk_remove_$k = {")
        [void]$Sb.AppendLine("    scope = character")
        [void]$Sb.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { has_dynasty_perk = $k } }")
        [void]$Sb.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        [void]$Sb.AppendLine("        if = { limit = { has_dynasty_perk = $k } remove_dynasty_perk = $k }")
        [void]$Sb.AppendLine("    } }")
        [void]$Sb.AppendLine("}")
        [void]$Sb.AppendLine("")
    }
    foreach ($t in $Tracks.Keys) {
        $trk = $Tracks[$t]
        [void]$Sb.AppendLine("DI_track_add_all_$t = {")
        [void]$Sb.AppendLine("    scope = character")
        [void]$Sb.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { NOT = { $($t)_perks >= $($trk.Count) } } }")
        [void]$Sb.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        foreach ($k in $trk) {
            [void]$Sb.AppendLine("        if = {")
            [void]$Sb.AppendLine("            limit = { NOT = { has_dynasty_perk = $k } }")
            [void]$Sb.AppendLine("            if = {")
            [void]$Sb.AppendLine("                limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
            [void]$Sb.AppendLine("                save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
            [void]$Sb.AppendLine("                add_dynasty_perk = $k")
            [void]$Sb.AppendLine("                add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige }")
            [void]$Sb.AppendLine("            }")
            [void]$Sb.AppendLine("            else_if = {")
            [void]$Sb.AppendLine("                limit = { dynasty_prestige >= { value = 250 add = { value = dynasty_num_unlocked_perks multiply = 500 } } }")
            [void]$Sb.AppendLine("                add_dynasty_perk = $k")
            [void]$Sb.AppendLine("            }")
            [void]$Sb.AppendLine("        }")
        }
        [void]$Sb.AppendLine("    } }")
        [void]$Sb.AppendLine("}")
        [void]$Sb.AppendLine("")
        [void]$Sb.AppendLine("DI_track_remove_all_$t = {")
        [void]$Sb.AppendLine("    scope = character")
        [void]$Sb.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { $($t)_perks > 0 } }")
        [void]$Sb.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        foreach ($k in $trk) {
            [void]$Sb.AppendLine("        if = { limit = { has_dynasty_perk = $k } remove_dynasty_perk = $k }")
        }
        [void]$Sb.AppendLine("    } }")
        [void]$Sb.AppendLine("}")
        [void]$Sb.AppendLine("")
    }
    # Bulk unlock-all / lock-all over the FULL merged perk set. These NAME-OVERRIDE
    # the base mod's vanilla-key versions (same-name scripted guis: later mod wins)
    # so the window's Unlock All / Lock All buttons cover mod-added tracks/keys too.
    # Each unit captures renown BEFORE its own grant and refunds the exact engine
    # charge afterwards - no per-track cost-mirror script value is needed.
    [void]$Sb.AppendLine("DI_perk_unlock_all = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    foreach ($k in $PerkMap.Keys) {
        [void]$Sb.AppendLine("            if = {")
        [void]$Sb.AppendLine("                limit = { NOT = { has_dynasty_perk = $k } }")
        [void]$Sb.AppendLine("                if = {")
        [void]$Sb.AppendLine("                    limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
        [void]$Sb.AppendLine("                    save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
        [void]$Sb.AppendLine("                    add_dynasty_perk = $k")
        [void]$Sb.AppendLine("                    add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige }")
        [void]$Sb.AppendLine("                }")
        [void]$Sb.AppendLine("                else_if = {")
        [void]$Sb.AppendLine("                    limit = { dynasty_prestige >= { value = 250 add = { value = dynasty_num_unlocked_perks multiply = 500 } } }")
        [void]$Sb.AppendLine("                    add_dynasty_perk = $k")
        [void]$Sb.AppendLine("                }")
        [void]$Sb.AppendLine("            }")
    }
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("}")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("DI_perk_lock_all = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    foreach ($k in $PerkMap.Keys) {
        [void]$Sb.AppendLine("            if = {")
        [void]$Sb.AppendLine("                limit = { has_dynasty_perk = $k }")
        [void]$Sb.AppendLine("                remove_dynasty_perk = $k")
        [void]$Sb.AppendLine("            }")
    }
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("}")
    [void]$Sb.AppendLine("")
}

function New-DiSubMod {
    param(
        [string]$PerkModPath,
        [string]$PerkModName,
        [string]$BaseDIName,
        [string]$GameDir,
        [string]$TargetFolder,
        [string]$UserFolder,
        [string[]]$LocDirs,
        [string]$SubModName = "",           # override the compatch display name (default "DI Perks - <mod name>")
        [string[]]$ExtraPerkModDirs = @(),   # ordered submod paths; engine order, later wins
        [switch]$Open,                       # open the output folder in Explorer after generation
        [switch]$WhatIf
    )
    $perkDir = Join-Path $PerkModPath "common\dynasty_perks"
    if (-not (Test-Path $perkDir)) { throw "No common\dynasty_perks at $PerkModPath" }
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)

    $dirName = if ($PerkModName) { $PerkModName } else { Split-Path $PerkModPath -Leaf }
    $prefix  = ($dirName -replace '[^A-Za-z0-9_]', '_').ToLowerInvariant()
    if ($prefix -match '^[0-9]') { $prefix = "_$prefix" }

    # --- merged perk model: mods in reverse engine order (first-seen parse wins,
    # so later-loaded mods win key collisions), then surviving vanilla files ---
    # Extras may be passed as mod ROOTS (needed for descriptor deps + dynasty_legacies
    # gates + modifier defs + loc discovery) or as flat perk dirs (documented form).
    # Normalize to perk dirs for parsing while keeping a parallel mod-roots list -
    # without this, root-form extras contribute ZERO perk files and multi-mod
    # compatches silently miss their perk data.
    $vanillaPerkDir = Join-Path $GameDir "common\dynasty_perks"
    $modRoots = @($PerkModPath)
    $extraPerkDirs = @()
    foreach ($e in $ExtraPerkModDirs) {
        $pd = Join-Path $e "common\dynasty_perks"
        if (Test-Path $pd) {
            $extraPerkDirs += $pd
            $modRoots += $e
        } else {
            $extraPerkDirs += $e
            $derived = Split-Path (Split-Path $e -Parent) -Parent
            if ($derived -and (Test-Path (Join-Path $derived "descriptor.mod"))) { $modRoots += $derived } else { $modRoots += $e }
        }
    }
    $allPerkDirs = @($perkDir) + $extraPerkDirs
    $shadowNames = @{}
    foreach ($d in $allPerkDirs) { Get-ChildItem $d -Filter '*.txt' -ErrorAction SilentlyContinue | ForEach-Object { $shadowNames[$_.Name] = $true } }
    $tmpVanillaPerks = Get-VanillaSurvivorSnapshot -ModDir $allPerkDirs[0] -VanillaDir $vanillaPerkDir -Tag "perks_$prefix"
    # The survivor snapshot above only knows the first mod dir's shadows; remove
    # vanilla files shadowed by ANY mod dir so same-name replacements win.
    Get-ChildItem $tmpVanillaPerks -Filter '*.txt' | ForEach-Object {
        if ($shadowNames.ContainsKey($_.Name)) { Remove-Item -LiteralPath $_.FullName -Force }
    }
    $parseDirs = @()
    for ($i = $extraPerkDirs.Count - 1; $i -ge 0; $i--) { $parseDirs += $extraPerkDirs[$i] }
    $parseDirs += $perkDir
    $parseDirs += $tmpVanillaPerks
    try {
        $perks = Get-Perks -Directories $parseDirs
        $effectTexts = Get-PerkEffectTextKeys -Directories $parseDirs
        $perkModifiers = Get-PerkModifierBlocks -Directories $parseDirs
    } finally { Remove-Item -LiteralPath $tmpVanillaPerks -Recurse -Force -ErrorAction SilentlyContinue }
    if ($perks.Count -eq 0) { Write-Warning "No perks parsed from $perkDir or $vanillaPerkDir"; return }
    if (-not (Test-PerksModel $perks)) { throw "Parsed perk model is inconsistent - aborting before writing" }
    $tracks = Group-PerksByTrack $perks
    $gridTracks = @(Get-DiGridSelection $tracks -EmptyGrid:$DiagnosticEmptyGrid -TrackKeys $DiagnosticGridTracks)

    # --- DLC gates from the same merged sources' dynasty_legacies folders ---------
    # Mod ROOTS in REVERSE engine order + vanilla last: Get-TrackDlcGates is
    # first-seen-wins (_perk_parser.ps1), so this ordering makes later-loaded mods
    # win, matching the perk parseDirs convention. The perk-dir form used before
    # never resolved <perkdir>\common\dynasty_legacies, silently dropping the
    # primary mod's own gates.
    $vanillaLegacyDir = Join-Path $GameDir "common\dynasty_legacies"
    $legacyDirs = @()
    for ($i = $modRoots.Count - 1; $i -ge 0; $i--) {
        $ld = Join-Path $modRoots[$i] "common\dynasty_legacies"
        if (Test-Path $ld) { $legacyDirs += $ld }
    }
    if (Test-Path $vanillaLegacyDir) { $legacyDirs += $vanillaLegacyDir }
    $trackGates = if ($legacyDirs.Count -gt 0) { Get-TrackDlcGates -Directories $legacyDirs } else { @{} }

    $vanilla = Get-VanillaPerkSet $GameDir
    $newCount = 0
    foreach ($k in $perks.Keys) { if (-not $vanilla.Contains($k)) { $newCount++ } }
    Write-Host "Merged grid: $($perks.Count) perks / $($tracks.Count) tracks (mod adds $newCount new keys; same-name mod files replace vanilla files)."

    # (no $costRef: free mode refunds the exact engine charge per unit; the paid
    # gate uses the dynasty_num_unlocked_perks trigger - no mirror script value)

    # -- effect_localization + loc values for static tooltip text --
    # F4: Get-EffectLocalization is first-seen-wins - mod dirs BEFORE vanilla so
    # mod mappings win for shared keys.
    $effLocDirs = @()
    foreach ($r in $modRoots) {
        $el = Join-Path $r "common\effect_localization"
        if (Test-Path $el) { $effLocDirs += $el }
    }
    $effLocDirs += (Join-Path $GameDir "common\effect_localization")
    $effectLocMap = Get-EffectLocalization -Directories $effLocDirs
    $locMap = Get-LocValues -Directories $LocDirs
    # Fallback: some mods ship loc outside localization\english (e.g. AGOT nests it
    # in english\agot\, Hiraeth in localization\ directly). If a mod-added perk's
    # name key is unresolvable, append that mod's localization tree - all extra
    # dirs collected first, then ONE rebuild over vanilla + extras so "later wins"
    # applies and the vanilla map is never discarded.
    $langPattern = '(simp_chinese|french|german|spanish|russian|polish|braz_por|japanese|korean|chinese|turkish)'
    $extraLocDirs = @()
    foreach ($r in $modRoots) {
        $missing = $false
        foreach ($k in $perks.Keys) { if (-not $vanilla.Contains($k) -and [string]::IsNullOrEmpty($locMap["$($k)_name"])) { $missing = $true; break } }
        if (-not $missing) { continue }
        # $r is a mod root; the mod's localization tree hangs off it (Hiraeth:
        # localization\ directly, AGOT: localization\english\agot\).
        $root = Join-Path $r "localization"
        if (Test-Path $root) {
            foreach ($y in (Get-ChildItem $root -Filter '*.yml' -Recurse)) {
                if ($y.FullName -notmatch $langPattern) { $extraLocDirs += $y.DirectoryName }
            }
        }
    }
    if ($extraLocDirs.Count -gt 0) {
        # F4: Select-Object -Unique preserves collection order (mod load order) -
        # the previous alphabetical Sort-Object discarded intended precedence.
        # @($LocDirs) forces array concat: with a scalar $LocDirs the + would
        # string-join vanilla + extras into ONE nonexistent path (empty locMap ->
        # raw-key tooltips everywhere - the 2026-09-05 regression).
        $locMap = Get-LocValues -Directories (@($LocDirs) + @($extraLocDirs | Select-Object -Unique))
    }

    # -- modifier definitions (value-formatting metadata); vanilla first, then any
    # perk mod's own modifier_definition_formats (mod definitions win) --
    $modDefDirs = @((Join-Path $GameDir "common\modifier_definition_formats"))
    foreach ($r in $modRoots) {
        $md = Join-Path $r "common\modifier_definition_formats"
        if (Test-Path $md) { $modDefDirs += $md }
    }
    $modifierDefs = Get-ModifierDefinitions -Directories $modDefDirs

    # -- scripted guis --
    $sgui = [System.Text.StringBuilder]::new()
    [void]$sgui.AppendLine("# GENERATED FILE - do not hand-edit. generate_mod_perks.ps1 -SubMod")
    [void]$sgui.AppendLine("# Free mode: each unit grants first and refunds the EXACT engine charge")
    [void]$sgui.AppendLine("# (renown-before minus renown-after). Paid mode gates on the defines")
    [void]$sgui.AppendLine("# formula (250 + 500 x unlocked) via dynasty_num_unlocked_perks - no mirror.")
    [void]$sgui.AppendLine("# Bulk unlock-all/lock-all NAME-OVERRIDE the base mod's versions (later mod wins)")
    [void]$sgui.AppendLine("# so the window buttons cover the full merged perk set.")
    [void]$sgui.AppendLine("")
    Write-SubModSguiBlocks -Sb $sgui -PerkMap $perks -Tracks $tracks

    # -- grid: COMPLETE same-path override of the base mod's generated grid --
    # CK3 GUI type registration is first-loaded-wins; a second di_perk_grid_extension
    # definition is silently rejected, so the extension-slot approach can never render.
    # This compatch therefore ships the ENTIRE grid (vanilla + mod perks) at the base
    # mod's exact path and must load AFTER the base mod in the playset.
    $gui = [System.Text.StringBuilder]::new()
    if ($diagnostic) { [void]$gui.AppendLine("### DIAGNOSTIC GRID - GUI only; full effects retained. See DI_grid_manifest.json.") }
    [void]$gui.AppendLine("### GENERATED FILE - do not hand-edit. generate_mod_perks.ps1 -SubMod")
    [void]$gui.AppendLine("### Same-path full-file override of the base mod's gui/DI_generated_perk_grid.gui.")
    [void]$gui.AppendLine("### This compatch must be loaded AFTER the base mod in the playset.")
    if ($DiagnosticDisableOwnedState) {
        [void]$gui.AppendLine("### Ownership indicators and their bindings are omitted for diagnosis; click actions remain.")
    } else {
        [void]$gui.AppendLine("### Owned state IS rendered via pure datafunction bindings (gold border +")
        [void]$gui.AppendLine("### checkmark; fully-owned tracks tint gold). Buttons stay enabled for left-add /")
        [void]$gui.AppendLine("### right-remove; the SGUI is_shown guards make wrong-direction clicks no-ops.")
    }
    [void]$gui.AppendLine("")
    [void]$gui.AppendLine("types DI_DynastyGeneratedPerks {")
    [void]$gui.AppendLine("    type di_generated_perk_grid = vbox {")
    [void]$gui.AppendLine("        layoutpolicy_horizontal = expanding")
    [void]$gui.AppendLine("        spacing = 5")
    [void]$gui.AppendLine("")
    $gridTracks = @(Get-DiSortedGridTracks -TrackKeys $gridTracks -LocMap $locMap)
    foreach ($t in $gridTracks) {
        $gate = $null
        if ($trackGates.ContainsKey($t)) { $gate = $trackGates[$t] }
        Write-VanillaTrackSection $gui $t $tracks[$t] $gate -DisableOwnedState:$DiagnosticDisableOwnedState
    }
    [void]$gui.AppendLine("    }")
    [void]$gui.AppendLine("    type di_perk_grid_extension = vbox {")
    [void]$gui.AppendLine("        layoutpolicy_horizontal = expanding")
    [void]$gui.AppendLine("    }")
    [void]$gui.AppendLine("}")

    # -- tooltip loc: STATIC resolved text (same format as the base generator).
    # CRITICAL: emit ONLY mod-added perk keys - vanilla keys are already covered by
    # the base mod's DI_generated_perk_tooltips_l_english.yml, and duplicate
    # definitions break loc resolution engine-side (pdx_localize errors).
    $ttLoc = [System.Text.StringBuilder]::new()
    [void]$ttLoc.AppendLine("# =============================================================================")
    [void]$ttLoc.AppendLine("# GENERATED FILE - do not hand-edit. generate_mod_perks.ps1 -SubMod")
    [void]$ttLoc.AppendLine("# Grid button tooltips: perk name (bold, $<key>_name$ loc var) + effect/modifier lines.")
    [void]$ttLoc.AppendLine("# =============================================================================")
    [void]$ttLoc.AppendLine("")
    [void]$ttLoc.AppendLine("l_english:")
    $modCount = 0
    foreach ($k in $perks.Keys) {
        if ($vanilla.Contains($k)) { continue }
        $name = $locMap["$($k)_name"]
        if ([string]::IsNullOrEmpty($name)) { $name = "$($k)_name" }
        # heading as a loc variable ref (not baked text): follows load-order loc at
        # runtime so renaming mods keep tooltip heading and button label in sync;
        # raw key fallback when the name loc is missing entirely
        if ($name -ne "$($k)_name") {
            $parts = '#bold $' + $k + '_name$#!'
        } else {
            $parts = "#bold $($k)_name#!"
        }
        if ($effectTexts.ContainsKey($k)) {
            foreach ($e in $effectTexts[$k]) {
                $locKey = if ($effectLocMap.ContainsKey($e)) { $effectLocMap[$e] } else { $e }
                $eff = $locMap[$locKey]
                # custom_description_no_bullet keys resolve under vanilla's _global suffix
                if ([string]::IsNullOrEmpty($eff)) { $eff = $locMap["${e}_global"] }
                if ([string]::IsNullOrEmpty($eff)) { $eff = $e }
                $parts += "\n$eff"
            }
        }
        if ($perkModifiers.ContainsKey($k)) {
            foreach ($mline in (ConvertTo-PerkModifierTooltipLines -ModifierBlocks $perkModifiers[$k] -ModifierDefs $modifierDefs -LocMap $locMap -PerkKey $k -PerkNameText $name)) {
                $parts += "\n$mline"
            }
        }
        # F8: escape only UNescaped quotes - captured loc values keep their source
        # escape sequences (\", \\) verbatim, so a blanket replace would double them.
        $escaped = $parts -replace '(?<!\\)"', '\"'
        [void]$ttLoc.AppendLine(" DI_perk_tt_${k}:0 `"$escaped`"")
        $modCount++
    }
    Write-Host "Tooltip loc: $modCount mod-added entries (vanilla keys resolve from the base mod's loc file)."

    # -- script value emitter REMOVED (refund simplification): no per-track cost
    # mirror is generated; free mode refunds the exact engine charge per unit and
    # the paid gate uses dynasty_num_unlocked_perks (mirrors 00_defines.txt).

    # -- output --
    $outDir = $TargetFolder
    $modDisplayName = if ($SubModName) { $SubModName } else { "DI Perks - $dirName" }
    if (-not $outDir) { $outDir = Join-Path $UserFolder "mod\$modDisplayName" }

    $deps = @($dirName)
    # $modRoots[0] is the primary mod (already covered by $dirName); the rest are
    # the extras - now correct for BOTH root-form and perk-dir-form extras.
    foreach ($d in ($modRoots | Select-Object -Skip 1)) {
        $desc = Join-Path $d "descriptor.mod"
        $nm = $null
        if (Test-Path $desc) { $m = Select-String -Path $desc -Pattern 'name="([^"]+)"' | Select-Object -First 1; if ($m) { $nm = $m.Matches[0].Groups[1].Value } }
        if (-not $nm) { $nm = Split-Path $d -Leaf }
        $deps += $nm
    }
    $deps += $BaseDIName

    if ($WhatIf) {
        Write-Host "[WhatIf] Would generate sub-mod (prefix=$prefix, $($perks.Count) perks / $($tracks.Count) tracks) -> $outDir"
        Write-Host "[WhatIf] Descriptor name: $modDisplayName"
        Write-Host "[WhatIf] Dependencies: $($deps -join ', ')"
        return
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $outDir "common\scripted_guis") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $outDir "gui") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $outDir "localization\english") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $outDir "common\scripted_guis\DI_generated_submod_${prefix}_toggles_sgui.txt"), $sgui.ToString(), $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $outDir "gui\DI_generated_perk_grid.gui"), $gui.ToString(), $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $outDir "localization\english\DI_generated_perk_tt_l_english.yml"), $ttLoc.ToString(), $utf8Bom)
    # remove the pre-v15 extension-slot grid if a previous run created it
    # (LiteralPath: IFFTed folder names contain [] which -Path would glob)
    $staleGrid = Join-Path $outDir "gui\DI_generated_submod_${prefix}_grid.gui"
    if (Test-Path -LiteralPath $staleGrid) { Remove-Item -LiteralPath $staleGrid -Force; Write-Host "Removed stale extension-slot grid: $staleGrid" }
    # remove the pre-simplification cost-mirror values file (refund simplification:
    # no script value is generated anymore - free mode refunds the exact engine charge)
    $staleValues = Join-Path $outDir "common\script_values\DI_generated_submod_${prefix}_values.txt"
    if (Test-Path -LiteralPath $staleValues) {
        Remove-Item -LiteralPath $staleValues -Force
        Write-Host "Removed stale cost-mirror values file: $staleValues"
        $svDir = Split-Path $staleValues -Parent
        if ((Get-ChildItem -LiteralPath $svDir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) { Remove-Item -LiteralPath $svDir -Force }
    }
    # deps were computed before the WhatIf gate; only the write happens here.

    Write-Descriptor -OutDir $outDir -ModName $modDisplayName -Depends $deps -UserFolder $UserFolder -WriteLauncher ([string]::IsNullOrEmpty($TargetFolder))
    Write-Host "Wrote sub-mod to $outDir"
    Write-DiGridManifest -OutputDir $outDir -GridPath (Join-Path $outDir 'gui/DI_generated_perk_grid.gui') -InputPaths (@($GameDir) + @($modRoots)) -Tracks $tracks -SelectedTracks $gridTracks -Gates $trackGates -Diagnostic $diagnostic -DisableOwnedState $DiagnosticDisableOwnedState
    if ($Open) { Start-Process explorer.exe $outDir }
}

# --- F4: combined compatch for a set of perk mods --------------------------------
function New-DiCombinedMod {
    param(
        [object[]]$PerkMods,          # @{Path; Name}
        [string]$CombinedName,
        [string]$BaseDIName,
        [string]$GameDir,
        [string]$TargetFolder,
        [string]$UserFolder,
        [string[]]$LocDirs,
        [switch]$WhatIf
    )
    if (-not $PerkMods -or $PerkMods.Count -eq 0) { throw "No perk mods supplied to combined generation." }
    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    $vanilla = Get-VanillaPerkSet $GameDir

    # Merge NEW keys across all mods, dedup by perk key; collect manifest data.
    $newPerks = [ordered]@{}
    $trackGates = @{}
    $manifestRows = @()
    foreach ($m in $PerkMods) {
        $perkDir = Join-Path $m.Path "common\dynasty_perks"
        if (-not (Test-Path $perkDir)) { Write-Warning "Skipping $($m.Name) - no perks dir"; continue }
        $perks = Get-Perks -Directories $perkDir
        $added = 0
        foreach ($k in $perks.Keys) {
            if (-not $vanilla.Contains($k) -and -not $newPerks.Contains($k)) { $newPerks[$k] = $perks[$k]; $added++ }
        }
        $legacyDir = Join-Path $m.Path "common\dynasty_legacies"
        if (Test-Path $legacyDir) {
            foreach ($g in (Get-TrackDlcGates -Directories $legacyDir).GetEnumerator()) {
                if (-not $trackGates.ContainsKey($g.Key)) { $trackGates[$g.Key] = $g.Value }
            }
        }
        $manifestRows += [pscustomobject]@{ Name = $m.Name; NewCount = $added }
    }
    if ($newPerks.Count -eq 0) { Write-Warning "No new (non-vanilla) keys across selected mods - nothing to generate."; return }
    $newTracks = Group-PerksByTrack $newPerks

    $modName = $CombinedName
    if (-not $modName) { $modName = "DI Perks - Combined" }
    $prefix = ($modName -replace '[^A-Za-z0-9_]', '_').ToLowerInvariant()
    if ($prefix -match '^[0-9]') { $prefix = "_$prefix" }
    Write-Host "Combined: $($newPerks.Count) new perks / $($newTracks.Count) tracks from $($PerkMods.Count) mod(s)."

    # -- scripted guis --
    $sgui = [System.Text.StringBuilder]::new()
    [void]$sgui.AppendLine("# GENERATED FILE - do not hand-edit. generate_mod_perks.ps1 -Playset / combined")
    [void]$sgui.AppendLine("# Free mode: each unit grants first and refunds the EXACT engine charge.")
    [void]$sgui.AppendLine("")
    foreach ($k in $newPerks.Keys) {
        [void]$sgui.AppendLine("DI_perk_add_$k = {")
        [void]$sgui.AppendLine("    scope = character")
        [void]$sgui.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { NOT = { has_dynasty_perk = $k } } }")
        [void]$sgui.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        [void]$sgui.AppendLine("        if = { limit = { NOT = { has_dynasty_perk = $k } }")
        [void]$sgui.AppendLine("                if = { limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
        [void]$sgui.AppendLine("                    save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
        [void]$sgui.AppendLine("                    add_dynasty_perk = $k")
        [void]$sgui.AppendLine("                    add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige } }")
        [void]$sgui.AppendLine("                add_dynasty_perk = $k }")
        [void]$sgui.AppendLine("    } }")
        [void]$sgui.AppendLine("}")
        [void]$sgui.AppendLine("")
        [void]$sgui.AppendLine("DI_perk_remove_$k = {")
        [void]$sgui.AppendLine("    scope = character")
        [void]$sgui.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { has_dynasty_perk = $k } }")
        [void]$sgui.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        [void]$sgui.AppendLine("        if = { limit = { has_dynasty_perk = $k } remove_dynasty_perk = $k }")
        [void]$sgui.AppendLine("    } }")
        [void]$sgui.AppendLine("}")
        [void]$sgui.AppendLine("")
    }
    foreach ($t in $newTracks.Keys) {
        $trk = $newTracks[$t]
        [void]$sgui.AppendLine("DI_track_add_all_$t = {")
        [void]$sgui.AppendLine("    scope = character")
        [void]$sgui.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { NOT = { $($t)_perks >= $($trk.Count) } } }")
        [void]$sgui.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        foreach ($k in $trk) {
            [void]$sgui.AppendLine("        if = { limit = { NOT = { has_dynasty_perk = $k } }")
            [void]$sgui.AppendLine("                if = { limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
            [void]$sgui.AppendLine("                    save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
            [void]$sgui.AppendLine("                    add_dynasty_perk = $k")
            [void]$sgui.AppendLine("                    add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige } }")
            [void]$sgui.AppendLine("                add_dynasty_perk = $k }")
        }
        [void]$sgui.AppendLine("    } }")
        [void]$sgui.AppendLine("}")
        [void]$sgui.AppendLine("")
        [void]$sgui.AppendLine("DI_track_remove_all_$t = {")
        [void]$sgui.AppendLine("    scope = character")
        [void]$sgui.AppendLine("    is_shown = { var:DI_dynasty_selected_dynasty = { $($t)_perks > 0 } }")
        [void]$sgui.AppendLine("    effect = { var:DI_dynasty_selected_dynasty = {")
        foreach ($k in $trk) {
            [void]$sgui.AppendLine("        if = { limit = { has_dynasty_perk = $k } remove_dynasty_perk = $k }")
        }
        [void]$sgui.AppendLine("    } }")
        [void]$sgui.AppendLine("}")
        [void]$sgui.AppendLine("")
    }

    # -- grid: single di_perk_grid_extension merging all rows --
    $gui = [System.Text.StringBuilder]::new()
    [void]$gui.AppendLine("### GENERATED FILE - do not hand-edit. generate_mod_perks.ps1 -Playset / combined")
    [void]$gui.AppendLine("types DI_DynastyGeneratedCombined$prefix {")
    [void]$gui.AppendLine("    type di_perk_grid_extension = vbox {")
    [void]$gui.AppendLine("        layoutpolicy_horizontal = expanding")
    [void]$gui.AppendLine("        spacing = 5")
    foreach ($t in $newTracks.Keys) {
        $perkList = $newTracks[$t]
        $gate = $null
        if ($trackGates.ContainsKey($t)) { $gate = $trackGates[$t] }
        [void]$gui.AppendLine("        # ---- $t ($($perkList.Count) perks)$(if ($gate) { " [DLC: $gate]" }) ----")
        [void]$gui.AppendLine("        vbox = {")
        if ($gate) { [void]$gui.AppendLine("            visible = ""[HasDlcFeature( '$gate' )]""") }
        [void]$gui.AppendLine("            layoutpolicy_horizontal = expanding")
        [void]$gui.AppendLine("            margin = { 5 5 }")
        [void]$gui.AppendLine("            hbox = {")
        [void]$gui.AppendLine("                layoutpolicy_horizontal = expanding")
        [void]$gui.AppendLine("                spacing = 8")
        [void]$gui.AppendLine("                icon = {")
        [void]$gui.AppendLine("                    texture = ""gfx/interface/icons/dynasty/$t.dds""")
        [void]$gui.AppendLine("                    size = { 24 24 }")
        [void]$gui.AppendLine("                }")
        [void]$gui.AppendLine("                text_single = {")
        [void]$gui.AppendLine("                    layoutpolicy_horizontal = expanding")
        [void]$gui.AppendLine('                    text = "[Localize('''+ $t + '_name'')]"')
        [void]$gui.AppendLine('                    tooltip = "[Localize('''+ $t + '_desc'')]"')
        [void]$gui.AppendLine('                    default_format = ""#high""')
        [void]$gui.AppendLine("                }")
        [void]$gui.AppendLine("                button_standard = {")
        [void]$gui.AppendLine("                    size = { 130 26 }")
        [void]$gui.AppendLine("                    text = DI_DYNASTY_EDITOR_TRACK_BUTTON")
        [void]$gui.AppendLine("                    onclick = ""[GetScriptedGui('DI_track_add_all_$t').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
        [void]$gui.AppendLine("                    onrightclick = ""[GetScriptedGui('DI_track_remove_all_$t').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
        [void]$gui.AppendLine("                    tooltip = DI_DYNASTY_EDITOR_TRACK_BUTTON_TT")
        [void]$gui.AppendLine("                }")
        [void]$gui.AppendLine("            }")
        [void]$gui.AppendLine("            flowcontainer = {")
        [void]$gui.AppendLine("                layoutpolicy_horizontal = expanding")
        [void]$gui.AppendLine("                spacing = 5")
        foreach ($k in $perkList) {
            [void]$gui.AppendLine("                button_standard = {")
            [void]$gui.AppendLine("                    size = { 260 44 }")
            [void]$gui.AppendLine("                    button_ignore = none")
            [void]$gui.AppendLine("                    onclick = ""[GetScriptedGui('DI_perk_add_$k').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
            [void]$gui.AppendLine("                    onrightclick = ""[GetScriptedGui('DI_perk_remove_$k').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]""")
            [void]$gui.AppendLine('                    tooltip = "[Localize('''+ $k + '_name'')]"')
            [void]$gui.AppendLine("                    hbox = {")
            [void]$gui.AppendLine("                        margin = { 5 0 }")
            [void]$gui.AppendLine("                        spacing = 8")
            [void]$gui.AppendLine("                        icon = {")
            [void]$gui.AppendLine("                            size = { 34 34 }")
            [void]$gui.AppendLine("                            texture = ""gfx/interface/icons/dynasty/$t.dds""")
            [void]$gui.AppendLine("                        }")
            [void]$gui.AppendLine("                        text_single = {")
            [void]$gui.AppendLine("                            layoutpolicy_horizontal = expanding")
            [void]$gui.AppendLine('                            text = "[Localize(''' + $k + '_name'')]"')
            [void]$gui.AppendLine('                            default_format = ""#clickable""')
            [void]$gui.AppendLine("                        }")
            [void]$gui.AppendLine("                    }")
            [void]$gui.AppendLine("                }")
        }
        [void]$gui.AppendLine("            }")
        [void]$gui.AppendLine("        }")
    }
    [void]$gui.AppendLine("    }")
    [void]$gui.AppendLine("}")

    # -- script value emitter REMOVED (refund simplification): no per-track cost
    # mirror for the combined route either; free mode refunds the exact engine
    # charge per unit, the paid gate uses dynasty_num_unlocked_perks.

    # -- manifest --
    $manifest = [System.Text.StringBuilder]::new()
    [void]$manifest.AppendLine("DI Perks combined compatch: $modName")
    [void]$manifest.AppendLine("Generated with tools/generate_mod_perks.ps1 -Playset or combined")
    [void]$manifest.AppendLine("This compatch adds editor toggles for the following perk mods:")
    [void]$manifest.AppendLine("")
    foreach ($r in $manifestRows) { [void]$manifest.AppendLine(("- {0}  ({1} new perks)" -f $r.Name, $r.NewCount)) }

    # -- output --
    $outDir = $TargetFolder
    if (-not $outDir) { $outDir = Join-Path $UserFolder "mod\$modName" }
    if ($WhatIf) { Write-Host "[WhatIf] Would generate combined (prefix=$prefix, $($newPerks.Count) perks / $($newTracks.Count) tracks) -> $outDir"; return }
    New-Item -ItemType Directory -Force -Path (Join-Path $outDir "common\scripted_guis") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $outDir "gui") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $outDir "common\scripted_guis\DI_generated_combined_${prefix}_toggles_sgui.txt"), $sgui.ToString(), $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $outDir "gui\DI_generated_combined_${prefix}_grid.gui"), $gui.ToString(), $utf8Bom)
    [System.IO.File]::WriteAllText((Join-Path $outDir "README_DI_perks.txt"), $manifest.ToString(), $utf8Bom)
    $deps = @()
    foreach ($m in $PerkMods) { $deps += $m.Name }
    $deps += $BaseDIName
    Write-Descriptor -OutDir $outDir -ModName $modName -Depends $deps -UserFolder $UserFolder -WriteLauncher $true
    Write-Host "Wrote combined compatch to $outDir"
}

# --- F2: interactive menu ---------------------------------------------------------
function Invoke-DiMenu {
    Write-Host "===================================================="
    Write-Host " DI Dynasty Perk Editor - Mod Support Generator"
    Write-Host "===================================================="
    $results = Invoke-DiScan
    Show-ScanTable $results
    Write-Host ""
    if ($results.Count -eq 0) { Write-Host "No perk mods found - nothing to do."; return }
    $baseName = Get-BaseDiName
    Write-Host "Choose an action:"
    Write-Host "  1) Generate ONE combined compatch from ALL listed perk mods"
    Write-Host "  2) Generate a standalone compatch for a single perk mod"
    Write-Host "  3) Generate from a Playset (recommended for a modlist)"
    Write-Host "  q) quit"
    $choice = Read-Host "> "
    switch ($choice) {
        "1" {
            $mods = $results | ForEach { [pscustomobject]@{ Path = $_.Path; Name = $_.Name } }
            $name = Read-Host "Combined mod name [DI Perks - Combined]: "
            if (-not $name) { $name = "DI Perks - Combined" }
            New-DiCombinedMod -PerkMods $mods -CombinedName $name -BaseDIName $baseName -GameDir $GameDir -UserFolder $UserFolder -LocDirs $LocDirs -WhatIf:$WhatIf
        }
        "2" {
            Write-Host "Numbered list (or -SubMod <name> at the CLI works too):"
            for ($i=0; $i -lt $results.Count; $i++) { Write-Host ("  {0}) {1}  [{2}]" -f ($i+1), $results[$i].Name, $results[$i].Path) }
            $sel = Read-Host "> "
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $results.Count) {
                $s = $results[$idx]
                New-DiSubMod -PerkModPath $s.Path -PerkModName $s.Name -BaseDIName $baseName -GameDir $GameDir -UserFolder $UserFolder -LocDirs $LocDirs -WhatIf:$WhatIf
            } else { Write-Host "Bad choice." }
        }
        "3" {
            $name = Read-Host "Playset name (use -Playset <name> at CLI too): "
            if (-not $name) { $name = "IronyModManager" }
            $mods = Get-PlaysetMods -UserFolder $UserFolder -PlaysetName $name
            $pl = @($mods | ForEach { if ($_.Path -and (Test-Path (Join-Path $_.Path "common\dynasty_perks"))) { [pscustomobject]@{ Path = $_.Path; Name = $_.Name } } })
            if ($pl.Count -eq 0) { Write-Host "No perk mods in that playset."; return }
            New-DiCombinedMod -PerkMods $pl -CombinedName "DI Perks - $name" -BaseDIName $baseName -GameDir $GameDir -UserFolder $UserFolder -LocDirs $LocDirs -WhatIf:$WhatIf
        }
        default { Write-Host "Bye." }
    }
}

# --- Playset resolution ------------------------------------------------------------
function Get-PlaysetMods {
    param([string]$UserFolder, [string]$PlaysetName)
    $db = Join-Path $UserFolder "launcher-v2.sqlite"
    if (-not (Test-Path -LiteralPath $db)) { throw "launcher-v2.sqlite not found at $db" }
    $tmp = Join-Path $env:TEMP ("lv_copy_{0}.sqlite" -f ([guid]::NewGuid().ToString('N')))
    Copy-Item -LiteralPath $db -Destination $tmp -Force
    $py = "$env:TEMP\di_lv_read.py"
    @" 
import sqlite3, sys
db=sys.argv[1]; name=sys.argv[2]
c=sqlite3.connect(db); cur=c.cursor()
cur.execute("SELECT m.id, m.displayName, m.dirPath, m.source FROM playsets p JOIN playsets_mods pm ON pm.playsetId=p.id JOIN mods m ON m.id=pm.modId WHERE p.name=? AND p.isRemoved=0 AND pm.enabled=1 ORDER BY pm.position", (name,))
for r in cur.fetchall():
    print("|".join(str(x) if x is not None else "" for x in r))
"@ | Set-Content -LiteralPath $py -Encoding UTF8
    try {
        $out = python $py $tmp $PlaysetName 2>$null
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    $mods = @()
    foreach ($line in $out) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split('|')
        if ($parts.Length -ge 2) { $mods += [pscustomobject]@{ Id=$parts[0]; Name=$parts[1]; Path=if($parts.Length -gt 2){$parts[2]}else{""}; Source=if($parts.Length -gt 3){$parts[3]}else{""} } }
    }
    return $mods
}

# --- Main ------------------------------------------------------------------------
$baseDIName = Get-BaseDiName
# -File invocations cannot pass PS arrays: accept a single comma/semicolon-joined
# string for -SubModExtraDirs (mirrors -PlaysetMods) and split it here. Paths with
# commas are not supported.
$SubModExtraDirs = @($SubModExtraDirs | ForEach-Object { $_ -split '[;,]+' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Scan) {
    # scan-only execution must not fall through to the interactive menu (audit F10)
    Show-ScanTable (Invoke-DiScan | Sort-Object PerkCount -Descending)
    return
}
if ($Playset) {
    $pm = Get-PlaysetMods -UserFolder $UserFolder -PlaysetName $Playset
    $select = @($pm | ForEach { if ($_.Path -and (Test-Path (Join-Path $_.Path "common\dynasty_perks"))) { [pscustomobject]@{ Path=$_.Path; Name=$_.Name } } })
    $cn = $CombinedName;     if (-not $cn) { $cn = "DI Perks - $Playset" }
    New-DiCombinedMod -PerkMods $select -CombinedName $cn -BaseDIName $baseDIName -GameDir $GameDir -TargetFolder $TargetFolder -UserFolder $UserFolder -LocDirs $LocDirs -WhatIf:$WhatIf
}
elseif ($PlaysetMods -or $SubMods) {
    # Explicit list of perk mod names to combine, comma/semicolon separated.
    $listStr = if ($PlaysetMods) { $PlaysetMods } else { $SubMods }
    $names = @($listStr -split '[;,]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $cands = Get-ModCandidates
    $select = @()
    foreach ($n in $names) {
        $match = @($cands | Where { $_.Name -like "*$n*" -or $_.Path -like "*$n*" })
        if ($match.Count -gt 0) { $select += [pscustomobject]@{ Path=$match[0].Path; Name=$match[0].Name } }
        else { Write-Warning "No match for '$n' - skipped." }
    }
    if ($select.Count -eq 0) { Write-Warning "No mods matched -PlaysetMods."; exit 1 }
    Write-Host "Selected: $($select.Count) mod(s)."
    New-DiCombinedMod -PerkMods $select -CombinedName $CombinedName -BaseDIName $baseDIName -GameDir $GameDir -TargetFolder $TargetFolder -UserFolder $UserFolder -LocDirs $LocDirs -WhatIf:$WhatIf
}
elseif ($PlaysetJson) {
    # Playset EXPORT json: {"game":"ck3","mods":[{displayName,enabled,position,steamId}]}
    # Routes through New-DiSubMod (current single-mod emitters: full same-path grid,
    # bulk unlock/lock-all name-overrides, one merged cost value) - NOT the obsolete
    # -Playset combined route (audit F1). Load order = JSON position.
    if (-not (Test-Path $PlaysetJson)) { Write-Warning "Playset JSON not found: $PlaysetJson"; exit 1 }
    $ps = Get-Content $PlaysetJson -Raw | ConvertFrom-Json
    $steamRoot = $GameDir -replace '\\common\\[^\\]+\\game$', ''
    $workshop = Join-Path $steamRoot "workshop\content\1158310"
    $perkMods = @()
    foreach ($m in ($ps.mods | Where-Object { $_.enabled } | Sort-Object position)) {
        $dir = Join-Path $workshop $m.steamId
        if (-not (Test-Path $dir)) {
            $cand = @(Get-ModCandidates | Where-Object { $_.Name -eq $m.displayName })
            if ($cand.Count -gt 0) { $dir = $cand[0].Path } else { Write-Warning "Playset mod '$($m.displayName)' (steamId $($m.steamId)) is not installed - skipped"; continue }
        }
        if (Test-Path (Join-Path $dir "common\dynasty_perks")) {
            $perkMods += [pscustomobject]@{ Path = $dir; Name = $m.displayName }
        }
    }
    if ($perkMods.Count -eq 0) { Write-Warning "No perk mods found in playset export."; exit 1 }
    Write-Host "Playset: $($perkMods.Count) perk mod(s) in load order: $(($perkMods | ForEach-Object { $_.Name }) -join ' -> ')"
    $primary = $perkMods[0]
    $extras = @($perkMods | Select-Object -Skip 1 | ForEach-Object { $_.Path })
    $cn = if ($SubModName) { $SubModName } else { "DI Perks - $([System.IO.Path]::GetFileNameWithoutExtension($PlaysetJson))" }
    New-DiSubMod -PerkModPath $primary.Path -PerkModName $primary.Name -BaseDIName $baseDIName -GameDir $GameDir -TargetFolder $TargetFolder -UserFolder $UserFolder -LocDirs $LocDirs -SubModName $cn -ExtraPerkModDirs $extras -Open:$Open -WhatIf:$WhatIf
}
elseif ($SubMod) {
    $cands = Get-ModCandidates
    # exact display-name match first; fuzzy matching must only consider mods that
    # actually HAVE a perk dir - renamed compatch copies (no common\dynasty_perks)
    # would otherwise win the -like match and break generation.
    $match = @($cands | Where { $_.Name -ieq $SubMod })
    if ($match.Count -eq 0) {
        $match = @($cands | Where { ($_.Name -like "*$SubMod*" -or $_.Path -like "*$SubMod*") -and (Test-Path (Join-Path $_.Path "common\dynasty_perks")) })
    }
    if ($match.Count -eq 0) { Write-Warning "No perk mod matched '$SubMod'."; exit 1 }
    if ($match.Count -gt 1) { Write-Warning "'$SubMod' matched multiple; using first." }
    $sel = $match[0]
    Write-Host "Generating sub-mod for: $($sel.Name)"
    New-DiSubMod -PerkModPath $sel.Path -PerkModName $sel.Name -BaseDIName $baseDIName -GameDir $GameDir -TargetFolder $TargetFolder -UserFolder $UserFolder -LocDirs $LocDirs -SubModName $SubModName -ExtraPerkModDirs $SubModExtraDirs -Open:$Open -WhatIf:$WhatIf
}
else {
    Invoke-DiMenu
}
