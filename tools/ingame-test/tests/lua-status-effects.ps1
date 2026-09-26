<#
  Scripted status effects (fix lua-status-effects).

  A Lua script that sets prisoner.StatusEffects.<name> only stored the charge; the effect never became
  active, so it did nothing and was not written to the save. The fix activates it the way the game does.

  Save: base3z.prison. The test places -Testers Status Effect Tester objects (tools/testmods/
  lua-status-effects-test, which sets StatusEffects.tazed = 60 on every prisoner within five tiles every
  four game minutes) on the tiles of the first prisoners in the save, runs the unpatched game and the
  fixes, and counts the prisoners whose save carries an active tazed effect in any autosave. Expected:
  none on the original, several with the fixes.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\base3z.prison'),
    [int] $Testers = 6,
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
$ModDir = Join-Path $PSScriptRoot '..\..\testmods\lua-status-effects-test'

function New-TesterSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $nl = "`r`n"
    $pos = [regex]::Matches($t, '(?s)Type\s+Prisoner\s*\r?\n\s+SubType\s+\S+\s*\r?\n\s+Pos\.x\s+([\d.]+)\s*\r?\n\s+Pos\.y\s+([\d.]+)')
    if ($pos.Count -eq 0) { throw 'no prisoners in the save' }
    $n = [regex]::Match($t, '(?m)^ObjectId\.next\s+(\d+)')
    $nextU = [int]$n.Groups[1].Value
    $o = [regex]::Match($t, '(?m)^BEGIN Objects\s*\r?\n    Size\s+(\d+)\s*\r?\n')
    $nextI = [int]$o.Groups[1].Value
    $lines = ''
    $placed = 0
    foreach ($m in $pos) {
        if ($placed -ge $Testers) { break }
        $x = [math]::Floor([double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)) + 0.5
        $y = [math]::Floor([double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)) + 0.5
        $lines += ('    BEGIN "[i {0}]"    Id.i {0}  Id.u {1}  Type StatusEffectTester  SubType 0  Pos.x {2:0.0000000}  Pos.y {3:0.0000000}  END' -f ($nextI + $placed), ($nextU + $placed), $x, $y) + $nl
        $placed++
    }
    $t = $t.Substring(0, $o.Index) + "BEGIN Objects$nl    Size                 $($nextI + $placed)$nl" + $lines + $t.Substring($o.Index + $o.Length)
    $t = [regex]::Replace($t, '(?m)^ObjectId\.next\s+\d+', "ObjectId.next        $($nextU + $placed)", 1)
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return $placed
}
function Get-Tazed($save) {
    @(Get-PrisonObjects $save -Type Prisoner | Where-Object { $_.Contains('StatusEffects') -and $_.StatusEffects.Contains('tazed') } | ForEach-Object { $_['Id.u'] })
}

$work = Join-Path $PSScriptRoot '..\results\lua-status-effects.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
$placed = New-TesterSave $Save $work
$before = ConvertFrom-PrisonSave $work
$t0 = ToDouble $before.TimeIndex
Write-Host ("edited save: {0} Status Effect Tester object(s) on prisoner tiles; clock {1:n0} ({2:00}:{3:00}); tazed now: {4}" -f $placed, $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), (Get-Tazed $before).Count)
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('original', 'fixes') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Mod $ModDir -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name "status-$sel"
    if (-not $r.Ok) { Write-Host "FAIL lua-status-effects ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $seen = @{}
    $line = @()
    foreach ($snap in (Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)) {
        $ids = Get-Tazed (ConvertFrom-PrisonSave $snap.FullName)
        $ids | ForEach-Object { $seen[$_] = $true }
        $line += "$($snap.BaseName): $($ids.Count) tazed"
    }
    Write-Host ("{0}: {1} prisoner(s) with an active tazed effect in some autosave ({2}); exe {3}; {4}" -f $sel, $seen.Count, ($line -join ', '), $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    $results[$sel] = $seen.Count
}
$fail = $false
if ($results.ContainsKey('original') -and $results['original'] -ne 0) { Write-Host "FAIL lua-status-effects: the original build saved $($results['original']) tazed prisoner(s) (expected 0)"; $fail = $true }
if ($results.ContainsKey('fixes') -and $results['fixes'] -lt 1) { Write-Host 'FAIL lua-status-effects: no prisoner was tazed by the script with the fixes'; $fail = $true }
if ($fail) { exit 1 }
Write-Host ("PASS lua-status-effects ({0})" -f (($runs | ForEach-Object { "$_ $($results[$_]) tazed" }) -join ', '))
exit 0
