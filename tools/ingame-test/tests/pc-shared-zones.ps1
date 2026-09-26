<#
  Protective Custody prisoners work and attend programs in shared sectors (tweak tweak-pc-shared-zones, GitHub issue #3).

  Save: the reporter's "Sunset PC work demo.prison" (analysis/issue-3). Every sector is Shared apart from
  staff areas, so there is no ProtectedOnly sector anywhere. The prisoners outside MinSec are
  stored as SuperMax; the test converts them to Protective Custody.

  -Mode ingame (default): the save is left as it is apart from one PC Test Controller object
  (tools/testmods/pc-test). In the running game the controller switches the SuperMax prisoners to
  Protective Custody with Object.SetProperty(prisoner, "Category", 4); can
  spawn -Spawn new prisoners and make them Protective Custody; and can switch -Toggle MinSec prisoners to
  Protective Custody once Game.Time() has advanced by -ToggleAfter. It also records, per category, how
  many prisoners hold a work station and a job, with a timeline.
  -Mode save: the older method, retyping SuperMax to Protected in the save text before loading.

  Signal: each prisoner's Experience block counts game minutes by activity (Work, Class; written only
  when non-zero). Prisoners are grouped by category at the start and at the end (SuperMax->Protected,
  MinSec->Protected for toggled ones, new->Protected for spawned ones, MinSec as the control). The test
  runs fixes+tweaks without this tweak, then fixes+tweaks, and compares the Work minutes and class attendance
  of the Protective Custody groups. Expected: none without the tweak, clearly more with it; MinSec works in both.
#>
param(
    [string] $Save = (Join-Path $PSScriptRoot '..\..\..\analysis\issue-3\Sunset PC work demo.prison'),
    [ValidateSet('ingame', 'save')] [string] $Mode = 'ingame',
    [string] $ConvertFrom = 'SuperMax',
    [int] $Spawn = 0,
    [int] $Toggle = 0,
    [double] $ToggleAfter = 0,
    [int] $Autosaves = 2,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 1,
    [ValidateSet('both', 'without', 'tweak')] [string] $Selection = 'both',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

$ModSrc = Join-Path $PSScriptRoot '..\..\testmods\pc-test'
$ResultsDir = Join-Path $PSScriptRoot '..\results'

function Add-Controller([string] $t) {
    # the controller in the middle of the map; it scans every prisoner within 400 tiles
    $nl = "`r`n"
    $n = [regex]::Match($t, '(?m)^ObjectId\.next\s+(\d+)')
    if (-not $n.Success) { throw 'no ObjectId.next in the save header' }
    $nextU = [int]$n.Groups[1].Value
    $o = [regex]::Match($t, '(?m)^BEGIN Objects\s*\r?\n    Size\s+(\d+)\s*\r?\n')
    if (-not $o.Success) { throw 'no Objects block with a Size line' }
    $nextI = [int]$o.Groups[1].Value
    $line = ('    BEGIN "[i {0}]"    Id.i {0}  Id.u {1}  Type PCTestController  SubType 0  Pos.x 50.5000000  Pos.y 40.5000000  END' -f $nextI, $nextU) + $nl
    $t = $t.Substring(0, $o.Index) + "BEGIN Objects$nl    Size                 $($nextI + 1)$nl" + $line + $t.Substring($o.Index + $o.Length)
    return [regex]::Replace($t, '(?m)^ObjectId\.next\s+\d+', "ObjectId.next        $($nextU + 1)", 1)
}
function New-TestSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $rx = [regex]'(?m)^        Category\s+SuperMax[^\r\n]*'
    $n = $rx.Matches($t).Count
    if ($n -eq 0) { throw 'the save has no SuperMax prisoners' }
    if ($Mode -eq 'save') { $t = $rx.Replace($t, '        Category             Protected  ') }
    else { $t = Add-Controller $t }
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return $n
}
function New-ModCopy([string] $dst) {
    if (Test-Path -LiteralPath $dst) { Remove-Item -Recurse -Force -LiteralPath $dst }
    Copy-Item -Recurse -LiteralPath $ModSrc -Destination $dst
    $lua = Join-Path $dst 'data\scripts\PCTestController.lua'
    $cfg = @(
        '-- BEGIN CONFIG'
        "local ConvertFrom = `"$ConvertFrom`""
        "local Spawn = $Spawn"
        "local ToggleCount = $Toggle"
        ('local ToggleAfter = {0}' -f $ToggleAfter.ToString([Globalization.CultureInfo]::InvariantCulture))
        'local SnapEvery = 15'
        '-- END CONFIG'
    ) -join "`r`n"
    $t = [IO.File]::ReadAllText($lua)
    $t = [regex]::Replace($t, '(?s)-- BEGIN CONFIG.*?-- END CONFIG', $cfg.Replace('$', '$$'))
    [IO.File]::WriteAllText($lua, $t, (New-Object Text.UTF8Encoding($false)))
}
function Get-Activity($save) {
    $out = @{}
    foreach ($p in (Get-PrisonObjects $save -Type Prisoner)) {
        $w = Get-PrisonValue $p 'Experience', 'Experience', 'Work'
        $c = Get-PrisonValue $p 'Experience', 'Experience', 'Class'
        $ra = Get-PrisonValue $p 'Experience', 'Experience', 'ReformAttendance'
        $out[$p['Id.u']] = [pscustomobject]@{
            Category = $p.Category
            Work = if ($w) { ToDouble $w } else { 0.0 }
            Class = if ($c) { ToDouble $c } else { 0.0 }
            Attend = if ($ra) { ToDouble $ra } else { 0.0 }
            InClass = ((Get-PrisonValue $p 'Needs', 'Action') -eq 'ReformProgram')
        }
    }
    return $out
}
function Get-Gains($a0, $a1) {
    $g = @{}
    foreach ($id in $a1.Keys) {
        $start = if ($a0.ContainsKey($id)) { $a0[$id] } else { $null }
        $from = if ($start) { $start.Category } else { 'new' }
        $to = $a1[$id].Category
        $key = if ($from -eq $to) { $to } else { "$from->$to" }
        if (-not $g.ContainsKey($key)) { $g[$key] = [pscustomobject]@{ N = 0; Work = 0.0; Class = 0.0; Attend = 0.0; Workers = 0; Students = 0; InClass = 0 } }
        $dw = $a1[$id].Work - $(if ($start) { $start.Work } else { 0 })
        $dc = $a1[$id].Class - $(if ($start) { $start.Class } else { 0 })
        $da = $a1[$id].Attend - $(if ($start) { $start.Attend } else { 0 })
        $g[$key].N++; $g[$key].Work += $dw; $g[$key].Class += $dc; $g[$key].Attend += $da
        if ($dw -gt 0) { $g[$key].Workers++ }
        if ($dc -gt 0) { $g[$key].Students++ }
    }
    return $g
}
function Show-Controller($save) {
    $obs = @(Get-PrisonObjects $save -Type PCTestController) | Select-Object -First 1
    if (-not $obs -or -not $obs.Contains('ScriptSystem')) { Write-Host '  controller: no ScriptSystem block'; return }
    $ss = $obs.ScriptSystem
    $keys = @($ss.Keys | Where-Object { $_ -ne '_name' -and $_ -notlike 'Spawned_*' -and $_ -notlike 'Toggled_*' -and $_ -notlike 'T*_*' })
    Write-Host ('  controller: ' + (($keys | Sort-Object | ForEach-Object { "$_=$($ss[$_])" }) -join '  '))
    $snaps = @($ss.Keys | Where-Object { $_ -match '^T(\d+)_GT$' } | ForEach-Object { [int]($_ -replace '^T(\d+)_GT$', '$1') } | Sort-Object)
    foreach ($k in $snaps) {
        $cats = @($ss.Keys | Where-Object { $_ -like "T${k}_*" -and $_ -ne "T${k}_GT" } | Sort-Object)
        Write-Host ("    t{0,-3} GT {1,-10} " -f $k, $ss["T${k}_GT"]) -NoNewline
        Write-Host (($cats | ForEach-Object { "$($_ -replace "^T${k}_", '')=$($ss[$_])" }) -join '  ') '(jobs/stations/prisoners)'
    }
}

New-Item -ItemType Directory -Force $ResultsDir | Out-Null
$work = Join-Path $ResultsDir 'pc-shared-zones.prison'
$found = New-TestSave $Save $work
$before = ConvertFrom-PrisonSave $work
$t0 = ToDouble $before.TimeIndex
$a0 = Get-Activity $before
$how = if ($Mode -eq 'save') { 'retyped to Protected in the save' } else { "left in the save; in game: convert '$ConvertFrom' to Protected, spawn $Spawn, toggle $Toggle MinSec after Game.Time +$ToggleAfter" }
Write-Host ("test save ({0}): {1} SuperMax prisoner(s) {2}; clock {3:n0} ({4:00}:{5:00}), {6} prisoners" -f $Mode, $found, $how, $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), $a0.Count)
$mod = $null
if ($Mode -eq 'ingame') { $mod = Join-Path $ResultsDir 'pc-test-mod'; New-ModCopy $mod }
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('without', 'tweak') } else { @($Selection) }
foreach ($sel in $runs) {
    $runArgs = @{ Save = $work; Selection = 'fixes+tweaks'; Autosaves = $Autosaves; TimeWarp = $TimeWarp; Speed = $Speed; Name = "pc-zones-$Mode-$sel"; NoFailureConditions = $true }
    if ($sel -eq 'without') { $runArgs.Without = @('tweak-pc-shared-zones') }
    if ($mod) { $runArgs.Mod = @($mod) }
    $r = Invoke-InGameRun @runArgs
    if (-not $r.Ok) { Write-Host "FAIL pc-shared-zones ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $after = ConvertFrom-PrisonSave $r.Autosave
    $base = $a0
    if ($Toggle -gt 0) {
        # the toggle happens after the first autosave; measure from there so the MinSec work before it does not count
        $first = Join-Path $r.ResultDir 'autosave-1.prison'
        if (Test-Path -LiteralPath $first) { $base = Get-Activity (ConvertFrom-PrisonSave $first) }
    }
    $g = Get-Gains $base (Get-Activity $after)
    $t1 = ToDouble $after.TimeIndex
    Write-Host ("{0}: after {1:n0} game minutes (clock {2:n0}), exe {3}; {4}" -f $sel, ($t1 - $t0), $t1, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    # in class at each autosave: prisoners whose current need action is ReformProgram, by the same groups
    $snapFiles = @(Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)
    foreach ($sf in $snapFiles) {
        $sa = Get-Activity (ConvertFrom-PrisonSave $sf.FullName)
        foreach ($id in $sa.Keys) {
            if (-not $sa[$id].InClass) { continue }
            $from = if ($a0.ContainsKey($id)) { $a0[$id].Category } else { 'new' }
            $to = $sa[$id].Category
            $key = if ($from -eq $to) { $to } else { "$from->$to" }
            if ($g.ContainsKey($key)) { $g[$key].InClass++ }
        }
    }
    foreach ($key in ($g.Keys | Sort-Object)) {
        $x = $g[$key]
        Write-Host ("  {0,-22} {1,4} prisoners: Work +{2,8:n0} min ({3} gained), Class +{4,7:n0} min ({5} gained), ReformAttendance +{6:n0}, in class {7} (sum over {8} autosaves)" -f $key, $x.N, $x.Work, $x.Workers, $x.Class, $x.Students, $x.Attend, $x.InClass, $snapFiles.Count)
    }
    if ($mod) { Show-Controller $after }
    $results[$sel] = $g
}

if ($runs.Count -lt 2) { exit 0 }
function Sum-PC($g, [string] $what) { $s = 0.0; foreach ($k in $g.Keys) { if ($k -like '*Protected') { $s += $g[$k].$what } }; return $s }
$pw = Sum-PC $results['without'] 'Work'; $pf = Sum-PC $results['tweak'] 'Work'
$mw = if ($results['without'].ContainsKey('MinSec')) { $results['without']['MinSec'].Work } else { 0 }
$mf = if ($results['tweak'].ContainsKey('MinSec')) { $results['tweak']['MinSec'].Work } else { 0 }
if ($mw -le 0 -or $mf -le 0) { Write-Host 'FAIL pc-shared-zones: the MinSec control did not work in both runs (scenario did not happen; try a longer run)'; exit 1 }
if ($pf -le [math]::Max(4 * $pw, 60)) { Write-Host ("FAIL pc-shared-zones: Protective Custody Work +{0:n0} min with the tweak vs +{1:n0} without" -f $pf, $pw); exit 1 }
$cw = Sum-PC $results['without'] 'InClass'; $cf = Sum-PC $results['tweak'] 'InClass'
Write-Host ("PASS pc-shared-zones (Protective Custody Work +{0:n0} min with the tweak, +{1:n0} without; in class at autosaves {2} vs {3})" -f $pf, $pw, $cf, $cw)
if ($cf -le [math]::Max(4 * $cw, 5)) { Write-Host ("NOTE: programs not shown working: Protective Custody prisoners in class {0} with the tweak vs {1} without" -f $cf, $cw) }
exit 0
