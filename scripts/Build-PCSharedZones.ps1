<#
  Build-PCSharedZones.ps1  (optional tweak)
  Writes patches/tweak-pc-shared-zones.patch.json.

  GitHub issue #3: Protective Custody prisoners walk into Shared sectors (and Custom sectors that include
  Protective Custody) but never take a job or attend a class there. The 2018 job finder (O:FUN_14045FD90)
  has no such rule; the 2018 counterparts of the other two sites below were not compared.

  Sunset applies one rule in three places: an entity whose zone type is ProtectedOnly (4) may only use a
  tile, a station, or a spot to take part from, in a sector whose zone (+0x64) is ProtectedOnly. Zone names are the table at
  DAT_140DFA070: 0 Shared, 1 MinSecOnly, 2 MedSecOnly, 3 MaxSecOnly, 4 ProtectedOnly, 5 SuperMaxOnly,
  6 DeathRowOnly, 7 InsaneSecOnly, 8 StaffOnly, 9 Unlocked, 10 Custom, 11 VisitorOnly. A prisoner's
  zone type comes from its Category (FUN_140536960 -> FUN_14070F370), Protected -> 4.

  1. Tile check FUN_14070E020(sectors, x, y, entity), used by the job finder for every job's tile, by
     station registration FUN_14070E360, by Entity::TryPassThroughDoor FUN_140533FF0 and by a few
     Escape Mode and prisoner job routines. Before its normal zone test FUN_14070E0D0 (which already
     accepts Shared and Unlocked, a Custom sector with the entity's category ticked, and the matching
     "Only" zone) it returns false for zone type 4 whenever the tile's sector is not ProtectedOnly.
  2. Job finder FUN_140796DD0 ("AssignJob"), prisoner block: the prisoner's Station sector
     (Entity+0x328, the .i half of Station.i/.u at +0x324) must be ProtectedOnly when Category
     (+0xA34) is Protected.

  3. Program and job step FUN_140547810 (called by the in-class handler FUN_140633350, the job system
     FUN_140791480 and FUN_1405D46E0): a Protected prisoner (+0xA34 == 4) standing in a sector that is
     not ProtectedOnly returns 0. This is what kept Protective Custody students out of classes: in the
     issue #3 save the same 51 students of the 09:00 sessions sat in class 50/51 while SuperMax and 0/51
     once switched to Protective Custody, on the unpatched build and on the build with only sites 1 and 2.

  Shared and Custom sectors are refused in all three, so a Protective Custody prisoner gets a station in a
  Shared sector (the station picker FUN_14070D5A0 has no such rule) but never a job there. Measured on
  the issue #3 save: 129 of 228 Protected prisoners held a station, none a job. The 2018 job finder
  (O:FUN_14045FD90) has no such rule.

  Shipped as an optional tweak (Mike's decision), not a fix: the final version may have meant it as a safety
  rule, even though the 2018 job finder has no such rule and the deployment help text says Protective
  Custody prisoners use Shared sector rooms when their needs are not met in their own sector.

  Tweak: skip the Protective Custody rule at all three sites, so Protective Custody is handled like every other
  category: FUN_14070E0D0 and the sector permission FUN_14070EFE0 still decide, so a Protective
  Custody prisoner works and attends programs only where its deployment lets it go.

  Site 0x14070E05B:  75 19   jnz 0x14070E076   (taken when the zone type is not 4)
  New:               EB 19   jmp 0x14070E076   (always)
  Skipped (0x14070E05D..0x14070E075): sector at the tile, cmp [rax+0x64],r11d / return false.

  Site 0x14079784F:  75 0A   jnz 0x14079785B   (taken when the prisoner is not Protective Custody)
  New:               EB 0A   jmp 0x14079785B   (always)
  Skipped (0x140797851..0x14079785A): cmp dword [rbx+0x64],4 / jnz 0x140798555 (reject).

  Site 0x14054791A:  75 52   jnz 0x14054796E   (taken when the prisoner is not Protective Custody)
  New:               EB 52   jmp 0x14054796E   (always)
  Skipped (0x14054791C..0x14054796D): sector at the prisoner's tile, cmp [rbx+0x64],4 / jmp 0x14054840E
  (return 0). RBX is only set inside the skipped block and not read after 0x14054796E.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\projects\tools\pa-test\game\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/tweak-pc-shared-zones.patch.json')
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

AddEdit 0x14070E05B (Bytes 'EB 19') 'tile check: skip the "Protective Custody only in ProtectedOnly sectors" rule (jnz -> jmp over it)'
AddEdit 0x14079784F (Bytes 'EB 0A') 'job finder: skip the same rule for the station sector (jnz -> jmp over it)'
AddEdit 0x14054791A (Bytes 'EB 52') 'program and job step: skip the same rule for the sector the prisoner stands in (jnz -> jmp over it)'

# The category tests before the sites and the zone tests we jump over must be the ones we mean, or the sites have moved.
$ctx = Hex $b[(VaToFile 0x14070E050)..((VaToFile 0x14070E076) - 1)]
$expectCtx = 'E80B89E2FF' + '448BD8' + '83F804' + '7519' + '8BD6488BCD' + 'E8E9EDFFFF' + '4885C0740A' + '44395864' + '7404' + '32C0EB3B'
if ($ctx -ne $expectCtx) { throw "context at 0x14070E050 is $ctx, expected $expectCtx" }
$ctx = Hex $b[(VaToFile 0x140797847)..((VaToFile 0x14079785B) - 1)]
$expectCtx = '4183BE340A000004' + '750A' + '837B6404' + '0F85FA0C0000'
if ($ctx -ne $expectCtx) { throw "context at 0x140797847 is $ctx, expected $expectCtx" }

$ctx = Hex $b[(VaToFile 0x14054790D)..((VaToFile 0x14054796E) - 1)]
$expectCtx = '837F406D' + '755B' + '83BF340A000004' + '7552' + 'F3440F2C474C' + 'F30F2C5748' + '488B05D2FF8000' + '488B8898010000' + '4881C1101D0000' + 'E80F551C00' + '488BD8' + '4885C07425' + 'B201B903000000' + 'E8FBF1C7FF' + '84C0740B' + '837B6404740F' + 'E9AA0A0000' + '837B6404' + '0F85A00A0000'
if ($ctx -ne $expectCtx) { throw "context at 0x14054790D is $ctx, expected $expectCtx" }

$expectOrig = @{ 0x14070E05B = '7519'; 0x14079784F = '750A'; 0x14054791A = '7552' }
foreach ($e in $edits) { $va = [long]$e.va; if ($e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }
$p = [byte[]]$b.Clone(); foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'tweak-pc-shared-zones'; name = 'Protective Custody prisoners work and attend programs in shared sectors'; version = '1.0.0'
    optional = $true
    description = 'Protective Custody prisoners take jobs and go to classes in Shared sectors, and in Custom sectors that include Protective Custody, not only in Protective Custody Only sectors. Keeping them apart from general population is then up to your deployment and regimes.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
