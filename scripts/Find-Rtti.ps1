<#
  Find-Rtti.ps1 -ClassName ContrabandSystem
  Locates a class's RTTI type descriptor, complete object locator and vtable
  in Prison Architect64.exe. Static analysis only; nothing is modified.
#>
[CmdletBinding()]
param(
    [string] $ClassName = 'ContrabandSystem',
    [string] $Exe = 'D:\SteamLibrary\steamapps\common\Prison Architect\Prison Architect64.exe'
)
$ErrorActionPreference = 'Stop'
$b = [System.IO.File]::ReadAllBytes($Exe)

# --- PE headers ---
$peOff = [BitConverter]::ToInt32($b, 0x3C)
if ([BitConverter]::ToUInt32($b, $peOff) -ne 0x00004550) { throw "Not a PE file" }
$nSections    = [BitConverter]::ToUInt16($b, $peOff + 6)
$optSize      = [BitConverter]::ToUInt16($b, $peOff + 20)
$optOff       = $peOff + 24
$magic        = [BitConverter]::ToUInt16($b, $optOff)
if ($magic -ne 0x20B) { throw "Not PE32+ (x64)" }
$imageBase    = [BitConverter]::ToUInt64($b, $optOff + 24)
$secOff       = $optOff + $optSize

$sections = @()
for ($i = 0; $i -lt $nSections; $i++) {
    $s = $secOff + ($i * 40)
    $sections += [pscustomobject]@{
        Name    = ([System.Text.Encoding]::ASCII.GetString($b, $s, 8)).Trim([char]0)
        VSize   = [BitConverter]::ToUInt32($b, $s + 8)
        VAddr   = [BitConverter]::ToUInt32($b, $s + 12)
        RawSize = [BitConverter]::ToUInt32($b, $s + 16)
        RawPtr  = [BitConverter]::ToUInt32($b, $s + 20)
    }
}
Write-Host ("ImageBase 0x{0:X}" -f $imageBase)
$sections | ForEach-Object { Write-Host ("  {0,-8} RVA 0x{1:X8}  raw 0x{2:X8}  size 0x{3:X}" -f $_.Name, $_.VAddr, $_.RawPtr, $_.VSize) }

function To-Rva([int]$fileOff) {
    foreach ($s in $sections) {
        if ($fileOff -ge $s.RawPtr -and $fileOff -lt ($s.RawPtr + $s.RawSize)) {
            return [uint32]($s.VAddr + ($fileOff - $s.RawPtr))
        }
    }
    return 0
}
function To-Off([uint32]$rva) {
    foreach ($s in $sections) {
        if ($rva -ge $s.VAddr -and $rva -lt ($s.VAddr + $s.VSize)) {
            return [int]($s.RawPtr + ($rva - $s.VAddr))
        }
    }
    return -1
}

# --- find the mangled type-descriptor name ---
$needle = ".?AV$ClassName@@"
$nb = [System.Text.Encoding]::ASCII.GetBytes($needle)
$strOff = -1
for ($i = 0; $i -lt ($b.Length - $nb.Length); $i++) {
    if ($b[$i] -eq $nb[0]) {
        $ok = $true
        for ($j = 1; $j -lt $nb.Length; $j++) { if ($b[$i+$j] -ne $nb[$j]) { $ok = $false; break } }
        if ($ok) { $strOff = $i; break }
    }
}
if ($strOff -lt 0) { throw "Type name '$needle' not found" }

$strRva  = To-Rva $strOff
$tdRva   = [uint32]($strRva - 16)          # TypeDescriptor: vftable(8) + spare(8) + name
Write-Host ""
Write-Host ("{0}" -f $needle)
Write-Host ("  name string  file 0x{0:X}  RVA 0x{1:X}" -f $strOff, $strRva)
Write-Host ("  TypeDescriptor          RVA 0x{0:X}" -f $tdRva)

# --- find COL(s) whose pTypeDescriptor == tdRva  (x64 COL: +12) ---
$tdBytes = [BitConverter]::GetBytes($tdRva)
$cols = @()
foreach ($s in $sections) {
    if ($s.Name -notin @('.rdata', '.data')) { continue }
    $end = $s.RawPtr + $s.RawSize - 4
    for ($i = [int]$s.RawPtr; $i -lt $end; $i += 4) {
        if ($b[$i] -eq $tdBytes[0] -and $b[$i+1] -eq $tdBytes[1] -and
            $b[$i+2] -eq $tdBytes[2] -and $b[$i+3] -eq $tdBytes[3]) {
            $colOff = $i - 12
            if ($colOff -lt $s.RawPtr) { continue }
            if ([BitConverter]::ToUInt32($b, $colOff) -ne 1) { continue }   # x64 signature
            $cols += $colOff
        }
    }
}
if (-not $cols) { throw "No complete object locator found" }

foreach ($colOff in $cols) {
    $colRva = To-Rva $colOff
    Write-Host ("  CompleteObjectLocator   RVA 0x{0:X}  (file 0x{1:X})" -f $colRva, $colOff)
    $colVa = $imageBase + $colRva
    $target = [BitConverter]::GetBytes([uint64]$colVa)
    foreach ($s in $sections) {
        if ($s.Name -ne '.rdata') { continue }
        $end = $s.RawPtr + $s.RawSize - 8
        for ($i = [int]$s.RawPtr; $i -lt $end; $i += 8) {
            $match = $true
            for ($j = 0; $j -lt 8; $j++) { if ($b[$i+$j] -ne $target[$j]) { $match = $false; break } }
            if ($match) {
                $vtOff = $i + 8
                $vtRva = To-Rva $vtOff
                Write-Host ("  >> VTABLE               RVA 0x{0:X}   VA 0x{1:X}" -f $vtRva, ($imageBase + $vtRva))
                $n = 0
                for ($k = $vtOff; $k -lt $vtOff + 400; $k += 8) {
                    $fn = [BitConverter]::ToUInt64($b, $k)
                    if ($fn -lt $imageBase -or $fn -gt ($imageBase + 0x2000000)) { break }
                    $n++
                }
                Write-Host ("     virtual methods: {0}" -f $n)
            }
        }
    }
}
