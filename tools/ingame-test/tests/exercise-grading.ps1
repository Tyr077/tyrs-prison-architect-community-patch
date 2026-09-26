<#
  Exercise on equipment counts for grading (fix exercise-grading).

  Save: base3z.prison has twelve weights benches in its Yard. The Yard is the only room in this save
  that the unpatched game credits as Exercise (the Gymnasium and FightClubRoom from DLC also would), so the test retypes that room to CommonRoom in the
  edited save (the room keeps its cells and objects; its indoor requirement fails, which is harmless).
  Then nobody can jog for credit, but the benches still work: their provider is an object provider
  with a slot and no room requirement. Unpatched, time on a bench is filed under Freetime or Regime;
  with the fix it lands in the Exercise counter.

  Signal: each prisoner's Experience block (BEGIN Experience TotalTime ... END, counters written only
  when non-zero). The test runs the unpatched build and the fixed build on the same edited save and
  compares each prisoner's Exercise counter before and after. A bench user is a prisoner whose Needs
  block targets a bench, or who stands on one, in any autosave snapshot. Expected: no prisoner gains
  Exercise on the original; at least one bench user gains it with the fix.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\base3z.prison'),
    [int] $Autosaves = 2,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 3,
    [ValidateSet('both', 'original', 'fixes')] [string] $Selection = 'both',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

function New-NoYardSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $rx = [regex]'(?m)^        RoomType\s+Yard\s*$'
    $n = $rx.Matches($t).Count
    if ($n -eq 0) { throw 'the save has no Yard room' }
    $t = $rx.Replace($t, '        RoomType             CommonRoom  ')
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return $n
}
function Get-ExerciseCounters($save) {
    $out = @{}
    foreach ($p in (Get-PrisonObjects $save -Type Prisoner)) {
        $e = Get-PrisonValue $p 'Experience', 'Experience', 'Exercise'
        $out[$p['Id.u']] = if ($e) { ToDouble $e } else { 0.0 }
    }
    return $out
}
function Get-BenchUsers($save) {
    $benches = @(Get-PrisonObjects $save -Type WeightsBench)
    $benchIds = @{}; foreach ($b in $benches) { $benchIds[$b['Id.u']] = $true }
    $users = @()
    foreach ($p in (Get-PrisonObjects $save -Type Prisoner)) {
        $target = Get-PrisonValue $p 'Needs', 'Target.u'
        if ($target -and $benchIds.ContainsKey($target)) { $users += $p['Id.u']; continue }
        $px = ToDouble $p['Pos.x']; $py = ToDouble $p['Pos.y']
        foreach ($b in $benches) {
            if ([math]::Abs($px - (ToDouble $b['Pos.x'])) -le 0.75 -and [math]::Abs($py - (ToDouble $b['Pos.y'])) -le 0.75) { $users += $p['Id.u']; break }
        }
    }
    return $users
}

$work = Join-Path $PSScriptRoot '..\results\exercise-grading.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
$retyped = New-NoYardSave $Save $work
$before = ConvertFrom-PrisonSave $work
$t0 = ToDouble $before.TimeIndex
$c0 = Get-ExerciseCounters $before
Write-Host ("edited save: {0} Yard room(s) retyped; clock {1:n0} ({2:00}:{3:00}), {4} prisoners, {5} benches, {6} prisoner(s) already with Exercise credit" -f $retyped, $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), $c0.Count, @(Get-PrisonObjects $before -Type WeightsBench).Count, @($c0.Keys | Where-Object { $c0[$_] -gt 0 }).Count)
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('original', 'fixes') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name "exercise-$sel"
    if (-not $r.Ok) { Write-Host "FAIL exercise-grading ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $after = ConvertFrom-PrisonSave $r.Autosave
    $c1 = Get-ExerciseCounters $after
    $gained = @($c1.Keys | Where-Object { $c0.ContainsKey($_) -and $c1[$_] -gt $c0[$_] })   # prisoners that arrived during the run have no start value
    $users = @{}
    foreach ($snap in (Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)) {
        foreach ($u in (Get-BenchUsers (ConvertFrom-PrisonSave $snap.FullName))) { $users[$u] = $true }
    }
    $gainedUsers = @($gained | Where-Object { $users.ContainsKey($_) })
    $t1 = ToDouble $after.TimeIndex
    Write-Host ("{0}: after {1:n0} game minutes, {2} bench user(s) seen in the snapshots, {3} prisoner(s) gained Exercise ({4} of them bench users); exe {5}; {6}" -f $sel, ($t1 - $t0), $users.Count, $gained.Count, $gainedUsers.Count, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    foreach ($u in $gained) { Write-Host ("  {0}: Exercise {1:n1} -> {2:n1} (bench user: {3})" -f $u, $c0[$u], $c1[$u], $users.ContainsKey($u)) }
    $results[$sel] = [pscustomobject]@{ Gained = $gained.Count; Users = $users.Count; GainedUsers = $gainedUsers.Count }
}

$fail = $false
if ($results.ContainsKey('original') -and $results['original'].Gained -ne 0) { Write-Host "FAIL exercise-grading: the original build credited $($results['original'].Gained) prisoner(s) with Exercise although the Yard was retyped"; $fail = $true }
if ($results.ContainsKey('fixes')) {
    if ($results['fixes'].Users -eq 0) { Write-Host 'FAIL exercise-grading: no prisoner used a bench during the run (scenario did not happen; try a longer run)'; $fail = $true }
    elseif ($results['fixes'].GainedUsers -eq 0) { Write-Host 'FAIL exercise-grading: prisoners used benches but none gained Exercise credit with the fix'; $fail = $true }
}
if ($fail) { exit 1 }
Write-Host ("PASS exercise-grading ({0})" -f (($runs | ForEach-Object { "${_}: $($results[$_].Gained) prisoner(s) gained Exercise, $($results[$_].Users) bench user(s) seen" }) -join ', '))
exit 0
