<#
  Smoke test: the harness can load a save into the scratch game, the clock advances, and the
  autosave parses. Run from anywhere:  powershell -File tools\ingame-test\tests\load-smoke.ps1
#>
param(
    [string] $Save = (Join-Path $PSScriptRoot '..\..\..\keycardtest3local.prison'),
    [ValidateSet('original', 'fixes', 'fixes+tweaks')] [string] $Selection = 'fixes',
    [int] $Autosaves = 1,
    [double] $TimeWarp = 1.25
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

$before = ConvertFrom-PrisonSave $Save
$r = Invoke-InGameRun -Save $Save -Selection $Selection -Autosaves $Autosaves -TimeWarp $TimeWarp -Name 'load-smoke'
if (-not $r.Ok) { Write-Host "FAIL load-smoke: $($r.Note) (results in $($r.ResultDir))"; exit 1 }
$after = ConvertFrom-PrisonSave $r.Autosave
$t0 = ToDouble $before.TimeIndex; $t1 = ToDouble $after.TimeIndex
Write-Host ("game clock {0:n1} -> {1:n1} min ({2:n1} game minutes in {3:n0} s wall clock)" -f $t0, $t1, ($t1 - $t0), ($r.Ended - $r.LoadedAt).TotalSeconds)
Get-PrisonSummary $after | Format-List | Out-String | Write-Host
if ($t1 -le $t0) { Write-Host 'FAIL load-smoke: game clock did not advance'; exit 1 }
Write-Host "PASS load-smoke (exe $($r.ExeSha256.Substring(0,8)), $($r.ResultDir))"
exit 0
