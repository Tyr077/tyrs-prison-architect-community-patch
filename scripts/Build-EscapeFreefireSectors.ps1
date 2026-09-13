<#
  Build-EscapeFreefireSectors.ps1  (fix, requires code-section)
  Writes patches/escape-freefire-sectors.patch.json.

  Escape Mode: when the player's gang kills a prisoner (EscapeMode kill handler FUN_1405561C0),
  the warden AI orders Freefire for three minutes: it sets the legacy global Freefire flag
  World+0x4614 and WeaponsFreeTimer (EscapeMode+0x110) = 180. The EscapeMode update
  (FUN_140552F10) counts the timer down and clears World+0x4614 whenever it is below zero.

  With "Search and Actions per sector" (the default), guards do not read World+0x4614. They read
  the per-sector crisis table CrisisSectorData: World+0x44C8 + order*14 + sector, 11 orders x 14
  sectors, order 1 = WeaponsFree (so World+0x44D6..+0x44E3), gated by World+0x4715. The warden's
  order therefore changes nothing a guard looks at.

  Fix: both sites that touch World+0x4614 do the same to the WeaponsFree row of the crisis table
  when World+0x4715 (per-sector actions) is set: all 14 sectors on when the order is given, all
  off while the timer is expired - the same behaviour the legacy flag has always had.

  Hooks: 0x14055634C (mov rax,[App] in the kill handler; the stub re-does it and the flag write,
  then resumes at 0x140556361) and 0x140553157 (mov [rcx+0x4614],bpl with bpl = 0 in the update;
  rcx = World). Neither stub calls anything.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/escape-freefire-sectors.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $OnAt = 0x7F0,
    [int] $OffAt = 0x840
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

$APP        = 0x140D57900
$ON_HOOK    = 0x14055634C; $ON_RESUME  = 0x140556361
$OFF_HOOK   = 0x140553157; $OFF_RESUME = 0x14055315E
$ON  = $SEC_VA + $OnAt
$OFF = $SEC_VA + $OffAt

function EmitRow([string]$b4, [string]$b2) {   # WeaponsFree row: World+0x44D6 .. +0x44E3 (14 bytes)
    Emit ('C7 81 D6 44 00 00 ' + $b4)
    Emit ('C7 81 DA 44 00 00 ' + $b4)
    Emit ('C7 81 DE 44 00 00 ' + $b4)
    Emit ('66 C7 81 E2 44 00 00 ' + $b2)
}

NewBlock $ON
Ref32 '48 8B 05' $APP                     # mov rax,[App]                 the replaced instructions
Emit '48 8B 88 98 01 00 00'               # mov rcx,[rax+0x198]
Emit 'C6 81 14 46 00 00 01'               # mov byte [rcx+0x4614],1       legacy Freefire
Emit '80 B9 15 47 00 00 00'               # cmp byte [rcx+0x4715],0       per-sector actions?
Ref8 '74' 'done'
EmitRow '01 01 01 01' '01 01'             # Freefire in every sector
Label 'done'
Ref32 'E9' $ON_RESUME
$onBytes = CloseBlock
AddEdit $ON $onBytes 'Escape Mode warden Freefire order: also set Freefire in every sector'
AddEdit $ON_HOOK (JmpHook $ON_HOOK $ON 7) 'EscapeMode kill handler: Freefire order routed through the stub'

NewBlock $OFF
Emit '40 88 A9 14 46 00 00'               # mov [rcx+0x4614],bpl          the replaced instruction (bpl = 0)
Emit '80 B9 15 47 00 00 00'               # cmp byte [rcx+0x4715],0
Ref8 '74' 'done'
EmitRow '00 00 00 00' '00 00'
Label 'done'
Ref32 'E9' $OFF_RESUME
$offBytes = CloseBlock
AddEdit $OFF $offBytes 'Escape Mode Freefire timer expired: also clear Freefire in every sector'
AddEdit $OFF_HOOK (JmpHook $OFF_HOOK $OFF 7) 'EscapeMode update: Freefire expiry routed through the stub'

if ($OnAt + $onBytes.Length -gt $OffAt) { throw 'on stub runs into the off stub' }
$expectOrig = @{ $ON_HOOK = '488B05AD158000'; $OFF_HOOK = '4088A914460000' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'escape-freefire-sectors'; name = 'Escape Mode Freefire with per-sector actions'; version = '1.0.0'
    requires = @('code-section')
    description = 'In Escape Mode the warden orders Freefire for three minutes when your gang kills someone. The order only set the old prison-wide Freefire switch, which guards ignore when "Search and Actions per sector" is on, as it is by default, so the order did nothing. It now also sets Freefire in every sector, and clears it again when the three minutes are up, the same way the old switch is cleared.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; on {1} bytes at +0x{2:X}, off {3} bytes at +0x{4:X})" -f $edits.Count, $onBytes.Length, $OnAt, $offBytes.Length, $OffAt)
