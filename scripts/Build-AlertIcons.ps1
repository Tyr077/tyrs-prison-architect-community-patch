<#
  Build-AlertIcons.ps1
  Assembles the alert-icon sprite-bank fix and writes patches/alert-icons.patch.json.
  Reads expected bytes from the user's own Prison Architect64.exe (preferring the .orig backup).

  Bug: MarkerIcon::DrawSprite (FUN_1405fd080) fetches the sprite from the bank the icon names
  (App+0x7B0[icon.bank], normally objects_d11_2) but computes the texture coordinates with the
  cell scale of the main Objects atlas (App+0x730, fields +0x60..+0x6C). Both are 4096 px in a
  vanilla install, so the mistake is invisible. Any mod with its own sprites.png makes the game
  build a bigger Objects atlas, the scale halves, and every alert icon that lives in
  objects_d11_2.png is drawn from the wrong quarter of its sheet.

  Fix: keep the fetched bank in RBX so the scale loads, the rect helper and the draw all use the
  bank the sprite actually came from. Two in-place edits, no code cave.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/alert-icons.patch.json')
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
Write-Host "reading $src"
$b = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }

function VaToFile([long]$va) { return [int]($va - 0x140000C00) }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
function LE32([long]$v) { [BitConverter]::GetBytes([int32]$v) }

$APP = 0x140D57900
$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) {
    $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]
    $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}

# Original at 0x1405FD4F0 (21 bytes), EAX = bank index, EDX = sprite index:
#   mov r8, rax ; mov rax,[App] ; mov rcx,[rax+0x7B0] ; mov rcx,[rcx+r8*8]      -> rcx = bank (lost after the call)
# New (21 bytes): same bank lookup, but parked in RBX (callee-saved) as well:
#   mov rcx,[App] ; mov rcx,[rcx+0x7B0] ; mov rbx,[rcx+rax*8] ; mov rcx,rbx
$site1 = 0x1405FD4F0
$rel = $APP - ($site1 + 7)
$new1 = New-Object System.Collections.Generic.List[byte]
$new1.AddRange([byte[]]@(0x48,0x8B,0x0D)); $new1.AddRange([byte[]](LE32 $rel))   # mov rcx,[rip+rel]  -> App
$new1.AddRange([byte[]](Bytes '48 8B 89 B0 07 00 00'))                            # mov rcx,[rcx+0x7B0]
$new1.AddRange([byte[]](Bytes '48 8B 1C C1'))                                     # mov rbx,[rcx+rax*8]
$new1.AddRange([byte[]](Bytes '48 8B CB'))                                        # mov rcx,rbx
if ($new1.Count -ne 21) { throw "site1 length $($new1.Count)" }
AddEdit $site1 ($new1.ToArray()) 'MarkerIcon::DrawSprite: keep the fetched sprite bank in RBX'

# Original at 0x1405FD524: lea rbx,[r14+0x730]  (RBX = Objects bank, the wrong one) -> 7-byte NOP
AddEdit 0x1405FD524 (Bytes '0F 1F 80 00 00 00 00') 'MarkerIcon::DrawSprite: do not replace RBX with the Objects bank'

# ---- Second site: FUN_1406cff30, an object overlay drawn with objects_d11_2 sprite 0x43 but scaled
# with the Objects atlas (App+0x790..0x79C). Park the bank array in RBX (the object pointer in RBX is
# not read again after this point), dereference it after the sprite lookup, and read the four scale
# fields from the bank. RCX must stay = App for the World load further down, so RCX is left alone.
AddEdit 0x1406CFFE0 (Bytes '48 8B 98 B0 07 00 00') 'overlay draw: mov rbx,[rax+0x7B0] (bank array) instead of rcx'
AddEdit 0x1406CFFFE (Bytes '48 8B 4B 08')          'overlay draw: mov rcx,[rbx+8] (objects_d11_2 bank) for the sprite lookup'
# 30 bytes at 0x1406D0033: movd xmm9,[rax+0x28]; movss xmm4,[rcx+0x798]; movd xmm5,[rax+0x2C]; movaps xmm0,xmm4; movss xmm2,[rcx+0x79C]
AddEdit 0x1406D0033 (Bytes '48 8B 5B 08  66 44 0F 6E 48 28  F3 0F 10 63 68  66 0F 6E 68 2C  0F 28 C4  F3 0F 10 53 6C  66 90') 'overlay draw: rbx = bank; scale pads from [rbx+0x68]/[rbx+0x6C]'
# 16 bytes at 0x1406D005B: movss xmm3,[rcx+0x790]; movss xmm1,[rcx+0x794]
AddEdit 0x1406D005B (Bytes 'F3 0F 10 5B 60  F3 0F 10 4B 64  66 0F 1F 44 00 00') 'overlay draw: cell scale from [rbx+0x60]/[rbx+0x64]'

$expectOrig = @{
    0x1405FD4F0 = '4C8BC0488B0506A47500488B88B00700004A8B0CC1'; 0x1405FD524 = '498D9E30070000'
    0x1406CFFE0 = '488B88B0070000'; 0x1406CFFFE = '488B4908'
    0x1406D0033 = '66440F6E4828F30F10A198070000660F6E682C0F28C4F30F10919C070000'
    0x1406D005B = 'F30F109990070000F30F108994070000'
}
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }

$p = [byte[]]$b.Clone()
foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()

$doc = [ordered]@{
    id              = 'alert-icons'
    name            = 'Alert icons with custom sprite-sheet mods'
    version         = '1.0.0'
    description     = 'Alert icons and the bakery oven glow draw correctly when a mod brings its own sprites.png. Disable the Alert Icons Partial Fix mod if you use it.'
    game_build      = 'Prison Architect 64-bit, Sunset Update (final)'
    sha256_original = $sha
    sha256_patched  = $shaP
    edits           = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"
Write-Host "wrote $Out ($($edits.Count) edits)"
