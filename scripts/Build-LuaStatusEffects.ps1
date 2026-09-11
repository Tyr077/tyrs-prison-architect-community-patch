<#
  Build-LuaStatusEffects.ps1  (fix, requires code-section)
  Writes patches/lua-status-effects.patch.json.

  Alpha 28 let mods script a prisoner's status effects ("this.StatusEffects.suppressed = 1"). The Lua
  table is built by StatusEffectSystem::RegisterLua (FUN_14072d040): one C getter (FUN_14072da00) and one
  C setter (FUN_14072dc60) per effect name, behind an __index/__newindex metatable. The setter writes the
  effect's charge float into the system (Prisoner+0x3C8, slots of 0x38 bytes) and stops there.

  A later update added an "active" bitset to the system (+0x620, mirrored to +0x628 for the save file).
  The per-tick decay (FUN_14072c5f0), IsActive (FUN_14072c7a0, used by the nameplate, AI and UI) and the
  save writer (FUN_14072cf90) all iterate or test that bitset, and the game's own Add/Set (FUN_14072c7f0,
  FUN_14072c930) set the bit and stamp the apply time. The Lua setter was never updated, so a charge set
  from Lua is invisible: never active, never decayed, never saved. The getter still reads it back.

  Fix: the setter's index/store sequence (11 bytes at 0x14072DE0D: cdqe / imul rcx,rax,0x38 /
  movss [rcx+rdi],xmm6) jumps to a stub in .tyrs that stores the charge, stamps the slot's apply time
  with the world clock (World+0x80, as FUN_14072c930 does), sets the active bit when the value is > 0 or
  clears it otherwise, and copies the bitset to the +0x628 mirror. Returns to 0x14072DE18.
  Registers at the hook: eax = effect index (>= 0), rdi = StatusEffectSystem, xmm6 = value as float,
  rbx = lua_State, rbp = Lua nil object, rsi = 0. rcx, rdx, r8, xmm0 and flags are free (recomputed or
  unused after the return point).
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/lua-status-effects.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json')
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$orig = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($orig)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
function LE32([long]$v) { [BitConverter]::GetBytes([int32]$v) }

# Base image = original + code-section patch applied.
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

$APP = 0x140D57900                      # global: pointer to the App object; World = *(App+0x198); world clock double at World+0x80
$STUB = $SEC_VA + 0x170; $HOOK = 0x14072DE0D; $RET = 0x14072DE18

# ---- code: section +0x170 ----
$code = New-Object System.Collections.Generic.List[byte]
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function EmitRip([string]$opcodeHex, [long]$target) { $pre = Bytes $opcodeHex; $next = $STUB + $script:code.Count + $pre.Count + 4; $script:code.AddRange([byte[]]$pre); $script:code.AddRange([byte[]](LE32 ($target - $next))) }
Emit '48 98'                        # +00 cdqe                          rax = effect index
Emit '4C 6B C0 38'                  # +02 imul r8,rax,0x38
Emit '4C 03 C7'                     # +06 add r8,rdi                    r8 = slot
Emit 'F3 41 0F 11 30'               # +09 movss [r8],xmm6               slot.charge = value (the original store)
EmitRip '48 8B 15' $APP             # +0E mov rdx,[rip+App]
Emit '48 8B 92 98 01 00 00'         # +15 mov rdx,[rdx+0x198]           World
Emit '48 8B 92 80 00 00 00'         # +1C mov rdx,[rdx+0x80]            world clock (double)
Emit '49 89 50 28'                  # +23 mov [r8+0x28],rdx             slot.lastApplied = now
Emit '8B C8'                        # +27 mov ecx,eax
Emit 'BA 01 00 00 00'               # +29 mov edx,1
Emit 'D3 E2'                        # +2E shl edx,cl                    bit for this effect
Emit '0F 57 C0'                     # +30 xorps xmm0,xmm0
Emit '0F 2F F0'                     # +33 comiss xmm6,xmm0
Emit '77 0A'                        # +36 ja set (+42)                  value > 0: activate
Emit 'F7 D2'                        # +38 not edx
Emit '21 97 20 06 00 00'            # +3A and [rdi+0x620],edx           value <= 0 (or NaN): deactivate
Emit 'EB 06'                        # +40 jmp mirror (+48)
if ($code.Count -ne 0x42) { throw "set label at $($code.Count), expected 0x42" }
Emit '09 97 20 06 00 00'            # +42 set: or [rdi+0x620],edx
if ($code.Count -ne 0x48) { throw "mirror label at $($code.Count), expected 0x48" }
Emit '8B 97 20 06 00 00'            # +48 mirror: mov edx,[rdi+0x620]
Emit '48 89 97 28 06 00 00'         # +4E mov [rdi+0x628],rdx           saved copy of the bitset (zero-extended)
EmitRip 'E9' $RET                   # +55 jmp back
AddEdit $STUB ($code.ToArray()) 'stub: store the charge, stamp the apply time, set (value > 0) or clear the active bit, mirror the bitset'

# ---- hook: 11 bytes at 0x14072DE0D -> jmp stub + 6-byte NOP ----
$hookBytes = New-Object System.Collections.Generic.List[byte]
$hookBytes.AddRange([byte[]](Bytes 'E9')); $hookBytes.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $hookBytes.AddRange([byte[]](Bytes '66 0F 1F 44 00 00'))
AddEdit $HOOK ($hookBytes.ToArray()) 'StatusEffects Lua setter: jump to the stub instead of storing the charge alone'

$expectOrig = @{ $HOOK = '4898486BC838F30F113439' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'lua-status-effects'; name = 'Lua StatusEffects assignment'; version = '1.0.0'
    requires = @('code-section')
    description = 'Restores the modding feature from Alpha 28 that lets a Lua script set a prisoner''s status effects ("prisoner.StatusEffects.tazed = 60"). A later update made the game track active effects in a separate flag set and forgot to update the Lua setter, so scripted effects were written but never took effect. The setter now activates (or, for 0, clears) the effect the same way the game does. Used by mods such as Less Lethal Expansion.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"; Write-Host "wrote $Out ($($edits.Count) edits, stub $($code.Count) bytes)"
