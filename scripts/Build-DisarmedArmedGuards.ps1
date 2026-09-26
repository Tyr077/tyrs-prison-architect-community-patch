<#
  Build-DisarmedArmedGuards.ps1  (fix, requires code-section)
  Writes patches/disarmed-armed-guards.patch.json.

  GetEquipmentDef (FUN_140536CB0) decides which weapon an entity fights with. For an ArmedGuard
  (type 0x6B) it asks "is the weapon drawn" (FUN_1405D6A80: WeaponDrawn timer +0xBFC > 0; the
  armed guard's update FUN_1404882B0 sets it to 5 s while Freefire applies and the guard has a
  target, and its damage handler FUN_140488500 sets it when it is attacked at 60% damage or more).
  If drawn, it returns the definition of the carried item (+0x2F8); if not, Fists (definition 1).

  It never checks that the guard still carries anything. A disarmed armed guard has item 0 (None),
  which has no Equipment entry and is not a ranged weapon, so while WeaponDrawn runs the guard
  attacks with an empty hand. (At 70% damage a guard is incapacitated, FUN_1405434D0, so the damage
  window is 60-70%.) Out of combat a disarmed armed guard goes to the nearest Armoury for its
  Shotgun (FUN_1405DCA00); this fix only covers the fighting in between.

  Fix: at that one call site, "weapon drawn" is only true when the guard carries an item; a
  disarmed armed guard gets Fists, the same as with the weapon holstered. The predicate itself and
  its other callers (surrender checks, weapon drawing) are unchanged.

  The hook replaces `mov rcx,rdi / call FUN_1405D6A80` (8 bytes at 0x140536DF3) with a call to
  the stub and three NOPs; the stub returns to the `test al,al` that follows.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/disarmed-armed-guards.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $StubAt = 0x7D0
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$orig = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($orig)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
function LE32([long]$v) { [BitConverter]::GetBytes([int32]$v) }

$sec = Get-Content -LiteralPath $SectionPatch -Raw | ConvertFrom-Json
$b = New-Object byte[] ($orig.Length + 0x1000); [Array]::Copy($orig, $b, $orig.Length)
foreach ($e in $sec.edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $b[$e.offset + $i] = $nb[$i] } }

$SEC_VA = 0x140E89000; $SEC_RAW = 0xDC1C00
function VaToFile([long]$va) { if ($va -ge $SEC_VA) { return [int]($va - $SEC_VA + $SEC_RAW) }; return [int]($va - 0x140000C00) }
$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) {
    $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]
    $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}

$HOOK    = 0x140536DF3    # mov rcx,rdi / call FUN_1405D6A80  (ArmedGuard branch of GetEquipmentDef)
$DRAWN   = 0x1405D6A80
$STUB    = $SEC_VA + $StubAt

$s = New-Object System.Collections.Generic.List[byte]
$s.AddRange([byte[]](Bytes '48 8B CF'))                   # mov rcx,rdi
$s.AddRange([byte[]](Bytes '83 BF F8 02 00 00 00'))       # cmp dword [rdi+0x2f8],0       carries nothing?
$s.AddRange([byte[]](Bytes '0F 85')); $s.AddRange([byte[]](LE32 ($DRAWN - ($STUB + $s.Count + 4))))   # jne FUN_1405D6A80 (tail call)
$s.AddRange([byte[]](Bytes '32 C0'))                      # xor al,al                     not drawn: Fists
$s.AddRange([byte[]](Bytes 'C3'))                         # ret
$stubBytes = $s.ToArray()
AddEdit $STUB $stubBytes 'ArmedGuard weapon choice: a guard carrying nothing counts as not drawn (Fists)'

$h = New-Object System.Collections.Generic.List[byte]
$h.AddRange([byte[]](Bytes 'E8')); $h.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $h.AddRange([byte[]](Bytes '90 90 90'))
AddEdit $HOOK $h.ToArray() 'GetEquipmentDef: weapon-drawn check for armed guards routed through the stub'

$expectOrig = @{ $HOOK = '488BCFE885FC0900' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'disarmed-armed-guards'; name = 'Disarmed armed guards can fight'; version = '1.0.0'
    requires = @('code-section')
    description = 'Armed guards who lose their shotgun fight with their fists while Freefire is on or when badly hurt, instead of not fighting back.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; stub {1} bytes at +0x{2:X})" -f $edits.Count, $stubBytes.Length, $StubAt)
