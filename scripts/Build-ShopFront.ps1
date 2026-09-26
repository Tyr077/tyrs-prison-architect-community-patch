<#
  Build-ShopFront.ps1  (fix, requires code-section)
  Writes patches/shop-front.patch.json.

  A need provider's stored position is where the game expects the user to stand. NeedsLibrary::Update
  (FUN_1406609c0) sets it from the object's own position and only replaces it with a real standing
  position when the provider declares a Slot, which is a marker baked into the object's sprite
  (WorldObject::GetSlotPosition FUN_1407E01D0 -> SpriteBank::GetMarkerOffset FUN_1403FD990).

  The Shopping provider in needs.txt declares no Slot, and the ShopFront sprite has no markers at all
  (objects.spritebank: VisitorTable has 4, VisitorTableSecure 2, WeightsBench 2, ShopFront 0). So a
  shop front's standing position is the shop front itself - a tile the object occupies, built into a
  wall. Provider validity FUN_140623D50 then asks both of its questions about that tile: region
  connectivity (FUN_14070E6A0, reason 0xD) and sector permission (FUN_14070EFE0, reason 0x17). A
  prisoner therefore has to be able to walk into the shop, and be permitted in it, to buy anything
  over a counter that exists to be used from outside. Adding "Slot 0" in a mod does not help: with no
  marker, GetSlotPosition falls back to the object's own tiles and returns the same wall tile.

  The provider stores one position shared by every consumer, so this cannot be fixed by choosing a
  better position - a shop front serving two sectors from opposite sides needs a different answer for
  each. The fix belongs in the per-consumer check.

  Fix: both checks in FUN_140623D50 are hooked. If the original check fails and the provider's object
  is BuiltOnWall, the four tiles around the provider's position are tried, and the check passes if any
  one of them is both reachable by this entity and permitted to it. Standing next to a serving hatch
  is what using it means. Nothing else changes: the provider's position is untouched, so pathing is
  unaffected, and an object on an ordinary floor tile never reaches the new code.

  The BuiltOnWall guard keeps this narrow. Without it the relaxation would also apply to, say, a bed
  in a room the prisoner may not enter, which would be a real behaviour change; with it, only objects
  that cannot presently work at all are affected.

  Registers at both hooks: rsi = provider definition (+0x24 is the object type id), r14 = the first
  argument, whose +0x20 is the entity, rdi = the provider record, rbx = the reason-out pointer. Both
  hooks replace a 5-byte CALL, so the arguments the game set up are already in place.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/shop-front.patch.json'),
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

$REACH       = 0x14070E6A0   # bool CanReach(sys, px, py, ex, ey, adjacentOk)
$PERMIT      = 0x14070EFE0   # bool IsAllowedAt(sys, px, py, entity)
$OBJDEF_TBL  = 0x140DECCA0   # qword: base of the ObjectDef table, 0x198 stride
$OBJDEF_CNT  = 0x140E085CC   # int:   number of ObjectDefs
$BUILT_ON_WALL_BIT = 0x18    # bit 24 of ObjectDef+0x98; property order in FUN_14007CB90

$HOOK_REACH  = 0x140623DCD   # CALL FUN_14070E6A0 inside FUN_140623D50
$HOOK_PERMIT = 0x140623EDD   # CALL FUN_14070EFE0 inside FUN_140623D50

$TABLE   = $SEC_VA + 0x010   # four (dx, dy) signed byte pairs
$TRYNBR  = $SEC_VA + 0x250
$RSTUB   = $SEC_VA + 0x320
$PSTUB   = $SEC_VA + 0x3A0

# --- tiny assembler: emit bytes, rip-relative operands and short jumps to named labels ---
$script:code = $null; $script:base = 0; $script:fix = $null; $script:lbl = $null
function NewBlock([long]$at) { $script:code = New-Object System.Collections.Generic.List[byte]; $script:base = $at; $script:fix = @(); $script:lbl = @{} }
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function EmitRip([string]$opcodeHex, [long]$target) { $pre = Bytes $opcodeHex; $next = $script:base + $script:code.Count + $pre.Count + 4; $script:code.AddRange([byte[]]$pre); $script:code.AddRange([byte[]](LE32 ($target - $next))) }
function Label([string]$name) { $script:lbl[$name] = $script:code.Count }
function EmitJmp([string]$opcodeHex, [string]$name) { Emit $opcodeHex; $script:fix += ,@($script:code.Count, $name); $script:code.Add(0) }
function CloseBlock() {
    foreach ($f in $script:fix) {
        $at = $f[0]; $name = $f[1]
        if (-not $script:lbl.ContainsKey($name)) { throw "undefined label $name" }
        $d = $script:lbl[$name] - ($at + 1)
        if ($d -lt -128 -or $d -gt 127) { throw "short jump to $name out of range ($d)" }
        $script:code[$at] = [byte]($d -band 0xFF)
    }
    return $script:code.ToArray()
}

# ---- data: the four neighbours, (dx, dy) as signed bytes ----
AddEdit $TABLE ([byte[]](Bytes 'FF 00 01 00 00 FF 00 01')) 'neighbour offsets: west, east, north, south'

# ---- TryNeighbours(rcx = sys, edx = px, r8d = py, r9 = entity) -> al ----
# True when any tile touching (px, py) is both reachable by the entity and permitted to it.
NewBlock $TRYNBR
Emit '53'                               # push rbx
Emit '56'                               # push rsi
Emit '57'                               # push rdi
Emit '41 54'                            # push r12
Emit '41 55'                            # push r13
Emit '41 56'                            # push r14
Emit '41 57'                            # push r15
Emit '48 83 EC 40'                      # sub rsp,0x40   (7 pushes then 0x40 keeps rsp 16-aligned)
Emit '48 8B D9'                         # mov rbx,rcx            sys
Emit '49 8B F1'                         # mov rsi,r9             entity
Emit '41 89 D4'                         # mov r12d,edx           px
Emit '45 89 C5'                         # mov r13d,r8d           py
Emit 'F3 44 0F 2C 76 48'                # cvttss2si r14d,[rsi+0x48]   entity x
Emit 'F3 44 0F 2C 7E 4C'                # cvttss2si r15d,[rsi+0x4c]   entity y
Emit '33 FF'                            # xor edi,edi            i = 0
Label 'loop'
EmitRip '48 8D 05' $TABLE               # lea rax,[rip+TABLE]
Emit '0F BE 0C 78'                      # movsx ecx,byte [rax+rdi*2]      dx
Emit '0F BE 54 78 01'                   # movsx edx,byte [rax+rdi*2+1]    dy
Emit '44 01 E1'                         # add ecx,r12d                    nx
Emit '44 01 EA'                         # add edx,r13d                    ny
Emit '89 4C 24 30'                      # mov [rsp+0x30],ecx
Emit '89 54 24 34'                      # mov [rsp+0x34],edx
Emit '48 8B CB'                         # mov rcx,rbx
Emit '41 89 D0'                         # mov r8d,edx                     ny
Emit '8B 54 24 30'                      # mov edx,[rsp+0x30]              nx
Emit '45 89 F1'                         # mov r9d,r14d                    entity x
Emit '44 89 7C 24 20'                   # mov [rsp+0x20],r15d             entity y
Emit '48 C7 44 24 28 00 00 00 00'       # mov qword [rsp+0x28],0          adjacentOk = 0
EmitRip 'E8' $REACH                     # call CanReach
Emit '84 C0'                            # test al,al
EmitJmp '74' 'next'                     # je next
Emit '48 8B CB'                         # mov rcx,rbx
Emit '8B 54 24 30'                      # mov edx,[rsp+0x30]
Emit '44 8B 44 24 34'                   # mov r8d,[rsp+0x34]
Emit '4C 8B CE'                         # mov r9,rsi                      entity
EmitRip 'E8' $PERMIT                    # call IsAllowedAt
Emit '84 C0'                            # test al,al
EmitJmp '74' 'next'                     # je next
Emit 'B0 01'                            # mov al,1
EmitJmp 'EB' 'done'                     # jmp done
Label 'next'
Emit 'FF C7'                            # inc edi
Emit '83 FF 04'                         # cmp edi,4
EmitJmp '7C' 'loop'                     # jl loop
Emit '32 C0'                            # xor al,al
Label 'done'
Emit '48 83 C4 40'                      # add rsp,0x40
Emit '41 5F'                            # pop r15
Emit '41 5E'                            # pop r14
Emit '41 5D'                            # pop r13
Emit '41 5C'                            # pop r12
Emit '5F'                               # pop rdi
Emit '5E'                               # pop rsi
Emit '5B'                               # pop rbx
Emit 'C3'                               # ret
$tryBytes = CloseBlock
AddEdit $TRYNBR $tryBytes 'TryNeighbours: is any tile touching the provider both reachable and permitted for this entity'

# The BuiltOnWall guard, identical in both stubs: rsi = provider def, falls to $fail when not set.
function EmitWallGuard([string]$fail) {
    Emit '48 63 46 24'                  # movsxd rax,dword [rsi+0x24]     provider def -> object type id
    Emit '85 C0'                        # test eax,eax
    EmitJmp '78' $fail                  # js fail
    EmitRip '3B 05' $OBJDEF_CNT         # cmp eax,[rip+ObjectDefCount]
    EmitJmp '7D' $fail                  # jge fail
    Emit '48 69 C0 98 01 00 00'         # imul rax,rax,0x198
    EmitRip '48 03 05' $OBJDEF_TBL      # add rax,[rip+ObjectDefTable]
    Emit ('0F BA A0 98 00 00 00 {0:X2}' -f $BUILT_ON_WALL_BIT)   # bt dword [rax+0x98],24
    EmitJmp '73' $fail                  # jnc fail
}

# ---- reach stub: replaces CALL CanReach at 0x140623DCD ----
# Entry rsp is the caller's minus the return address, so its 5th and 6th arguments
# sit at +0x70 and +0x78 once this frame is open.
NewBlock $RSTUB
Emit '48 83 EC 48'                      # sub rsp,0x48
Emit '48 89 4C 24 30'                   # mov [rsp+0x30],rcx      save sys
Emit '89 54 24 38'                      # mov [rsp+0x38],edx      save px
Emit '44 89 44 24 3C'                   # mov [rsp+0x3C],r8d      save py
Emit '8B 84 24 70 00 00 00'             # mov eax,[rsp+0x70]      caller's arg5 (entity y)
Emit '89 44 24 20'                      # mov [rsp+0x20],eax
Emit '48 8B 84 24 78 00 00 00'          # mov rax,[rsp+0x78]      caller's arg6 (adjacentOk)
Emit '48 89 44 24 28'                   # mov [rsp+0x28],rax
EmitRip 'E8' $REACH                     # call CanReach            the original check, unchanged
Emit '84 C0'                            # test al,al
EmitJmp '75' 'rdone'                    # jne rdone
EmitWallGuard 'rfail'
Emit '48 8B 4C 24 30'                   # mov rcx,[rsp+0x30]
Emit '8B 54 24 38'                      # mov edx,[rsp+0x38]
Emit '44 8B 44 24 3C'                   # mov r8d,[rsp+0x3C]
Emit '4D 8B 4E 20'                      # mov r9,[r14+0x20]       entity
EmitRip 'E8' $TRYNBR                    # call TryNeighbours
EmitJmp 'EB' 'rdone'                    # jmp rdone
Label 'rfail'
Emit '32 C0'                            # xor al,al
Label 'rdone'
Emit '48 83 C4 48'                      # add rsp,0x48
Emit 'C3'                               # ret
AddEdit $RSTUB (CloseBlock) 'reach stub: a wall-mounted provider may also be reached from a tile beside it'

# ---- permit stub: replaces CALL IsAllowedAt at 0x140623EDD ----
NewBlock $PSTUB
Emit '48 83 EC 38'                      # sub rsp,0x38
Emit '48 89 4C 24 20'                   # mov [rsp+0x20],rcx      save sys
Emit '89 54 24 28'                      # mov [rsp+0x28],edx      save px
Emit '44 89 44 24 2C'                   # mov [rsp+0x2C],r8d      save py
Emit '4C 89 4C 24 30'                   # mov [rsp+0x30],r9       save entity
EmitRip 'E8' $PERMIT                    # call IsAllowedAt         the original check, unchanged
Emit '84 C0'                            # test al,al
EmitJmp '75' 'pdone'                    # jne pdone
EmitWallGuard 'pfail'
Emit '48 8B 4C 24 20'                   # mov rcx,[rsp+0x20]
Emit '8B 54 24 28'                      # mov edx,[rsp+0x28]
Emit '44 8B 44 24 2C'                   # mov r8d,[rsp+0x2C]
Emit '4C 8B 4C 24 30'                   # mov r9,[rsp+0x30]
EmitRip 'E8' $TRYNBR                    # call TryNeighbours
EmitJmp 'EB' 'pdone'                    # jmp pdone
Label 'pfail'
Emit '32 C0'                            # xor al,al
Label 'pdone'
Emit '48 83 C4 38'                      # add rsp,0x38
Emit 'C3'                               # ret
AddEdit $PSTUB (CloseBlock) 'permission stub: a wall-mounted provider may also be permitted from a tile beside it'

# ---- the two hooks: redirect each CALL to its stub ----
$r = New-Object System.Collections.Generic.List[byte]
$r.AddRange([byte[]](Bytes 'E8')); $r.AddRange([byte[]](LE32 ($RSTUB - ($HOOK_REACH + 5))))
AddEdit $HOOK_REACH $r.ToArray() 'provider validity: route the reachability check through the stub'
$p = New-Object System.Collections.Generic.List[byte]
$p.AddRange([byte[]](Bytes 'E8')); $p.AddRange([byte[]](LE32 ($PSTUB - ($HOOK_PERMIT + 5))))
AddEdit $HOOK_PERMIT $p.ToArray() 'provider validity: route the sector permission check through the stub'

# Section blocks must not overlap. The free-space check below reads the unpatched base image, so one
# stub written over another would not show up there.
$secEdits = @($edits | Where-Object { [long]$_.va -ge $SEC_VA } | Sort-Object { [long]$_.va })
for ($i = 1; $i -lt $secEdits.Count; $i++) {
    $prev = $secEdits[$i - 1]
    $end = [long]$prev.va + $prev.replace.Length / 2
    if ([long]$secEdits[$i].va -lt $end) { throw ("section blocks overlap: 0x{0:X} ends at 0x{1:X} but 0x{2:X} starts there" -f [long]$prev.va, $end, [long]$secEdits[$i].va) }
}
$expectOrig = @{ $HOOK_REACH = 'E8CEA80E00'; $HOOK_PERMIT = 'E8FEB00E00' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'shop-front'; name = 'Shops usable from outside the shop'; version = '1.0.0'
    requires = @('code-section')
    description = 'The shop front can face a hallway, and prisoners buy from it without being allowed into the shop. Who works in a shop and who shops there can be kept apart.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host "wrote $Out ($($edits.Count) edits; TryNeighbours $($tryBytes.Length) bytes)"
