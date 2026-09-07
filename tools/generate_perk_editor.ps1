# =============================================================================
# DI Dynasty Perk Editor - Generator (Phase 1 step 0, plan v2)
# =============================================================================
# Reads vanilla (and optionally mod) common/dynasty_perks/*.txt and generates:
#   1. common/scripted_guis/DI_generated_perk_toggles_sgui.txt
#      - one per-perk toggle scripted gui: add if missing, remove if owned
#   2. gui/DI_generated_perk_grid.gui
#      - a `di_generated_perk_grid` type (vbox: one row per track, N perk buttons)
#   3. localization/english/DI_generated_perk_tooltips_l_english.yml
#      - one DI_perk_tt_<perk> loc entry per perk: name + effect description +
#        character_modifier lines, used as the grid button tooltip (game-like,
#        mirrors vanilla highlight)
#
# Usage:
#   pwsh -File tools/generate_perk_editor.ps1
#   pwsh -File tools/generate_perk_editor.ps1 -GameDir "H:\SteamLibrary\steamapps\common\Crusader Kings III\game" -ModDir . -ExtraPerkDirs "C:\path\to\some_mod\common\dynasty_perks"
#
# Re-run after every game patch or when adding perk mods. Output is fully
# regenerated (idempotent). Do not hand-edit the generated files.
# =============================================================================

param(
    [string]$GameDir = "H:\SteamLibrary\steamapps\common\Crusader Kings III\game",
    [string]$ModDir  = "$PSScriptRoot\..",
    [string[]]$ExtraPerkDirs = @(),   # e.g. AGOT mod's common/dynasty_perks
    [string[]]$LocDirs = @("H:\SteamLibrary\steamapps\common\Crusader Kings III\game\localization\english"),
    [switch]$DiagnosticEmptyGrid,
    [string[]]$DiagnosticGridTracks = @(),
    [switch]$DiagnosticDisableOwnedState,
    [switch]$WhatIf,
    [switch]$Check   # dry-run summary only (no writes); used by validate_perk_editor.ps1
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_grid_diagnostics.ps1")
$diagnostic = $DiagnosticEmptyGrid -or $DiagnosticGridTracks.Count -gt 0 -or $DiagnosticDisableOwnedState
if ($diagnostic) {
    if (-not $PSBoundParameters.ContainsKey('ModDir')) { throw 'Diagnostic generation requires explicit -ModDir staging output.' }
    Assert-DiDiagnosticOutput $ModDir
}
if ($DiagnosticEmptyGrid -and $DiagnosticGridTracks.Count) { throw 'DiagnosticEmptyGrid and DiagnosticGridTracks are mutually exclusive.' }
$WhatIf = $WhatIf -or $Check

$perkDirs   = @("$GameDir\common\dynasty_perks") + $ExtraPerkDirs
$outSgui    = Join-Path $ModDir "common\scripted_guis\DI_generated_perk_toggles_sgui.txt"
$outGui     = Join-Path $ModDir "gui\DI_generated_perk_grid.gui"
$outTtLoc   = Join-Path $ModDir "localization\english\DI_generated_perk_tooltips_l_english.yml"

# --- Free-edit renown handling ------------------------------------------------
# add_dynasty_perk DEDUCTS renown at the vanilla cost (user-confirmed in-game):
#   cost = 250 (PERK_COST_BASE) + 500 (PERK_COST_MULTIPLIER) x total perks owned
# Free mode grants FIRST and then refunds the EXACT engine charge, computed as
# renown-before minus renown-after (save_scope_value_as + inline subtract value) -
# the net renown change is zero regardless of which perks the dynasty already owns.
# A flat top-up (first design) and the generated per-track cost-mirror script value
# (previous design, DI_dynasty_perk_cost_next) were both removed: the mirror
# duplicated engine state and under-counted whenever modded tracks lagged coverage.
# The paid gate mirrors the defines formula directly via dynasty_num_unlocked_perks.

# --- DLC gating ----------------------------------------------------------------
# Tracks can be DLC-gated in vanilla via is_shown = { has_dlc_feature = X }.
# The generator parses that gate and wraps each track row in the grid with
# HasDlcFeature('X') so the row is hidden when the DLC is missing (no errors,
# no dead buttons). Tracks without a gate are always shown.
# NOTE: only the FIRST has_dlc_feature in is_shown is used; vanilla tracks use
# exactly one (sometimes followed by OR game-rule/government conditions, which
# are ignored - worst case a gated track shows for players who disabled the
# "unrestricted legacies" game rule, which is acceptable for a cheat menu).

# --- Shared parser (dot-sourced) -------------------------------------------------
# Both generators use the same parser so a fix/feature lands in both. Extraction
# moved verbatim here into _perk_parser.ps1 (plan v9 F5). The vanilla-look grid
# writers live in _grid_templates.ps1 and are dot-sourced further down - AFTER the
# parse and the encoding setup, because that module is definitions-only and the
# emit below needs $perks / $tracks / $trackGates / $utf8Bom in scope.
. (Join-Path $PSScriptRoot "_perk_parser.ps1")

Write-Host "Parsing perk files..."
$perks = Get-Perks -Directories $perkDirs
if ($perks.Count -eq 0) { throw "No perks parsed - check -GameDir" }
if (-not (Test-PerksModel $perks)) { throw "Parsed perk model is inconsistent - aborting before writing generated files" }

# effect-text loc keys per perk (for the generated tooltip loc file). Missing key
# = perk has no effect = { ... } text; the tooltip falls back to name-only.
$effectTexts = Get-PerkEffectTextKeys -Directories $perkDirs

# loc values (key -> resolved text) for static tooltip emission. Vanilla first,
# then any extra loc dirs (mod loc wins). Resolved at generation time so the
# emitted loc file contains only static text - [Localize('key')] wrappers broke
# in-game because no vanilla tooltip loc uses that quoted form.
$locMap = Get-LocValues -Directories $LocDirs

# effect_localization chain: some perk effect texts (e.g. warfare_legacy_5_effect)
# are dynamic - the real text lives in a plain loc key via common/effect_localization.
# Load that mapping so tooltip resolution can follow the chain instead of falling
# back to the raw dynamic key.
# F4: Get-EffectLocalization is first-seen-wins, so extra (mod) dirs must come
# BEFORE vanilla or vanilla mappings would shadow mod mappings for shared keys.
$effLocDirs = @($perkDirs | Select-Object -Skip 1 | ForEach-Object { $_ -replace 'dynasty_perks$', 'effect_localization' })
$effLocDirs += @("$GameDir\common\effect_localization")
$effectLocMap = Get-EffectLocalization -Directories $effLocDirs

# modifier definitions (value-formatting metadata) + per-perk character_modifier
# blocks, for the static modifier lines appended to each perk tooltip. Vanilla
# definitions first; extra perk dirs' sibling modifier_definition_formats override
# afterwards (mods may add their own definitions).
$modDefDirs = @("$GameDir\common\modifier_definition_formats")
foreach ($d in $ExtraPerkDirs) {
    $md = $d -replace 'dynasty_perks$', 'modifier_definition_formats'
    if (Test-Path $md) { $modDefDirs += $md }
}
$modifierDefs = Get-ModifierDefinitions -Directories $modDefDirs
$perkModifiers = Get-PerkModifierBlocks -Directories $perkDirs

# parse DLC gates from the same dirs' sibling dynasty_legacies folders
$legacyDirs = $perkDirs | ForEach-Object { $_ -replace 'dynasty_perks$', 'dynasty_legacies' }
$trackGates = Get-TrackDlcGates -Directories $legacyDirs
$gatedCount = ($trackGates.Values | Where-Object { $_ }).Count
Write-Host "Parsed $($perks.Count) perks ($gatedCount DLC-gated tracks)"

# group by track, preserving first-seen order
$tracks = Group-PerksByTrack $perks
$gridTracks = @(Get-DiGridSelection $tracks -EmptyGrid:$DiagnosticEmptyGrid -TrackKeys $DiagnosticGridTracks)
Write-Host "Parsed $($perks.Count) perks across $($tracks.Count) tracks"

# --- Output encoding -----------------------------------------------------------
# CK3's lexer wants UTF-8 with BOM for script files; plain UTF8 spams an error.log
# warning per generated file on every load.
$utf8Bom = [System.Text.UTF8Encoding]::new($true)

# --- Shared grid writers (dot-sourced after parse + encoding) --------------------
# Definitions only: Write-VanillaTrackSection / Write-VanillaPerkButton. The actual
# grid emit is the "Generate GUI grid" section at the bottom of this file, which is
# the only place that owns $gui / $outGui / the file write.
. (Join-Path $PSScriptRoot "_grid_templates.ps1")

# --- Shared SGUI/track emission helpers -----------------------------------------
# Extracted (plan step 1) so the add/remove and add-all/remove-all rules live in
# exactly one place; output must remain byte-identical to the pre-refactor build.
function Write-PerPerkBlocks {
    param($Sb, [string]$Key)
    [void]$Sb.AppendLine("DI_perk_add_$Key = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    is_shown = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            NOT = { has_dynasty_perk = $Key }")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            if = {")
    [void]$Sb.AppendLine("                limit = { NOT = { has_dynasty_perk = $Key } }")
    [void]$Sb.AppendLine("                # free-edit mode: grant first, then refund the EXACT engine")
    [void]$Sb.AppendLine("                # charge (inside dynasty scope; gate checks root = player character)")
    [void]$Sb.AppendLine("                if = {")
    [void]$Sb.AppendLine("                    limit = { root = { has_variable = DI_legacy_editor_free_mode } }")
    [void]$Sb.AppendLine("                    save_scope_value_as = { name = DI_renown_before value = dynasty_prestige }")
    [void]$Sb.AppendLine("                    add_dynasty_perk = $Key")
    [void]$Sb.AppendLine("                    add_dynasty_prestige = { value = scope:DI_renown_before subtract = dynasty_prestige }")
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("                else_if = {")
    [void]$Sb.AppendLine("                    limit = { dynasty_prestige >= { value = 250 add = { value = dynasty_num_unlocked_perks multiply = 500 } } }")
    [void]$Sb.AppendLine("                    add_dynasty_perk = $Key")
    [void]$Sb.AppendLine("                }")
    [void]$Sb.AppendLine("            }")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("}")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("DI_perk_remove_$Key = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    is_shown = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            has_dynasty_perk = $Key")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            if = {")
    [void]$Sb.AppendLine("                limit = { has_dynasty_perk = $Key }")
    [void]$Sb.AppendLine("                remove_dynasty_perk = $Key")
    [void]$Sb.AppendLine("            }")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("}")
    [void]$Sb.AppendLine("")
}

function Write-TrackAddAllBlock {
    param($Sb, [string]$Track, $PerkList)
    [void]$Sb.AppendLine("DI_track_add_all_$Track = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    is_shown = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            NOT = { $($Track)_perks >= $($PerkList.Count) }")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    foreach ($k in $PerkList) {
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
}

function Write-TrackRemoveAllBlock {
    param($Sb, [string]$Track, $PerkList)
    [void]$Sb.AppendLine("DI_track_remove_all_$Track = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    is_shown = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    [void]$Sb.AppendLine("            $($Track)_perks > 0")
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    foreach ($k in $PerkList) {
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

# --- Generate scripted guis ----------------------------------------------------
# Per perk: separate add (left click) and remove (right click) effects, each with
# is_shown gating so the GUI can grey out the inapplicable direction via
# GetScriptedGui(...).IsValid (the mod's standard enabled pattern).
$sgui = [System.Text.StringBuilder]::new()
[void]$sgui.AppendLine("# =============================================================================")
[void]$sgui.AppendLine("# GENERATED FILE - do not hand-edit.")
[void]$sgui.AppendLine("# Regenerate with: tools/generate_perk_editor.ps1")
[void]$sgui.AppendLine("# Per dynasty perk: add/remove effects (left click adds, right click removes),")
[void]$sgui.AppendLine("# plus per-track add-all/remove-all and bulk unlock-all/lock-all effects.")
[void]$sgui.AppendLine("# Operates on the dynasty selected in the DI perk editor")
[void]$sgui.AppendLine("# (player variable DI_dynasty_selected_dynasty).")
[void]$sgui.AppendLine("# =============================================================================")
[void]$sgui.AppendLine("")
foreach ($k in $perks.Keys) {
    Write-PerPerkBlocks $sgui $k
}

# per-track add-all / remove-all (skip already-in-target-state perks so renown is
# only touched for perks actually granted)
foreach ($t in $tracks.Keys) {
    Write-TrackAddAllBlock $sgui $t $tracks[$t]
    Write-TrackRemoveAllBlock $sgui $t $tracks[$t]
}

# --- Bulk unlock/lock-all -------------------------------------------------------
# Apply the exact per-perk add/remove body to every perk in first-seen order, so
# free-mode vs. renown-cost logic is identical to the single-perk toggles. Buttons
# live in the hand-written editor window's control bar.
function Write-BulkAllBlock {
    param($Sb, [string]$Name, $PerkMap, [string]$Direction)
    [void]$Sb.AppendLine("$Name = {")
    [void]$Sb.AppendLine("    scope = character")
    [void]$Sb.AppendLine("")
    [void]$Sb.AppendLine("    effect = {")
    [void]$Sb.AppendLine("        var:DI_dynasty_selected_dynasty = {")
    foreach ($k in $PerkMap.Keys) {
        if ($Direction -eq 'add') {
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
        } else {
            [void]$Sb.AppendLine("            if = {")
            [void]$Sb.AppendLine("                limit = { has_dynasty_perk = $k }")
            [void]$Sb.AppendLine("                remove_dynasty_perk = $k")
            [void]$Sb.AppendLine("            }")
        }
    }
    [void]$Sb.AppendLine("        }")
    [void]$Sb.AppendLine("    }")
    [void]$Sb.AppendLine("}")
    [void]$Sb.AppendLine("")
}
Write-BulkAllBlock $sgui "DI_perk_unlock_all" $perks 'add'
Write-BulkAllBlock $sgui "DI_perk_lock_all" $perks 'remove'
if (-not $WhatIf) {
    New-Item -ItemType Directory -Force -Path (Split-Path $outSgui) | Out-Null
    [System.IO.File]::WriteAllText($outSgui, $sgui.ToString(), $utf8Bom)
    Write-Host "Wrote $outSgui"
}

# --- Generate script values ----------------------------------------------------
# REMOVED (refund simplification): the per-track cost-mirror script value
# (DI_dynasty_perk_cost_next = 250 + one if per perk) is no longer generated.
# Free mode now grants first and refunds the EXACT engine charge via
# save_scope_value_as + an inline subtract value; the paid gate uses the
# documented dynasty_num_unlocked_perks trigger (mirrors 00_defines.txt:
# COST = PERK_COST_BASE + unlocked * PERK_COST_MULTIPLIER) - no mirror file.

# --- Generate GUI grid -----------------------------------------------------------
# Vanilla-look grid: one section per track (80x80 track icon + localized <track>_name
# / <track>_desc header + add-all/remove-all button) followed by a flowcontainer of
# PER-KEY perk buttons, so each perk keeps its own add/remove scripted gui (no runtime
# perk enumeration exists in CK3). Perks are never disabled: left click adds, right
# click removes, out-of-order is intended.
# Vanilla loc: perk names = <perk_key>_name; track name/desc = <track>_name / <track>_desc.
# Track icons: gfx/interface/icons/dynasty/<track>.dds (verified in vanilla files).
$gui = [System.Text.StringBuilder]::new()
if ($diagnostic) { [void]$gui.AppendLine("### DIAGNOSTIC GRID - GUI only; full effects retained. See DI_grid_manifest.json.") }
[void]$gui.AppendLine("### GENERATED FILE - do not hand-edit. Regenerate with: tools/generate_perk_editor.ps1")
[void]$gui.AppendLine("### Per-perk toggle grid for the DI dynasty perk editor.")
if ($DiagnosticDisableOwnedState) {
    [void]$gui.AppendLine("### Ownership indicators and their bindings are omitted for diagnosis; click actions remain.")
} else {
    [void]$gui.AppendLine("### Owned state IS rendered via pure datafunction bindings (gold border +")
    [void]$gui.AppendLine("### checkmark; fully-owned tracks tint gold). Buttons stay enabled for left-add /")
    [void]$gui.AppendLine("### right-remove.")
}
[void]$gui.AppendLine("### left click = add (no-op if already owned via the add SGUI's is_shown guard),")
[void]$gui.AppendLine("### right click = remove (no-op if not owned). Out-of-order add/remove is intended.")
[void]$gui.AppendLine("")
[void]$gui.AppendLine("types DI_DynastyGeneratedPerks {")
[void]$gui.AppendLine("    type di_generated_perk_grid = vbox {")
[void]$gui.AppendLine("        layoutpolicy_horizontal = expanding")
[void]$gui.AppendLine("        spacing = 5")
[void]$gui.AppendLine("")
foreach ($t in $gridTracks) {
    $perkList = $tracks[$t]
    $gate = $null
    if ($trackGates.ContainsKey($t)) { $gate = $trackGates[$t] }
    Write-VanillaTrackSection $gui $t $perkList $gate -DisableOwnedState:$DiagnosticDisableOwnedState
}
[void]$gui.AppendLine("    }")
    # Empty extension slot (Phase 3). Sub-mods and combined-playset mods REDEFINE this
    # type with their extra track rows, which is why the base keeps defining it: the
    # instantiation in gui/DI_dynasty_perk_editor.gui (blockoverride "scrollbox_content")
    # must always resolve to a defined type, with or without a compatch enabled. With no
    # compatch it renders nothing. One shared name is intentional: exactly ONE DI Perks
    # compatch per modlist (see docs/DYNASTY_PERK_EDITOR_PLAN.md, "Coexistence").
[void]$gui.AppendLine("    type di_perk_grid_extension = vbox {")
[void]$gui.AppendLine("        layoutpolicy_horizontal = expanding")
[void]$gui.AppendLine("    }")
[void]$gui.AppendLine("}")

if (-not $WhatIf) {
    New-Item -ItemType Directory -Force -Path (Split-Path $outGui) | Out-Null
    [System.IO.File]::WriteAllText($outGui, $gui.ToString(), $utf8Bom)
    Write-Host "Wrote $outGui"
    Write-DiGridManifest -OutputDir $ModDir -GridPath $outGui -InputPaths $perkDirs -Tracks $tracks -SelectedTracks $gridTracks -Gates $trackGates -Diagnostic $diagnostic -DisableOwnedState $DiagnosticDisableOwnedState
}

# --- Generate tooltip loc ---------------------------------------------------------
# One loc entry per perk, referenced by the grid button tooltip. Text is resolved
# STATICALLY at generation time from the loc files (vanilla first, then -LocDirs
# so mod loc wins):  DI_perk_tt_<perk>:0 "#bold $<perk>_name$#!\n<effect1>..." +
# character_modifier lines (bold block name + per-modifier #P/#N value lines,
# formatted via ConvertTo-PerkModifierTooltipLines in _perk_parser.ps1). The bold
# heading is a loc VARIABLE ref (not baked text) so it follows load-order loc at
# runtime - renaming mods keep tooltip heading and button label in sync. Effect
# keys come from the perk's effect = { ... } block (_ai_effect/_req_effect
# excluded by the parser), resolved as <key>, then vanilla's <key>_global
# (custom_description convention), then the raw key. Perks without effect text
# get name-only tooltips. No [Localize(...)] wrappers in the TOOLTIP ATTRIBUTE:
# the quoted form has no vanilla tooltip precedent and silently rendered empty.
$ttLoc = [System.Text.StringBuilder]::new()
[void]$ttLoc.AppendLine("# =============================================================================")
[void]$ttLoc.AppendLine("# GENERATED FILE - do not hand-edit.")
[void]$ttLoc.AppendLine("# Regenerate with: tools/generate_perk_editor.ps1")
[void]$ttLoc.AppendLine("# Grid button tooltips: perk name (bold, $<key>_name$ loc var) + effect/modifier lines.")
[void]$ttLoc.AppendLine("# =============================================================================")
[void]$ttLoc.AppendLine("")
[void]$ttLoc.AppendLine("l_english:")
foreach ($k in $perks.Keys) {
    $name = $locMap["${k}_name"]
    if ([string]::IsNullOrEmpty($name)) { $name = "${k}_name" }
    # heading as a loc variable ref (not baked text): follows load-order loc at
    # runtime so renaming mods keep tooltip heading and button label in sync;
    # raw key fallback when the name loc is missing entirely
    if ($name -ne "${k}_name") {
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
}
if (-not $WhatIf) {
    New-Item -ItemType Directory -Force -Path (Split-Path $outTtLoc) | Out-Null
    [System.IO.File]::WriteAllText($outTtLoc, $ttLoc.ToString(), $utf8Bom)
    Write-Host "Wrote $outTtLoc"
}

Write-Host "Done. $($perks.Count) toggles, $($tracks.Count) track rows generated."
