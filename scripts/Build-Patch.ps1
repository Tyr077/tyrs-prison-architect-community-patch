<#
  Build-Patch.ps1
  Assembles the hand-off fix and writes patches/gang-handoff.patch.json for Apply-ExePatch.ps1.
  Reads expected bytes from the user's own Prison Architect64.exe; ships no game code.

  Layout (Sunset Update build, SHA256 cc460fc4...):
    World          = *(*(0x140D57900) + 0x198)
    ContrabandSys  = World + 0x21A0   (HandOffGuard +0x184, HandOffGangMember +0x18C,
                                       chosenContraband +0x194, handOffTimer +0x198,
                                       triedHandOffToday +0x19C)
    Prisoner.misbehaviourState = +0xA2C   (10 = ContrabandHandOff)
    Code cave: end of .text, VA 0x140A44256..0x140A44400, all zero.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/gang-handoff.patch.json')
)
$ErrorActionPreference = 'Stop'
# Prefer the untouched backup if the live exe has already been patched.
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
Write-Host "reading $src"
$b = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }

function VaToFile([long]$va) { return [int]($va - 0x140000C00) }     # .text: VA 0x140001000 -> file 0x400
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
function LE32([long]$v) { [BitConverter]::GetBytes([int32]$v) }

# --- game addresses ---
$APP        = 0x140D57900
$FN_IdEq    = 0x1401C9710   # bool ObjectId::Equals(a*, b*)   -> AL
$FN_Resolve = 0x1407BADC0   # Object* World::Resolve(World*, ObjectId*)
$FN_Reset   = 0x1406AED00   # Prisoner::ClearMisbehaviour(prisoner*)

# --- mini assembler: items are byte[], a label string, or a hashtable {pre=[byte[]]; to=<VA or label>} (pre + rel32) ---
$script:labels = @{}
function Asm([long]$base, [object[]]$items) {
    $pc = $base
    foreach ($it in $items) {
        if ($it -is [string]) { $script:labels[$it] = $pc; continue }
        if ($it -is [hashtable]) { $pc += $it.pre.Length + 4 } else { $pc += $it.Length }
    }
    $outb = New-Object System.Collections.Generic.List[byte]
    $pc = $base
    foreach ($it in $items) {
        if ($it -is [string]) { continue }
        if ($it -is [hashtable]) {
            $to = $it.to; if ($to -is [string]) { $to = $script:labels[$to] }
            if ($null -eq $to) { throw "unresolved label $($it.to)" }
            $len = $it.pre.Length + 4
            $rel = [long]$to - ($pc + $len)
            $outb.AddRange([byte[]]$it.pre); $outb.AddRange([byte[]](LE32 $rel)); $pc += $len
        } else { $outb.AddRange([byte[]]$it); $pc += $it.Length }
    }
    return ,$outb.ToArray()
}
function J([string]$cc, $to) {
    $pre = switch ($cc) { 'jmp' {@(0xE9)} 'call' {@(0xE8)} 'je' {@(0x0F,0x84)} 'jne' {@(0x0F,0x85)} 'js' {@(0x0F,0x88)} 'jge' {@(0x0F,0x8D)} }
    return @{ pre = [byte[]]$pre; to = $to }
}
function RipMovRax([long]$absAddr) { return @{ pre = [byte[]]@(0x48,0x8B,0x05); to = $absAddr } }   # mov rax,[rip+rel]
function RipMovRcx([long]$absAddr) { return @{ pre = [byte[]]@(0x48,0x8B,0x0D); to = $absAddr } }   # mov rcx,[rip+rel]

$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) {
    $off = VaToFile $va
    $old = $b[$off..($off + $new.Length - 1)]
    $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}

# ============ code cave ============
$CAVE = 0x140A44260

# ---- Stub A: guard hand-off routine, regime mismatch. rbx = prisoner. ----
#   if (prisoner.state != 10) return;  else goto reset-tail (ClearMisbehaviour + member = -1)
$stubA_va = $CAVE
$stubA = Asm $stubA_va @(
    (Bytes '83 BB 2C 0A 00 00 0A'),   # cmp dword [rbx+0xA2C], 10
    (J 'jne' 0x1405DDB85),           # plain return (restores rbx)
    (J 'jmp' 0x1405DDB64)            # existing tail: ClearMisbehaviour(rbx); HandOffGangMember = -1
)

# ---- Stub B: prisoner misbehaviour update, state-10 validity. rbx = prisoner, eax = state. ----
$stubB_va = $stubA_va + $stubA.Length + 8
$stubB = Asm $stubB_va @(
    (Bytes '83 F8 0A'),                          # cmp eax, 10
    (J 'jne' 0x1406AEC28),                       # not state 10 -> original fallthrough
    # am I the current HandOffGangMember?
    (RipMovRax $APP), (Bytes '48 8B 80 98 01 00 00'),   # rax = World
    (Bytes '48 8D 88 2C 23 00 00'),              # rcx = &World.HandOffGangMember
    (Bytes '48 8D 93 38 00 00 00'),              # rdx = &prisoner.id
    (J 'call' $FN_IdEq), (Bytes '84 C0'), (J 'je' 'B_reset'),
    # does the HandOffGuard still exist?
    (RipMovRax $APP), (Bytes '48 8B 88 98 01 00 00'),   # rcx = World
    (Bytes '48 8D 91 24 23 00 00'),              # rdx = &World.HandOffGuard
    (J 'call' $FN_Resolve), (Bytes '48 85 C0'), (J 'je' 'B_reset'),
    # regime check, identical to the guard routine
    (RipMovRax $APP), (Bytes '48 8B 80 98 01 00 00'),   # rax = World
    (Bytes '80 B8 DC 05 00 00 00'), (J 'jne' 'B_valid'), # if (World+0x5DC) skip regime check
    (Bytes '48 63 8B 34 0A 00 00'),              # rcx = (long)prisoner.sectorIndex (+0xA34)
    (Bytes '85 C9'), (J 'js' 'B_reset'),
    (Bytes '3B 88 F4 05 00 00'), (J 'jge' 'B_reset'),   # idx >= World+0x5F4
    (Bytes '48 8B 80 E8 05 00 00'),              # rax = World+0x5E8 (regime slot table)
    (Bytes '48 8B 04 C8'),                       # rax = table[idx]
    (Bytes '8B 40 60'),                          # eax = slot->type
    (Bytes '83 F8 01'), (J 'je' 'B_valid'),
    (Bytes '83 F8 07'), (J 'jne' 'B_reset'),
    'B_valid',
    (Bytes 'BA 0A 00 00 00'), (Bytes '48 8B CB'), # edx = 10; rcx = prisoner
    (J 'jmp' 0x1406AEC23),                        # -> CALL SetMisbehaviour(prisoner,10); continue
    'B_reset',
    (Bytes '48 8B CB'), (J 'call' $FN_Reset),     # ClearMisbehaviour(prisoner)
    (J 'jmp' 0x1406AECA7)                         # function epilogue
)

# ---- Stub C: ContrabandSystem update, hand-off guard set but gone. rbx = ContrabandSystem. ----
$stubC_va = $stubB_va + $stubB.Length + 8
$stubC = Asm $stubC_va @(
    (RipMovRcx $APP), (Bytes '48 8B 89 98 01 00 00'),   # rcx = World
    (Bytes '48 8D 93 84 01 00 00'),              # rdx = &this.HandOffGuard
    (J 'call' $FN_Resolve), (Bytes '48 85 C0'),
    (J 'jne' 0x1404F76B2),                       # guard alive -> original "skip pick"
    # guard gone: reset the old member if he is mid-hand-off
    (RipMovRcx $APP), (Bytes '48 8B 89 98 01 00 00'),
    (Bytes '48 8D 93 8C 01 00 00'),              # rdx = &this.HandOffGangMember
    (J 'call' $FN_Resolve), (Bytes '48 85 C0'), (J 'je' 'C_pick'),
    (Bytes '83 B8 2C 0A 00 00 0A'), (J 'jne' 'C_pick'),   # only if state == 10
    (Bytes '48 8B C8'), (J 'call' $FN_Reset),
    'C_pick',
    (Bytes 'C7 83 94 01 00 00 FF FF FF FF'),     # chosenContraband = -1  (new guard starts from pick-up)
    (Bytes 'C7 83 98 01 00 00 00 00 00 00'),     # handOffTimer = 0
    (J 'jmp' 0x1404F760F)                        # original pick code
)

$caveEnd = $stubC_va + $stubC.Length
if ($caveEnd -gt 0x140A44400) { throw ("cave overflow: end 0x{0:X}" -f $caveEnd) }

# ============ edits ============
AddEdit 0x1405DD8DF (Asm 0x1405DD8DF @((J 'je' 0x1405DDB6C))) 'guard routine: unresolvable gang member clears the slot'
AddEdit 0x1405DD8FF (Asm 0x1405DD8FF @((J 'js'  $stubA_va))) 'guard routine: regime fail (idx<0) -> stub A'
AddEdit 0x1405DD90C (Asm 0x1405DD90C @((J 'jge' $stubA_va))) 'guard routine: regime fail (idx>=n) -> stub A'
AddEdit 0x1405DD92B (Asm 0x1405DD92B @((J 'jne' $stubA_va))) 'guard routine: regime fail (type) -> stub A'
AddEdit 0x1406AEC19 (Asm 0x1406AEC19 @((J 'jmp' $stubB_va))) 'prisoner update: state-10 validity -> stub B'
AddEdit 0x1404F7609 (Asm 0x1404F7609 @((J 'jne' $stubC_va))) 'system update: guard set -> stub C (resolve check)'
AddEdit $stubA_va $stubA 'stub A: regime abort'
AddEdit $stubB_va $stubB 'stub B: prisoner self-heal'
AddEdit $stubC_va $stubC 'stub C: stale guard re-pick'

# sanity: original bytes at hook sites must be what the analysis saw; cave must be empty
$expectOrig = @{ 0x1405DD8DF='0F84A0020000'; 0x1405DD8FF='0F8880020000'; 0x1405DD90C='0F8D73020000'; 0x1405DD92B='0F8554020000'; 0x1406AEC19='83F80A750A'; 0x1404F7609='0F85A3000000' }
foreach ($e in $edits) {
    $va = [long]$e.va
    if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }
    if ($va -ge 0x140A44256 -and ($e.expect -replace '0','') -ne '') { throw "cave not empty at $($e.va)" }
}

# patched hash
$p = [byte[]]$b.Clone()
foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()

$doc = [ordered]@{
    id              = 'gang-handoff'
    name            = 'Gang contraband hand-off fix'
    version         = '1.0.0'
    description     = 'Gang contraband hand-offs no longer leave gang members pacing forever or crooked guards doing nothing.'
    game_build      = 'Prison Architect 64-bit, Sunset Update (final)'
    sha256_original = $sha
    sha256_patched  = $shaP
    edits           = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))   # no BOM
Write-Host ("stub A @ 0x{0:X} ({1} bytes)" -f $stubA_va, $stubA.Length)
Write-Host ("stub B @ 0x{0:X} ({1} bytes)" -f $stubB_va, $stubB.Length)
Write-Host ("stub C @ 0x{0:X} ({1} bytes)   cave end 0x{2:X} (limit 0x140A44400)" -f $stubC_va, $stubC.Length, $caveEnd)
Write-Host "patched sha256: $shaP"
Write-Host "wrote $Out ($($edits.Count) edits)"
