# =============================================================================
# validate_perk_editor.ps1 - DI Dynasty Perk Editor drift validator (CI / release gate)
# =============================================================================
# Regenerates the three generated artifacts (using the real game files) into a temp
# dir, then diffs them against the shipped generated files. Any difference means the
# generator and the shipped files are out of sync (e.g. a game patch added a DLC
# track, or the generator changed without regenerating) -> exit 1.
#
# Also checks that each generated script block is brace-balanced (crude lexer-safe
# check: braces on their own tokens, ignoring < > and # comments).
#
# The generator's own output is echoed, so a generator crash is reported as a crash
# and not mistaken for content drift.
#
# Usage:
#   pwsh -File tools/validate_perk_editor.ps1
#   pwsh -File tools/validate_perk_editor.ps1 -GameDir "H:\...\game"
# GameDir default: $env:CK3_GAME_DIR when set, else the local Steam path.
# =============================================================================

param(
    [string]$GameDir = $(if ($env:CK3_GAME_DIR) { $env:CK3_GAME_DIR } else { "H:\SteamLibrary\steamapps\common\Crusader Kings III\game" }),
    [string]$ModDir  = "$PSScriptRoot\.."
)

$ErrorActionPreference = "Stop"

$files = @(
    @{ Rel = "gui\DI_generated_perk_grid.gui";                        Label = "grid" },
    @{ Rel = "common\scripted_guis\DI_generated_perk_toggles_sgui.txt"; Label = "toggles" },
    @{ Rel = "localization\english\DI_generated_perk_tooltips_l_english.yml"; Label = "tooltips-loc" }
)

if (-not (Test-Path (Join-Path $GameDir "common\dynasty_perks"))) {
    Write-Host "[FAIL] game perk dir not found: $GameDir\common\dynasty_perks (pass -GameDir or set CK3_GAME_DIR)"
    exit 1
}

$tmp = Join-Path $env:TEMP ("di_validate_{0}" -f ([guid]::NewGuid().ToString('N')))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $tmp "common\scripted_guis"), (Join-Path $tmp "gui"), (Join-Path $tmp "localization\english") | Out-Null

    Write-Host "Regenerating from $GameDir ..."
    & (Join-Path $PSScriptRoot "generate_perk_editor.ps1") -GameDir $GameDir -ModDir $tmp

    $fail = $false
    foreach ($f in $files) {
        $committed = Join-Path $ModDir $f.Rel
        $generated = Join-Path $tmp $f.Rel
        if (-not (Test-Path $committed)) { Write-Host "[FAIL] missing shipped file: $($f.Rel)"; $fail = $true; continue }
        if (-not (Test-Path $generated)) { Write-Host "[FAIL] generator did not produce $($f.Rel) - generator is broken, not drifting"; $fail = $true; continue }

        # F6: byte-level comparison - Compare-Object on line arrays accepted
        # reordered executable statements and discarded encoding. We compare
        # ORDERED normalized content (CRLF/LF-insensitive) plus explicit BOM and
        # line-ending-style checks.
        $bytesA = [System.IO.File]::ReadAllBytes($committed)
        $bytesB = [System.IO.File]::ReadAllBytes($generated)
        $bomA = ($bytesA.Length -ge 3 -and $bytesA[0] -eq 0xEF -and $bytesA[1] -eq 0xBB -and $bytesA[2] -eq 0xBF)
        $bomB = ($bytesB.Length -ge 3 -and $bytesB[0] -eq 0xEF -and $bytesB[1] -eq 0xBB -and $bytesB[2] -eq 0xBF)
        $rawA = [System.Text.Encoding]::UTF8.GetString($bytesA)
        $rawB = [System.Text.Encoding]::UTF8.GetString($bytesB)
        $normA = ($rawA -replace "`r`n", "`n").TrimStart([char]0xFEFF)
        $normB = ($rawB -replace "`r`n", "`n").TrimStart([char]0xFEFF)
        if ($normA -cne $normB) {
            # ordered mismatch - locate the first differing line for the report
            $la = $normA -split "`n"
            $lb = $normB -split "`n"
            $idx = 0
            while ($idx -lt $la.Count -and $idx -lt $lb.Count -and $la[$idx] -ceq $lb[$idx]) { $idx++ }
            Write-Host "[FAIL] drift in $($f.Label) ($($f.Rel)) - first difference at line $($idx + 1)"
            Write-Host "    shipped  : $($la[$idx])"
            Write-Host "    generated: $($lb[$idx])"
            $fail = $true
        } elseif ($bomA -ne $bomB) {
            Write-Host "[FAIL] $($f.Label) BOM mismatch (shipped=$(if ($bomA) { 'UTF-8 BOM' } else { 'no BOM' }), generated=$(if ($bomB) { 'UTF-8 BOM' } else { 'no BOM' }))"
            $fail = $true
        } elseif ((($rawA -match "`r`n") -gt 0) -ne (($rawB -match "`r`n") -gt 0)) {
            Write-Host "[FAIL] $($f.Label) line-ending style mismatch (shipped=$(if ($rawA -match "`r`n") { 'CRLF' } else { 'LF' }), generated=$(if ($rawB -match "`r`n") { 'CRLF' } else { 'LF' }))"
            $fail = $true
        } else {
            $lineCount = ($normA -split "`n").Count
            Write-Host "[ OK ] $($f.Label) matches generator byte-for-byte ($lineCount lines, BOM consistent)"
        }
    }

    # --- brace-balance check (recommended sanity, not a full parse) -------------
    foreach ($f in $files) {
        $path = Join-Path $tmp $f.Rel
        if (-not (Test-Path $path)) { continue }
        $raw  = Get-Content $path -Raw
        $noComments = ($raw -split "`n" | Where-Object { $_.Trim() -notmatch '^#' }) -join "`n"
        $opens  = ($noComments.ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $closes = ($noComments.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        if ($opens -ne $closes) {
            Write-Host "[FAIL] $($f.Label) brace imbalance: $opens open / $closes close"
            $fail = $true
        } else {
            Write-Host "[ OK ] $($f.Label) braces balanced ($opens pairs)"
        }
    }

    # Regeneration can faithfully reproduce an invalid expression: check arity
    # and ownership truth tables independently of the generator's output.
    & (Join-Path $PSScriptRoot 'test_grid_diagnostics.ps1') -GridPaths (Join-Path $ModDir 'gui/DI_generated_perk_grid.gui')

    # --- structural sanity: the hand-written editor window must still wire up ---
    $editorGui = Join-Path $ModDir "gui\DI_dynasty_perk_editor.gui"
    if (-not (Test-Path $editorGui)) {
        Write-Host "[FAIL] missing editor window gui\DI_dynasty_perk_editor.gui"
        $fail = $true
    } else {
        $editorRaw = Get-Content $editorGui -Raw
        $missing = @()
        if ($editorRaw -notmatch 'di_generated_perk_grid') { $missing += 'di_generated_perk_grid' }
        if ($editorRaw -notmatch 'di_perk_grid_extension')   { $missing += 'di_perk_grid_extension' }
        if ($missing.Count -gt 0) {
            Write-Host "[FAIL] editor window missing instantiation of: $($missing -join ', ')"
            $fail = $true
        } else {
            Write-Host "[ OK ] editor window instantiates di_generated_perk_grid + di_perk_grid_extension"
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail) { Write-Host "VALIDATION FAILED - regenerate generated files with tools/generate_perk_editor.ps1"; exit 1 }
Write-Host "VALIDATION PASSED - generated files are in sync."

