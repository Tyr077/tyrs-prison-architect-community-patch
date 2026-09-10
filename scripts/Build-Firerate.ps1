<#
  Build-Firerate.ps1
  Assembles the ranged-weapon fire-rate fix and writes patches/weapon-firerate.patch.json.
  Reads expected bytes from the user's own Prison Architect64.exe (preferring the .orig backup).

  Bug: Entity::FireRangedShot (FUN_140537930) sets ReloadTimer = 2.0 after EVERY shot, and the
  NPC attack routine will not count down AttackTimer while ReloadTimer > 0. So every ranged weapon
  fires at most once per two seconds and RechargeTime (0.1 for the assault rifle) is ignored.

  Fix:
    1. FireRangedShot stores ReloadTimer = 0. NPC cadence becomes RechargeTime via AttackTimer.
    2. The escape-mode player attack (FUN_140557310) gated on ReloadTimer, so it would now fire
       without limit. Its gate is replaced by a stub that compares the time since the last shot
       (Entity+0x310, set by FireRangedShot) with the weapon's RechargeTime.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/weapon-firerate.patch.json')
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

$APP           = 0x140D57900
$FN_GetEquipDef = 0x140536CB0   # EquipmentDef* Entity::GetEquipmentDef(entity*, int* outType)

$script:labels = @{}
function Asm([long]$base, [object[]]$items) {
    $pc = $base
    foreach ($it in $items) { if ($it -is [string]) { $script:labels[$it] = $pc; continue }; if ($it -is [hashtable]) { $pc += $it.pre.Length + 4 } else { $pc += $it.Length } }
    $outb = New-Object System.Collections.Generic.List[byte]; $pc = $base
    foreach ($it in $items) {
        if ($it -is [string]) { continue }
        if ($it -is [hashtable]) { $to = $it.to; if ($to -is [string]) { $to = $script:labels[$to] }; if ($null -eq $to) { throw "unresolved label $($it.to)" }
            $len = $it.pre.Length + 4; $rel = [long]$to - ($pc + $len); $outb.AddRange([byte[]]$it.pre); $outb.AddRange([byte[]](LE32 $rel)); $pc += $len }
        else { $outb.AddRange([byte[]]$it); $pc += $it.Length }
    }
    return ,$outb.ToArray()
}
function J([string]$cc, $to) { $pre = switch ($cc) { 'jmp' {@(0xE9)} 'call' {@(0xE8)} 'jb' {@(0x0F,0x82)} 'jne' {@(0x0F,0x85)} }; return @{ pre = [byte[]]$pre; to = $to } }
function RipMovRax([long]$abs) { return @{ pre = [byte[]]@(0x48,0x8B,0x05); to = $abs } }

$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) {
    $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]
    $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}

# ---- Stub: escape-mode player attack gate. rbx = entity. Frame has shadow space; [rsp+0x40] is scratch. ----
$stubAddr = 0x140A443C0      # remaining slack after the hand-off fix (ends 0x140A44400)
$stub = Asm $stubAddr @(
    (Bytes '48 8B CB'),                    # mov rcx, rbx
    (Bytes '48 8D 54 24 40'),              # lea rdx, [rsp+0x40]
    (J 'call' $FN_GetEquipDef),            # rax = equipment def
    (Bytes 'F3 0F 5A 48 50'),              # cvtss2sd xmm1, dword [rax+0x50]   (RechargeTime)
    (RipMovRax $APP), (Bytes '48 8B 80 98 01 00 00'),   # rax = World
    (Bytes 'F2 0F 10 80 80 00 00 00'),     # movsd xmm0, [rax+0x80]           (world time)
    (Bytes 'F2 0F 5C 83 10 03 00 00'),     # subsd xmm0, [rbx+0x310]          (- last shot time)
    (Bytes '66 0F 2F C1'),                 # comisd xmm0, xmm1
    (J 'jb' 0x140557422),                  # elapsed < RechargeTime -> return path
    (J 'jmp' 0x140557382)                  # otherwise continue the attack
)
$stubEnd = $stubAddr + $stub.Length
if ($stubEnd -gt 0x140A44400) { throw ("stub overflows cave: end 0x{0:X}" -f $stubEnd) }

# 1. FireRangedShot: ReloadTimer = 2.0f -> 0.0f  (mov dword [rbx+0x34c], imm32)
AddEdit 0x140537CC5 (Bytes 'C7 83 4C 03 00 00 00 00 00 00') 'FireRangedShot: ReloadTimer = 0 instead of 2.0 s'
# 2. Escape-mode attack gate: "xorps xmm0,xmm0; comiss xmm0,[rbx+0x34c]; jc ret" (16 bytes) -> jmp stub + nops
$hook = New-Object System.Collections.Generic.List[byte]
$hook.AddRange([byte[]](Asm 0x140557372 @((J 'jmp' $stubAddr))))
while ($hook.Count -lt 16) { $hook.Add([byte]0x90) }
AddEdit 0x140557372 ($hook.ToArray()) 'escape-mode attack: gate on time since last shot >= RechargeTime'
AddEdit $stubAddr $stub 'stub: escape-mode fire-rate gate'

$expectOrig = @{ 0x140537CC5 = 'C7834C03000000000040'; 0x140557372 = '0F57C00F2F834C0300000F82A0000000' }
foreach ($e in $edits) {
    $va = [long]$e.va
    if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) }
    if ($va -ge 0x140A44256 -and ($e.expect -replace '0','') -ne '') { throw "cave not empty at $($e.va)" }
}

$p = [byte[]]$b.Clone()
foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()

$doc = [ordered]@{
    id              = 'weapon-firerate'
    name            = 'Ranged weapon fire-rate fix'
    version         = '1.0.0'
    description     = 'Every ranged weapon was limited to one shot per two seconds regardless of its RechargeTime, so assault rifles and SMGs never fired automatically. Restores RechargeTime as the rate of fire for guards and prisoners, including in Escape Mode.'
    game_build      = 'Prison Architect 64-bit, Sunset Update (final)'
    sha256_original = $sha
    sha256_patched  = $shaP
    edits           = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("stub @ 0x{0:X} ({1} bytes) ends 0x{2:X}" -f $stubAddr, $stub.Length, $stubEnd)
Write-Host "patched sha256: $shaP"
Write-Host "wrote $Out ($($edits.Count) edits)"
