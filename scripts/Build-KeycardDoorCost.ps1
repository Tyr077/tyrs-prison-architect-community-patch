<#
  Build-KeycardDoorCost.ps1
  Writes patches/keycard-door-path-cost.patch.json.

  CanEnterCell (FUN_14061b6d0) is the per-cell cost/permission test used by the A* router. For a cell
  holding a door it decides whether the entity can open the door itself (from its movement flags) and,
  if not, marks the step "needs a guard" and multiplies the cost by 10. Every locked door type works
  that way, except keycard doors (KeycardDoor 0x247, KeycardDoorLarge 0x248): those ALSO add a flat
  penalty of 1000 (DAT_140B1BE84, the same constant used for swimming across water) to every entity
  without movement flag bit 39 (tracking belt), staff with the staff key included. A guard therefore sees a keycard
  door as roughly a thousand tiles of walking and detours around it whenever any other route exists.

  Fix: NOP the addition, so keycard doors cost the same as jail doors for the router: entities with the
  staff key pass at normal cost, everyone else gets the usual "needs a guard" x10 cost. The 1000
  constant itself is untouched (swimming and the "recently stuck at a door" penalty still use it).

  Site 0x14061BD82:  F3 0F 58 C5   addss xmm0, xmm5   (xmm5 = 1000.0)
  New:               0F 1F 40 00   nop dword [rax+0]
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/keycard-door-path-cost.patch.json')
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$b = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }
function VaToFile([long]$va) { return [int]($va - 0x140000C00) }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) { $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]; $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note }) }

AddEdit 0x14061BD82 (Bytes '0F 1F 40 00') 'CanEnterCell: drop the flat 1000 route penalty for keycard doors'

$expectOrig = @{ 0x14061BD82 = 'F30F58C5' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'keycard-door-path-cost'; name = 'Staff detour around keycard doors'; version = '1.0.0'
    description = 'Staff go through keycard doors instead of taking long detours around them.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
