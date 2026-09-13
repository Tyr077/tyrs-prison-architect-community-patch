<#
  Build-PavilionReload.ps1  (fix, requires code-section)
  Writes patches/pavilion-reload.patch.json.

  A guard manning a Guard Pavilion is "Loaded" (Entity+0x6E) on the pavilion. The entity update
  (FUN_14053ED20) asks FUN_14053BED0 first whether the entity is loaded, and if so returns
  straight away - before it reaches the reload countdown (FUN_140537D00, run while
  ReloadTimer +0x34C > 0). A stationed armed guard's ReloadTimer therefore never runs down after
  the first shot, and the attack routines refuse to fire while it is positive: the armed guard
  fires once and never again ("cannot reload the shotgun while stationed in a pavilion"). The
  AIO mod works around it by decrementing ReloadTimer from the pavilion's script.

  Fix: in FUN_14053BED0's loaded branch, run the reload countdown when ReloadTimer > 0, then
  carry on exactly as before. Nothing else a loaded entity skips is touched.

  Registers at the hook (0x14053BEE1): rcx = entity, xmm2 = frame time (copied from xmm1 at
  0x14053BED8), rsp % 16 == 0 (sub rsp,0x28 on entry). rcx and xmm2 are read again after the
  hook, so the stub preserves them across the call.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/pavilion-reload.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $StubAt = 0x790
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

$HOOK      = 0x14053BEE1   # movsxd rax,[rcx+0x40] / test eax,eax  (loaded branch of FUN_14053BED0)
$RESUME    = 0x14053BEE7   # js ...
$COUNTDOWN = 0x140537D00   # reload countdown (entity, dt)
$STUB      = $SEC_VA + $StubAt

NewBlock $STUB
Emit '0F 57 C0'                           # xorps xmm0,xmm0
Emit '0F 2F 81 4C 03 00 00'               # comiss xmm0,[rcx+0x34c]    0 >= ReloadTimer ?
Ref8 '73' 'resume'                        # jae resume
Emit '48 83 EC 30'                        # sub rsp,0x30
Emit '48 89 4C 24 20'                     # mov [rsp+0x20],rcx
Emit 'F3 0F 11 54 24 28'                  # movss [rsp+0x28],xmm2
Emit '0F 28 CA'                           # movaps xmm1,xmm2           dt
Ref32 'E8' $COUNTDOWN
Emit '48 8B 4C 24 20'                     # mov rcx,[rsp+0x20]
Emit 'F3 0F 10 54 24 28'                  # movss xmm2,[rsp+0x28]
Emit '48 83 C4 30'                        # add rsp,0x30
Label 'resume'
Emit '48 63 41 40'                        # movsxd rax,[rcx+0x40]      the replaced instructions
Emit '85 C0'                              # test eax,eax
Ref32 'E9' $RESUME
$stubBytes = CloseBlock
AddEdit $STUB $stubBytes 'loaded entities: run the reload countdown before skipping the rest of the update'

$h = New-Object System.Collections.Generic.List[byte]
$h.AddRange([byte[]](Bytes 'E9')); $h.AddRange([byte[]](LE32 ($STUB - ($HOOK + 5)))); $h.Add(0x90)
AddEdit $HOOK $h.ToArray() 'FUN_14053BED0 loaded branch routed through the reload stub'

$expectOrig = @{ $HOOK = '4863414085C0' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }; if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) } }
$p2 = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p2[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p2)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'pavilion-reload'; name = 'Armed guards reload in pavilions'; version = '1.0.0'
    requires = @('code-section')
    description = 'Armed guards manning a Guard Pavilion fire more than once. A guard on a pavilion counts as carried by it, and the game skipped the whole update for carried people, including the reload timer that runs after every shot. A stationed armed guard fired once and then waited for a reload that never finished. The reload timer now keeps running while a guard is stationed.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host ("wrote $Out ({0} edits; stub {1} bytes at +0x{2:X})" -f $edits.Count, $stubBytes.Length, $StubAt)
