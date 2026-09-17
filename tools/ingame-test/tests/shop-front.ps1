<#
  Shops usable from outside the shop (fix shop-front).

  Save: base3z.prison has a Shop room (x 231..240, y 155..159) whose shop front sits in the bottom
  wall and faces a hallway; the only door is on the top wall. The room's sector is Shared, so today
  every prisoner can walk in and the shop trades. The shop is staffed by prisoners of the prison's own
  labour allocation (MinSec prisoners stand behind the counter from about 13:00), so the shop cannot
  simply be zoned StaffOnly: that starves it of shopkeepers and nothing sells on any build (first
  attempt). Instead the test builds the layout the bug reports describe: a shop zoned for one
  category that serves other categories through the hatch.

  Edits: the shop's sector gets Zone MinSecOnly, and every MinSec prisoner except KeepMinSec of them
  is recategorised Normal (no sector in this prison is category-restricted apart from the shop, so
  they lose nothing). The remaining MinSec prisoners staff the shop and may buy; the Normal majority
  can only buy over the counter, which unpatched fails: the Shopping provider's standing position is
  the shop front's own wall tile inside the Shop room, and a Normal prisoner is not allowed in there.

  Signals, compared between the unpatched and the fixed build on the same edited save over a full
  day: the Finance block's DailyShopRevenue, the shelves' Stock, and Shopping actions in the Needs
  blocks of the autosave snapshots, by category. Expected: the original never shows a non-MinSec
  shopper; the fixed build does, and its revenue is above the original's. Shopping in this prison
  starts around 13:00, so the run covers twelve autosaves from 06:46.
#>
param(
    [string] $Save = (Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves\base3z.prison'),
    [int] $Autosaves = 12,
    [double] $TimeWarp = 1.25,
    [ValidateSet('both', 'original', 'fixes')] [string] $Selection = 'both',
    [switch] $DryRun,
    # the shop's sector rectangle in the Sectors block (base3z), the zone, and how many MinSec to keep
    [int[]] $Rect = @(230, 155, 240, 159),
    [string] $ShopZone = 'MinSecOnly',
    [int] $KeepMinSec = 5
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')

function New-ShopSave([string] $src, [string] $dst) {
    $t = [IO.File]::ReadAllText($src)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    # 1. zone the shop's sector (geometry unchanged, so the line survives the load)
    $rx = [regex]('(?s)(        BEGIN "\[i (\d+)\]"\s*\r?\n            id\s+\d+\s*\r?\n            TopLeft\.x\s+' + $Rect[0] + '\s*\r?\n            TopLeft\.y\s+' + $Rect[1] + '\s*\r?\n            BottomRight\.x\s+' + $Rect[2] + '\s*\r?\n            BottomRight\.y\s+' + $Rect[3] + '\s*\r?\n)')
    $m = $rx.Match($t)
    if (-not $m.Success) { throw "no sector with rectangle ($($Rect -join ',')) in $src" }
    $rest = $t.Substring($m.Index + $m.Length)
    $endIdx = $rest.IndexOf("$nl        END")
    $entry = $rest.Substring(0, $endIdx)
    if ($entry -match '(?m)^            Zone\s') { $entry = [regex]::Replace($entry, '(?m)^            Zone\s+\S+', "            Zone                 $ShopZone") }
    else { $entry = "            Zone                 $ShopZone  $nl" + $entry }
    $t = $t.Substring(0, $m.Index) + $m.Groups[1].Value + $entry + $rest.Substring($endIdx)
    $sid = [int]$m.Groups[2].Value
    # 2. recategorise all but KeepMinSec of the MinSec prisoners as Normal (prisoner blocks only: 8-space Category)
    $catRx = [regex]'(?m)^        Category\s+MinSec\s*$'
    $seen = 0
    $t = $catRx.Replace($t, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $script:seen++; if ($script:seen -le $KeepMinSec) { $mm.Value } else { '        Category             Normal  ' } })
    [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Sector = $sid; MinSecBefore = $script:seen; Recategorised = [math]::Max(0, $script:seen - $KeepMinSec) }
}
function Get-ShopState($save) {
    $shelves = @(Get-PrisonObjects $save -Type ShopShelf)
    $stock = 0; foreach ($s in $shelves) { if ($s.Contains('Stock')) { $stock += ToInt $s['Stock'] } }
    [pscustomobject]@{
        Revenue = ToDouble (Get-PrisonValue $save 'Finance', 'DailyShopRevenue')
        Stock = $stock; Shelves = $shelves.Count
    }
}
function Get-Shoppers($save) {
    Get-PrisonObjects $save -Type Prisoner | Where-Object { (Get-PrisonValue $_ 'Needs', 'Action') -eq 'Shopping' } | ForEach-Object { [pscustomobject]@{ Id = $_['Id.u']; Category = $_['Category'] } }
}
function Get-SectorZone($save) {
    foreach ($s in (Get-PrisonBlocks $save.Sectors.Sectors)) {
        if ($s.Contains('TopLeft.x') -and [int]$s['TopLeft.x'] -eq $Rect[0] -and [int]$s['TopLeft.y'] -eq $Rect[1] -and [int]$s['BottomRight.x'] -eq $Rect[2] -and [int]$s['BottomRight.y'] -eq $Rect[3]) {
            return $(if ($s.Contains('Zone')) { $s['Zone'] } else { 'Shared (default)' })
        }
    }
    return 'sector not found'
}

$work = Join-Path $PSScriptRoot '..\results\shop-front.prison'
New-Item -ItemType Directory -Force (Split-Path $work) | Out-Null
$edit = New-ShopSave $Save $work
$before = ConvertFrom-PrisonSave $work
$t0 = ToDouble $before.TimeIndex
$s0 = Get-ShopState $before
$cats = (Get-PrisonObjects $before -Type Prisoner | Group-Object { $_['Category'] } | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
Write-Host ("edited save: shop sector {0} zoned {1}, {2} of {3} MinSec recategorised Normal ({4}); clock {5:n0} ({6:00}:{7:00}); revenue today {8}, stock {9} on {10} shelves" -f $edit.Sector, $ShopZone, $edit.Recategorised, $edit.MinSecBefore, $cats, $t0, [math]::Floor(($t0 % 1440) / 60), [math]::Floor($t0 % 60), $s0.Revenue, $s0.Stock, $s0.Shelves)
if ($DryRun) { Write-Host "dry run: $work"; exit 0 }

$results = @{}
$runs = if ($Selection -eq 'both') { @('original', 'fixes') } else { @($Selection) }
foreach ($sel in $runs) {
    $r = Invoke-InGameRun -Save $work -Selection $sel -Autosaves $Autosaves -TimeWarp $TimeWarp -Name "shop-$sel"
    if (-not $r.Ok) { Write-Host "FAIL shop-front ($sel): $($r.Note) (results in $($r.ResultDir))"; exit 1 }
    $after = ConvertFrom-PrisonSave $r.Autosave
    $s1 = Get-ShopState $after
    $shoppers = @{}
    foreach ($snap in (Get-ChildItem (Join-Path $r.ResultDir 'autosave-*.prison') | Sort-Object Name)) {
        foreach ($sh in (Get-Shoppers (ConvertFrom-PrisonSave $snap.FullName))) { $shoppers[$sh.Id] = $sh.Category }
    }
    $nonMin = @($shoppers.Keys | Where-Object { $shoppers[$_] -ne 'MinSec' })
    $t1 = ToDouble $after.TimeIndex
    Write-Host ("{0}: after {1:n0} game minutes ({2:00}:{3:00}): shop zone {4}; revenue today {5}, stock {6} -> {7}; shoppers seen in snapshots: {8} ({9} not MinSec); exe {10}; {11}" -f $sel, ($t1 - $t0), [math]::Floor(($t1 % 1440) / 60), [math]::Floor($t1 % 60), (Get-SectorZone $after), $s1.Revenue, $s0.Stock, $s1.Stock, $shoppers.Count, $nonMin.Count, $r.ExeSha256.Substring(0, 8), $r.ResultDir)
    foreach ($k in $shoppers.Keys) { Write-Host "  shopper $k ($($shoppers[$k]))" }
    $results[$sel] = [pscustomobject]@{ Revenue = $s1.Revenue; Stock = $s1.Stock; Shoppers = $shoppers.Count; NonMinSec = $nonMin.Count }
}

$fail = $false
if ($results.ContainsKey('original') -and $results['original'].NonMinSec -gt 0) { Write-Host "FAIL shop-front: the original build let $($results['original'].NonMinSec) non-MinSec prisoner(s) shop at a MinSec-only shop (scenario does not reproduce the bug)"; $fail = $true }
if ($results.ContainsKey('fixes')) {
    $sold = ($results['fixes'].Revenue -gt 0) -or ($results['fixes'].Stock -lt $s0.Stock)
    if (-not $sold) { Write-Host 'FAIL shop-front: nothing was sold with the fix (is the shop staffed? see the snapshots)'; $fail = $true }
    elseif ($results['fixes'].NonMinSec -eq 0 -and $results.ContainsKey('original') -and $results['fixes'].Revenue -le $results['original'].Revenue) { Write-Host 'FAIL shop-front: with the fix no non-MinSec shopper was seen and revenue is not above the original'; $fail = $true }
}
if ($fail) { exit 1 }
Write-Host ("PASS shop-front ({0})" -f (($runs | ForEach-Object { "$_ revenue $($results[$_].Revenue), stock $($results[$_].Stock), non-MinSec shoppers $($results[$_].NonMinSec)" }) -join '; '))
exit 0
