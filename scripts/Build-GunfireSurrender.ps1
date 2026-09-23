<#
  Build-GunfireSurrender.ps1  (fix, requires code-section)
  Writes patches/gunfire-surrender.patch.json.

  In the 2018 build of the game, Entity::FireRangedShot ends with this, for every shot fired by
  anyone but a prisoner with anything but the Tazer:

      list = prisoners within 4 tiles of the aim point  +  prisoners within 4 tiles of the shooter
      up to 10 times: take a random prisoner out of the list and call its OnAttackedBy(shooter)

  OnAttackedBy is the handler a prisoner runs when it is hit. Against an armed guard with its weapon
  drawn, a soldier or a sniper it rolls for surrender (certain for a prisoner who is not misbehaving,
  less likely for the tough, fearless and so on); a prisoner who does not surrender may turn on the
  shooter. This is the rule the wiki describes: "Prisoners might surrender if an armed guard is
  shooting within 4 squares distance. A maximum of 10 prisoners will surrender per gun shot."

  The final build's FireRangedShot (FUN_140537930) has lost the whole block, so only the prisoner
  who is actually hit reacts. Everything the block used is still in the game with the same
  signatures:
      FUN_1407C1B40(World, int x, int y, float radius, list*, int type, char flag)   objects in range
      FUN_1407BADC0(World, id*)                                                      entity by id
      Prisoner vtable +0x190                                                         OnAttackedBy
  The list is { id pairs*, int capacity, int count }, zeroed by the caller, grown by the range
  function and freed by the caller (FUN_1408252F0).

  Fix: hook the last two instructions before the epilogue (0x140537CCF, AttackTimer = RechargeTime)
  and run the 2018 block after them. One difference: 2018 called through the resolved entity
  without testing it; the stub skips an id that no longer resolves.

  Frame at the hook: rbx = shooter, r15 = EquipmentDef, rbp = frame base, rsp % 16 == 0 with the
  function's own 0xC0 bytes below rbp+0x37; the aim point is the function's second argument, home
  [rbp+0x77] (x) and [rbp+0x7b] (y). rsi, rdi and r14 were pushed by the prologue and are popped
  right after, so the stub uses them. The list lives in the string locals at [rbp-0x29], which are
  finished with by then and clear of the outgoing argument slots [rsp+0x20..0x37] (rbp = rsp+0x89).
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/gunfire-surrender.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $StubAt = 0x970
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$orig = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($orig)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { throw "Unexpected build hash $sha (is the 2018 beta installed without a Sunset .orig next to it?)" }
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

$APP     = 0x140D57900
$EQUIP   = 0x140DECCC0   # EquipmentDef array pointer, 0x90 stride
$RANGE   = 0x1407C1B40   # objects of a type within a radius
$RESOLVE = 0x1407BADC0   # entity by id pair
$FREE    = 0x1408252F0
$RNG     = 0x140D2CA58   # random generator object; [vtable+0x10] = next
$HOOK    = 0x140537CCF   # mov eax,[r15+0x50] / mov [rbx+0x348],eax   (10 bytes)
$RESUME  = 0x140537CD9   # mov al,1 and the epilogue
$STUB    = $SEC_VA + $StubAt

function EmitRangeCall([string]$loadX, [string]$loadY) {
    Ref32 '48 8B 05' $APP                 # mov rax,[App]
    Emit '48 8B 88 98 01 00 00'           # mov rcx,[rax+0x198]      World
    Emit $loadX                           # cvttss2si edx, x
    Emit $loadY                           # cvttss2si r8d, y
    Ref32 'F3 0F 10 1D' 'four'            # movss xmm3,[4.0]         radius
    Emit '48 8D 45 D7'                    # lea rax,[rbp-0x29]
    Emit '48 89 44 24 20'                 # mov [rsp+0x20],rax       list
    Emit 'C7 44 24 28 6D 00 00 00'        # mov dword [rsp+0x28],0x6D   Prisoner
    Emit 'C7 44 24 30 01 00 00 00'        # mov dword [rsp+0x30],1
    Ref32 'E8' $RANGE
}

NewBlock $STUB
Emit '41 8B 47 50'                        # mov eax,[r15+0x50]       the replaced instructions:
Emit '89 83 48 03 00 00'                  # mov [rbx+0x348],eax      AttackTimer = RechargeTime
Emit '83 7B 40 6D'                        # cmp dword [rbx+0x40],0x6D   a prisoner's shot scares nobody
Ref32 '0F 84' 'done'
Ref32 '48 8B 05' $EQUIP                   # mov rax,[EquipmentDefs]
Emit '48 05 D0 14 00 00'                  # add rax,0x25*0x90        Tazer
Emit '4C 3B F8'                           # cmp r15,rax
Ref32 '0F 84' 'done'
Emit '33 C0'                              # xor eax,eax
Emit '48 89 45 D7'                        # mov [rbp-0x29],rax       list.data = 0
Emit '48 89 45 DF'                        # mov [rbp-0x21],rax       list.capacity = list.count = 0
EmitRangeCall 'F3 0F 2C 55 77' 'F3 44 0F 2C 45 7B'          # around the aim point [rbp+0x77], [rbp+0x7b]
EmitRangeCall 'F3 0F 2C 53 48' 'F3 44 0F 2C 43 4C'          # around the shooter   [rbx+0x48], [rbx+0x4c]
Emit 'BE 0A 00 00 00'                     # mov esi,10               at most ten prisoners per shot
Label 'next'
Emit '8B 7D E3'                           # mov edi,[rbp-0x1d]       list.count
Emit '85 FF'                              # test edi,edi
Ref8 '7E' 'free'
Ref32 '48 8D 0D' $RNG                     # lea rcx,[rng]
Ref32 '48 8B 05' $RNG                     # mov rax,[rng]
Emit 'FF 50 10'                           # call [rax+0x10]          eax = random
Emit '33 D2'                              # xor edx,edx
Emit 'F7 F7'                              # div edi
Emit '44 8B F2'                           # mov r14d,edx             index = random % count
Emit '48 8B 45 D7'                        # mov rax,[rbp-0x29]
Emit '4A 8D 14 F0'                        # lea rdx,[rax+r14*8]      &list[index]
Ref32 '48 8B 05' $APP                     # mov rax,[App]
Emit '48 8B 88 98 01 00 00'               # mov rcx,[rax+0x198]      World
Ref32 'E8' $RESOLVE                       # rax = prisoner or 0
Emit '48 85 C0'                           # test rax,rax
Ref8 '74' 'remove'
Emit '48 8B C8'                           # mov rcx,rax
Emit '48 8B D3'                           # mov rdx,rbx              shooter
Emit '48 8B 00'                           # mov rax,[rax]
Emit 'FF 90 90 01 00 00'                  # call [rax+0x190]         OnAttackedBy(prisoner, shooter)
Label 'remove'
Emit 'FF CF'                              # dec edi
Emit '89 7D E3'                           # mov [rbp-0x1d],edi       count - 1
Emit '44 3B F7'                           # cmp r14d,edi
Ref8 '74' 'removed'
Emit '48 8B 45 D7'                        # mov rax,[rbp-0x29]
Emit '48 8B 0C F8'                        # mov rcx,[rax+rdi*8]      last entry
Emit '4A 89 0C F0'                        # mov [rax+r14*8],rcx      fills the hole
Label 'removed'
Emit 'FF CE'                              # dec esi
Ref8 '75' 'next'
Label 'free'
Emit '48 8B 4D D7'                        # mov rcx,[rbp-0x29]
Emit '48 85 C9'                           # test rcx,rcx
Ref8 '74' 'done'
Ref32 'E8' $FREE
Label 'done'
Ref32 'E9' $RESUME
Label 'four'; Emit '00 00 80 40'          # 4.0f
$stubBytes = CloseBlock
if ($StubAt + $stubBytes.Length -gt 0x1000) { throw 'stub runs past the end of the section' }

AddEdit $STUB $stubBytes 'stub: AttackTimer, then OnAttackedBy for up to 10 random prisoners within 4 tiles of the aim point and the shooter'
AddEdit $HOOK (JmpHook $HOOK $STUB 10) 'FireRangedShot: end of the shot routed through the surrender stub'

$expectOrig = @{ $HOOK = '418B4750898348030000' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'gunfire-surrender'; name = 'Prisoners near gunfire surrender'; version = '1.0.0'
    requires = @('code-section')
    description = 'Gunfire frightens bystanders again. In the 2018 version of the game every shot from a guard''s gun made up to ten prisoners within four squares of the shot react as if they had been shot at themselves, and most of them surrendered. The final version lost that code, so only the prisoner who was hit reacted. The 2018 behaviour is restored. It does not apply to shots fired by prisoners or to the Tazer.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; stub {1} bytes at +0x{2:X}, ends +0x{3:X})" -f $edits.Count, $stubBytes.Length, $StubAt, ($StubAt + $stubBytes.Length))
