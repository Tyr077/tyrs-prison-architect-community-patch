<#
  Visitor booths facing up (fix visitor-booth-facing).

  No save on hand has booths, so this test makes one in two stages.

  Stage 1 takes a prison whose Visitation room is a vertical strip with a prison door on the top wall
  and a visitor door on the bottom wall (base3z: room x 254..258, y 139..149), removes the visitor
  tables, puts a row of two VisitorTableSecure booths facing up (prisoner side at the top) across the
  room at y 144..145, and turns the leftover floor tiles of that row into wall so the booths split the
  room. The game recomputes sectors when it loads that, so stage 1 is loaded once (unpatched, a few
  game minutes, before visiting hours) and its autosave becomes the base for stage 2.

  Stage 2 marks the visitor half's sector "Zone VisitorOnly" in that autosave. Now the visitor half
  neither admits prisoners nor is meant for them, which is how a real booth room is zoned and the
  condition the bug needs: unpatched, the pairing check asks for the visitor-side slot and tests
  that tile for the prisoner's sector permission, so no visit is ever set up. With the fix the check
  asks for the prisoner-side slot and visits happen. (Without the zone both builds pair prisoners,
  because the visitor half is reachable region-wise and Shared by default; that was the first
  attempt.)

  The save-visible signal is the prisoner's LastVisitors stamp, written when a visit starts
  (VisitCount only counts finished visits and visitors arrive slowly). Assertion: at least one
  prisoner has LastVisitors inside the run (fixes), none has (original). The stage 2 save starts a
  few game minutes after 06:46; at the defaults (-TimeWarp 1.0, -Speed 3, about 300 game minutes per
  real minute) visiting hours (08:00) begin well within the first real minute after the speed key.

  -DryRun builds stage 1 (and prints the stage 2 save if it exists) without launching the game.
  -Rebuild discards the cached stage 2 save.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\base3z.prison'),
    [ValidateSet('original', 'fixes', 'fixes+tweaks')] [string] $Selection = 'fixes',
    [int] $Autosaves = 6,
    [double] $TimeWarp = 1.0,
    # in-game speed selector after the load: 1 normal, 2 = x2, 3 = x5, 4 = x10 (0 = leave at normal)
    [ValidateRange(0, 4)] [int] $Speed = 3,
    [string] $VisitorZone = 'VisitorOnly',
    [switch] $DryRun,
    [switch] $Rebuild,
    # room geometry (base3z): booth row and the tiles to wall off
    [int] $RowY = 144,
    [int[]] $BoothCentresX = @(255, 257),
    [int[]] $WallX = @(258),
    [int] $RoomTop = 139, [int] $RoomBottom = 149, [int] $RoomLeft = 254, [int] $RoomRight = 258
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

function New-BoothSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    # 1. drop every visitor table
    $tableRx = [regex]'(?m)^    BEGIN "\[i \d+\]"\s+Id\.i \d+\s+Id\.u \d+\s+Type VisitorTable\s[^\r\n]*\r?\n'
    $tables = $tableRx.Matches($t).Count
    if ($tables -eq 0) { throw 'the save has no VisitorTable objects to replace' }
    $t = $tableRx.Replace($t, '')
    # 2. add the booths after the Objects Size line, with fresh index and unique ids
    $m = [regex]::Match($t, '(?m)^ObjectId\.next\s+(\d+)')
    if (-not $m.Success) { throw 'no ObjectId.next in the save header' }
    $nextU = [int]$m.Groups[1].Value
    $o = [regex]::Match($t, '(?m)^BEGIN Objects\s*\r?\n    Size\s+(\d+)\s*\r?\n')
    if (-not $o.Success) { throw 'no Objects block with a Size line' }
    $nextI = [int]$o.Groups[1].Value
    $lines = ''
    foreach ($cx in $BoothCentresX) {
        $lines += ('    BEGIN "[i {0}]"    Id.i {0}  Id.u {1}  Type VisitorTableSecure  SubType 0  Pos.x {2}.0000000  Pos.y {3}.0000000  Or.x 0.0000000  Or.y -1.000000  Powered true  On true  END' -f $nextI, $nextU, $cx, ($RowY + 1)) + $nl
        $nextI++; $nextU++
    }
    $t = $t.Substring(0, $o.Index) + "BEGIN Objects$nl    Size                 $nextI$nl" + $lines + $t.Substring($o.Index + $o.Length)
    $t = [regex]::Replace($t, '(?m)^ObjectId\.next\s+\d+', "ObjectId.next        $nextU", 1)
    # 3. wall off the leftover tiles of the booth row (Cells block entries: 4-space indent, "Mat" first)
    $walled = @()
    foreach ($x in $WallX) {
        foreach ($y in @($RowY, ($RowY + 1))) {
            $key = '{0} {1}' -f $x, $y
            $cellRx = [regex]('(?m)^    BEGIN "' + [regex]::Escape($key) + '"\s+Mat [^\r\n]*')
            $mm = $cellRx.Match($t)
            if (-not $mm.Success) { throw "cell $key not found in the Cells block" }
            $t = $t.Substring(0, $mm.Index) + ('    BEGIN "{0}"    Mat ConcreteWall  Con 100.0000  Ind true  END' -f $key) + $t.Substring($mm.Index + $mm.Length)
            $walled += $key
        }
    }
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Tables = $tables; Walled = $walled }
}

function Add-SectorZone([string] $src, [string] $dst, [int] $left, [int] $top, [int] $right, [int] $bottom, [string] $zone) {
    <# Insert "Zone <zone>" into the sector entry whose rectangle covers exactly (left,top)-(right,bottom).
       Sector entries: 8-space "BEGIN "[i N]"", 12-space fields, "Zone" written only when not Shared. #>
    $t = [IO.File]::ReadAllText($src)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $rx = [regex]('(?s)(        BEGIN "\[i (\d+)\]"\s*\r?\n            id\s+\d+\s*\r?\n            TopLeft\.x\s+' + $left + '\s*\r?\n            TopLeft\.y\s+' + $top + '\s*\r?\n            BottomRight\.x\s+' + $right + '\s*\r?\n            BottomRight\.y\s+' + $bottom + '\s*\r?\n)')
    $m = $rx.Match($t)
    if (-not $m.Success) { throw "no sector with rectangle ($left,$top)-($right,$bottom) in $src" }
    $head = $m.Groups[1].Value
    $rest = $t.Substring($m.Index + $m.Length)
    $endIdx = $rest.IndexOf("$nl        END")
    $entry = $rest.Substring(0, $endIdx)
    if ($entry -match '(?m)^            Zone\s') { $entry = [regex]::Replace($entry, '(?m)^            Zone\s+\S+', "            Zone                 $zone") }
    else { $entry = "            Zone                 $zone  $nl" + $entry }
    $t = $t.Substring(0, $m.Index) + $head + $entry + $rest.Substring($endIdx)
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return [int]$m.Groups[2].Value
}

function Get-VisitedPrisoners($save, [double] $since) {
    Get-PrisonObjects $save -Type Prisoner | Where-Object { $_.Contains('LastVisitors') -and (ToDouble $_['LastVisitors']) -ge $since }
}
function Get-SectorZone($save, [int] $left, [int] $top, [int] $right, [int] $bottom) {
    foreach ($s in (Get-PrisonBlocks $save.Sectors.Sectors)) {
        if ($s.Contains('TopLeft.x') -and [int]$s['TopLeft.x'] -eq $left -and [int]$s['TopLeft.y'] -eq $top -and [int]$s['BottomRight.x'] -eq $right -and [int]$s['BottomRight.y'] -eq $bottom) {
            return ("sector {0}: {1}" -f $s['id'], $(if ($s.Contains('Zone')) { $s['Zone'] } else { 'Shared (default)' }))
        }
    }
    return 'sector not found'
}

$stage1 = Join-Path $PSScriptRoot '..\results\visitor-booth-facing-stage1.prison'
$stage2 = Join-Path $PSScriptRoot '..\results\visitor-booth-facing.prison'
New-Item -ItemType Directory -Force (Split-Path $stage1) | Out-Null
$edit = New-BoothSave $Save $stage1
$s1 = ConvertFrom-PrisonSave $stage1
$t0 = ToDouble $s1.TimeIndex
Write-Host ("stage 1: {0} table(s) removed, {1} booth(s) facing up at y {2}, walled {3}, clock {4:n0} ({5:00}:{6:00})" -f $edit.Tables, @(Get-PrisonObjects $s1 -Type VisitorTableSecure).Count, ($RowY + 1), ($edit.Walled -join ' / '), $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60))
# the visitor half: from the booth row's lower edge to the room's bottom, one tile of wall on each side
$rect = @(($RoomLeft - 1), ($RowY + 1), ($RoomRight + 1), $RoomBottom)

if ($Rebuild -and (Test-Path -LiteralPath $stage2)) { Remove-Item -LiteralPath $stage2 -Force }
if ($DryRun) {
    if (Test-Path -LiteralPath $stage2) { $s2 = ConvertFrom-PrisonSave $stage2; Write-Host ("stage 2 (cached): clock {0:n0}, visitor half {1}" -f (ToDouble $s2.TimeIndex), (Get-SectorZone $s2 $rect[0] $rect[1] $rect[2] $rect[3])) }
    Write-Host "dry run: $stage1"; exit 0
}
if (-not (Test-Path -LiteralPath $stage2)) {
    Write-Host 'stage 2: loading stage 1 once so the game recomputes the sectors ...'
    $r1 = Invoke-InGameRun -Save $stage1 -Selection original -Autosaves 1 -TimeWarp 0.125 -Name 'visitor-booth-stage'
    if (-not $r1.Ok) { Write-Host "FAIL visitor-booth-facing: stage 2 run failed: $($r1.Note)"; exit 1 }
    $sid = Add-SectorZone $r1.Autosave $stage2 $rect[0] $rect[1] $rect[2] $rect[3] $VisitorZone
    Write-Host "stage 2: sector $sid (visitor half) zoned $VisitorZone -> $stage2"
}
$before = ConvertFrom-PrisonSave $stage2
$t0 = ToDouble $before.TimeIndex
$booths = @(Get-PrisonObjects $before -Type VisitorTableSecure)
Write-Host ("test save: clock {0:n0} ({1:00}:{2:00}), booths {3}, visitor half {4}, already-visited stamps since start: {5}" -f $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), $booths.Count, (Get-SectorZone $before $rect[0] $rect[1] $rect[2] $rect[3]), @(Get-VisitedPrisoners $before $t0).Count)

$r = Invoke-InGameRun -Save $stage2 -Selection $Selection -Autosaves $Autosaves -TimeWarp $TimeWarp -Speed $Speed -Name 'visitor-booth'
if (-not $r.Ok) { Write-Host "FAIL visitor-booth-facing: $($r.Note) (results in $($r.ResultDir))"; exit 1 }
$after = ConvertFrom-PrisonSave $r.Autosave
$boothsAfter = @(Get-PrisonObjects $after -Type VisitorTableSecure)
$visited = @(Get-VisitedPrisoners $after $t0)
$records = @(Get-PrisonBlocks $after.Visitation)
$t1 = ToDouble $after.TimeIndex
Write-Host ("after {0:n0} game minutes ({1:00}:{2:00}): booths {3}, visitor half {4}, visit records {5}, visitors in the prison {6}, prisoners visited during the run {7}" -f ($t1 - $t0), [math]::Floor(($t1 % 1440) / 60), [math]::Floor($t1 % 60), $boothsAfter.Count, (Get-SectorZone $after $rect[0] $rect[1] $rect[2] $rect[3]), $records.Count, @(Get-PrisonObjects $after -Type Visitor).Count, $visited.Count)
foreach ($rec in $records) { Write-Host ("  record: state {0}, table {1}, prisoner {2}" -f $rec['State'], $rec['Table.i'], $rec['Prisoner.i']) }
foreach ($p in $visited) { Write-Host ("  visited: {0} {1} at {2:n0}, loaded on {3}" -f $p.Bio.Forname, $p.Bio.Surname, (ToDouble $p['LastVisitors']), $p['CarrierId.i']) }
foreach ($k in $edit.Walled) { $mat = Get-PrisonValue $after 'Cells', $k, 'Mat'; if ($mat -ne 'ConcreteWall') { Write-Host "FAIL visitor-booth-facing: wall at $k did not survive the load ($mat)"; exit 1 } }
Write-Host "exe $($r.ExeSha256.Substring(0, 8)); results $($r.ResultDir)"
if ($boothsAfter.Count -ne $booths.Count) { Write-Host "FAIL visitor-booth-facing: the game kept $($boothsAfter.Count) of $($booths.Count) booths (save edit not accepted)"; exit 1 }

if ($Selection -eq 'original') {
    if ($visited.Count -eq 0) { Write-Host 'PASS visitor-booth-facing (original: no visit started, as expected)'; exit 0 }
    Write-Host "FAIL visitor-booth-facing (original): $($visited.Count) prisoner(s) got a visit, expected none"; exit 1
}
if ($visited.Count -gt 0) { Write-Host "PASS visitor-booth-facing ($($visited.Count) prisoner(s) visited at the up-facing booths)"; exit 0 }
Write-Host 'FAIL visitor-booth-facing: no visit started with the fix'; exit 1
