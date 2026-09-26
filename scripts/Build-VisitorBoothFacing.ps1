<#
  Build-VisitorBoothFacing.ps1  (fix, requires code-section)
  Writes patches/visitor-booth-facing.patch.json.

  A visitor booth (VisitorTableSecure, type 0x118) has two standing positions, sprite markers 0
  and 1. Which side is the prisoner's follows the booth's facing: the prisoner's visitation job
  (FUN_140632F30) takes slot 0 unless the booth faces up (dir.y == -1.0), when it takes slot 1,
  and the visitor's job (FUN_140761A00 / FUN_140761CA0) does the mirror image. For a booth facing
  down, left or right slot 0 is the prisoner's side; for one facing up, slot 1 is.

  The VisitationSystem's pairing check (FUN_14075E5A0), which decides whether a prisoner may be
  matched to a visitor at a given booth, does not know that. It always asks for slot 0 and then
  requires that tile to be in a sector the prisoner's category is allowed in and reachable from
  the prisoner's cell. For a booth facing up that is the VISITOR's side. Unless prisoners can walk
  into the visitor half of the room, no visit is ever arranged at that booth - the reported
  "prisoner-up / visitor-down booths do not work unless both sides can be pathed into", and the
  reason the suggested workarounds open the visitor side to prisoners and lose the contraband
  separation the booth exists for. Booths facing the other three ways are checked at the right
  tile, which is why only that orientation fails.

  Fix: the pairing check asks for the same slot the prisoner will actually use - slot 1 when the
  booth is a VisitorTableSecure facing up, slot 0 otherwise. The eight bytes that set the slot to
  0 and make the virtual call are replaced by a jump to a stub that does both.

  Registers at the hook (0x14075E698): rbx = the table object (+0x40 type id, +0x58 direction y),
  rax = its vtable, r8/r9 = the position and direction out-pointers, [rsp+0x20] = the fifth
  argument. rcx and rdx are free (the replaced bytes set them). Nothing else is touched.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/visitor-booth-facing.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $StubAt = 0x500         # section offset; the default is the one recorded in docs/code-section.md
                                  # (+0x4D0 also assembles, but with the intake fix and no tweaks that layout
                                  # trips Defender's cloud heuristic; see docs/visitor-booth-facing.md)
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

$HOOK     = 0x14075E698   # xor edx,edx / mov rcx,rbx / call [rax+0x68] inside FUN_14075E5A0
$RESUME   = 0x14075E6A0   # the instruction after the call
$STUB     = $SEC_VA + $StubAt
$BOOTH    = 0x118         # VisitorTableSecure

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

# ---- stub: slot = (type == VisitorTableSecure && dir.y == -1.0f) ? 1 : 0, then the original call ----
NewBlock $STUB
Emit '33 D2'                            # xor edx,edx                    slot 0
Emit ('81 7B 40 {0:X2} {1:X2} 00 00' -f ($BOOTH -band 0xFF), ($BOOTH -shr 8))   # cmp dword [rbx+0x40],0x118
EmitJmp '75' 'call'                     # jne call
Emit '81 7B 58 00 00 80 BF'             # cmp dword [rbx+0x58],0xBF800000   dir.y == -1.0f (facing up)
EmitJmp '75' 'call'                     # jne call
Emit 'BA 01 00 00 00'                   # mov edx,1                      slot 1: the prisoner's side
Label 'call'
Emit '48 8B CB'                         # mov rcx,rbx
Emit 'FF 50 68'                         # call qword [rax+0x68]          WorldObject::GetSlotPosition
EmitRip 'E9' $RESUME                    # jmp RESUME
$stubBytes = CloseBlock
AddEdit $STUB $stubBytes 'pairing check: ask for the slot the prisoner will use (1 for a booth facing up)'

# ---- hook: the eight bytes become a jump to the stub ----
$h = New-Object System.Collections.Generic.List[byte]
$h.AddRange([byte[]](Bytes 'E9')); $h.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $h.AddRange([byte[]](Bytes '90 90 90'))
AddEdit $HOOK $h.ToArray() 'VisitationSystem pairing check: slot choice routed through the stub'

$expectOrig = @{ $HOOK = '33D2488BCBFF5068' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'visitor-booth-facing'; name = 'Visitor booths facing up'; version = '1.0.0'
    requires = @('code-section')
    description = 'Visitor booths work with the prisoners'' side at the top, not just the bottom. Rotate the booth to face your prisoners while placing it.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ($($edits.Count) edits; stub $($stubBytes.Length) bytes at +0x{0:X})" -f $StubAt)
