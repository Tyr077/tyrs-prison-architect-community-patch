<#
.SYNOPSIS
  Run one of the tools/ghidra-scripts/*.java scripts headlessly against the analysed game project
  (or a throwaway import of a patched copy) and write the result into analysis/.

.EXAMPLE
  .\scripts\Ghidra-Dump.ps1 DumpCallers registerlua 1407d65b0 14045b0e0
    -> analysis/registerlua.txt

  .\scripts\Ghidra-Dump.ps1 DumpClass classes Entity Prisoner Guard

  .\scripts\Ghidra-Dump.ps1 DumpAsmRange verify-x 0x14072DE00 0x14072DE20 -Exe C:\scratch\patched.exe
    -> imports the copy into a throwaway project (no analysis), disassembles, deletes the project.

  .\scripts\Ghidra-Dump.ps1 DumpStringRefs surrender ShoutWarning -Build 2018
    -> analysis/2018/surrender.txt, from the 2018 build's project (ghidra/PA2018.gpr).

  .\scripts\Ghidra-Dump.ps1 DumpAll full -Build 2018
    -> analysis/2018/full/decomp/*.c and index.tsv: every function decompiled, for grep.

.NOTES
  Ghidra location: $env:GHIDRA_HOME, else D:\projects\tools\ghidra_12.1.3_PUBLIC.
  JDK: $env:JAVA_HOME, else the Adoptium JDK 21 under Program Files.
  Displacements (DumpDisp, DumpDispSites, the disp of DumpSpriteIdxCallers) need a 0x prefix; DumpAsmRange,
  DumpCallers and DumpImmRefs accept one; the other scripts take bare hex (see tools/ghidra-scripts/README.md).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Script,
    [Parameter(Mandatory, Position = 1)] [string] $Name,
    [Parameter(Position = 2, ValueFromRemainingArguments)] [string[]] $ScriptArgs = @(),
    [string] $Exe,
    [ValidateSet('sunset', '2018')] [string] $Build = 'sunset',
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$ghidra = if ($env:GHIDRA_HOME) { $env:GHIDRA_HOME } else { 'D:\projects\tools\ghidra_12.1.3_PUBLIC' }
if (-not $env:JAVA_HOME) {
    $jdk = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
}
$headless = Join-Path $ghidra 'support\analyzeHeadless.bat'
if (-not (Test-Path $headless)) { throw "analyzeHeadless.bat not found under $ghidra (set GHIDRA_HOME)" }

$scriptPath = Join-Path $repo 'tools\ghidra-scripts'
$java = Join-Path $scriptPath ($Script + '.java')
if (-not (Test-Path $java)) { throw "No script $java" }

# The 2018 build (Steam beta prisonarchitect_anniversary_2018_version) is the project PA2018; its dumps go
# to analysis/2018/ so that a name can be used for the same dump of both builds.
$project = if ($Build -eq '2018') { 'PA2018' } else { 'PA' }
$outDir = if ($Build -eq '2018') { Join-Path $repo 'analysis\2018' } else { Join-Path $repo 'analysis' }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }
# DumpAll writes a directory (decomp/*.c and index.tsv), every other script one text file.
$isDir = $Script -eq 'DumpAll'
$out = if ([IO.Path]::IsPathRooted($Name)) { $Name } elseif ($isDir) { Join-Path $outDir $Name } else { Join-Path $outDir ($Name + '.txt') }

if ($Exe) {
    # Throwaway project for a patched copy: import without analysis, run, delete.
    $tmp = Join-Path $env:TEMP ('ghidra-verify-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory $tmp | Out-Null
    $args = @($tmp, 'Verify', '-import', $Exe, '-noanalysis', '-deleteProject')
} else {
    $args = @((Join-Path $repo 'ghidra'), $project, '-process', 'Prison Architect64.exe', '-noanalysis')
}
$args += @('-scriptPath', $scriptPath, '-postScript', ($Script + '.java'), $out) + $ScriptArgs

$log = & $headless @args 2>&1
if ($Exe) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
if (-not $Quiet) { $log | Where-Object { $_ -match 'ERROR|Exception|SCRIPT' } | ForEach-Object { Write-Host $_ } }
if ($isDir -and (Test-Path (Join-Path $out 'index.tsv'))) {
    $n = (Get-Content (Join-Path $out 'index.tsv') | Measure-Object -Line).Lines - 1
    Write-Host "Wrote $out ($n functions)"
} elseif (Test-Path $out) {
    $lines = (Get-Content $out | Measure-Object -Line).Lines
    Write-Host "Wrote $out ($lines lines)"
} else {
    throw "Script produced no output; run without -Quiet to see the Ghidra log"
}
