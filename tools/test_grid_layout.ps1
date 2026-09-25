param([string]$BeforeGrid, [string]$AfterGrid, [string]$ManifestPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_grid_order.ps1')
function Assert-Layout($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$loc = @{
    z_name = 'alpha'; a_name = 'ALPHA'; b_name = 'bravo'
    nested_name = '$house$'; house = '$family$'; family = '#high Charlie#!'
    cycle_name = '$cycle_name$'; unresolved_name = '$absent$'
    dynamic_name = '[Dynasty.GetName]'; override_name = 'Zulu'
}
$loc.override_name = 'Delta' # Final loaded localization override must win.
$keys = @('z', 'nested', 'missing', 'override', 'b', 'a')
$sorted = @(Get-DiSortedGridTracks $keys $loc)
Assert-Layout (($sorted -join ',') -ceq 'a,z,b,nested,override,missing') 'Displayed-name order or key tie-break failed'
Assert-Layout (($keys -join ',') -ceq 'z,nested,missing,override,b,a') 'Input keys mutated'
Assert-Layout (@(Get-DiSortedGridTracks @() $loc).Count -eq 0) 'Empty diagnostic selection changed'
Assert-Layout ((Resolve-DiStaticLoc nested_name $loc) -ceq 'Charlie') 'Nested static reference failed'
foreach ($key in 'cycle', 'unresolved', 'dynamic', 'missing') {
    Assert-Layout ($null -eq (Resolve-DiStaticLoc "${key}_name" $loc)) "Unresolvable name did not fall back: $key"
}
Assert-Layout ((@(Get-DiSortedGridTracks @('unresolved','missing','dynamic','cycle') $loc) -join ',') -ceq 'cycle,dynamic,missing,unresolved') 'Fallback ordering failed'
$originalCulture = [Globalization.CultureInfo]::CurrentCulture
try {
    [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('tr-TR')
    Assert-Layout ((@(Get-DiSortedGridTracks $keys $loc) -join ',') -ceq ($sorted -join ',')) 'Ordering depends on machine culture'
} finally { [Globalization.CultureInfo]::CurrentCulture = $originalCulture }
if ($BeforeGrid -or $AfterGrid -or $ManifestPath) {
    if (-not ($BeforeGrid -and $AfterGrid -and $ManifestPath)) { throw 'Supply BeforeGrid, AfterGrid and ManifestPath together.' }
    $before = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BeforeGrid)).Replace("`r`n", "`n")
    $after = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $AfterGrid)).Replace("`r`n", "`n")
    $pattern = '(?ms)^        # ---- (?<key>\S+).*?(?=^        # ---- |^    \})'
    $oldSections = [regex]::Matches($before, $pattern)
    $newSections = [regex]::Matches($after, $pattern)
    Assert-Layout ($oldSections.Count -gt 0 -and $oldSections.Count -eq $newSections.Count) 'Track count changed'
    $oldByKey = @{}
    foreach ($m in $oldSections) { $oldByKey[$m.Groups['key'].Value] = $m.Value }
    foreach ($m in $newSections) {
        $key = $m.Groups['key'].Value
        Assert-Layout ($oldByKey.ContainsKey($key)) "Unexpected track: $key"
        $expected = $oldByKey[$key].Replace('size = { 296 128 }', 'size = { 296 64 }').Replace('margin_top = 18', 'margin_top = 8')
        Assert-Layout ($expected -ceq $m.Value) "Unexpected section change (including perk order): $key"
    }
    Assert-Layout ([regex]::Replace($before, $pattern, '') -ceq [regex]::Replace($after, $pattern, '')) 'Grid wrapper changed'
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $emittedKeys = @($newSections | ForEach-Object { $_.Groups['key'].Value })
    Assert-Layout (($emittedKeys -join ',') -ceq ($manifest.trackKeys -join ',')) 'Manifest order does not match emitted order'
    Assert-Layout (([regex]::Matches($after, 'size = \{ 296 64 \}')).Count -eq $manifest.cellCount) 'Perk button sizes/count changed'
    Assert-Layout ($after -notmatch 'size = \{ 296 128 \}') 'Old cell height remains'
    Write-Host "[OK] $($manifest.cellCount) compact cells; $($newSections.Count) unchanged track contents; manifest matches emitted order."
}
Write-Host '[OK] Layout sorting: case, tie-breaks, static references, overrides, missing/dynamic names, culture independence.'
