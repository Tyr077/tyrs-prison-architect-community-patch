<#
  Build-ArmedGuardWarnings.ps1
  Writes patches/armed-guard-warnings.patch.json.

  Guards decide once per engagement whether to shout a warning or attack, in the combat step
  FUN_1405D7680. For an armed guard the warning chance starts at 0.7 (0.8 when it is the prisoner's own
  attacker; 0.4 or 0 when another staff member is already fighting the prisoner close by), is cut to a
  fifth when the guard is more than half dead, and is zeroed when the prisoner is flagged to be fired on
  at sight or when the guard itself is pissed off (Staff+0xA88, recomputed every tick from its needs
  while Staff Needs is on). Then, only with Staff Needs on, the chance is multiplied by the global staff
  morale percentage (World+0x2064, the top-bar figure). At 0% morale no armed guard ever warns; at 50%
  half as often as it should. That is the behaviour reported in issue #1: with Staff Needs on, armed
  guards fire without warning even when their own needs are met.

  Fix: skip the global-morale multiply. The branch that tests the Staff Needs option before the multiply
  becomes an unconditional jump to the code after it. The per-guard pissed-off test and everything else
  in the decision stay as they were, so a guard whose own needs are neglected still fires without
  warning, and Staff Needs off is unchanged.

  Site 0x1405D7DED:  74 15   jz 0x1405D7E04    (taken when StaffNeeds is off)
  New:               EB 15   jmp 0x1405D7E04   (always)

  The skipped instructions (0x1405D7DEF..0x1405D7E03): movss xmm0,[r11+0x2064] / mulss xmm0,[0.01] /
  mulss xmm6,xmm0. xmm0 is scratch there; xmm6 is the chance, left as computed.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/armed-guard-warnings.patch.json')
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$b = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }
function VaToFile([long]$va) { return [int]($va - 0x140000C00) }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function Bytes([string]$hex) { ,@(($hex -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }
$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) { $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]; $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note }) }

AddEdit 0x1405D7DED (Bytes 'EB 15') 'guard combat step: skip the multiply of the warning chance by global staff morale (jz -> jmp over it)'

# The bytes we jump over must be the multiply we mean to skip, or the site has moved.
$ctx = Hex $b[(VaToFile 0x1405D7DE5)..((VaToFile 0x1405D7E04) - 1)]
$expectCtx = '4180BBE946000000' + '7415' + 'F3410F1083642000' + '00F30F5905B4335400' + 'F30F59F0'
if ($ctx -ne $expectCtx) { throw "context at 0x1405D7DE5 is $ctx, expected $expectCtx" }

$expectOrig = @{ 0x1405D7DED = '7415' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'armed-guard-warnings'; name = 'Armed guard warnings with Staff Needs'; version = '1.0.0'
    description = 'With Staff Needs on, an armed guard''s chance to shout a warning before opening fire was multiplied by the prison''s overall staff morale, so at low morale armed guards shot without warning whatever the state of the guard itself. The chance no longer depends on overall morale. A guard whose own needs are neglected still skips the warning, and with Staff Needs off nothing changes.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
