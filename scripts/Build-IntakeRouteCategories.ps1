<#
  Build-IntakeRouteCategories.ps1  (fix, requires code-section)
  Writes patches/intake-route-categories.patch.json.

  Each transport stop (road, helipad, boat dock) carries a list of prisoner categories it accepts.
  The dispatcher honours it: when a prisoner vehicle is sent to a stop, the number of prisoners it
  loads is the number queued in the categories that stop accepts (FUN_1407326C0), and every
  prisoner is created through FUN_140608A30 with the stop's accepted set.

  The creation step does not honour it. FUN_140608A30 asks the intake system for the next queued
  prisoner (FUN_140665370), which always hands out the FIRST category with anything queued and
  decrements that category's queue. If that category is not accepted by the stop, FUN_140608A30
  simply asks again - and again - until an accepted one comes up. Every rejected draw has already
  removed a queued prisoner of some other category. Those prisoners are never created, but the
  arrival system (World+0x600) was told to expect them when the day's intake was scheduled
  (FUN_140665110 -> FUN_140734CF0), so its pending count keeps them. Pending prisoners count
  against capacity (FUN_140665F10), and once the queue is empty no stop accepts anything, so
  nothing is ever dispatched to clear them. The pending count grows day by day until "fill to
  capacity" finds no free capacity and the prison reports itself closed to new inmates - with
  empty cells. This needs a stop that accepts only some categories (a "partial" route) and another
  category queued ahead of an accepted one in the intake list, which is exactly the reported
  trigger.

  Fix: while FUN_140608A30 is drawing for a stop, FUN_140665370 prefers the first queued category
  the stop accepts. The stop's accepted set is passed through a pointer in the code section
  (.tyrs+0x018): a wrapper around the call at 0x140608A91 stores it before the call and clears it
  after, and a stub at the head of FUN_140665370's search loop scans for an accepted queued category
  first. If there is one, the original loop is entered at that entry and takes it exactly as before
  (same side effects, same bookkeeping). If there is none, or no set is active (the unfiltered
  spawner FUN_140608780), the original loop runs unchanged from the start.

  Registers at the loop head (0x1406653C2): r11 = intake system, rbx = prisoner, esi = 0,
  r8b = 0 (a flag the loop may set to 1 and tests afterwards). eax and rcx are the loop's index and
  byte offset, both initialised by the bytes the hook replaces. r9 and r10 are not read until they
  are written again after the loop, so the stub uses them and r8d as scratch and re-zeroes r8b.
  At the wrapper site rdi holds the address of the accepted-set pointer (callee-saved; read by
  the loop as "mov rcx,[rdi]"), and rcx/rdx are already the call's arguments.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/intake-route-categories.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $ScanAt = 0x410,        # section offsets; the defaults are the ones recorded in docs/code-section.md
    [int] $WrapAt = 0x4A0,
    [int] $PtrAt  = 0x018
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

$POP          = 0x140665370   # NewIntakeSystem: give a new prisoner the next queued category
$LOOP_HOOK    = 0x1406653C2   # head of the search loop inside it (mov eax,esi / cmp [r11+0x2a4],eax / jle)
$LOOP_NONE    = 0x14066541C   # where the loop goes when nothing is queued
$LOOP_INIT    = 0x1406653CD   # mov ecx,esi; nop; (loop body follows at LOOP_BODY)
$LOOP_BODY    = 0x1406653D0   # loop body: expects eax = index, rcx = offset, r11 = intake system
$CALL_HOOK    = 0x140608A91   # CALL FUN_140665370 inside FUN_140608A30 (the filtered spawner)

$ALLOWED_PTR  = $SEC_VA + $PtrAt   # qword: the active stop's accepted-category bytes, or 0
$SCAN         = $SEC_VA + $ScanAt
$WRAP         = $SEC_VA + $WrapAt

# --- tiny assembler: emit bytes, rip-relative operands and short jumps to named labels ---
$script:code = $null; $script:base = 0; $script:fix = $null; $script:lbl = $null
function NewBlock([long]$at) { $script:code = New-Object System.Collections.Generic.List[byte]; $script:base = $at; $script:fix = @(); $script:lbl = @{} }
function Emit([string]$hex) { $script:code.AddRange([byte[]](Bytes $hex)) }
function EmitRip([string]$opcodeHex, [long]$target, [int]$tail = 0) { $pre = Bytes $opcodeHex; $next = $script:base + $script:code.Count + $pre.Count + 4 + $tail; $script:code.AddRange([byte[]]$pre); $script:code.AddRange([byte[]](LE32 ($target - $next))) }
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

# ---- data: the active accepted-set pointer, 0 when no filtered draw is in progress ----
AddEdit $ALLOWED_PTR ([byte[]](Bytes '00 00 00 00 00 00 00 00')) 'accepted-category pointer for the current filtered draw (0 = none)'

# ---- scan stub: entered from the loop head; finds the first queued category the stop accepts ----
NewBlock $SCAN
EmitRip '4C 8B 0D' $ALLOWED_PTR         # mov r9,[rip+ALLOWED_PTR]
Emit '4D 85 C9'                         # test r9,r9
EmitJmp '74' 'vanilla'                  # jz vanilla                     no filter active
Emit '45 8B 93 A4 02 00 00'             # mov r10d,[r11+0x2a4]           category count
Emit '45 85 D2'                         # test r10d,r10d
EmitJmp '7E' 'vanilla'                  # jle vanilla
Emit '49 8B 93 98 02 00 00'             # mov rdx,[r11+0x298]            category array, 0x1c stride
Emit '33 C0'                            # xor eax,eax                    index
Emit '33 C9'                            # xor ecx,ecx                    byte offset
Label 'scan'
Emit '83 3C 11 08'                      # cmp dword [rcx+rdx],8          same side effect as the original loop:
EmitJmp '75' 'queued'                   # jne queued                     a category-8 entry it passes
Emit 'C7 44 11 18 00 00 00 00'          # mov dword [rcx+rdx+0x18],0     has its NumNITGs cleared
Label 'queued'
Emit '83 7C 11 14 00'                   # cmp dword [rcx+rdx+0x14],0     Queue empty?
EmitJmp '74' 'next'                     # je next
Emit '44 8B 04 11'                      # mov r8d,[rcx+rdx]              PrisonerCategory
Emit '41 83 F8 08'                      # cmp r8d,8                      the accepted set has 9 bytes (0..8)
EmitJmp '77' 'next'                     # ja next                        (unsigned: also rejects negatives)
Emit '43 80 3C 01 00'                   # cmp byte [r9+r8],0             accepted by this stop?
EmitJmp '75' 'found'                    # jne found
Label 'next'
Emit 'FF C0'                            # inc eax
Emit '48 83 C1 1C'                      # add rcx,0x1c
Emit '41 3B C2'                         # cmp eax,r10d
EmitJmp '7C' 'scan'                     # jl scan
Label 'vanilla'                         # nothing accepted is queued: run the original loop from the start
Emit '45 32 C0'                         # xor r8b,r8b
Emit '33 C0'                            # xor eax,eax                    (was: mov eax,esi)
Emit '41 39 83 A4 02 00 00'             # cmp [r11+0x2a4],eax
EmitRip '0F 8E' $LOOP_NONE              # jle LOOP_NONE
EmitRip 'E9' $LOOP_INIT                 # jmp LOOP_INIT                  mov ecx,esi and into the loop
Label 'found'                           # enter the original loop at this entry; it re-checks and takes it
Emit '45 32 C0'                         # xor r8b,r8b
EmitRip 'E9' $LOOP_BODY                 # jmp LOOP_BODY
$scanBytes = CloseBlock
AddEdit $SCAN $scanBytes 'queue scan: prefer the first queued category the current stop accepts'

# ---- wrapper: replaces CALL FUN_140665370 in the filtered spawner; publishes the accepted set ----
# Entry rsp is 8 mod 16 (we were CALLed from an aligned frame); 0x28 restores alignment for the
# inner call and provides the 32-byte home area the callee writes into.
NewBlock $WRAP
Emit '48 8B 07'                         # mov rax,[rdi]                  accepted-set bytes for this stop
EmitRip '48 89 05' $ALLOWED_PTR         # mov [rip+ALLOWED_PTR],rax
Emit '48 83 EC 28'                      # sub rsp,0x28
EmitRip 'E8' $POP                       # call FUN_140665370             rcx/rdx are still its arguments
Emit '48 83 C4 28'                      # add rsp,0x28
EmitRip '48 C7 05' $ALLOWED_PTR 4       # mov qword [rip+ALLOWED_PTR],0  (rip is past the imm32)
Emit '00 00 00 00'
Emit 'C3'                               # ret
$wrapBytes = CloseBlock
AddEdit $WRAP $wrapBytes 'spawn wrapper: publish the stop''s accepted set around the queue draw'

# ---- hooks ----
$h1 = New-Object System.Collections.Generic.List[byte]
$h1.AddRange([byte[]](Bytes 'E9')); $h1.AddRange([byte[]](LE32 ($SCAN - ($LOOP_HOOK + 5)))); $h1.AddRange([byte[]](Bytes '90 90 90 90 90 90'))
AddEdit $LOOP_HOOK $h1.ToArray() 'queue draw: scan for an accepted category before the original search'
$h2 = New-Object System.Collections.Generic.List[byte]
$h2.AddRange([byte[]](Bytes 'E8')); $h2.AddRange([byte[]](LE32 ($WRAP - ($CALL_HOOK + 5))))
AddEdit $CALL_HOOK $h2.ToArray() 'filtered spawner: draw through the wrapper'

# Section blocks must not overlap. The free-space check below reads the unpatched base image, so one
# stub written over another would not show up there.
$secEdits = @($edits | Where-Object { [long]$_.va -ge $SEC_VA } | Sort-Object { [long]$_.va })
for ($i = 1; $i -lt $secEdits.Count; $i++) {
    $prev = $secEdits[$i - 1]
    $end = [long]$prev.va + $prev.replace.Length / 2
    if ([long]$secEdits[$i].va -lt $end) { throw ("section blocks overlap: 0x{0:X} ends at 0x{1:X} but 0x{2:X} starts there" -f [long]$prev.va, $end, [long]$secEdits[$i].va) }
}
$expectOrig = @{ $LOOP_HOOK = '8BC6413983A40200007E4F'; $CALL_HOOK = 'E8DAC80500' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'intake-route-categories'; name = 'Intake routes that accept only some categories'; version = '1.0.0'
    requires = @('code-section')
    description = 'Fill to capacity and the other intake modes keep working when a road, helipad or boat dock accepts only some prisoner categories. When a vehicle was loaded for such a stop, the game drew prisoners from the intake queue in list order and threw away every queued prisoner of a category the stop did not accept until it found one it did. Those prisoners were still counted as on their way, and a prisoner on its way counts against capacity, so the count crept up day after day until the prison declared itself closed to new inmates with cells standing empty. A vehicle now takes the queued prisoners of the categories its stop accepts and leaves the rest queued for a route that does.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ($($edits.Count) edits; scan $($scanBytes.Length) bytes at +0x{0:X}, wrapper $($wrapBytes.Length) bytes at +0x{1:X}, pointer at +0x{2:X})" -f $ScanAt, $WrapAt, $PtrAt)
