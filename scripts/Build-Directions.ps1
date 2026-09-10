<#
  Build-Directions.ps1
  Assembles the direction / byte-field save fix and writes patches/direction-save.patch.json.
  Reads expected bytes from the user's own Prison Architect64.exe (preferring the .orig backup).

  Bug: DataRegistry fields registered with type 3 (a single byte: the tile's PrisonDir and StaffDir,
  the skin and clothing colour bytes of visitors and civilians, particle colours) are written into the
  save tree as node type 3. Directory::WritePlainText (FUN_140165350) only knows node types 1, 2, 4, 5
  and 7, logs "Directory ERROR : Writing Plain Text, unsupported data type" and writes the key with
  no value. The plain-text reader then drops the key ("Unexpected EOL reading corresponding value").
  So prisoner and staff directions, among others, are lost on every save.

  Fix: DataRegistry::Write (FUN_1401c3910) case 3 emits an int node instead. The value was already
  zero-extended into EBX; the int store is the same length as the byte store. The reader side is
  untouched: DataRegistry::Read case 3 goes through Node::GetAsNumber, which accepts int nodes, and
  narrows back to the byte. Two instructions, in place, no code cave.

  Discovered independently by vojin154 (pa_fix_direction_serialization), whose fix changes the two tile
  registrations to type 1 at runtime. This patch fixes the writer instead so every byte field is covered
  and no 4-byte access is made to a 1-byte field.
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $Out = (Join-Path $PSScriptRoot '../patches/direction-save.patch.json')
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

$edits = New-Object System.Collections.Generic.List[object]
function AddEdit([long]$va, [byte[]]$new, [string]$note) {
    $off = VaToFile $va; $old = $b[$off..($off + $new.Length - 1)]
    $edits.Add([ordered]@{ va = ('0x{0:X}' -f $va); offset = $off; expect = (Hex $old); replace = (Hex $new); note = $note })
}

# DataRegistry::Write, case 3 (byte field), at 0x1401C3C64:
#   mov rax,[rsi+8] ; movzx ebx,byte [rax] ; lea rdx,[rsi+0x58] ; mov rcx,r13 ; call Node::GetOrAdd
#   0x1401C3C77  C7 40 20 03 00 00 00   mov dword [rax+0x20], 3     ; node type = char
#   0x1401C3C7E  88 58 2C               mov byte  [rax+0x2C], bl    ; char slot
# becomes
#   0x1401C3C77  C7 40 20 01 00 00 00   mov dword [rax+0x20], 1     ; node type = int
#   0x1401C3C7E  89 58 24               mov dword [rax+0x24], ebx   ; int slot (ebx is zero-extended)
AddEdit 0x1401C3C77 (Bytes 'C7 40 20 01 00 00 00  89 58 24') 'DataRegistry::Write: emit byte fields as int nodes so the plain-text save writer keeps them'

$expectOrig = @{ 0x1401C3C77 = 'C740200300000088582C' }
foreach ($e in $edits) { $va = [long]$e.va; if ($expectOrig.ContainsKey($va) -and $e.expect -ne $expectOrig[$va]) { throw ("site 0x{0:X}: found {1}, expected {2}" -f $va, $e.expect, $expectOrig[$va]) } }

$p = [byte[]]$b.Clone()
foreach ($e in $edits) { $nb = Bytes $e.replace; for ($i = 0; $i -lt $nb.Count; $i++) { $p[$e.offset + $i] = $nb[$i] } }
$shaP = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($p)).Replace('-','').ToLower()

$doc = [ordered]@{
    id              = 'direction-save'
    name            = 'Prisoner and staff directions not saved'
    version         = '1.0.0'
    description     = 'Tile directions for prisoners and staff (and every other single-byte field, such as visitor skin and clothing colours) were written to the save file without a value and silently dropped on load. The save writer now stores these fields as plain numbers, which the loader already understands.'
    game_build      = 'Prison Architect 64-bit, Sunset Update (final)'
    sha256_original = $sha
    sha256_patched  = $shaP
    edits           = $edits
}
[System.IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 5) + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "patched sha256: $shaP"
Write-Host "wrote $Out ($($edits.Count) edits)"
