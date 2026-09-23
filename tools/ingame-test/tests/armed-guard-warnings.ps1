<#
  Armed guard warnings with Staff Needs (optional tweak tweak-armed-guard-warnings).

  Save: RIOT(ROCKHARD).prison, a riot in progress with 28 rioting prisoners and six active armed
  guards, Staff Needs on. The test edits the save so staff morale is low: StaffPayModifier 0 (the pay
  factor in the staff morale formula) and StaffMorale 10 in the Thermometer block, which the game then
  keeps around 25-30% because desired morale is computed from pay, happy, unhappy and injured staff.

  Mechanism under test: a guard's warning chance is multiplied by StaffMorale/100 when Staff Needs is
  on (unpatched), so at ~27% morale an armed guard warns about a fifth as often as it should. A
  warning from an armed guard almost always ends in surrender and gives the prisoner the
  "surrendered" status effect; the other ways to get that effect need Freefire or a soldier, neither
  present here. So the count of prisoners carrying "surrendered" is the save-visible signal.

  The test runs the fixes alone and the fixes plus tweaks on the same edited save (not the unpatched
  build: the gunfire-surrender fix also makes prisoners surrender, so both runs must have it) and compares the
  highest number of prisoners with "surrendered" seen in any autosave. Expected: clearly more with
  the tweak. Thresholds: tweaked >= MinFixed and tweaked > fixes alone.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\RIOT(ROCKHARD).prison'),
    [int] $Autosaves = 4,
    [double] $TimeWarp = 1.25,
    [int] $MinFixed = 3,
    [ValidateSet('both', 'fixes', 'fixes+tweaks')] [string] $Selection = 'both',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

function New-LowMoraleSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $m = [regex]::Match($t, '(?m)^(    StaffPayModifier\s+)\S+')
    if (-not $m.Success) { throw 'no StaffPayModifier in the save' }
    $t = $t.Substring(0, $m.Index) + $m.Groups[1].Value + '0.0000000' + $t.Substring($m.Index + $m.Length)
    $th = [regex]::Match($t, '(?m)^BEGIN Thermometer\s*\r?\n')
    if (-not $th.Success) { throw 'no Thermometer block' }
    if ($t -match '(?m)^    StaffMorale\s') { $t = [regex]::Replace($t, '(?m)^    StaffMorale\s+\S+', '    StaffMorale          10.00000') }
    else { $t = $t.Substring(0, $th.Index + $th.Length) + "    StaffMorale          10.00000  $nl" + $t.Substring($th.Index + $th.Length) }
    if ($t -notmatch '(?m)^StaffNeeds\s+true') { throw 'the save does not have StaffNeeds on' }
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
}
function Count-Surrendered($save) {
    @(Get-PrisonObjects $save -Type Prisoner | Where-Object { $_.Contains('StatusEffects') -and $_.StatusEffects.Contains('surrendered') }).Count
}

$work = Join-Path $PSScriptRoot '..\results\armed-guard-warnings.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
New-LowMoraleSave $Save $work
$before = ConvertFrom-PrisonSave $work
$t0 = ToDouble $before.TimeIndex
Write-Host ("edited save: clock {0:n0} ({1:00}:{2:00}), {3} prisoners, {4} armed guards, rioting {5}, StaffMorale {6}, StaffPayModifier {7}, surrendered now: {8}" -f $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), @(Get-PrisonObjects $before -Type Prisoner).Count, @(Get-PrisonObjects $before -Type ArmedGuard).Count, $before.Thermometer['RiotingPrisoners'], $before.Thermometer['StaffMorale'], (Get-PrisonValue $before 'Finance', 'StaffPayModifier'), (Count-Surrendered $before))
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('fixes', 'fixes+tweaks') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Autosaves $Autosaves -TimeWarp $TimeWarp -Name "warnings-$sel"
    if (-not $r.Ok) { Write-Host "FAIL armed-guard-warnings ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $peak = 0; $line = @()
    foreach ($snap in (Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)) {
        $s = ConvertFrom-PrisonSave $snap.FullName
        $n = Count-Surrendered $s
        $line += ("{0}: {1} surrendered, morale {2}, rioting {3}" -f $snap.BaseName, $n, $s.Thermometer['StaffMorale'], $s.Thermometer['RiotingPrisoners'])
        if ($n -gt $peak) { $peak = $n }
    }
    Write-Host ("{0}: peak {1} prisoner(s) with the surrendered effect; exe {2}; {3}" -f $sel, $peak, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    $line | ForEach-Object { Write-Host "  $_" }
    $results[$sel] = $peak
}

if ($results.ContainsKey('fixes+tweaks') -and $results['fixes+tweaks'] -lt $MinFixed) { Write-Host "FAIL armed-guard-warnings: only $($results['fixes+tweaks']) surrendered with the tweak (expected at least $MinFixed)"; exit 1 }
if ($results.ContainsKey('fixes') -and $results.ContainsKey('fixes+tweaks') -and $results['fixes+tweaks'] -le $results['fixes']) { Write-Host "FAIL armed-guard-warnings: with the tweak $($results['fixes+tweaks']) is not above the fixes alone $($results['fixes'])"; exit 1 }
Write-Host ("PASS armed-guard-warnings ({0})" -f (($runs | ForEach-Object { "$_ peak $($results[$_])" }) -join ', '))
exit 0
