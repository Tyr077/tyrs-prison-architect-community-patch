<#
  Build-Firerate.ps1  (fix, requires code-section since 2.0.0)
  Assembles the ranged-weapon fire-rate fix and writes patches/weapon-firerate.patch.json.
  Reads expected bytes from the user's own Prison Architect64.exe (preferring the .orig backup).

  Bug: Entity::FireRangedShot (FUN_140537930) sets ReloadTimer = 2.0 after EVERY shot, and the
  NPC attack routine (FUN_1405370f0) will not count down AttackTimer while ReloadTimer > 0. So every
  ranged weapon fires at most once per two seconds plus its RechargeTime, and automatic weapons
  (RechargeTime 0.1) never fire automatically.

  The 2018 build of the game has the same routine with three values instead of one:
      AssaultRifle, SubMachineGun   0.02 s
      Tazer                         2.0 s
      every other weapon            0.7 s
  The later build kept only the Tazer's. Everything around it is unchanged between the builds: the
  NPC routine waits for ReloadTimer, then counts AttackTimer (= RechargeTime) down, and the Escape
  Mode player attack (FUN_140557310) fires when ReloadTimer <= 0.

  Fix (2.0.0): the store of 2.0 becomes a jump to a stub that stores the 2018 value for the weapon.
  Weapons are recognised by their definition pointer (r15 = EquipmentDef, 0x90 stride from
  [0x140DECCC0]): Tazer 0x25, AssaultRifle 0x2D, SubMachineGun 0x2E, and ModifiedAssaultRifle 0x68,
  the DLC automatic rifle, which is given the automatic value. Cadence for guards and prisoners is
  the value above plus RechargeTime: Gun 1.2 s, Shotgun 1.7 s, Rifle 2.7 s, AssaultRifle and
  SubMachineGun 0.12 s, Tazer 4 s. The reload countdown (FUN_140537d00) ejects the casing and plays
  the Reload_<weapon> sound when the timer runs out, as in 2018.

  Versions 1.0.0 and 1.1.0 removed the wait altogether (ReloadTimer 0, then 0.001) and replaced the
  Escape Mode gate with a stub that compared the time since the last shot with RechargeTime. That
  made non-automatic guns faster than they had ever been. 2.0.0 gives the Escape Mode gate its
  original bytes back, since with the 2018 values it behaves as it did in 2018, and clears the old
  stub from the .text cave. The older bytes are listed as "superseded" so the patcher recognises
  and upgrades an exe patched by those versions.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/weapon-firerate.patch.json'),
    [string] $SectionPatch = (Join-Path $PSScriptRoot '../patches/code-section.patch.json'),
    [int] $StubAt = 0x920
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
Write-Host "reading $src"
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
# $superseded: the bytes each earlier release left at this site, newest first (1.1.0, then 1.0.0).
function AddEdit([long]$va, [byte[]]$new, [string]$note, [string[]]$superseded) {
    $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]
    $e = [ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note }
    if ($superseded) { $e.superseded = @($superseded | ForEach-Object { $h = ($_ -replace '\s',''); if ($h.Length -ne $new.Length * 2) { throw ("superseded bytes must match the edit length at 0x{0:X}" -f $va) }; $h }) }
    $edits.Add($e)
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

$EQUIP     = 0x140DECCC0   # EquipmentDef array pointer, 0x90 stride
$HOOK      = 0x140537CC5   # mov dword [rbx+0x34c], 2.0f   (10 bytes)
$RESUME    = 0x140537CCF   # mov eax,[r15+0x50] ...
$GATE      = 0x140557372   # Escape Mode attack gate, 16 bytes
$CAVE_STUB = 0x140A443C0   # 63 bytes of the .text cave used by 1.0.0 / 1.1.0
$STUB      = $SEC_VA + $StubAt

# ---- stub: ReloadTimer by weapon. rbx = shooter, r15 = EquipmentDef. rax and rcx are dead here:
#      the instruction before the hook stored rax, the one after loads eax. ----
NewBlock $STUB
Ref32 '48 8B 05' $EQUIP                   # mov rax,[EquipmentDefs]
Emit '49 8B CF'                           # mov rcx,r15
Emit '48 2B C8'                           # sub rcx,rax              offset of the weapon's definition
Emit 'B8 00 00 00 40'                     # mov eax,2.0f             Tazer 0x25
Emit '48 81 F9 D0 14 00 00'               # cmp rcx,0x25*0x90
Ref8 '74' 'store'
Emit 'B8 0A D7 A3 3C'                     # mov eax,0.02f            automatic weapons
Emit '48 81 F9 50 19 00 00'               # cmp rcx,0x2D*0x90        AssaultRifle
Ref8 '74' 'store'
Emit '48 81 F9 E0 19 00 00'               # cmp rcx,0x2E*0x90        SubMachineGun
Ref8 '74' 'store'
Emit '48 81 F9 80 3A 00 00'               # cmp rcx,0x68*0x90        ModifiedAssaultRifle
Ref8 '74' 'store'
Emit 'B8 33 33 33 3F'                     # mov eax,0.7f             everything else
Label 'store'
Emit '89 83 4C 03 00 00'                  # mov [rbx+0x34c],eax      ReloadTimer
Ref32 'E9' $RESUME
$stubBytes = CloseBlock

$HOOK_V110 = 'C7834C0300006F12833A'       # 1.1.0: ReloadTimer = 0.001
$HOOK_V100 = 'C7834C03000000000000'       # 1.0.0: ReloadTimer = 0
$GATE_OLD  = 'E949D04E009090909090909090909090'
$CAVE_OLD  = '488BCB488D542440E8E328AFFFF30F5A4850488B0527353100488B8098010000F20F108080000000F20F5C8310030000660F2FC10F822830B1FFE9832FB1FF'
$free      = 'CC' * $stubBytes.Length     # the section bytes 1.0.0 and 1.1.0 left alone

AddEdit $HOOK (JmpHook $HOOK $STUB 10) 'FireRangedShot: ReloadTimer by weapon (2018 values) instead of 2.0 s for all' @($HOOK_V110, $HOOK_V100)
AddEdit $STUB $stubBytes 'stub: ReloadTimer 0.02 automatic rifles, 2.0 Tazer, 0.7 others' @($free, $free)
# Sites 1.0.0 and 1.1.0 changed and 2.0.0 gives back: replace equals the original bytes.
$gateOrig = $b[(VaToFile $GATE)..((VaToFile $GATE) + 15)]
$caveOrig = $b[(VaToFile $CAVE_STUB)..((VaToFile $CAVE_STUB) + 62)]
AddEdit $GATE $gateOrig 'escape-mode attack: original ReloadTimer gate (1.x replaced it)' @($GATE_OLD, $GATE_OLD)
AddEdit $CAVE_STUB $caveOrig '.text cave: the 1.x escape-mode gate stub is removed' @($CAVE_OLD, $CAVE_OLD)

$expectOrig = @{ $HOOK = 'C7834C03000000000040'; $GATE = '0F57C00F2F834C0300000F82A0000000' }
foreach ($e in $edits) {
    $va = [long]$e.va
    if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }
    if ($va -eq $CAVE_STUB -and ($e.expect -replace '0','') -ne '') { throw "cave not empty at $($e.va)" }
    if ($va -ge $SEC_VA -and ($e.expect -replace 'CC','') -ne '') { throw ("section bytes at 0x{0:X} are not free" -f $va) }
}

$p = [byte[]]$b.Clone()
foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()

$doc = [ordered]@{
    id              = 'weapon-firerate'
    name            = 'Ranged weapon fire-rate fix'
    version         = '2.0.0'
    requires        = @('code-section')
    description     = 'Every ranged weapon waited two seconds after each shot, so assault rifles and SMGs never fired automatically. The 2018 version of the game waited 0.02 s for automatic weapons, 2 s for the Tazer and 0.7 s for everything else; those values are restored, for guards, prisoners and Escape Mode. Version 2.0.0: earlier versions removed the wait completely, which made pistols, shotguns and rifles fire faster than they ever did.'
    game_build      = 'Prison Architect 64-bit, Sunset Update (final)'
    sha256_original = $sha
    sha256_patched  = $shaP
    edits           = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("stub @ .tyrs+0x{0:X} ({1} bytes) ends +0x{2:X}" -f $StubAt, $stubBytes.Length, ($StubAt + $stubBytes.Length))
Write-Host "patched sha256 (with code-section): $shaP"
Write-Host "wrote $Out ($($edits.Count) edits)"
