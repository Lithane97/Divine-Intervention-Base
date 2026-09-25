# Presentation-only ordering. Never reorder the parsed perk model or effect loops.
function Resolve-DiStaticLoc {
    param([string]$Key, $LocMap, [string[]]$Seen = @())
    if ($Key -in $Seen -or $Seen.Count -ge 16 -or -not $LocMap.ContainsKey($Key)) { return $null }
    $value = [string]$LocMap[$Key]
    foreach ($match in [regex]::Matches($value, '\$([^$]+)\$')) {
        $replacement = Resolve-DiStaticLoc -Key $match.Groups[1].Value -LocMap $LocMap -Seen (@($Seen) + $Key)
        if ([string]::IsNullOrWhiteSpace($replacement)) { return $null }
        $value = $value.Replace($match.Value, $replacement)
    }
    # Runtime datafunctions cannot be resolved reliably during generation.
    if ($value -match '\$|\[|\]') { return $null }
    $value = $value -replace '#!', '' -replace '#[A-Za-z_][A-Za-z_0-9:;.=-]*\s+', '' -replace '@[^\s!]+!', ''
    $value = $value.Replace('\"', '"').Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    return $value
}

function Get-DiSortedGridTracks {
    param([string[]]$TrackKeys = @(), $LocMap)
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($key in $TrackKeys) {
        $name = Resolve-DiStaticLoc -Key "${key}_name" -LocMap $LocMap
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $key }
        $rows.Add([pscustomobject]@{ Key = $key; Name = $name })
    }
    $rows.Sort([Comparison[object]]{
        param($a, $b)
        $result = [Globalization.CultureInfo]::GetCultureInfo('en').CompareInfo.Compare(
            $a.Name, $b.Name, [Globalization.CompareOptions]::IgnoreCase)
        if ($result -eq 0) { return [StringComparer]::Ordinal.Compare($a.Key, $b.Key) }
        return $result
    })
    foreach ($row in $rows) { $row.Key }
}
