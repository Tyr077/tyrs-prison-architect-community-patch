<#
  Apply-ExePatch.ps1
  Applies a byte-level patch to the user's own Prison Architect64.exe.
  Ships no game code: only offsets, the bytes expected at each offset, and
  the replacement bytes. Refuses to write unless every expected byte matches;
  a SHA256 mismatch only warns, so a different build that happens to have the
  same bytes at every site would still be patched.

  Usage:
    .\Apply-ExePatch.ps1                 # verify + dry run
    .\Apply-ExePatch.ps1 -Apply          # patch (backup made first)
    .\Apply-ExePatch.ps1 -Revert         # restore from backup
    .\Apply-ExePatch.ps1 -Status         # report patched / unpatched
#>
[CmdletBinding()]
param(
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe',
    [string] $PatchFile = (Join-Path $PSScriptRoot '../patches/gang-handoff.patch.json'),
    [switch] $Apply,
    [switch] $Revert,
    [switch] $Status
)
$ErrorActionPreference = 'Stop'
$backup = "$Exe.orig"

if ($Revert) {
    if (-not (Test-Path -LiteralPath $backup)) { throw "No backup at $backup" }
    Copy-Item -LiteralPath $backup -Destination $Exe -Force
    Write-Host "Restored original from $backup"
    return
}

if (-not (Test-Path -LiteralPath $Exe))       { throw "Not found: $Exe" }
if (-not (Test-Path -LiteralPath $PatchFile)) { throw "Not found: $PatchFile" }

$patch = Get-Content -LiteralPath $PatchFile -Raw | ConvertFrom-Json
$b = [System.IO.File]::ReadAllBytes($Exe)

# Sanity: the patch is tied to one exact build.
$sha = (Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash.ToLower()
$isOrig = ($sha -eq $patch.sha256_original.ToLower())
$isPatched = ($patch.sha256_patched -and $sha -eq $patch.sha256_patched.ToLower())

function HexToBytes([string]$h) { ,@(($h -replace '\s','') -split '(..)' | Where-Object { $_ } | ForEach-Object { [byte]('0x' + $_) }) }

$allMatchOrig = $true; $allMatchNew = $true
foreach ($e in $patch.edits) {
    $off = [int]$e.offset
    $old = HexToBytes $e.expect
    $new = HexToBytes $e.replace
    if ($old.Count -ne $new.Count) { throw "Edit at 0x{0:X}: expect/replace length mismatch" -f $off }
    for ($i = 0; $i -lt $old.Count; $i++) {
        if ($b[$off + $i] -ne $old[$i]) { $allMatchOrig = $false }
        if ($b[$off + $i] -ne $new[$i]) { $allMatchNew  = $false }
    }
}

Write-Host "Exe:      $Exe"
Write-Host "SHA256:   $sha"
Write-Host ("Patch:    {0}  ({1} edit(s))" -f $patch.name, $patch.edits.Count)
if     ($allMatchNew)  { Write-Host "State:    PATCHED" }
elseif ($allMatchOrig) { Write-Host "State:    unpatched (original bytes present)" }
else                   { Write-Host "State:    UNKNOWN - bytes match neither original nor patched"; if (-not $Status) { throw "Refusing to touch an unrecognised binary." } }
if ($Status -or $allMatchNew) { return }
if (-not $isOrig) { Write-Host "WARNING: SHA256 does not match the build this patch was made for." }

foreach ($e in $patch.edits) {
    Write-Host ("  0x{0:X8}  {1}  ->  {2}   {3}" -f [int]$e.offset, $e.expect, $e.replace, $e.note)
}

if (-not $Apply) { Write-Host ""; Write-Host "Dry run. Re-run with -Apply to patch."; return }

if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $Exe -Destination $backup; Write-Host "Backup:   $backup" }
foreach ($e in $patch.edits) {
    $off = [int]$e.offset; $new = HexToBytes $e.replace
    for ($i = 0; $i -lt $new.Count; $i++) { $b[$off + $i] = $new[$i] }
}
[System.IO.File]::WriteAllBytes($Exe, $b)
Write-Host ("Applied.  New SHA256: {0}" -f (Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash.ToLower())
Write-Host "Note: Steam 'Verify integrity' will restore the original. Re-run -Apply afterwards."
