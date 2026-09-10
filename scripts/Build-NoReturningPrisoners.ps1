<#
  Build-NoReturningPrisoners.ps1  (optional tweak)
  Writes patches/tweak-no-returning-prisoners.patch.json.

  When a new prisoner is generated, FUN_1406a8920 scans the released-prisoner records for one in the
  "Reoffended" state (ReleaseStatus == 4) and, with a 40% chance keyed on the record id, re-creates that
  exact prisoner from the data tree stored in the record: name, traits, reputations and all. That is how
  an Extremely Deadly, Extremely Volatile Min Sec arrives through normal intake. This tweak makes the
  state comparison never match, so intake always generates a fresh prisoner by the normal rules.
  Records still move to "Reoffended", so the reoffending statistics and the fine are unaffected.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/tweak-no-returning-prisoners.patch.json')
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
# 0x1406A89E8  83 7E 34 04   cmp dword [rsi+0x34], 4 (ReleaseStatus == Reoffended)  ->  cmp ..., 0x7F (never)
AddEdit 0x1406A89E8 (Bytes '83 7E 34 7F') 'returning-prisoner scan: compare ReleaseStatus with an impossible value'
$expectOrig = @{ 0x1406A89E8 = '837E3404' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'tweak-no-returning-prisoners'; name = 'No returning prisoners (Second Chances)'; version = '1.0.0'; optional = $true
    description = 'Reoffended prisoners no longer come back through intake as the exact prisoner who left, traits and reputations included. Intake always generates prisoners by the normal category rules. Reoffending is still tracked and fined as before. Balance tweak, not a bug fix.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
