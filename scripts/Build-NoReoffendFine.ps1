<#
  Build-NoReoffendFine.ps1  (optional tweak)
  Writes patches/tweak-no-reoffend-fine.patch.json.

  Every released prisoner gets a record with a rolled "will reoffend" status. Two days after release,
  FUN_140753a40 turns "WillReoffend" into "Reoffended" and charges a flat $5000 "parole_fine" via the
  finance system (FUN_1405a0470), then subtracts 5000 from the running fines total at World+0x860.
  This tweak removes the charge and the total update but keeps the status change, so reoffending is
  still tracked, the prisoner can still return, and the reform reward is untouched.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/tweak-no-reoffend-fine.patch.json')
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
# 0x140753C0B  E8 60 C8 E4 FF   call FUN_1405a0470 (charge -5000 "parole_fine")   -> 5-byte NOP
AddEdit 0x140753C0B (Bytes '0F 1F 44 00 00') 'skip the 5000 parole_fine finance charge'
# 0x140753C5C  F3 41 0F 5C C0   subss xmm0, xmm8 (fines total -= 5000)          -> 5-byte NOP
AddEdit 0x140753C5C (Bytes '0F 1F 44 00 00') 'do not add the fine to the running fines total'
$expectOrig = @{ 0x140753C0B = 'E860C8E4FF'; 0x140753C5C = 'F3410F5CC0' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'tweak-no-reoffend-fine'; name = 'No reoffending fine (Second Chances)'; version = '1.0.0'; optional = $true
    description = 'Removes the flat $5,000 charge when a released prisoner reoffends.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
