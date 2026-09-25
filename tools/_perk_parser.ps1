# =============================================================================
# _perk_parser.ps1 - SHARED dynasty-perk/track parser (dot-sourced by both generators)
# =============================================================================
# Dot-source this file, then call Get-Perks / Get-TrackDlcGates.
#
# Consumed by:
#   - generate_perk_editor.ps1  (vanilla + DLC; ships in the base mod)
#   - generate_mod_perks.ps1    (Phase 3 F1 scanner / sub-mod generator)
#
# Hardening per plan v9 F1 / F5:
#   - Get-Perks supports single-line perk blocks (`my_perk = { legacy = x }`), which
#     mod authors write; the old regex only matched `key = {` with the brace alone
#     on the line and silently dropped them.
#   - Get-Perks warns when a dynasty_perks/*.txt file parses to 0 perks (parse miss,
#     not necessarily an empty file).
#   - Extraction note (v10): moved verbatim out of generate_perk_editor.ps1 so one
#     parser fix fixes both tools.
# =============================================================================

# Parse common/dynasty_perks/*.txt: perk key -> its track.
# Returns an ordered hashtable keyed by perk key.
function Get-Perks {
    param([string[]]$Directories)
    $perks = [ordered]@{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { Write-Warning "perk dir not found: $dir"; continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.txt' | Sort-Object Name) {
            $lines = Get-Content $file.FullName
            $fileKeyCount = 0
            $currentKey = $null
            $depth = 0
            foreach ($line in $lines) {
                $trimmed = ($line -replace '#.*$', '').Trim()
                # --- block opener on its own line: `key = {` ---
                if ($trimmed -match '^(\w+)\s*=\s*\{\s*$') {
                    $currentKey = $Matches[1]
                    $depth = 1
                    continue
                }
                # --- single-line block opener + content: `key = { legacy = x }` ---
                if ($trimmed -match '^(\w+)\s*=\s*\{\s*(.*)\}$') {
                    $currentKey = $Matches[1]
                    $inner = $Matches[2]
                    if ($inner -match 'legacy\s*=\s*(\w+)') {
                        $perks[$currentKey] = $Matches[1]
                        $fileKeyCount++
                    }
                    $currentKey = $null
                    $depth = 0
                    continue
                }
                if ($null -ne $currentKey) {
                    $chars = $trimmed.ToCharArray() | Where-Object { $_ -eq '{' -or $_ -eq '}' }
                    foreach ($c in $chars) { if ($c -eq '{') { $depth++ } else { $depth-- } }
                    if ($depth -le 0) {
                        $currentKey = $null
                        $depth = 0
                        continue
                    }
                    if ($trimmed -match '^\s*legacy\s*=\s*(\w+)') {
                        if (-not $perks.Contains($currentKey)) {
                            $perks[$currentKey] = $Matches[1]
                            $fileKeyCount++
                        }
                    }
                }
            }
            if ($fileKeyCount -eq 0) {
                Write-Warning "No perks parsed from $($file.Name) (parse miss or empty)"
            }
        }
    }
    return $perks
}

# Parse common/dynasty_legacies/*.txt: track key -> DLC feature (or $null if ungated).
# Returns a hashtable track key -> DLC feature string.
function Get-TrackDlcGates {
    param([string[]]$Directories)
    $gates = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.txt' | Sort-Object Name) {
            $lines = Get-Content $file.FullName
            $currentKey = $null
            $depth = 0
            $inIsShown = $false
            foreach ($line in $lines) {
                $trimmed = ($line -replace '#.*$', '').TrimEnd()
                if ($trimmed -match '^(\w+)\s*=\s*\{\s*$' -and $depth -eq 0) {
                    $currentKey = $Matches[1]
                    $depth = 1
                    $inIsShown = $false
                    continue
                }
                if ($null -ne $currentKey) {
                    if ($trimmed -match '^\s*is_shown\s*=\s*\{') { $inIsShown = $true }
                    $chars = $trimmed.ToCharArray() | Where-Object { $_ -eq '{' -or $_ -eq '}' }
                    foreach ($c in $chars) { if ($c -eq '{') { $depth++ } else { $depth-- } }
                    if ($depth -le 0) {
                        $currentKey = $null
                        $depth = 0
                        $inIsShown = $false
                        continue
                    }
                    if ($inIsShown -and $trimmed -match 'has_dlc_feature\s*=\s*(\w+)') {
                        if (-not $gates.ContainsKey($currentKey)) {
                            $gates[$currentKey] = $Matches[1]
                        }
                    }
                }
            }
        }
    }
    return $gates
}

# Group a perk-key->track map into an ordered track -> List[perk-key] map,
# preserving first-seen order.
function Group-PerksByTrack {
    param($PerkMap)
    $tracks = [ordered]@{}
    if ($null -eq $PerkMap) { return $tracks }
    foreach ($k in $PerkMap.Keys) {
        $t = $PerkMap[$k]
        if (-not $tracks.Contains($t)) { $tracks[$t] = [System.Collections.Generic.List[string]]::new() }
        $tracks[$t].Add($k)
    }
    return $tracks
}

# Parse common/dynasty_perks/*.txt: perk key -> list of effect-text loc keys.
# Effect text keys are `text = <key>` values found inside the perk's first-level
# `effect = { ... }` block (vanilla emits them via custom_description_no_bullet,
# either on its own line or inline: `custom_description_no_bullet = { text = X }`
# - the key is matched anywhere in the line). Keys ending in _ai_effect /
# _req_effect are excluded: they are AI-behaviour / requirement text
# (Hiraeth-style mods), not player-facing effect descriptions.
# Returns a hashtable perk key -> List[string] (empty list when the perk has no
# effect text). Perk keys absent from the result have no effect block at all.
function Get-PerkEffectTextKeys {
    param([string[]]$Directories)
    $result = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.txt' | Sort-Object Name) {
            $lines = Get-Content $file.FullName
            $currentKey = $null
            $depth = 0
            $inEffect = $false
            foreach ($line in $lines) {
                $trimmed = ($line -replace '#.*$', '').Trim()
                # --- single-line perk block: effects are out of scope there, but
                # --- still scan for text keys when an inline effect block exists.
                if ($null -eq $currentKey -and $trimmed -match '^(\w+)\s*=\s*\{\s*(.*)\}\s*$') {
                    $singleKey = $Matches[1]
                    $inner = $Matches[2]
                    if ($inner -match 'legacy\s*=\s*\w+' -and $inner -match 'effect\s*=\s*\{') {
                        $keys = [System.Collections.Generic.List[string]]::new()
                        foreach ($m in [regex]::Matches($inner, 'text\s*=\s*(\w+)')) {
                            $k = $m.Groups[1].Value
                            if ($k -notmatch '_(ai|req)_effect$' -and -not $keys.Contains($k)) { $keys.Add($k) }
                        }
                        if ($keys.Count -gt 0) { $result[$singleKey] = $keys }
                    }
                    continue
                }
                # --- top-level perk opener ---
                if ($null -eq $currentKey -and $depth -eq 0 -and $trimmed -match '^(\w+)\s*=\s*\{\s*$') {
                    $currentKey = $Matches[1]
                    $depth = 1
                    $inEffect = $false
                    continue
                }
                if ($null -ne $currentKey) {
                    # effect block opens at the perk's first nesting level
                    if (-not $inEffect -and $depth -eq 1 -and $trimmed -match '^effect\s*=\s*\{') {
                        $inEffect = $true
                    }
                    if ($inEffect -and $trimmed -match '\btext\s*=\s*(\w+)') {
                        $k = $Matches[1]
                        if ($k -notmatch '_(ai|req)_effect$') {
                            if (-not $result.ContainsKey($currentKey)) {
                                $result[$currentKey] = [System.Collections.Generic.List[string]]::new()
                            }
                            if (-not $result[$currentKey].Contains($k)) { $result[$currentKey].Add($k) }
                        }
                    }
                    $chars = $trimmed.ToCharArray() | Where-Object { $_ -eq '{' -or $_ -eq '}' }
                    foreach ($c in $chars) { if ($c -eq '{') { $depth++ } else { $depth-- } }
                    if ($inEffect -and $depth -le 1) { $inEffect = $false }
                    if ($depth -le 0) {
                        $currentKey = $null
                        $depth = 0
                        $inEffect = $false
                    }
                }
            }
        }
    }
    return $result
}

# Sanity-check the parsed model: every perk maps to a non-empty track and no track
# ends up empty. Returns $true if OK; writes warnings naming the offender otherwise.
# Called by generate_perk_editor.ps1 before it writes any generated file.
function Test-PerksModel {
    param($PerkMap)
    if ($null -eq $PerkMap -or $PerkMap.Count -eq 0) {
        Write-Warning "Test-PerksModel: no perks parsed (empty map)"
        return $false
    }
    $ok = $true
    foreach ($k in $PerkMap.Keys) {
        $t = $PerkMap[$k]
        if ([string]::IsNullOrWhiteSpace($t)) {
            Write-Warning "Test-PerksModel: perk '$k' has empty/blank track"
            $ok = $false
        }
    }
    $tracks = Group-PerksByTrack $PerkMap
    foreach ($t in $tracks.Keys) {
        if ($tracks[$t].Count -eq 0) {
            Write-Warning "Test-PerksModel: track '$t' has zero perks"
            $ok = $false
        }
    }
    return $ok
}

# Load localization values from one or more loc directories into a flat
# key -> value hashtable. Parses YAML-ish lines matching
#   <key>:<version> "<value>"
# across all *.yml files (recursive) in each directory, in the order given.
# Later directories/files override earlier ones, so mod loc passed AFTER vanilla
# wins. Values are kept raw, including #bold markers and any datafunctions they
# contain - CK3 resolves those at display time.
function Get-LocValues {
    param([string[]]$Directories)
    $locMap = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { Write-Warning "loc dir not found: $dir"; continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.yml' -Recurse | Sort-Object FullName) {
            foreach ($line in Get-Content $file.FullName) {
                # vanilla loc uses <key>:<version> "value"; several mods omit the
                # version (AGOT). \d*\s* covers both "key:0" and "key: ".
                # F8: the value capture honors backslash-escaped characters, so
                # embedded \" quotes no longer truncate the entry; the captured
                # value keeps the source's escape sequences verbatim.
                if ($line -match '^\s*(\S+):\d*\s*"((?:[^"\\]|\\.)*)"') {
                    $locMap[$Matches[1]] = $Matches[2]
                }
            }
        }
    }
    return $locMap
}

# Parse common/effect_localization/*.txt: effect-loc key -> its `global = <LOC_KEY>`
# mapping. These are dynamically-evaluated effect descriptions (e.g.
# warfare_legacy_5_effect -> HOUSE_GUARD_DESCRIPTION) whose actual text lives in a
# normal loc key. Returns a hashtable effectLocKey -> plain loc key (first `global`
# entry wins; that is the key the GUI displays by default).
function Get-EffectLocalization {
    param([string[]]$Directories)
    $map = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.txt' | Sort-Object Name) {
            $lines = Get-Content $file.FullName
            $currentKey = $null
            $depth = 0
            foreach ($line in $lines) {
                $trimmed = ($line -replace '#.*$', '').Trim()
                if ($null -eq $currentKey -and $depth -eq 0 -and $trimmed -match '^(\w+)\s*=\s*\{\s*$') {
                    $currentKey = $Matches[1]
                    $depth = 1
                    continue
                }
                if ($null -ne $currentKey) {
                    $chars = $trimmed.ToCharArray() | Where-Object { $_ -eq '{' -or $_ -eq '}' }
                    foreach ($c in $chars) { if ($c -eq '{') { $depth++ } else { $depth-- } }
                    if ($depth -le 0) {
                        $currentKey = $null
                        $depth = 0
                        continue
                    }
                    if ($depth -eq 1 -and $trimmed -match '^\s*global\s*=\s*(\w+)') {
                        if (-not $map.ContainsKey($currentKey)) { $map[$currentKey] = $Matches[1] }
                    }
                }
            }
        }
    }
    return $map
}

# Parse common/modifier_definition_formats/00_*.txt: modifier key -> formatting
# metadata (Prefix loc key, Decimals, Percent, AlreadyPercent, Hidden). Later
# directories win (pass vanilla first, then mod dirs), so mods can override
# vanilla definitions. Unknown properties inside an entry are ignored.
function Get-ModifierDefinitions {
    param([string[]]$Directories)
    $defs = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in Get-ChildItem $dir -Filter '00_*.txt' | Sort-Object Name) {
            $currentKey = $null
            $entry = $null
            foreach ($line in Get-Content $file.FullName) {
                $trimmed = ($line -replace '#.*$', '').Trim()
                if ($null -eq $currentKey -and $trimmed -match '^(\w+)\s*=\s*\{\s*$') {
                    $currentKey = $Matches[1]
                    $entry = @{ Prefix = $null; Decimals = $null; Percent = $false; AlreadyPercent = $false; Hidden = $false; Color = $null }
                    continue
                }
                if ($null -ne $currentKey) {
                    if ($trimmed -match '^\}$') {
                        $defs[$currentKey] = $entry
                        $currentKey = $null
                        $entry = $null
                        continue
                    }
                    if ($trimmed -match '^prefix\s*=\s*(\w+)') { $entry.Prefix = $Matches[1] }
                    elseif ($trimmed -match '^decimals\s*=\s*(-?\d+)') { $entry.Decimals = [int]$Matches[1] }
                    elseif ($trimmed -match '^percent\s*=\s*(\w+)') { $entry.Percent = ($Matches[1] -eq 'yes') }
                    elseif ($trimmed -match '^already_percent\s*=\s*(\w+)') { $entry.AlreadyPercent = ($Matches[1] -eq 'yes') }
                    elseif ($trimmed -match '^hidden\s*=\s*(\w+)') { $entry.Hidden = ($Matches[1] -eq 'yes') }
                    elseif ($trimmed -match '^color\s*=\s*(\w+)') { $entry.Color = $Matches[1] }
                }
            }
        }
    }
    return $defs
}

# Parse common/dynasty_perks/*.txt: perk key -> ordered list of character_modifier
# blocks. Each block is a pscustomobject { Name; Modifiers } where Name is the
# optional `name = <loc key>` (bold heading in the tooltip) and Modifiers is an
# ordered key -> raw value map in file order. `name =` is never treated as a
# modifier key; non key/value lines inside the block are ignored. Other
# *_modifier containers are reported via Write-Warning (parsed, not fatal).
# First-seen-wins per perk key across directories, matching Get-Perks.
function Get-PerkModifierBlocks {
    param([string[]]$Directories)
    $result = @{}
    $claimed = @{}
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in Get-ChildItem $dir -Filter '*.txt' | Sort-Object Name) {
            $fileKeys = @{}
            $currentKey = $null
            $depth = 0
            $inMod = $false
            $modName = $null
            $modBlock = $null
            foreach ($line in Get-Content $file.FullName) {
                $trimmed = ($line -replace '#.*$', '').Trim()
                if ($null -eq $currentKey -and $depth -eq 0 -and $trimmed -match '^(\w+)\s*=\s*\{\s*$') {
                    $currentKey = $Matches[1]
                    $depth = 1
                    $inMod = $false
                    $modName = $null
                    $modBlock = $null
                    continue
                }
                if ($null -eq $currentKey) { continue }
                if (-not $inMod -and $depth -eq 1 -and $trimmed -match '^(\w*modifier)\s*=\s*\{\s*$') {
                    if ($Matches[1] -eq 'character_modifier') {
                        $inMod = $true
                        $modName = $null
                        $modBlock = [ordered]@{}
                    } else {
                        Write-Warning "Perk '$currentKey': container '$($Matches[1])' is not parsed (only character_modifier is supported)"
                    }
                }
                elseif ($inMod -and $null -eq $modName -and $trimmed -match '^name\s*=\s*(\w+)') {
                    $modName = $Matches[1]
                }
                elseif ($inMod -and $trimmed -match '^(\w+)\s*=\s*(-?[\d.]+)\s*$' -and $Matches[1] -ne 'name') {
                    $modBlock[$Matches[1]] = $Matches[2]
                }
                $chars = $trimmed.ToCharArray() | Where-Object { $_ -eq '{' -or $_ -eq '}' }
                foreach ($c in $chars) { if ($c -eq '{') { $depth++ } else { $depth-- } }
                if ($inMod -and $depth -le 1) {
                    if ($modBlock.Count -gt 0 -or -not [string]::IsNullOrEmpty($modName)) {
                        if (-not $claimed.ContainsKey($currentKey) -or $fileKeys.ContainsKey($currentKey)) {
                            if (-not $result.ContainsKey($currentKey)) {
                                $result[$currentKey] = [System.Collections.Generic.List[object]]::new()
                            }
                            $result[$currentKey].Add([pscustomobject]@{ Name = $modName; Modifiers = $modBlock })
                            $fileKeys[$currentKey] = $true
                            $claimed[$currentKey] = $true
                        }
                    }
                    $inMod = $false
                    $modName = $null
                    $modBlock = $null
                }
                if ($depth -le 0) {
                    $currentKey = $null
                    $depth = 0
                }
            }
        }
    }
    return $result
}

# Format one perk's character_modifier blocks as static tooltip lines (shared by
# both generators so base and sub-mod tooltips stay in sync). Emits, per block,
# an optional "#bold <resolved block name>#!" heading followed by one line per
# modifier: "<loc>" + colon unless the loc is a lone icon embed, then
# "#P +<value>%#!" / "#N <value>%#!". Loc resolution order (vanilla-verified):
# definition prefix key -> MOD_<KEY_UPPER> -> the raw modifier key (e.g.
# monthly_martial_lifestyle_xp_gain_mult is loc'd under its own name);
# unresolvable keys skip the line with a warning - the perk keeps its other
# tooltip lines instead of hard-failing name-only. percent = yes multiplies by
# 100 unless already_percent = yes; decimals defaults to 2 per the engine's
# _definitions.info ("Defaults to 2").
function ConvertTo-PerkModifierTooltipLines {
    param($ModifierBlocks, $ModifierDefs, $LocMap, [string]$PerkKey = "", [string]$PerkNameText = "")
    $lines = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $ModifierBlocks) { return $lines }
    foreach ($block in $ModifierBlocks) {
        if (-not [string]::IsNullOrEmpty($block.Name)) {
            $n = $LocMap[$block.Name]
            if ([string]::IsNullOrEmpty($n)) { $n = $block.Name }
            # vanilla reuses <perk>_name as the modifier name (directly or as a
            # "$<perk>_name$" loc variable) - skip the heading when it would
            # duplicate the perk's own bold name line
            $dup = (-not [string]::IsNullOrEmpty($PerkNameText) -and $n -eq $PerkNameText) -or
                   ($n -match '^\$(\w+)\$$' -and -not [string]::IsNullOrEmpty($PerkKey) -and $Matches[1] -eq "${PerkKey}_name")
            if (-not $dup) { $lines.Add("#bold $n#!") }
        }
        foreach ($mk in $block.Modifiers.Keys) {
            $def = $null
            if ($null -ne $ModifierDefs -and $ModifierDefs.ContainsKey($mk)) { $def = $ModifierDefs[$mk] }
            if ($null -ne $def -and $def.Hidden) { continue }
            $locKey = "MOD_$($mk.ToUpperInvariant())"
            if ($null -ne $def -and -not [string]::IsNullOrEmpty($def.Prefix)) { $locKey = $def.Prefix }
            $locText = $LocMap[$locKey]
            if ([string]::IsNullOrEmpty($locText) -and $LocMap.ContainsKey($mk)) { $locText = $LocMap[$mk] }
            if ([string]::IsNullOrEmpty($locText)) {
                Write-Warning "Modifier '$mk': loc key '$locKey' not resolvable - tooltip line skipped"
                continue
            }
            $raw = 0.0
            if (-not [double]::TryParse([string]$block.Modifiers[$mk], [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$raw)) { continue }
            $isPercent = $false
            $decimals = 2
            if ($null -ne $def) {
                $isPercent = $def.Percent -and -not $def.AlreadyPercent
                if ($null -ne $def.Decimals) { $decimals = [int]$def.Decimals }
            }
            $v = [math]::Round($(if ($isPercent) { $raw * 100 } else { $raw }), $decimals)
            $formatted = $v.ToString("F$decimals", [System.Globalization.CultureInfo]::InvariantCulture)
            $sep = if ($locText -match '^\[.*_i\]$') { ' ' } else { ': ' }
            $pct = if ($null -ne $def -and $def.Percent) { '%' } else { '' }
            # F9: the definition's color semantics override the numeric sign.
            # color = bad (vanilla negative_random_genetic_chance) means a NEGATIVE
            # value is a beneficial reduction -> #P; an increase -> #N. All other
            # cases keep the sign-based #P/#N convention. The sign prefix is
            # sign-aware in BOTH branches: reductions render "#P -30%#!" (never
            # "#P +-30%#!") and #N of a positive value renders "#N +25%#!".
            $sign = if ($formatted.StartsWith('-')) { '' } else { '+' }
            $beneficial = if ($null -ne $def -and $def.Color -eq 'bad') { $v -lt 0 } else { $v -ge 0 }
            if ($beneficial) { $lines.Add("$locText$sep#P $sign$formatted$pct#!") }
            else { $lines.Add("$locText$sep#N $sign$formatted$pct#!") }
        }
    }
    return $lines
}
