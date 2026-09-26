<#
  Released prisoners behind a revoked keycard door (fix keycard-door-released-prisoners).
  Save: keycardtest3local.prison holds two prisoners whose sentence is fully served (Served >= SentenceF)
  and who, unpatched, stay behind a revoked keycard door for the whole run. With the fix they call a guard,
  walk out and are removed from the prison.

  Assertion: after the run, every prisoner that had served its sentence at the start is either gone
  from the save or has moved more than MinMove tiles from where it started. With -Selection original
  the test expects the opposite (they are still there and have not moved), so both directions of the
  fix can be checked.
#>
param(
    [string] $Save = (Join-Path $PSScriptRoot '..\..\..\keycardtest3local.prison'),
    [ValidateSet('original', 'fixes', 'fixes+tweaks')] [string] $Selection = 'fixes',
    [int] $Autosaves = 4,
    [double] $MinMove = 3.0,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 3
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

function Get-ServedPrisoners($save) {
    Get-PrisonObjects $save -Type Prisoner | Where-Object {
        $_.Contains('Bio') -and $_.Bio.Contains('Served') -and $_.Bio.Contains('SentenceF') -and
        (ToDouble $_.Bio.Served) -ge (ToDouble $_.Bio.SentenceF)
    }
}

$before = ConvertFrom-PrisonSave $Save
$served = @(Get-ServedPrisoners $before)
if ($served.Count -eq 0) { Write-Host 'FAIL keycard-released-prisoners: the save has no prisoner with a served sentence'; exit 1 }
Write-Host ("start: {0} served prisoner(s): {1}" -f $served.Count, (($served | ForEach-Object { "$($_['Id.i']) $($_.Bio.Forname) $($_.Bio.Surname) @ $($_['Pos.x']),$($_['Pos.y'])" }) -join '; '))

$r = Invoke-InGameRun -Save $Save -Selection $Selection -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name 'keycard-released'
if (-not $r.Ok) { Write-Host "FAIL keycard-released-prisoners: $($r.Note) (results in $($r.ResultDir))"; exit 1 }
$after = ConvertFrom-PrisonSave $r.Autosave
$afterById = @{}
foreach ($p in (Get-PrisonObjects $after -Type Prisoner)) { $afterById[$p['Id.u']] = $p }

$released = 0; $stuck = 0
foreach ($p in $served) {
    $id = $p['Id.u']; $q = $afterById[$id]
    if ($null -eq $q) { Write-Host "  $($p.Bio.Forname) $($p.Bio.Surname): gone from the prison"; $released++; continue }
    $dx = (ToDouble $q['Pos.x']) - (ToDouble $p['Pos.x']); $dy = (ToDouble $q['Pos.y']) - (ToDouble $p['Pos.y'])
    $d = [math]::Sqrt($dx * $dx + $dy * $dy)
    if ($d -gt $MinMove) { Write-Host ("  {0} {1}: moved {2:n1} tiles (still in the prison)" -f $p.Bio.Forname, $p.Bio.Surname, $d); $released++ }
    else { Write-Host ("  {0} {1}: still within {2:n1} tiles of the start" -f $p.Bio.Forname, $p.Bio.Surname, $d); $stuck++ }
}
$t0 = ToDouble $before.TimeIndex; $t1 = ToDouble $after.TimeIndex
Write-Host ("game clock advanced {0:n1} minutes; exe {1}; results {2}" -f ($t1 - $t0), $r.ExeSha256.Substring(0, 8), $r.ResultDir)

if ($Selection -eq 'original') {
    if ($stuck -eq $served.Count) { Write-Host 'PASS keycard-released-prisoners (original: prisoners stay stuck, as expected)'; exit 0 }
    Write-Host "FAIL keycard-released-prisoners (original): $released of $($served.Count) got out, expected none"; exit 1
}
if ($stuck -eq 0) { Write-Host "PASS keycard-released-prisoners ($released of $($served.Count) got out)"; exit 0 }
Write-Host "FAIL keycard-released-prisoners: $stuck of $($served.Count) still stuck"; exit 1
