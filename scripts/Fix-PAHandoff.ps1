<#
  Fix-PAHandoff.ps1
  Clears a stalled gang contraband-handoff in a Prison Architect (PA1) save.

  The global "BEGIN Contraband" block is serialised, so a save/reload does NOT
  clear it. This resets the pinned handoff so the system re-picks a valid pair.

  Usage:
    .\Fix-PAHandoff.ps1                      # dry run on newest save
    .\Fix-PAHandoff.ps1 -Apply               # write the fix (makes a backup)
    .\Fix-PAHandoff.ps1 -Apply -UncorruptGuards
    .\Fix-PAHandoff.ps1 -Path "C:\path\to\my.prison" -Apply
#>
[CmdletBinding()]
param(
    [string] $Path,
    [switch] $Apply,
    [switch] $UncorruptGuards
)

$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $saveDir = Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect\saves'
    $newest = Get-ChildItem -Path $saveDir -Filter *.prison |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { throw "No .prison files found in $saveDir" }
    $Path = $newest.FullName
}
if (-not (Test-Path -LiteralPath $Path)) { throw "Save not found: $Path" }
Write-Host "Save: $Path"

$lines = [System.IO.File]::ReadAllLines($Path)

# Values to write. -1 matches the game's own "no object" sentinel
# (see DealerId.i -1 in the Gangs Territory block).
$reset = [ordered]@{
    'ObjectIndex'       = '-1'
    'HandOffGuard.i'    = '-1'
    'HandOffGuard.u'    = '-1'
    'chosenContraband'  = '-1'
    'handOffTimer'      = '0.0000000'
    'triedHandOffToday' = 'false'
}

$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^BEGIN Contraband\s*$') { $start = $i; break }
}
if ($start -lt 0) { throw "No 'BEGIN Contraband' block in this save." }

$end = -1
for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^END\s*$') { $end = $i; break }
}
if ($end -lt 0) { throw "Unterminated Contraband block." }

$changes = 0
for ($i = $start + 1; $i -lt $end; $i++) {
    if ($lines[$i] -match '^\s{4}(\S+)\s+(.*?)\s*$') {
        $name = $Matches[1]; $old = $Matches[2]
        if ($reset.Contains($name)) {
            $new = $reset[$name]
            if ($old -ne $new) {
                Write-Host ("  {0,-20} {1,-14} -> {2}" -f $name, $old, $new)
                # 4-space indent, name column padded to 21, two trailing spaces
                $lines[$i] = '    ' + $name.PadRight(21) + $new + '  '
                $changes++
            }
        }
    }
}

if ($UncorruptGuards) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s{8}Corrupted\s+true\s*$') {
            $lines[$i] = '        ' + 'Corrupted'.PadRight(21) + 'false' + '  '
            Write-Host ("  Corrupted            true           -> false  (line {0})" -f ($i + 1))
            $changes++
        }
    }
}

if ($changes -eq 0) { Write-Host "Nothing to change; handoff state already clean."; return }

if (-not $Apply) {
    Write-Host ""
    Write-Host "$changes change(s) staged. Dry run only. Re-run with -Apply to write."
    return
}

$backup = "$Path.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item -LiteralPath $Path -Destination $backup
Write-Host "Backup: $backup"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$nl = [Environment]::NewLine   # save file is CRLF throughout
[System.IO.File]::WriteAllText($Path, ($lines -join $nl) + $nl, $utf8NoBom)
Write-Host "Applied $changes change(s)."
