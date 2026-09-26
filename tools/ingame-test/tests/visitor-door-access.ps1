<#
  Visitors and civilians at single visitor doors (fix visitor-door-access).

  The movement code lets every non-prisoner open a single visitor door itself, so it never asks a guard,
  but Door::Open only admits an old list of types (Visitor, Teacher, emergency services and a few more,
  plus staff). Later types (RehabilitatedPrisoner, AnimalTherapist, FireSafetyTeacher, EntityDeliveryMan,
  and Repairman or PestControlWorker when they arrive without an event override) are refused; a Discord
  report says they wait at the door, which this test has not reproduced yet. The fix makes Door::Open refuse only prisoners.

  Save: base3z.prison and its single visitor door -DoorId (Id.i 693, in an east-west wall). The test adds
  a Door Test Controller (tools/testmods/door-test) that spawns -PerType NPCs of each type in -Types
  -Offset tiles on one side of the door and keeps sending them to the tile -Offset tiles on the other
  side with Object.NavigateTo. It runs the unpatched game and the fixes and reads, per type, how many
  were spawned and how many arrived. Workman (staff) and Visitor are meant as controls that pass
  either way. Expected: the other spawned types arrive only with the fixes. 2026-09-23: not working
  as a scenario; NavigateTo moved only Workman and EntityDeliveryMan (the Visitor control did not get
  through on either build), and EntityDeliveryMan also got through on the original.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\base3z.prison'),
    [int] $DoorId = 693,
    [int] $Offset = 3,
    [string[]] $Types = @('Workman', 'Visitor', 'Repairman', 'PestControlWorker', 'EntityDeliveryMan', 'FireSafetyTeacher', 'AnimalTherapist', 'RehabilitatedPrisoner'),
    [string[]] $Controls = @('Workman', 'Visitor'),
    [int] $PerType = 2,
    [int] $Autosaves = 1,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 3,
    [ValidateSet('both', 'original', 'fixes')] [string] $Selection = 'both',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')
$ModSrc = Join-Path $PSScriptRoot '..\..\testmods\door-test'
$ResultsDir = Join-Path $PSScriptRoot '..\results'

function Get-CellMat([string] $t, [int] $x, [int] $y) {
    $m = [regex]::Match($t, ('(?m)^    BEGIN "{0} {1}"\s+Mat (\S+)' -f $x, $y))
    if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}
function Test-Solid([string] $mat) { return ($mat -match 'Wall|Fence' -or $mat -eq '') }

$t = [IO.File]::ReadAllText($Save)
$d = [regex]::Match($t, ('(?m)^    BEGIN "\[i {0}\]"\s+Id\.i {0}\s+Id\.u \d+\s+Type (VisitorDoor|FenceGateVisitor)\s+SubType \d+\s+Pos\.x ([\d.]+)\s+Pos\.y ([\d.]+)' -f $DoorId))
if (-not $d.Success) { throw "no single visitor door with Id.i $DoorId" }
$dx = [int][math]::Floor([double]::Parse($d.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture))
$dy = [int][math]::Floor([double]::Parse($d.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture))
# the wall runs along the axis whose neighbours are solid; walk through along the other axis
if ((Test-Solid (Get-CellMat $t ($dx - 1) $dy)) -and (Test-Solid (Get-CellMat $t ($dx + 1) $dy))) { $ax = 0; $ay = 1 }
elseif ((Test-Solid (Get-CellMat $t $dx ($dy - 1))) -and (Test-Solid (Get-CellMat $t $dx ($dy + 1)))) { $ax = 1; $ay = 0 }
else { throw "door $DoorId at $dx,$dy is not set in a straight wall" }
$from = @(($dx + $ax * $Offset), ($dy + $ay * $Offset)); $to = @(($dx - $ax * $Offset), ($dy - $ay * $Offset))
foreach ($c in @($from, $to)) {
    if (Test-Solid (Get-CellMat $t $c[0] $c[1])) { throw "tile $($c[0]),$($c[1]) beside door $DoorId is solid; try another -Offset" }
}

# controller object next to the door, and a configured copy of the mod
$nl = "`r`n"
$n = [regex]::Match($t, '(?m)^ObjectId\.next\s+(\d+)'); $nextU = [int]$n.Groups[1].Value
$o = [regex]::Match($t, '(?m)^BEGIN Objects\s*\r?\n    Size\s+(\d+)\s*\r?\n'); $nextI = [int]$o.Groups[1].Value
$line = ('    BEGIN "[i {0}]"    Id.i {0}  Id.u {1}  Type DoorTestController  SubType 0  Pos.x {2}.5000000  Pos.y {3}.5000000  END' -f $nextI, $nextU, $from[0], $from[1]) + $nl
$t = $t.Substring(0, $o.Index) + "BEGIN Objects$nl    Size                 $($nextI + 1)$nl" + $line + $t.Substring($o.Index + $o.Length)
$t = [regex]::Replace($t, '(?m)^ObjectId\.next\s+\d+', "ObjectId.next        $($nextU + 1)", 1)
New-Item -ItemType Directory -Force $ResultsDir | Out-Null
$work = Join-Path $ResultsDir 'visitor-door-access.prison'
[IO.File]::WriteAllText($work, $t, (New-Object Text.UTF8Encoding($false)))
$mod = Join-Path $ResultsDir 'door-test-mod'
if (Test-Path -LiteralPath $mod) { Remove-Item -Recurse -Force -LiteralPath $mod }
Copy-Item -Recurse -LiteralPath $ModSrc -Destination $mod
$lua = Join-Path $mod 'data\scripts\DoorTestController.lua'
$cfg = @(
    '-- BEGIN CONFIG'
    ('local Types = {{ {0} }}' -f (($Types | ForEach-Object { '"' + $_ + '"' }) -join ', '))
    "local PerType = $PerType"
    ('local FromX, FromY = {0}.5, {1}.5' -f $from[0], $from[1])
    ('local ToX, ToY = {0}.5, {1}.5' -f $to[0], $to[1])
    'local RenavEvery = 10'
    '-- END CONFIG'
) -join "`r`n"
$src = [IO.File]::ReadAllText($lua)
[IO.File]::WriteAllText($lua, [regex]::Replace($src, '(?s)-- BEGIN CONFIG.*?-- END CONFIG', $cfg.Replace('$', '$$')), (New-Object Text.UTF8Encoding($false)))
Write-Host ("door {0} at {1},{2} ({3} wall): spawn at {4},{5}, target {6},{7}; types {8}" -f $DoorId, $dx, $dy, $(if ($ax -eq 0) { 'east-west' } else { 'north-south' }), $from[0], $from[1], $to[0], $to[1], ($Types -join ', '))
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('original', 'fixes') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Mod $mod -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name "door-$sel"
    if (-not $r.Ok) { Write-Host "FAIL visitor-door-access ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $obs = @(Get-PrisonObjects (ConvertFrom-PrisonSave $r.Autosave) -Type DoorTestController) | Select-Object -First 1
    if (-not $obs -or -not $obs.Contains('ScriptSystem')) { Write-Host "FAIL visitor-door-access ($sel): the controller saved no results (did the mod load?) $($r.ResultDir)"; exit 1 }
    $ss = $obs.ScriptSystem
    $row = @{}
    foreach ($ty in $Types) {
        $sp = [int](ToDouble $ss["Spawned_$ty"]); $ar = [int](ToDouble $ss["Arrived_$ty"])
        $cl = if ($ss.Contains("Closest_$ty")) { '{0:n1}' -f (ToDouble $ss["Closest_$ty"]) } else { '-' }
        $row[$ty] = [pscustomobject]@{ Spawned = $sp; Arrived = $ar; Closest = $cl }
    }
    Write-Host ("{0}: exe {1}; {2}" -f $sel, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    foreach ($ty in $Types) { Write-Host ("  {0,-22} spawned {1}, arrived {2}, closest {3} tiles" -f $ty, $row[$ty].Spawned, $row[$ty].Arrived, $row[$ty].Closest) }
    $results[$sel] = $row
}

$fail = $false
foreach ($sel in $runs) {
    foreach ($c in $Controls) {
        $x = $results[$sel][$c]
        if ($x -and $x.Spawned -gt 0 -and $x.Arrived -lt $x.Spawned) { Write-Host "FAIL visitor-door-access: control $c did not get through on $sel (scenario problem: route, AI or door)"; $fail = $true }
    }
}
$tested = @($Types | Where-Object { $Controls -notcontains $_ -and $results[$runs[0]][$_].Spawned -gt 0 })
if ($tested.Count -eq 0) { Write-Host 'FAIL visitor-door-access: none of the affected types could be spawned'; exit 1 }
if ($results.ContainsKey('fixes')) {
    foreach ($ty in $tested) { if ($results['fixes'][$ty].Arrived -lt $results['fixes'][$ty].Spawned) { Write-Host "FAIL visitor-door-access: $ty did not get through with the fixes"; $fail = $true } }
}
if ($results.ContainsKey('original')) {
    $stuck = @($tested | Where-Object { $results['original'][$_].Arrived -eq 0 })
    Write-Host ("NOTE visitor-door-access: on the original build {0} of {1} affected types never got through ({2})" -f $stuck.Count, $tested.Count, ($stuck -join ', '))
}
if ($fail) { exit 1 }
Write-Host ("PASS visitor-door-access (types tested: {0})" -f ($tested -join ', '))
exit 0
