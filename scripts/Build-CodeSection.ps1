<#
  Build-CodeSection.ps1
  Writes patches/code-section.patch.json: a hidden base patch that appends a 4 KiB read/write/execute
  section ".tyrs" to the executable for fixes that need new code or data. The .text slack cave used by
  the first fixes is full. Patches that need room declare  "requires": ["code-section"]  and the patcher
  applies this first and removes it again when nothing depends on it.

  PE facts for this build (see docs/code-section.md): e_lfanew 0x148, 8 sections, section table at 0x250,
  9th header slot at 0x390 is free, SizeOfImage 0xE89000, last section .rsrc at VA 0xE80000,
  file length 0xDC1C00, no Authenticode signature, no Control Flow Guard.
  New section: VA 0x140E89000, raw offset 0xDC1C00, 0x1000 bytes, filled with INT3 (0xCC).
  Layout: +0x000..+0x0FF data (globals for patches), +0x100.. code. Allocations are listed in the doc.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/code-section.patch.json')
)
$ErrorActionPreference = 'Stop'
$src = $Exe; if (Test-Path -LiteralPath ($Exe + '.orig')) { $src = $Exe + '.orig' }
$b = [System.IO.File]::ReadAllBytes($src)
$sha = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower()
if ($sha -ne 'cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9') { Write-Warning "Unexpected build hash $sha" }
if ($b.Length -ne 0xDC1C00) { throw "unexpected file length $($b.Length)" }
function Hex([byte[]]$a) { ($a | ForEach-Object { '{0:X2}' -f $_ }) -join '' }
function LE32([long]$v) { [BitConverter]::GetBytes([uint32]($v -band 4294967295)) }
$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([string]$va, [int]$off, [byte[]]$new, [string]$note) {
    $old = if ($off -ge $b.Length) { [byte[]]@() } else { $b[$off..($off + $new.Length - 1)] }
    $edits.Add([ordered]@{ va = $va; offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}
$pe = [BitConverter]::ToInt32($b, 0x3C); $opt = $pe + 24; $secTab = $opt + [BitConverter]::ToUInt16($b, $pe + 20)
if ($pe -ne 0x148 -or [BitConverter]::ToUInt16($b, $pe + 6) -ne 8) { throw 'PE layout differs from the expected build' }
AddEdit 'hdr:NumberOfSections' ($pe + 6) ([byte[]](0x09, 0x00)) 'NumberOfSections 8 -> 9'
AddEdit 'hdr:SizeOfImage' ($opt + 56) (LE32 0xE8A000) 'SizeOfImage 0xE89000 -> 0xE8A000'
$hdr = New-Object System.Collections.Generic.List[byte]
$hdr.AddRange([byte[]][System.Text.Encoding]::ASCII.GetBytes('.tyrs'.PadRight(8, [char]0)))
$hdr.AddRange([byte[]](LE32 0x1000)); $hdr.AddRange([byte[]](LE32 0xE89000)); $hdr.AddRange([byte[]](LE32 0x1000)); $hdr.AddRange([byte[]](LE32 0xDC1C00))
$hdr.AddRange([byte[]](LE32 0)); $hdr.AddRange([byte[]](LE32 0)); $hdr.AddRange([byte[]](0, 0, 0, 0)); $hdr.AddRange([byte[]](LE32 0xE0000020))
if ($hdr.Count -ne 40) { throw 'header size' }
AddEdit 'hdr:section9' ($secTab + 8 * 40) ($hdr.ToArray()) 'section header .tyrs: VA 0xE89000, raw 0xDC1C00, 0x1000 bytes, code+RWX'
$fill = New-Object byte[] 0x1000; for ($i = 0; $i -lt $fill.Length; $i++) { $fill[$i] = 0xCC }
AddEdit '0x140E89000' $b.Length $fill 'appended section body, INT3-filled; patches that require this write into it'
$p = New-Object byte[] ($b.Length + 0x1000); [Array]::Copy($b, $p, $b.Length)
foreach ($e in $edits) { $nb = ($e.replace -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }); for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()
$doc = [ordered]@{
    id = 'code-section'; name = 'Code section for patches'; version = '1.0.0'; hidden = $true
    description = 'Adds an empty 4 KiB section to the executable so other fixes have room for new code. Applied automatically when a fix needs it and removed when none does.'
    game_build = 'Prison Architect 64-bit, Sunset Update (final)'; sha256_original = $sha; sha256_patched = $shaP; edits = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"; Write-Host "wrote $Out ($($edits.Count) edits)"
