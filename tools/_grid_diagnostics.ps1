# GUI-only diagnostic selection. Never filter the underlying perk/effect model.
function Assert-DiDiagnosticOutput {
    param([string]$OutputDir)
    if (-not $OutputDir) { throw 'Diagnostic generation requires an explicit staging output directory.' }
    $outputPath = [IO.Path]::GetFullPath($OutputDir).TrimEnd('\', '/')
    $roots = @([IO.Path]::GetFullPath($env:TEMP), [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.ck3modding')))
    $allowed = $false
    foreach ($root in $roots) {
        if ($outputPath.StartsWith($root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            # Reject child junctions/symlinks that could redirect staging to an installed mod.
            $cursor = $outputPath
            while ($cursor.Length -gt $root.TrimEnd('\', '/').Length) {
                if (Test-Path -LiteralPath $cursor) {
                    $item = Get-Item -LiteralPath $cursor -Force
                    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                        throw "Diagnostic staging must use ordinary directories: $cursor"
                    }
                }
                $cursor = Split-Path $cursor -Parent
            }
            $allowed = $true
        }
    }
    if (-not $allowed) { throw 'Diagnostic output must be a subdirectory of TEMP or the Base repository .ck3modding directory.' }
}

function Get-DiGridSelection {
    param($Tracks, [switch]$EmptyGrid, [string[]]$TrackKeys = @())
    if ($EmptyGrid -and $TrackKeys.Count) { throw 'DiagnosticEmptyGrid and DiagnosticGridTracks are mutually exclusive.' }
    foreach ($key in $TrackKeys) {
        if ($key -notin @($Tracks.Keys)) { throw "Unknown diagnostic track key '$key'." }
    }
    foreach ($key in $Tracks.Keys) {
        if (@($Tracks[$key]).Count -eq 0) { throw "Cannot generate empty dynasty track '$key'." }
        if (-not $EmptyGrid -and ($TrackKeys.Count -eq 0 -or $key -in $TrackKeys)) { $key }
    }
}

function Write-DiGridManifest {
    param([string]$OutputDir, [string]$GridPath, [string[]]$InputPaths,
        $Tracks, [string[]]$SelectedTracks, $Gates, [bool]$Diagnostic, [bool]$DisableOwnedState)
    $catalog = @(foreach ($key in $Tracks.Keys) {
        [ordered]@{ key = $key; perks = @($Tracks[$key]); dlcGate = $Gates[$key] }
    })
    $gridText = [IO.File]::ReadAllText($GridPath)
    $manifest = [ordered]@{
        schemaVersion = 1
        diagnostic = $Diagnostic
        ownershipIndicators = -not $DisableOwnedState
        # Paths are ordered vanilla first, followed by source mods in engine order.
        inputPaths = @($InputPaths)
        trackKeys = @($SelectedTracks)
        cellCount = ([regex]::Matches($gridText, 'onclick = "\[GetScriptedGui\(''DI_perk_add_')).Count
        ownershipBindingCount = ([regex]::Matches($gridText, 'visible = "\[(?:Not\( )?(?:And\(|Dynasty.HasPerk)')).Count
        hasPerkCallCount = ([regex]::Matches($gridText, 'Dynasty.HasPerk')).Count
        gridSha256 = (Get-FileHash -LiteralPath $GridPath -Algorithm SHA256).Hash
        availableTracks = $catalog
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDir 'DI_grid_manifest.json') -Encoding utf8
}
