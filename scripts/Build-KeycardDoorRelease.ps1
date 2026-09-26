<#
  Build-KeycardDoorRelease.ps1
  Writes patches/keycard-door-released-prisoners.patch.json.

  A keycard door (KeycardDoor 0x247, KeycardDoorLarge 0x248) can have prisoner access revoked per door
  ("KeycardDoorAccess" in the save; nav cell byte [0xc]). In CanEnterCell (FUN_14061b6d0) that flag is
  handled as a hard refusal: any entity without the staff key (movement flag bit 2) gets "cannot enter"
  instead of the usual "needs a guard" result that every other locked door produces. A released prisoner
  has no staff key, so when a revoked keycard door is the only way out the route planner finds no route
  at all and the prisoner stands still, still wearing the RELEASED nameplate (the in-game test
  keycard-released-prisoners.ps1 shows them stuck on the original build).

  The movement flags (FUN_140540810) set bit 7, "ignore deployment zones", for a prisoner only when
  Prisoner::IsReleased (FUN_1406afa00) is true, when it is on the escort list (World+0x2CD8), or when
  its record at World+0x2AC0 is in state 5..7 (escorted or misbehaving). Every non-prisoner has bit 7
  too, but also the staff key if it is staff.

  Fix: the staff-key test at the revoked-door check also accepts bit 7. The refusal then only applies to
  prisoners bound by deployment zones, which is what the door option describes ("prisoner access can be
  revoked"). Entities that pass fall into the normal "needs a guard" path, so a guard is sent to open the
  door exactly as for a jail door. Prisoners with a tracking belt are still refused at revoked doors.

  Site 0x14061BD6E:  40 F6 C7 04   test dil, 0x04     (bit 2, staff key)
  New:               40 F6 C7 84   test dil, 0x84     (bit 2 or bit 7)
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/keycard-door-released-prisoners.patch.json')
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

AddEdit 0x14061BD6E (Bytes '40 F6 C7 84') 'CanEnterCell: revoked keycard door also admits released/escorted prisoners (flag bit 7) to the needs-a-guard path'

$expectOrig = @{ 0x14061BD6E = '40F6C704' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'keycard-door-released-prisoners'; name = 'Released prisoners stuck behind revoked keycard doors'; version = '1.0.0'
    description = 'When a keycard door with prisoner access revoked is the only way out, released prisoners call a guard to let them out instead of standing still.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
