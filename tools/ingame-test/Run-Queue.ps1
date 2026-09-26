<#
  Run-Queue.ps1: run several in-game tests one after another, unattended.

  Each entry is a test name from tests\ (without .ps1), optionally followed by its arguments, for example
      .\Run-Queue.ps1 'exercise-grading' 'shop-front' 'gunfire-surrender -Repeat 3'
  Every test runs in its own PowerShell process so a failing test cannot stop the queue. The full
  output of each test goes to results\queue-<stamp>\<n>-<name>.log, and summary.txt collects each
  test's exit code, duration and its PASS / FAIL / NOTE lines. The game is only ever run by one test at
  a time, so do not play while a queue runs.
#>
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)] [string[]] $Tests
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dir = Join-Path $root ("results\queue-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
New-Item -ItemType Directory -Force $dir | Out-Null
$summary = Join-Path $dir 'summary.txt'
$i = 0
foreach ($entry in $Tests) {
    $i++
    $parts = @($entry -split '\s+' | Where-Object { $_ })
    $name = $parts[0]
    $script = Join-Path $root "tests\$name.ps1"
    if (-not (Test-Path -LiteralPath $script)) { Add-Content $summary "[$i] ${entry}: no such test"; continue }
    $log = Join-Path $dir ("{0:00}-{1}.log" -f $i, $name)
    $start = Get-Date
    Write-Host ("[{0}/{1}] {2} ({3:HH:mm})" -f $i, $Tests.Count, $entry, $start)
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) + @($parts | Select-Object -Skip 1)
    & powershell.exe @argList *>&1 | Tee-Object -FilePath $log | Out-Null
    $code = $LASTEXITCODE
    $mins = ((Get-Date) - $start).TotalMinutes
    $lines = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^(PASS|FAIL|NOTE)' })
    Add-Content $summary ("[{0}] {1}: exit {2}, {3:n1} min" -f $i, $entry, $code, $mins)
    $lines | ForEach-Object { Add-Content $summary "    $_" }
    Write-Host ("      exit {0}, {1:n1} min: {2}" -f $code, $mins, ($lines -join ' | '))
}
Write-Host "summary: $summary"
Get-Content $summary
