<#
  Build-VisitorDoor.ps1
  Writes patches/visitor-door-access.patch.json.

  Door::Open (FUN_140526a90, called only from Entity::TryPassThroughDoor FUN_140533ff0) decides who may
  open a door. For the visitor-door class (VisitorDoor 0x2B, FenceGateVisitor 0x18, DoubleVisitorDoor
  0x1A9, or any door whose definition has access class 2) it refuses every entity that is not in a
  hard-coded allow list, not a staff type and not under an escape/override flag. The list misses
  several later entity types: RehabilitatedPrisoner (0x1C2), AnimalTherapist (0x1BF), FireSafetyTeacher (0x1FD)
  and EntityDeliveryMan (0x20E) are missing, among others.

  The movement-flag function (FUN_140540810) grants visitor-door access (bit 27) to every non-prisoner
  unconditionally, so TryPassThroughDoor believes those entities can open the door themselves and never
  requests a guard. Result, as reported on the community Discord: they stand at the door. Double
  visitor doors take a branch in TryPassThroughDoor that requires a different bit, so a guard is
  requested (the report says they get through there). Not yet reproduced by the in-game harness.

  Fix: replace the allow-list test with "refuse only prisoners (0x6D)", which is exactly the rule the
  movement flags already use. Staff, visitors, the override flags and prisoners behave as before.

  Original at 0x140526DBA:  8D 41 96      lea eax,[rcx-0x6a]
                             83 F8 18      cmp eax,0x18
                             77 0A         ja  0x140526DCC
  New:                       83 F9 6D      cmp ecx,0x6d          (ecx = entity type)
                             75 4F         jnz 0x140526E0E       (not a prisoner: allowed)
                             EB 0B         jmp 0x140526DCC       (prisoner: continue the original checks)
                             90            nop
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/visitor-door-access.patch.json')
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

$SITE = 0x140526DBA; $ALLOWED = 0x140526E0E; $CONTINUE = 0x140526DCC
$new = New-Object System.Collections.Generic.List[byte]
$new.AddRange([byte[]](Bytes '83 F9 6D'))                                  # cmp ecx,0x6d
$new.AddRange([byte[]](Bytes '75')); $new.Add([byte]($ALLOWED - ($SITE + 5)))   # jnz allowed
$new.AddRange([byte[]](Bytes 'EB')); $new.Add([byte]($CONTINUE - ($SITE + 7)))  # jmp continue
$new.Add([byte]0x90)
if ($new.Count -ne 8) { throw "expected 8 bytes, got $($new.Count)" }
AddEdit $SITE ($new.ToArray()) 'Door::Open visitor-door class: refuse only prisoners instead of an allow list that misses several NPC types'

$expectOrig = @{ $SITE = '8D419683F818770A' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'visitor-door-access'; name = 'Visitors and civilians stuck at visitor doors'; version = '1.0.0'
    description = 'Mentors, therapists and other visitors no longer wait forever at visitor doors and gates. Prisoners still cannot open them.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
