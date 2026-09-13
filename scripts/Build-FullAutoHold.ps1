<#
  Build-FullAutoHold.ps1  (fix, requires code-section)
  Writes patches/full-auto-hold.patch.json.

  Mouse state (DAT_140D57648): +0x14A = left button held (set on WM_LBUTTONDOWN, cleared on
  WM_LBUTTONUP, FUN_14011A760), +0x14D = left button went down this frame (FUN_14011A1C0).

  Warden mode (FUN_140764010, the controlled warden's attack): fires only when +0x14D is set, so
  one click is one shot whatever the weapon. The rate limit is already there - AttackTimer
  (+0x348), set to RechargeTime by FireRangedShot and counted down by the caller.

  Escape Mode (FUN_140552F10): fires on +0x14D, and also on +0x14A when the selected inventory
  item is 0x2D (AssaultRifle). The SubMachineGun (0x2E) and the DLC ModifiedAssaultRifle (0x68)
  were left out, so they only fire per click.

  Fix:
    - Warden mode, hook 0x140764100 (cmp [rax+0x14D],0 / jz no-fire): also fire while the button
      is held, when the warden is in attack mode (+0xA9, the same condition that lets a click
      through without "order failed") and carries an automatic weapon (+0x2F8 = 0x2D, 0x2E or
      0x68).
    - Escape Mode, hook 0x14055308F (cmp item,0x2D / jne): the held-button shot accepts all three
      automatic weapons.

  How fast a held weapon fires is still decided by the weapon's RechargeTime; in Escape Mode that
  needs the weapon fire-rate fix, without which the old two-second reload applies.

  Registers: warden hook - rax = mouse state, rbx = warden controller, rdi = warden entity, rcx
  free; Escape hook - rax = inventory slot array, rcx = slot index, rcx free afterwards.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/full-auto-hold.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $EscAt = 0x880,
    [int] $WarAt = 0x8A0
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

$script:code = $null; $script:base = 0; $script:fix = $null; $script:lbl = $null
function NewBlock([long]$at) { $script:code = New-Object System.Collections.Generic.List[byte]; $script:base = $at; $script:fix = New-Object System.Collections.Generic.List[object]; $script:lbl = @{} }
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function Label([string]$name) { $script:lbl[$name] = $script:code.Count }
function Ref8([string]$op, [string]$name) { Emit $op; $script:fix.Add(@($script:code.Count, 1, $name)); $script:code.Add(0) }
function Ref32([string]$op, $target) { Emit $op; $script:fix.Add(@($script:code.Count, 4, $target)); for ($i = 0; $i -lt 4; $i++) { $script:code.Add(0) } }
function CloseBlock() {
    foreach ($f in $script:fix) {
        $at = $f[0]; $size = $f[1]; $t = $f[2]
        if ($t -is [string]) { if (-not $script:lbl.ContainsKey($t)) { throw "undefined label $t" }; $dest = $script:base + $script:lbl[$t] } else { $dest = [long]$t }
        $d = $dest - ($script:base + $at + $size)
        if ($size -eq 1) { if ($d -lt -128 -or $d -gt 127) { throw "short reference to $t out of range ($d)" }; $script:code[$at] = [byte]($d -band 0xFF) }
        else { $lb = [BitConverter]::GetBytes([int32]$d); for ($i = 0; $i -lt 4; $i++) { $script:code[$at + $i] = $lb[$i] } }
    }
    return $script:code.ToArray()
}
function JmpHook([long]$hook, [long]$stub, [int]$len) {
    $h = New-Object System.Collections.Generic.List[byte]
    $h.AddRange([byte[]](Bytes 'E9')); $h.AddRange([byte[]](LE32 ($stub - ($hook + 5))))
    for ($i = 5; $i -lt $len; $i++) { $h.Add(0x90) }
    return $h.ToArray()
}

$ESC_HOOK = 0x14055308F; $ESC_FIRE = 0x140553095; $ESC_SKIP = 0x1405530A0
$WAR_HOOK = 0x140764100; $WAR_FIRE = 0x14076410D; $WAR_SKIP = 0x1407643E2
$ESC = $SEC_VA + $EscAt
$WAR = $SEC_VA + $WarAt

# ---- Escape Mode: held button fires any of the three automatic weapons ----
NewBlock $ESC
Emit '8B 0C 88'                           # mov ecx,[rax+rcx*4]           selected item
Emit '83 F9 2D'; Ref8 '74' 'fire'         # AssaultRifle
Emit '83 F9 2E'; Ref8 '74' 'fire'         # SubMachineGun
Emit '83 F9 68'; Ref8 '74' 'fire'         # ModifiedAssaultRifle
Ref32 'E9' $ESC_SKIP
Label 'fire'
Ref32 'E9' $ESC_FIRE
$escBytes = CloseBlock
AddEdit $ESC $escBytes 'Escape Mode: holding the button fires the AssaultRifle, SubMachineGun and ModifiedAssaultRifle'
AddEdit $ESC_HOOK (JmpHook $ESC_HOOK $ESC 6) 'EscapeMode update: held-button weapon check routed through the stub'

# ---- Warden mode: held button fires an automatic weapon ----
NewBlock $WAR
Emit '80 B8 4D 01 00 00 00'               # cmp byte [rax+0x14d],0        clicked this frame?
Ref32 '0F 85' $WAR_FIRE
Emit '80 B8 4A 01 00 00 00'               # cmp byte [rax+0x14a],0        held?
Ref32 '0F 84' $WAR_SKIP
Emit '80 BB A9 00 00 00 00'               # cmp byte [rbx+0xa9],0         in attack mode?
Ref32 '0F 84' $WAR_SKIP
Emit '8B 8F F8 02 00 00'                  # mov ecx,[rdi+0x2f8]           carried weapon
Emit '83 F9 2D'; Ref32 '0F 84' $WAR_FIRE
Emit '83 F9 2E'; Ref32 '0F 84' $WAR_FIRE
Emit '83 F9 68'; Ref32 '0F 84' $WAR_FIRE
Ref32 'E9' $WAR_SKIP
$warBytes = CloseBlock
AddEdit $WAR $warBytes 'Warden mode: holding the button in attack mode keeps firing an automatic weapon'
AddEdit $WAR_HOOK (JmpHook $WAR_HOOK $WAR 13) 'warden attack: click check routed through the stub'

if ($EscAt + $escBytes.Length -gt $WarAt) { throw 'escape stub runs into the warden stub' }
$expectOrig = @{ $ESC_HOOK = '833C882D750B'; $WAR_HOOK = '80B84D010000000F84D5020000' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'full-auto-hold'; name = 'Hold to fire automatic weapons'; version = '1.0.0'
    requires = @('code-section')
    description = 'Assault rifles and SMGs fire while the mouse button is held, in Warden Mode and Escape Mode. Warden Mode fired one shot per click whatever the weapon, and Escape Mode only let the assault rifle keep firing, not the SMG or the modified assault rifle. The rate of fire still comes from each weapon; in Escape Mode it needs the ranged weapon fire-rate fix to be faster than one shot every two seconds.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; escape {1} bytes at +0x{2:X}, warden {3} bytes at +0x{4:X})" -f $edits.Count, $escBytes.Length, $EscAt, $warBytes.Length, $WarAt)
