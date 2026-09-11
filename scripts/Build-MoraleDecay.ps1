<#
  Build-MoraleDecay.ps1  (optional tweak, requires code-section)
  Writes patches/tweak-staff-death-morale-decay.patch.json.

  Staff morale (Thermometer::UpdateStaffMorale, FUN_14073e580) computes the desired morale as
      100 + happy/staff*50 - unhappy/staff*100 - injured/staff*50 - staffDeaths + (payFactor-1)*100
  where staffDeaths is VictorySystem+0x210 (World+0x2798), incremented in FUN_1407551e0 whenever an entity
  with the staff flag dies, read only there and by the top-bar staff morale tooltip, and not saved.
  Every death costs one morale point for the rest of the session.

  Tweak: the subtraction is routed through a stub in the .tyrs section. The game's counter is left alone;
  the stub keeps its own "forgiven" count in the section and subtracts (deaths - forgiven) instead.
  Forgiven grows by one on each consecutive in-game day (world time at World+0x80 is in minutes; 1440 per
  day) while it is below deaths. A jump of more than one day (first tick after a load, or a different save
  loaded in the same process) only records the day. Forgiven above deaths (a fresh world) resets to zero.
  Hook: 15 bytes at 0x14073E633 (movd/cvtdq2ps/subss) -> jmp stub; stub returns to 0x14073E642.
  Free registers at the hook: rax, r8, r9, xmm0, flags. rdx = World, xmm3 = running desired morale.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/tweak-staff-death-morale-decay.patch.json'),
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
function AddEdit([long]$va, [byte[]]$new, [string]$note) { $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]; $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note }) }

# ---- data: section +0x000 lastDay (int32, 0), +0x004 forgiven (int32, 0), +0x008 double 1440.0 ----
$LASTDAY = $SEC_VA + 0x000; $FORGIVEN = $SEC_VA + 0x004; $K1440 = $SEC_VA + 0x008
AddEdit $LASTDAY (Bytes '00 00 00 00  00 00 00 00  00 00 00 00 00 80 96 40') 'data: lastDay int32 = 0, forgiven int32 = 0, double 1440.0 (minutes per day)'

# ---- code: section +0x100 ----
$STUB = $SEC_VA + 0x100; $HOOK = 0x14073E633; $RET = 0x14073E642
$code = New-Object System.Collections.Generic.List[byte]
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function EmitRip([string]$opcodeHex, [long]$target) { $pre = Bytes $opcodeHex; $next = $STUB + $script:code.Count + $pre.Count + 4; $script:code.AddRange([byte[]]$pre); $script:code.AddRange([byte[]](LE32 ($target - $next))) }
Emit '8B 82 98 27 00 00'            # +00 mov eax,[rdx+0x2798]        deaths (never written by us)
EmitRip '44 8B 0D' $FORGIVEN        # +06 mov r9d,[rip+forgiven]
Emit '44 3B C8'                     # +0D cmp r9d,eax
Emit '7E 0A'                        # +10 jle day (+1C)               forgiven <= deaths: fine
Emit '45 33 C9'                     # +12 xor r9d,r9d                 forgiven > deaths: new world, reset
EmitRip '44 89 0D' $FORGIVEN        # +15 mov [rip+forgiven],r9d
if ($code.Count -ne 0x1C) { throw "day label at $($code.Count), expected 0x1C" }
Emit 'F2 0F 10 82 80 00 00 00'      # +1C day: movsd xmm0,[rdx+0x80]  world time, minutes
EmitRip 'F2 0F 5E 05' $K1440        # +24 divsd xmm0,[rip+K1440]       days
Emit 'F2 44 0F 2C C0'               # +2C cvttsd2si r8d,xmm0           day number
Emit '41 FF C8'                     # +31 dec r8d
EmitRip '44 3B 05' $LASTDAY         # +34 cmp r8d,[rip+lastDay]        ZF = exactly one day since last tick
Emit '45 8D 40 01'                  # +3B lea r8d,[r8+1]               restore day, flags kept
EmitRip '44 89 05' $LASTDAY         # +3F mov [rip+lastDay],r8d        always track the day
Emit '75 0F'                        # +46 jne apply (+57)              same day, first tick, or a jump: no decay
Emit '44 3B C8'                     # +48 cmp r9d,eax
Emit '7D 0A'                        # +4B jge apply (+57)              nothing left to forgive
Emit '41 FF C1'                     # +4D inc r9d                      one death forgiven per day
EmitRip '44 89 0D' $FORGIVEN        # +50 mov [rip+forgiven],r9d
if ($code.Count -ne 0x57) { throw "apply label at $($code.Count), expected 0x57" }
Emit '41 2B C1'                     # +57 apply: sub eax,r9d           deaths - forgiven
Emit 'F3 0F 2A C0'                  # +5A cvtsi2ss xmm0,eax
Emit 'F3 0F 5C D8'                  # +5E subss xmm3,xmm0
EmitRip 'E9' $RET                   # +62 jmp back
AddEdit $STUB ($code.ToArray()) 'stub: subtract (deaths - forgiven) from morale; forgiven grows by one per consecutive in-game day, capped at deaths'

# ---- hook: 15 bytes at 0x14073E633 -> jmp stub + 10-byte NOP ----
$hookBytes = New-Object System.Collections.Generic.List[byte]
$hookBytes.AddRange([byte[]](Bytes 'E9')); $hookBytes.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $hookBytes.AddRange([byte[]](Bytes '0F 1F 84 00 00 00 00 00  66 90'))
AddEdit $HOOK ($hookBytes.ToArray()) 'UpdateStaffMorale: jump to the decay stub instead of subtracting the raw death count'

$expectOrig = @{ $HOOK = '660F6E82982700000F5BC0F30F5CD8' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'tweak-staff-death-morale-decay'; name = 'Staff death morale penalty fades'; version = '1.1.0'; optional = $true
    requires = @('code-section')
    description = 'The staff morale penalty for staff who died on duty normally lasts for the whole session, one point per death. With this tweak it fades by one death per in-game day. The death count itself is untouched, so the "staff have died on duty" line in the staff morale panel still shows the real number. Balance tweak, not a bug fix.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"; Write-Host "wrote $Out ($($edits.Count) edits, stub $($code.Count) bytes)"
