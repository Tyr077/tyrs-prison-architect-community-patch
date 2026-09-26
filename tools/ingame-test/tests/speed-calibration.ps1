<#
  Speed calibration: what each in-game speed key does to the game clock.

  The save header's TimeWarpFactor is game minutes per real second, set by map size when the map was
  made (1.0, 0.75 or 0.5 for small, medium, large, in FUN_1401845D0); the speed selector (pause and four speeds, shown as >, >>, >>>, >>>>)
  multiplies it. This test loads the keycard save with TimeWarpFactor -TimeWarp, sends one key to the
  game window after the load (none first, then each of -Keys), and measures game minutes per real
  minute between the first and the last autosave, from the TimeIndex in each file and its write time.
#>
param(
    [string] $Save = (Join-Path $PSScriptRoot '..\..\..\keycardtest3local.prison'),
    [string[]] $Keys = @('', '1', '2', '3', '4'),
    [double] $TimeWarp = 1.0,
    [int] $Autosaves = 3
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')

function Get-TimeIndex([string] $path) {
    foreach ($line in [IO.File]::ReadLines($path)) {
        if ($line -match '^TimeIndex\s+([\d.]+)') { return [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture) }
    }
    return $null
}

$rows = @()
foreach ($k in $Keys) {
    $label = if ($k) { "key $k" } else { 'no key' }
    $r = Invoke-InGameRun -Save $Save -Selection fixes -Autosaves $Autosaves -TimeWarp $TimeWarp -SpeedKey $k -Name ("speed-" + $(if ($k) { $k } else { 'none' }))
    if (-not $r.Ok) { Write-Host "FAIL speed-calibration ($label): $($r.Note)"; exit 1 }
    $snaps = @(Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object { [int]($_.BaseName -replace '\D', '') })
    $a = $snaps[0]; $b = $snaps[-1]
    $gm = (Get-TimeIndex $b.FullName) - (Get-TimeIndex $a.FullName)
    $rm = ($b.LastWriteTime - $a.LastWriteTime).TotalMinutes
    $rate = if ($rm -gt 0) { $gm / $rm } else { 0 }
    Write-Host ("{0}: {1:n1} game minutes in {2:n2} real minutes = {3:n1} game minutes per real minute" -f $label, $gm, $rm, $rate)
    $rows += [pscustomobject]@{ Key = $label; Rate = $rate }
}
Write-Host ("PASS speed-calibration (TimeWarpFactor {0}): {1}" -f $TimeWarp, (($rows | ForEach-Object { '{0} {1:n0}/min' -f $_.Key, $_.Rate }) -join ', '))
exit 0
