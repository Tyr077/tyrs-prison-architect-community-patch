<#
  Install-HandoffMod.ps1
  Builds a Prison Architect (PA1) data mod that stops the gang contraband
  hand-off bug from recurring.

  Ships NO Paradox content. It reads crookedguards_settings.txt out of YOUR
  OWN main.dat at install time, rewrites the values, and writes the result
  into your local mods folder.

  Modes:
    Off    Crooked guards never spawn. Bug cannot trigger. Loses the feature.
    Light  Keeps crooked guards, far fewer of them, and a 4h bribe window
           instead of 48h so a stalled pairing expires quickly. Unproven.

  Usage:
    .\Install-HandoffMod.ps1 -Mode Off
    .\Install-HandoffMod.ps1 -Mode Light
    .\Install-HandoffMod.ps1 -Mode Off -Uninstall
#>
[CmdletBinding()]
param(
    [ValidateSet('Off','Light')] [string] $Mode = 'Off',
    [string] $GameDir  = 'D:\SteamLibrary\steamapps\common\Prison Architect',
    [string] $SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [switch] $Uninstall
)

$ErrorActionPreference = 'Stop'
$modName = 'NoCrookedHandoffBug'
$modsDir = Join-Path $env:LOCALAPPDATA "Introversion\Prison Architect\mods"
$modDir  = Join-Path $modsDir $modName

if ($Uninstall) {
    if (Test-Path -LiteralPath $modDir) {
        Remove-Item -LiteralPath $modDir -Recurse -Force
        Write-Host "Removed $modDir"
    } else { Write-Host "Not installed." }
    return
}

$dat = Join-Path $GameDir 'main.dat'
foreach ($p in @($dat, $SevenZip)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
}

# Pull the stock settings file out of the user's own game data.
$tmp = Join-Path $env:TEMP ("pa-handoff-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
& $SevenZip x $dat "-o$tmp" 'data\crookedguards_settings.txt' -y | Out-Null
$src = Join-Path $tmp 'data\crookedguards_settings.txt'
if (-not (Test-Path -LiteralPath $src)) { throw "Could not extract crookedguards_settings.txt" }

$overrides = @{}
if ($Mode -eq 'Off') {
    $overrides = @{
        'Minimum Gang Population (Cumulative)'                       = '999999'
        'Corrupt Every Nth Hired Guard'                              = '999999'
        'Chance to Corrupt One Guard Per Interval'                   = '0.00000'
        'Minimum Wait Interval for Next Corruption (Days)'           = '999999'
        'Crooked Guards to Normal Guards Ratio'                      = '0.0000000'
        'Crooked Guards to Normal Guards Ratio - with Staff Vetting' = '0.0000000'
    }
} else {
    $overrides = @{
        'Chance to Corrupt One Guard Per Interval'                   = '5.00000'
        'Minimum Wait Interval for Next Corruption (Days)'           = '30'
        'Crooked Guards to Normal Guards Ratio'                      = '0.0300000'
        'Crooked Guards to Normal Guards Ratio - with Staff Vetting' = '0.0100000'
        'Active Bribe Effect Time (Hrs)'                             = '4.000000'
    }
}

$nl = [Environment]::NewLine
$out = New-Object System.Collections.Generic.List[string]
$hits = 0
foreach ($line in [System.IO.File]::ReadAllLines($src)) {
    if ($line -match '^\s*"([^"]+)"\s+(\S+)\s*$') {
        $key = $Matches[1]
        if ($overrides.ContainsKey($key)) {
            $out.Add(('"{0}" {1}  ' -f $key, $overrides[$key]))
            Write-Host ("  {0}: {1} -> {2}" -f $key, $Matches[2], $overrides[$key])
            $hits++
            continue
        }
    }
    $out.Add($line)
}
if ($hits -ne $overrides.Count) {
    throw "Matched $hits of $($overrides.Count) keys. Game data may have changed; aborting."
}

New-Item -ItemType Directory -Path (Join-Path $modDir 'data') -Force | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Join-Path $modDir 'data\crookedguards_settings.txt'),
    (($out -join $nl) + $nl), $utf8NoBom)

$manifest = @(
    ('Name          "No Crooked Hand-Off Bug ({0})"' -f $Mode),
    'Author        "local"',
    'Description   "Stops the stalled gang contraband hand-off that leaves prisoners unescortable."',
    'Version       "v1.0"',
    ('Date          "{0}"' -f (Get-Date -Format 'dd/MM/yyyy')),
    'isTranslation false'
) -join $nl
[System.IO.File]::WriteAllText((Join-Path $modDir 'manifest.txt'), $manifest + $nl, $utf8NoBom)

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host ""
Write-Host "Installed mode '$Mode' to $modDir"
Write-Host "Enable it in the game's Mods menu, then restart Prison Architect."
