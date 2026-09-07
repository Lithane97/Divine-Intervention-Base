param([string[]]$GridPaths = @())
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_grid_templates.ps1')
. (Join-Path $PSScriptRoot '_grid_diagnostics.ps1')
function Assert-True($Value, $Message) { if (-not $Value) { throw $Message } }
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch { if ($_.Exception.Message -match $Pattern) { return }; throw }
    throw "Expected failure: $Pattern"
}
# Independent recursive parser/evaluator: count top-level arguments, not string
# occurrences. This rejects the original N-ary And regression even after regeneration.
function Read-OwnedExpression([string]$Expression, [hashtable]$Owned) {
    $e = $Expression.Trim()
    if ($e -match "^Dynasty\.HasPerk\(\s*GetDynastyPerk\('([^']+)'\)\s*\)$") { return [bool]$Owned[$Matches[1]] }
    if ($e -notmatch '^(And|Not)\(\s*(.*)\s*\)$') { throw "Invalid owned expression: $e" }
    $op = $Matches[1]; $body = $Matches[2]; $depth = 0; $start = 0
    $argsList = [Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $body.Length; $i++) {
        switch ($body[$i]) {
            '(' { $depth++ }
            ')' { $depth--; if ($depth -lt 0) { throw 'Unbalanced expression' } }
            ',' { if ($depth -eq 0) { $argsList.Add($body.Substring($start, $i - $start)); $start = $i + 1 } }
        }
    }
    if ($depth -ne 0) { throw 'Unbalanced expression' }
    $argsList.Add($body.Substring($start))
    $expected = if ($op -eq 'And') { 2 } else { 1 }
    if ($argsList.Count -ne $expected) { throw "$op expected $expected arguments; got $($argsList.Count)" }
    $a = Read-OwnedExpression $argsList[0] $Owned
    if ($op -eq 'Not') { return -not $a }
    $b = Read-OwnedExpression $argsList[1] $Owned
    return $a -and $b
}
foreach ($n in 1, 2, 5) {
    $keys = @(1..$n | ForEach-Object { "perk_$_" })
    $sb = [Text.StringBuilder]::new()
    Write-VanillaTrackSection $sb 'fixture' $keys ''
    $expressions = [regex]::Matches($sb.ToString(), 'visible = "\[([^\r\n]+)\]"')
    Assert-True ($expressions.Count -eq (2 + 2 * $n)) 'Unexpected ownership binding count'
    for ($mask = 0; $mask -lt [math]::Pow(2, $n); $mask++) {
        $owned = @{}; for ($i = 0; $i -lt $n; $i++) { $owned[$keys[$i]] = [bool]($mask -band (1 -shl $i)) }
        $all = $mask -eq ([math]::Pow(2, $n) - 1)
        Assert-True ((Read-OwnedExpression $expressions[0].Groups[1].Value $owned) -eq $all) 'Owned header truth table failed'
        Assert-True ((Read-OwnedExpression $expressions[1].Groups[1].Value $owned) -eq (-not $all)) 'Unowned header truth table failed'
    }
    $off = [Text.StringBuilder]::new()
    Write-VanillaTrackSection $off 'fixture' $keys '' -DisableOwnedState
    Assert-True ($off.ToString() -notmatch 'HasPerk|icon_check|Background_Frame_Gold') 'Disabled ownership widgets remain'
    Assert-True (([regex]::Matches($off.ToString(), 'Execute\(')).Count -eq (2 + 2 * $n)) 'Click actions changed'
}
Assert-Throws { Write-VanillaTrackSection ([Text.StringBuilder]::new()) 'empty' @() '' } 'empty dynasty track'
Assert-Throws { Read-OwnedExpression "And(Dynasty.HasPerk(GetDynastyPerk('a')), Dynasty.HasPerk(GetDynastyPerk('b')), Dynasty.HasPerk(GetDynastyPerk('c')))" @{} } 'expected 2'
$tracks = [ordered]@{ first = @('a'); second = @('b', 'c') }
Assert-True (@(Get-DiGridSelection $tracks -EmptyGrid).Count -eq 0) 'Empty selection failed'
Assert-True ((@(Get-DiGridSelection $tracks -TrackKeys @('second', 'first')) -join ',') -eq 'first,second') 'Generator order changed'
Assert-Throws { Get-DiGridSelection $tracks -TrackKeys missing } 'Unknown diagnostic track'
Assert-Throws { Get-DiGridSelection $tracks -EmptyGrid -TrackKeys first } 'mutually exclusive'
Assert-Throws { Assert-DiDiagnosticOutput (Join-Path $PSScriptRoot '..') } 'subdirectory'
Assert-DiDiagnosticOutput (Join-Path $env:TEMP 'di-grid-fixture')
foreach ($path in $GridPaths) {
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path))
    $count = 0
    foreach ($m in [regex]::Matches($text, 'visible = "\[([^\r\n]+)\]"')) {
        if ($m.Groups[1].Value -match 'Dynasty.HasPerk') { Read-OwnedExpression $m.Groups[1].Value @{} | Out-Null; $count++ }
    }
    Write-Host "[OK] $path : $count ownership bindings parsed"
}
Write-Host '[OK] Grid diagnostic tests: binary arity, truth tables, empty tracks, selection, staging, click preservation.'
