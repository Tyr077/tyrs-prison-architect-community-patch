<#
  Build-ExerciseGrading.ps1  (fix, requires code-section)
  Writes patches/exercise-grading.patch.json.

  A prisoner's Health grade on the Grading tab scores "% of stay exercising", one point per 5%. The
  time behind it is one of 28 counters in the prisoner's Experience object (Prisoner+0xE60, counter
  array at +0x10, names and timeline colours in DAT_140de0da0). Experience::Tick (FUN_1405889d0, run
  from FUN_140588150 every 15 in-game seconds) credits exactly one counter per tick, chosen from the
  prisoner's current ActionType at Prisoner+0xDE0: 0xB Work keeps slot 7, 0xE ReformProgram gives slot
  9 (Class), 8 Exercise gives slot 8 (Exercise), anything else gives slot 10 (Freetime) or 5 (Regime).

  Only one need provider in the whole game has ActionType Exercise: the Yard room. Every piece of
  exercise equipment - weights bench, treadmill, punch bag, gym mat, dumbbell rack, tyre apparatus,
  training dummy, pull-up bar - declares "PrimaryNeed Exercise" with "ActionType Use" in needs.txt and
  needs_dlc.txt. So a prisoner who works out on equipment satisfies the Exercise need but is credited
  to Freetime or Regime, and an indoor gym can never score the Health grade's exercise criterion. Only
  jogging laps in a yard counts. A poor Health grade adds up to +25% re-offending chance.

  Fix: the ActionType 8 test (9 bytes at 0x140588B23) jumps to a stub in .tyrs that keeps the original
  test and adds one more: ActionType 1 (Use) also counts as exercise when the provider the prisoner is
  using declares PrimaryNeed Exercise. The provider comes from NeedSystem.Target (Prisoner+0xDE4,
  resolved by FUN_14065f6d0 against the list at World+0x1b60); its def index at +0x08 indexes the def
  table at World+0x1ba8 (0x80 stride, count World+0x1bb4), where +0x40 is PrimaryNeed and 7 is
  Exercise. Data-driven, so DLC and modded equipment are covered without naming any object.

  The test stays keyed on ActionType Use on purpose: three DLC providers pair PrimaryNeed Exercise
  with ActionType Work, and those must keep crediting the Work counter.

  Registers at the hook: eax = ActionType, r9 = prisoner, r8 = App, edi = counter slot (7 so far),
  esi = regime slot, rbx = Experience. r8 is volatile and is read again at the return point, so the
  stub reloads it from the App global after the call. rbx/rsi/rdi/xmm6/xmm7/xmm8 are non-volatile and
  survive the call. The frame is "push rbx; sub rsp,0x50", so rsp is 16-byte aligned here and the call
  gets its shadow space from a further "sub rsp,0x20".
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/exercise-grading.patch.json'),
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

$APP       = 0x140D57900     # global: pointer to the App object; World = *(App+0x198)
$FIND_PROV = 0x14065F6D0     # ActiveNeedProvider* FindById(list, int* idPair) - pure lookup, no side effects
$STUB      = $SEC_VA + 0x1D0
$HOOK      = 0x140588B23     # cmp eax,8 / jne +4 / mov edi,eax / jmp -> 9 bytes
$RET_EX    = 0x140588B66     # shared tail that adds the tick to counters[edi]
$RET_FALL  = 0x140588B2C     # the regime/freetime branch

# ---- code: section +0x1D0 ----
$code = New-Object System.Collections.Generic.List[byte]
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function EmitRip([string]$opcodeHex, [long]$target) { $pre = Bytes $opcodeHex; $next = $STUB + $script:code.Count + $pre.Count + 4; $script:code.AddRange([byte[]]$pre); $script:code.AddRange([byte[]](LE32 ($target - $next))) }
Emit '83 F8 08'                     # +00 cmp eax,8                     ActionType Exercise (jogging)
Emit '74 60'                        # +03 je  exercise (+65)
Emit '83 F8 01'                     # +05 cmp eax,1                     ActionType Use
Emit '75 65'                        # +08 jne fall (+6F)
EmitRip '48 8B 0D' $APP             # +0A mov rcx,[rip+App]
Emit '48 8B 89 98 01 00 00'         # +11 mov rcx,[rcx+0x198]           World
Emit '48 81 C1 60 1B 00 00'         # +18 add rcx,0x1B60                active need provider list
Emit '49 8D 91 E4 0D 00 00'         # +1F lea rdx,[r9+0xDE4]            &NeedSystem.Target (.u, .i)
Emit '48 83 EC 20'                  # +26 sub rsp,0x20                  shadow space, rsp stays aligned
EmitRip 'E8' $FIND_PROV             # +2A call FindById
Emit '48 83 C4 20'                  # +2F add rsp,0x20
EmitRip '4C 8B 05' $APP             # +33 mov r8,[rip+App]              r8 is volatile; the tail reads it
Emit '48 85 C0'                     # +3A test rax,rax
Emit '74 30'                        # +3D jz  fall (+6F)                no provider (stale target)
Emit '8B 48 08'                     # +3F mov ecx,[rax+8]               provider def index
Emit '49 8B 90 98 01 00 00'         # +42 mov rdx,[r8+0x198]            World
Emit '3B 8A B4 1B 00 00'            # +49 cmp ecx,[rdx+0x1BB4]          def count; unsigned, so < 0 fails too
Emit '73 1E'                        # +4F jae fall (+6F)
Emit '48 63 C9'                     # +51 movsxd rcx,ecx
Emit '48 C1 E1 07'                  # +54 shl rcx,7                     * 0x80 stride
Emit '48 03 8A A8 1B 00 00'         # +58 add rcx,[rdx+0x1BA8]          provider def
Emit '83 79 40 07'                  # +5F cmp dword ptr [rcx+0x40],7    PrimaryNeed == Exercise
Emit '75 0A'                        # +63 jne fall (+6F)
if ($code.Count -ne 0x65) { throw "exercise label at 0x$('{0:X}' -f $code.Count), expected 0x65" }
Emit 'BF 08 00 00 00'               # +65 exercise: mov edi,8           counter slot 8 (Exercise)
EmitRip 'E9' $RET_EX                # +6A jmp back to the shared tail
if ($code.Count -ne 0x6F) { throw "fall label at 0x$('{0:X}' -f $code.Count), expected 0x6F" }
EmitRip 'E9' $RET_FALL              # +6F fall: jmp back to the regime/freetime branch
AddEdit $STUB ($code.ToArray()) 'stub: count ActionType Use against the Exercise counter when the provider in use serves the Exercise need'

# ---- hook: 9 bytes at 0x140588B23 -> jmp stub + 4-byte NOP ----
$hookBytes = New-Object System.Collections.Generic.List[byte]
$hookBytes.AddRange([byte[]](Bytes 'E9')); $hookBytes.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $hookBytes.AddRange([byte[]](Bytes '0F 1F 40 00'))
AddEdit $HOOK ($hookBytes.ToArray()) 'Experience tick: ask the stub which actions count as exercise'

$expectOrig = @{ $HOOK = '83F8087504 8BF8 EB3A' -replace '\s','' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'exercise-grading'; name = 'Exercise on equipment counts for grading'; version = '1.0.0'
    requires = @('code-section')
    description = 'Time a prisoner spends on gym and yard equipment now counts towards the "% of stay exercising" line of their Health grade. The game only ever credited jogging laps around a yard, because that is the one activity tagged as the Exercise action; weights benches, treadmills, punch bags, gym mats and the rest are tagged as "use an object" and were credited to free time instead. A prison whose prisoners exercise indoors could not score that part of the Health grade at all, which also raised their re-offending chance.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"; Write-Host "wrote $Out ($($edits.Count) edits, stub $($code.Count) bytes)"
