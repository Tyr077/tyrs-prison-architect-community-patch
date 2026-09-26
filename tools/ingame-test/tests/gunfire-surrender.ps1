<#
  Gunfire surrender (fix gunfire-surrender) and the 2018 fire rate (weapon-firerate 2.0.0).

  Save: RIOT(ROCKHARD).prison, a riot with six armed guards, edited as in armed-guard-warnings.ps1 so
  staff morale is low (the fixes alone then rarely let an armed guard warn, which keeps warnings from
  masking the gunfire effect), plus a Fire Rate Observer object from tools\testmods\fire-rate-observer.

  Runs:
    fixes -Without gunfire-surrender   every fix except the surrender hook (byte-identical otherwise)
    fixes                              every fix
    original (with -Original)          the unpatched game, for the fire rate baseline

  Checks:
    surrender: the peak number of prisoners with the "surrendered" status effect over the autosaves,
      averaged over Repeat runs per build, is higher with the fix than without it, and at least
      MinSurrendered.
    fire rate: the observer keeps a histogram of the ReloadTimer each armed guard shot stores, by the
      guard's main weapon. Guards with a shotgun also carry a Tazer, whose shots store 2.0 in every
      build, so the check is on the short bucket: with the fixes some shots store 0.7 s or less (the
      2018 shotgun value); unpatched none do (the final game stores 2.0 for every weapon).
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\RIOT(ROCKHARD).prison'),
    [int] $Autosaves = 3,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 2,
    [int] $MinSurrendered = 3,
    [int] $Repeat = 2,
    [switch] $Original,
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')
$ModDir = Join-Path $PSScriptRoot '..\..\testmods\fire-rate-observer'

function New-GunfireSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    # low staff morale, as in armed-guard-warnings.ps1
    $m = [regex]::Match($t, '(?m)^(    StaffPayModifier\s+)\S+')
    if (-not $m.Success) { throw 'no StaffPayModifier in the save' }
    $t = $t.Substring(0, $m.Index) + $m.Groups[1].Value + '0.0000000' + $t.Substring($m.Index + $m.Length)
    $th = [regex]::Match($t, '(?m)^BEGIN Thermometer\s*\r?\n')
    if (-not $th.Success) { throw 'no Thermometer block' }
    if ($t -match '(?m)^    StaffMorale\s') { $t = [regex]::Replace($t, '(?m)^    StaffMorale\s+\S+', '    StaffMorale          10.00000') }
    else { $t = $t.Substring(0, $th.Index + $th.Length) + "    StaffMorale          10.00000  $nl" + $t.Substring($th.Index + $th.Length) }
    # the observer object, on the tile of the first armed guard
    $g = [regex]::Match($t, '(?s)Type\s+ArmedGuard\s*\r?\n\s+SubType\s+\S+\s*\r?\n\s+Pos\.x\s+([\d.]+)\s*\r?\n\s+Pos\.y\s+([\d.]+)')
    if (-not $g.Success) { throw 'no ArmedGuard in the save' }
    $x = [math]::Floor([double]::Parse($g.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)) + 0.5
    $y = [math]::Floor([double]::Parse($g.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)) + 0.5
    $n = [regex]::Match($t, '(?m)^ObjectId\.next\s+(\d+)')
    if (-not $n.Success) { throw 'no ObjectId.next in the save header' }
    $nextU = [int]$n.Groups[1].Value
    $o = [regex]::Match($t, '(?m)^BEGIN Objects\s*\r?\n    Size\s+(\d+)\s*\r?\n')
    if (-not $o.Success) { throw 'no Objects block with a Size line' }
    $nextI = [int]$o.Groups[1].Value
    $line = ('    BEGIN "[i {0}]"    Id.i {0}  Id.u {1}  Type FireRateObserver  SubType 0  Pos.x {2:0.0000000}  Pos.y {3:0.0000000}  END' -f $nextI, $nextU, $x, $y) + $nl
    $t = $t.Substring(0, $o.Index) + "BEGIN Objects$nl    Size                 $($nextI + 1)$nl" + $line + $t.Substring($o.Index + $o.Length)
    $t = [regex]::Replace($t, '(?m)^ObjectId\.next\s+\d+', "ObjectId.next        $($nextU + 1)", 1)
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
}
function Count-Surrendered($save) {
    @(Get-PrisonObjects $save -Type Prisoner | Where-Object { $_.Contains('StatusEffects') -and $_.StatusEffects.Contains('surrendered') }).Count
}
function Get-ObserverReadings($save) {
    $obs = @(Get-PrisonObjects $save -Type FireRateObserver) | Select-Object -First 1
    $r = @{}
    if (-not $obs -or -not $obs.Contains('ScriptSystem')) { return $r }
    # the script's own fields are saved in the object's ScriptSystem block
    foreach ($k in @($obs.ScriptSystem.Keys)) { if ($k -like 'RT_*') { $r[$k] = $obs.ScriptSystem[$k] } }
    return $r
}

$work = Join-Path $PSScriptRoot '..\results\gunfire-surrender.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
New-GunfireSave $Save $work
$before = ConvertFrom-PrisonSave $work
Write-Host ("edited save: {0} prisoners, {1} armed guards, rioting {2}, StaffMorale {3}, observers {4}, surrendered now: {5}" -f @(Get-PrisonObjects $before -Type Prisoner).Count, @(Get-PrisonObjects $before -Type ArmedGuard).Count, $before.Thermometer['RiotingPrisoners'], $before.Thermometer['StaffMorale'], @(Get-PrisonObjects $before -Type FireRateObserver).Count, (Count-Surrendered $before))
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$runs = @()
for ($i = 1; $i -le $Repeat; $i++) {
    $runs += @{ Key = 'without'; Selection = 'fixes'; Without = @('gunfire-surrender'); N = $i }
    $runs += @{ Key = 'fixes'; Selection = 'fixes'; Without = @(); N = $i }
}
if ($Original) { $runs += @{ Key = 'original'; Selection = 'original'; Without = @(); N = 1 } }
$peaks = @{}; $short = @{}; $long = @{}
foreach ($run in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $run.Selection -Without $run.Without -Mod $ModDir -NoFailureConditions -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name "gunfire-$($run.Key)"
    if (-not $r.Ok) { Write-Host "FAIL gunfire-surrender ($($run.Key) #$($run.N)): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $p = 0; $lines = @()
    foreach ($snap in (Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)) {
        $s = ConvertFrom-PrisonSave $snap.FullName
        $c = Count-Surrendered $s
        $lines += ("{0}: {1} surrendered, rioting {2}, morale {3}" -f $snap.BaseName, $c, $s.Thermometer['RiotingPrisoners'], $s.Thermometer['StaffMorale'])
        if ($c -gt $p) { $p = $c }
    }
    $readings = Get-ObserverReadings (ConvertFrom-PrisonSave $r.Autosave)
    # shotgun histogram: b1..b7 = a reload of 0.7 s or less (2018 value), b8 and up = longer (2.0 unpatched, or a Tazer shot)
    $s7 = 0; $sl = 0
    foreach ($k in $readings.Keys) {
        if ($k -match '^RT_Shotgun_b(-?\d+)$') { if ([int]$Matches[1] -le 7) { $s7 += [int](ToDouble $readings[$k]) } else { $sl += [int](ToDouble $readings[$k]) } }
    }
    $peaks[$run.Key] += @($p); $short[$run.Key] += $s7; $long[$run.Key] += $sl
    Write-Host ("{0} #{1}: peak {2} surrendered; shotgun-guard shots <=0.7 s: {3}, longer: {4}; exe {5}; {6}" -f $run.Key, $run.N, $p, $s7, $sl, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    $lines | ForEach-Object { Write-Host "  $_" }
    Write-Host ("  observer: {0}" -f (($readings.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '))
}

function Mean($a) { ($a | Measure-Object -Average).Average }
$mw = Mean $peaks['without']; $mf = Mean $peaks['fixes']
$fail = @()
if ($mf -lt $MinSurrendered) { $fail += "mean peak with the fix $mf (expected at least $MinSurrendered)" }
if ($mf -le $mw) { $fail += "mean peak with the fix $mf is not above $mw without it" }
foreach ($k in @('without', 'fixes')) {
    if ($short[$k] -lt 1) { $fail += "$k runs: no shotgun-guard shot with a reload of 0.7 s or less (longer: $($long[$k]))" }
}
if ($Original -and $short['original'] -gt 0) { $fail += "original run: $($short['original']) shot(s) with a reload of 0.7 s or less, expected none (the final game stores 2.0)" }
Write-Host ("surrender peaks: without {0} (mean {1:n1}), fixes {2} (mean {3:n1})" -f ($peaks['without'] -join '/'), $mw, ($peaks['fixes'] -join '/'), $mf)
Write-Host ("shotgun-guard shots <=0.7 s / longer: " + (($short.Keys | Sort-Object | ForEach-Object { "$_ $($short[$_])/$($long[$_])" }) -join ', '))
if ($fail.Count) { $fail | ForEach-Object { Write-Host "FAIL gunfire-surrender: $_" }; exit 1 }
Write-Host 'PASS gunfire-surrender'
exit 0
