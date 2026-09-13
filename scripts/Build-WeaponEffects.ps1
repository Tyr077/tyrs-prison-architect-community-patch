<#
  Build-WeaponEffects.ps1  (fix, requires code-section)
  Writes patches/weapon-effects.patch.json.

  The game still contains a complete weapon-fire routine (FUN_1401AC610, reached only through
  script command 0x3B, which nothing queues any more). Besides the bullet tracer it spawns:
    - for the Shotgun: five smoke puffs (FUN_1403F6C70) and fifteen tracers spread over a disc
      of radius distance*0.1 around the aim point - the buckshot;
    - for the AssaultRifle and SubMachineGun: a muzzle flash (FUN_1403F7130) at the barrel, and
      it plays their Attack_ sound (a multi-round burst sample) at most every 0.5 s, keeping the
      time in Entity+0x340.
  The routine every shooter actually uses, FireRangedShot (FUN_140537930), spawns one tracer
  and plays Attack_ on every shot. So muzzle flashes, smoke and buckshot never appear, and
  automatic weapons play one burst sample per round.

  Fix, two hooks in FireRangedShot:
    1. 0x140537C80 (lea rcx,[rbx+0x48] / call tracer): the stub spawns the tracer as before,
       then the extra effects for the weapon. Weapons are recognised by their definition
       pointer (r15 = EquipmentDef, 0x90 stride from [0x140DECCC0]): Shotgun 0x20,
       AssaultRifle 0x2D, SubMachineGun 0x2E, and also ModifiedAssaultRifle 0x68, the DLC
       automatic rifle the old routine predates.
    2. 0x140537B32 (the start of the Attack_ sound block): for the automatic rifles the sound is
       skipped when the last one played less than 0.5 s ago, exactly as the old routine did.
       Entity+0x340 is zeroed by the Entity constructor and used by nothing else.

  Frame at both hooks: rbx = shooter, r15 = weapon definition, rbp = frame base, rsp % 16 == 0.
  [rbp+0x67] holds the aim point. rsi, rdi and r14 are pushed by the prologue and not read again
  after the hooks, so the stubs use them freely; xmm6+ and r12/r13 are left alone. The scratch
  vectors live in the function's own string locals, which are finished with by then.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/weapon-effects.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $FxAt = 0x530,
    [int] $SndAt = 0x710
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

# --- tiny assembler: bytes, 8/32-bit references to labels or absolute addresses ---
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

$APP       = 0x140D57900
$EQUIP     = 0x140DECCC0   # EquipmentDef array pointer, 0x90 stride
$ADDPART   = 0x1403F1DF0   # ParticleSystem::Add(system, particle, 1)
$TRACER    = 0x1403F6990   # bullet tracer (from, to)
$SMOKE     = 0x1403F6C70   # smoke puff (from, towards)
$FLASH     = 0x1403F7130   # muzzle flash (at, facing)
$ROTATE    = 0x14011FF20   # rotate vec3 in place about axis (vec*, axis*, angle xmm2)
$RNG       = 0x140D2CA58   # random generator object; [vtable+0x10] = next
$RNGMAX    = 0x140D2CA60
$NOW       = 0x14011D620   # clock, double seconds
$ATTACKSTR = 0x140ABAF98   # "Attack_"
$FX_HOOK   = 0x140537C80; $FX_RESUME  = 0x140537CA9
$SND_HOOK  = 0x140537B32; $SND_RESUME = 0x140537B3C; $SND_SKIP = 0x140537C68
$FX  = $SEC_VA + $FxAt
$SND = $SEC_VA + $SndAt

function EmitAddParticle {
    Emit '48 8B D0'                       # mov rdx,rax
    Ref32 '48 8B 05' $APP                 # mov rax,[App]
    Emit '48 8B 88 98 01 00 00'           # mov rcx,[rax+0x198]      World
    Emit '48 81 C1 E8 0D 00 00'           # add rcx,0xde8            particle system
    Emit '41 B0 01'                       # mov r8b,1
    Ref32 'E8' $ADDPART
}
function EmitClassify([string]$shotgunLabel, [string]$autoLabel) {
    Ref32 '48 8B 05' $EQUIP               # mov rax,[EquipmentDefs]
    Emit '49 8B CF'                       # mov rcx,r15
    Emit '48 2B C8'                       # sub rcx,rax
    if ($shotgunLabel) { Emit '48 81 F9 00 12 00 00'; Ref32 '0F 84' $shotgunLabel }   # Shotgun 0x20
    Emit '48 81 F9 50 19 00 00'; Ref32 '0F 84' $autoLabel   # AssaultRifle 0x2D
    Emit '48 81 F9 E0 19 00 00'; Ref32 '0F 84' $autoLabel   # SubMachineGun 0x2E
    Emit '48 81 F9 80 3A 00 00'; Ref32 '0F 84' $autoLabel   # ModifiedAssaultRifle 0x68
}

# ---- effects stub ----
NewBlock $FX
Emit '48 8D 4B 48'                        # lea rcx,[rbx+0x48]       the replaced instructions:
Ref32 'E8' $TRACER                        # call tracer              rdx = aim point, set before the hook
EmitAddParticle
EmitClassify 'shotgun' 'auto'
Ref32 'E9' $FX_RESUME
Label 'auto'
Emit '48 8D 53 54'                        # lea rdx,[rbx+0x54]       facing
Emit '48 8D 4B 48'                        # lea rcx,[rbx+0x48]
Ref32 'E8' $FLASH
EmitAddParticle
Ref32 'E9' $FX_RESUME
Label 'shotgun'
Emit 'F3 0F 10 45 67'                     # movss xmm0,[rbp+0x67]    aim x
Emit 'F3 0F 5C 43 48'                     # subss xmm0,[rbx+0x48]
Emit 'F3 0F 10 4D 6B'                     # movss xmm1,[rbp+0x6b]    aim y
Emit 'F3 0F 5C 4B 4C'                     # subss xmm1,[rbx+0x4c]
Emit 'F3 0F 59 C0'                        # mulss xmm0,xmm0
Emit 'F3 0F 59 C9'                        # mulss xmm1,xmm1
Emit 'F3 0F 58 C1'                        # addss xmm0,xmm1
Emit 'F3 0F 51 C0'                        # sqrtss xmm0,xmm0         distance
Ref32 'F3 0F 59 05' 'tenth'               # mulss xmm0,[0.1]
Emit 'F3 0F 11 45 E7'                     # movss [rbp-0x19],xmm0    spread radius
Emit 'BE 13 00 00 00'                     # mov esi,19               5 smoke puffs, then 14 more tracers
Label 'loop'
Ref32 '48 8D 0D' $RNG                     # lea rcx,[rng]
Ref32 '48 8B 05' $RNG                     # mov rax,[rng]
Emit 'FF 50 10'                           # call [rax+0x10]
Emit '8B C0'                              # mov eax,eax
Emit '0F 57 D2'                           # xorps xmm2,xmm2
Emit 'F3 48 0F 2A D0'                     # cvtsi2ss xmm2,rax
Ref32 '8B 05' $RNGMAX                     # mov eax,[rngmax]
Emit '0F 57 C0'                           # xorps xmm0,xmm0
Emit 'F3 48 0F 2A C0'                     # cvtsi2ss xmm0,rax
Emit 'F3 0F 5E D0'                        # divss xmm2,xmm0
Ref32 'F3 0F 59 15' 'twopi'               # mulss xmm2,[2pi]         random angle
Emit 'C7 45 A7 00 00 80 3F'               # vec  = (1,0,0) at [rbp-0x59]
Emit 'C7 45 AB 00 00 00 00'
Emit 'C7 45 AF 00 00 00 00'
Emit 'C7 45 B7 00 00 00 00'               # axis = (0,0,1) at [rbp-0x49]
Emit 'C7 45 BB 00 00 00 00'
Emit 'C7 45 BF 00 00 80 3F'
Emit '48 8D 55 B7'                        # lea rdx,[rbp-0x49]
Emit '48 8D 4D A7'                        # lea rcx,[rbp-0x59]
Ref32 'E8' $ROTATE
Emit 'F3 0F 10 45 A7'                     # movss xmm0,[rbp-0x59]    x
Emit 'F3 0F 10 4D AB'                     # movss xmm1,[rbp-0x55]    y
Emit '0F 28 D0'                           # movaps xmm2,xmm0
Emit 'F3 0F 59 D0'                        # mulss xmm2,xmm0
Emit '0F 28 D9'                           # movaps xmm3,xmm1
Emit 'F3 0F 59 D9'                        # mulss xmm3,xmm1
Emit 'F3 0F 58 D3'                        # addss xmm2,xmm3
Emit 'F3 0F 51 D2'                        # sqrtss xmm2,xmm2
Emit 'F3 0F 10 5D E7'                     # movss xmm3,[rbp-0x19]
Emit 'F3 0F 5E DA'                        # divss xmm3,xmm2          radius / length
Emit 'F3 0F 59 C3'                        # mulss xmm0,xmm3
Emit 'F3 0F 59 CB'                        # mulss xmm1,xmm3
Emit 'F3 0F 58 45 67'                     # addss xmm0,[rbp+0x67]
Emit 'F3 0F 58 4D 6B'                     # addss xmm1,[rbp+0x6b]
Emit 'F3 0F 11 45 D7'                     # movss [rbp-0x29],xmm0    point on the spread disc
Emit 'F3 0F 11 4D DB'                     # movss [rbp-0x25],xmm1
Emit '48 8D 55 D7'                        # lea rdx,[rbp-0x29]
Emit '48 8D 4B 48'                        # lea rcx,[rbx+0x48]
Emit '83 FE 0E'                           # cmp esi,14
Ref8 '7E' 'tracer'                        # jle tracer
Ref32 'E8' $SMOKE
Ref8 'EB' 'add'
Label 'tracer'
Ref32 'E8' $TRACER
Label 'add'
EmitAddParticle
Emit 'FF CE'                              # dec esi
Ref32 '0F 85' 'loop'
Ref32 'E9' $FX_RESUME
Label 'tenth'; Emit 'CD CC CC 3D'         # 0.1f
Label 'twopi'; Emit 'DB 0F C9 40'         # 6.2831855f
$fxBytes = CloseBlock
if ($FxAt + $fxBytes.Length -gt $SndAt) { throw ("effects stub ({0} bytes) runs into the sound stub" -f $fxBytes.Length) }
AddEdit $FX $fxBytes 'FireRangedShot effects: tracer, then muzzle flash (automatic rifles) or smoke and buckshot (shotgun)'
AddEdit $FX_HOOK (JmpHook $FX_HOOK $FX 9) 'FireRangedShot: tracer spawn routed through the effects stub'

# ---- sound stub ----
NewBlock $SND
EmitClassify $null 'auto'
Ref8 'EB' 'play'
Label 'auto'
Ref32 'E8' $NOW                           # xmm0 = now
Emit '0F 28 C8'                           # movaps xmm1,xmm0
Emit 'F2 0F 5C 8B 40 03 00 00'            # subsd xmm1,[rbx+0x340]   time since the last burst sound
Ref32 '66 0F 2F 0D' 'half'                # comisd xmm1,[0.5]
Ref32 '0F 82' $SND_SKIP                   # jb  skip the sound
Emit 'F2 0F 11 83 40 03 00 00'            # movsd [rbx+0x340],xmm0
Label 'play'
Emit '4D 8B C7'                           # mov r8,r15               the replaced instructions
Ref32 '48 8D 15' $ATTACKSTR               # lea rdx,["Attack_"]
Ref32 'E9' $SND_RESUME
Label 'half'; Emit '00 00 00 00 00 00 E0 3F'
$sndBytes = CloseBlock
AddEdit $SND $sndBytes 'FireRangedShot sound: automatic rifles play their burst sample at most every 0.5 s'
AddEdit $SND_HOOK (JmpHook $SND_HOOK $SND 10) 'FireRangedShot: Attack_ sound routed through the sound stub'

$expectOrig = @{ $FX_HOOK = '488D4B48E807EDEBFF'; $SND_HOOK = '4D8BC7488D155C345800' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'weapon-effects'; name = 'Muzzle flash, smoke and buckshot'; version = '1.0.0'
    requires = @('code-section')
    description = 'Guns show their effects again. The game still has the old firing code that draws a muzzle flash for assault rifles and SMGs and smoke plus a spread of buckshot for the shotgun, but every shot now goes through a newer routine that only draws a single tracer. The effects are added back to that routine. Automatic rifles also play their burst sound at most twice a second again, as the old code did, instead of one full burst per round.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; effects {1} bytes at +0x{2:X}, sound {3} bytes at +0x{4:X})" -f $edits.Count, $fxBytes.Length, $FxAt, $sndBytes.Length, $SndAt)
