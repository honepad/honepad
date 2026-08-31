# Replay shared traces against a PowerShell solution.
# Methods are camelCase. Bank booleans are JSON true/false.
# ConvertTo-Json uses -Depth so nested report objects are not truncated.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Src,
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $ClassName,
    [Parameter(Mandatory = $true, Position = 2)]
    [string] $CasesPath
)

$ErrorActionPreference = 'Stop'
$reportOut = [Console]::Out
[Console]::SetOut([IO.TextWriter]::Null)

function ConvertTo-Camel([string] $Snake) {
    if (-not $Snake.Contains('_')) {
        return $Snake
    }
    $parts = $Snake.Split('_')
    $out = $parts[0]
    for ($i = 1; $i -lt $parts.Length; $i++) {
        if ($parts[$i].Length -eq 0) {
            continue
        }
        $out += $parts[$i].Substring(0, 1).ToUpper() + $parts[$i].Substring(1)
    }
    return $out
}

function ConvertTo-JsonValue($Value) {
    if ($null -eq $Value) {
        return 'null'
    }
    if ($Value -is [bool]) {
        if ($Value) { return 'true' } else { return 'false' }
    }
    if ($Value -is [string]) {
        return (ConvertTo-Json -InputObject $Value -Compress -Depth 20)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        return (ConvertTo-Json -InputObject $Value -Compress -Depth 20)
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return (ConvertTo-Json -InputObject @($Value) -Compress -Depth 20)
    }
    return (ConvertTo-Json -InputObject $Value -Compress -Depth 20)
}

. $Src

$cls = $ClassName -as [type]
if ($null -eq $cls) {
    Write-Error "missing class $ClassName"
    exit 2
}

$cases = @(Get-Content -Raw -LiteralPath $CasesPath | ConvertFrom-Json)
$failed = [System.Collections.Generic.List[object]]::new()
$passed = 0

foreach ($case in $cases) {
    $obj = $cls::new()
    $ok = $true
    $calls = @($case.calls)
    for ($i = 0; $i -lt $calls.Count; $i++) {
        $call = $calls[$i]
        $methodSnake = [string] $call.m
        $name = ConvertTo-Camel $methodSnake
        $expected = $call.e
        $argv = @($call.a)
        $method = $obj.PSObject.Methods[$name]
        if ($null -eq $method) {
            $failed.Add([ordered]@{
                    case     = [string] $case.id
                    index    = $i
                    method   = $methodSnake
                    expected = $expected
                    actual   = 'exc:missing'
                })
            $ok = $false
            break
        }
        try {
            $actual = $method.Invoke($argv)
        }
        catch {
            $excName = $_.Exception.GetType().Name
            $failed.Add([ordered]@{
                    case     = [string] $case.id
                    index    = $i
                    method   = $methodSnake
                    expected = $expected
                    actual   = "exc:$excName"
                })
            $ok = $false
            break
        }
        if ((ConvertTo-JsonValue $actual) -ne (ConvertTo-JsonValue $expected)) {
            $failed.Add([ordered]@{
                    case     = [string] $case.id
                    index    = $i
                    method   = $methodSnake
                    expected = $expected
                    actual   = $actual
                })
            $ok = $false
            break
        }
    }
    if ($ok) {
        $passed += 1
    }
}

$report = [ordered]@{
    passed = $passed
    failed = @($failed)
}
[Console]::SetOut($reportOut)
$reportOut.WriteLine((ConvertTo-Json -InputObject $report -Compress -Depth 20))
if ($failed.Count -gt 0) {
    exit 1
}
exit 0
