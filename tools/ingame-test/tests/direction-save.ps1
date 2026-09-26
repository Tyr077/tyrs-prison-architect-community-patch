<#
  Prisoner and staff directions survive a save (fix direction-save).

  Direction markings are stored per cell as one-byte fields (PrisonDir, StaffDir). The unpatched save
  writer cannot write one-byte fields: it writes the key with no value, and the loader drops it, so the
  markings are lost on the next load. The loader always accepted numbers, so a save can carry them.

  Save: keycardtest3local.prison. The test writes PrisonDir and StaffDir values into -Cells floor cells
  (MosaicFloor) of the Cells block, runs one autosave on the unpatched game and on the fixes, and counts
  the cells whose PrisonDir and StaffDir come back with the same values in the autosave. Expected: none
  on the original (the keys have no value), all of them with the fixes.
#>
param(
    [string] $Save = (Join-Path $PSScriptRoot '..\..\..\keycardtest3local.prison'),
    [int] $Cells = 20,
    [int] $Autosaves = 1,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 4,
    [ValidateSet('both', 'original', 'fixes')] [string] $Selection = 'both',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')

# cell key "x y" -> "<PrisonDir> <StaffDir>"
function New-DirectionSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $rx = [regex]'(?m)^    BEGIN "(\d+ \d+)"( +)Mat MosaicFloor([^\r\n]*?)END'
    $want = @{}
    $k = 0
    $t = $rx.Replace($t, {
        param($m)
        if ($script:k -ge $Cells) { return $m.Value }
        $script:k++
        $p = ($script:k % 4) + 1
        $s = (($script:k + 1) % 4) + 1
        $want[$m.Groups[1].Value] = "$p $s"
        return ('    BEGIN "{0}"{1}Mat MosaicFloor{2}PrisonDir {3}  StaffDir {4}  END' -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $p, $s)
    })
    if ($want.Count -eq 0) { throw 'no MosaicFloor cells found in the save' }
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return $want
}
function Get-Directions([string] $path, $keys) {
    # read the Cells block lines for the given cells; values are "<PrisonDir> <StaffDir>", or $null when missing
    $found = @{}
    $inCells = $false
    foreach ($line in [IO.File]::ReadLines($path)) {
        if ($line -eq 'BEGIN Cells      ' -or $line -match '^BEGIN Cells\s*$') { $inCells = $true; continue }
        if ($inCells -and $line -match '^END') { break }
        if (-not $inCells) { continue }
        $m = [regex]::Match($line, '^    BEGIN "(\d+ \d+)"')
        if (-not $m.Success -or -not $keys.ContainsKey($m.Groups[1].Value)) { continue }
        $p = [regex]::Match($line, 'PrisonDir\s+(\d+)'); $s = [regex]::Match($line, 'StaffDir\s+(\d+)')
        $found[$m.Groups[1].Value] = if ($p.Success -and $s.Success) { "$($p.Groups[1].Value) $($s.Groups[1].Value)" } else { $null }
    }
    return $found
}

$work = Join-Path $PSScriptRoot '..\results\direction-save.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
$script:k = 0
$want = New-DirectionSave $Save $work
$check = Get-Directions $work $want
$okIn = @($want.Keys | Where-Object { $check[$_] -eq $want[$_] }).Count
Write-Host ("edited save: {0} cell(s) given PrisonDir/StaffDir, {1} read back from the edited file" -f $want.Count, $okIn)
if ($okIn -ne $want.Count) { Write-Host 'FAIL direction-save: the edited save does not carry the values (test bug)'; exit 1 }
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('original', 'fixes') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name "directions-$sel"
    if (-not $r.Ok) { Write-Host "FAIL direction-save ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $got = Get-Directions $r.Autosave $want
    $kept = @($want.Keys | Where-Object { $got[$_] -eq $want[$_] }).Count
    $bare = [regex]::Matches([IO.File]::ReadAllText($r.Autosave), '(?m)PrisonDir\s+(?=\s*(StaffDir|END))').Count
    Write-Host ("{0}: {1} of {2} cells kept both directions; {3} PrisonDir key(s) written without a value; exe {4}; {5}" -f $sel, $kept, $want.Count, $bare, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    $results[$sel] = $kept
}
$fail = $false
if ($results.ContainsKey('fixes') -and $results['fixes'] -ne $want.Count) { Write-Host "FAIL direction-save: with the fixes only $($results['fixes']) of $($want.Count) cells kept their directions"; $fail = $true }
if ($results.ContainsKey('original') -and $results['original'] -ne 0) { Write-Host "NOTE direction-save: the original build kept $($results['original']) cells (expected 0)" }
if ($fail) { exit 1 }
Write-Host ("PASS direction-save ({0})" -f (($runs | ForEach-Object { "$_ kept $($results[$_]) of $($want.Count)" }) -join ', '))
exit 0
