<#
.SYNOPSIS
  Load a save in a scratch copy of the game, let it run, and collect the autosave and debug log.

.DESCRIPTION
  Dot-source this file and call Invoke-InGameRun. It

    1. refuses to run while the real game is open;
    2. prepares the scratch game copy (default D:\projects\tools\pa-test\game, made once from the Steam
       install with the original exe kept as "Prison Architect64.exe.orig" and a steam_appid.txt so the
       Steam API initialises without relaunching through Steam);
    3. resets the exe to the original and applies the requested patch selection with the patcher CLI;
    4. stages the save as saves\<StagedName>.prison, points continue_game.json at it, optionally installs
       a mod folder and enables it, forces windowed mode and a one-minute autosave;
    5. launches "Prison Architect64.exe --continuelastsave", watches debug.txt for the "Loading map from"
       line and then for Autosaves autosaves ("Save completed"), or gives up after MaxMinutes;
    6. kills the game, copies autosave.prison and debug.txt into a results folder, restores
       preferences.txt and continue_game.json (also on failure), and returns a result object.

  The game shares the user folder (%LocalAppData%\Introversion\Prison Architect) with the real install,
  so the run edits and restores the real preferences.txt and continue_game.json. Do not play while a
  test runs.

.EXAMPLE
  . .\Run-InGameTest.ps1
  $r = Invoke-InGameRun -Save ..\..\keycardtest3local.prison -Selection fixes -Autosaves 3
  $r.Autosave     # path of the collected autosave
  $r.LoadedMap    # the "Loading map from" line
#>
Set-StrictMode -Off

$script:Defaults = @{
    GameDir    = 'D:\projects\tools\pa-test\game'
    SteamGame  = 'D:\SteamLibrary\steamapps\common\Prison Architect'
    UserDir    = Join-Path $env:LOCALAPPDATA 'Introversion\Prison Architect'
    Patcher    = Join-Path $PSScriptRoot '..\..\patcher\bin\Release\net48\TyrsPAPatch.exe'
    Results    = Join-Path $PSScriptRoot 'results'
    StagedName = 'tyrs-test'
    ProcName   = 'Prison Architect64'
    AppId      = '233450'
}

function Get-Sha256([string] $path) {
    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}

function Initialize-ScratchGame {
    <# Make (or refresh) the scratch copy. Idempotent: only copies when the copy is missing. #>
    [CmdletBinding()]
    param([string] $GameDir = $script:Defaults.GameDir, [string] $SteamGame = $script:Defaults.SteamGame)
    $exe = Join-Path $GameDir 'Prison Architect64.exe'
    $orig = "$exe.orig"
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Host "Copying the game to $GameDir ..."
        New-Item -ItemType Directory -Force $GameDir | Out-Null
        & robocopy $SteamGame $GameDir /E /XD Launcher /XF *.dmp 'Prison Architect64.exe.orig' /NFL /NDL /NJH /NJS /NP | Out-Null
    }
    if (-not (Test-Path -LiteralPath $orig)) {
        $steamOrig = Join-Path $SteamGame 'Prison Architect64.exe.orig'
        if (Test-Path -LiteralPath $steamOrig) { Copy-Item -LiteralPath $steamOrig $orig -Force }
        else { Copy-Item -LiteralPath (Join-Path $SteamGame 'Prison Architect64.exe') $orig -Force }
    }
    $appid = Join-Path $GameDir 'steam_appid.txt'
    if (-not (Test-Path -LiteralPath $appid)) { [IO.File]::WriteAllText($appid, $script:Defaults.AppId) }
    return $GameDir
}

function Set-GameSelection {
    <# Reset the scratch exe to the original and apply a patch selection: original | fixes | fixes+tweaks. #>
    [CmdletBinding()]
    param(
        [string] $GameDir = $script:Defaults.GameDir,
        [ValidateSet('original', 'fixes', 'fixes+tweaks')] [string] $Selection = 'fixes',
        [string] $Patcher = $script:Defaults.Patcher
    )
    $exe = Join-Path $GameDir 'Prison Architect64.exe'
    Copy-Item -LiteralPath "$exe.orig" $exe -Force
    if ($Selection -ne 'original') {
        if (-not (Test-Path -LiteralPath $Patcher)) { throw "patcher not found at $Patcher (build it with dotnet build -c Release in patcher\)" }
        $args = @('--apply'); if ($Selection -eq 'fixes+tweaks') { $args += '--tweaks' }; $args += ('"' + $exe + '"')
        $p = Start-Process -FilePath $Patcher -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -ne 0) { throw "patcher --apply failed with exit code $($p.ExitCode)" }
    }
    return Get-Sha256 $exe
}

function Get-ModName([string] $ModDir) {
    $m = Join-Path $ModDir 'manifest.txt'
    if (-not (Test-Path -LiteralPath $m)) { throw "no manifest.txt in $ModDir" }
    $line = Get-Content -LiteralPath $m | Where-Object { $_ -match '^\s*Name\s+' } | Select-Object -First 1
    if (-not $line) { throw "manifest.txt in $ModDir has no Name line" }
    return ($line -replace '^\s*Name\s+', '').Trim().Trim('"')
}

function Invoke-InGameRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Save,
        [ValidateSet('original', 'fixes', 'fixes+tweaks')] [string] $Selection = 'fixes',
        [string[]] $Mod = @(),
        [int] $Autosaves = 2,
        [double] $TimeWarp = 0,
        [double] $MaxMinutes = 15,
        [string] $Name = 'run',
        [string] $GameDir = $script:Defaults.GameDir,
        [string] $Patcher = $script:Defaults.Patcher,
        [string] $ResultsRoot = $script:Defaults.Results,
        [switch] $KeepRunning
    )
    $ErrorActionPreference = 'Stop'
    $user = $script:Defaults.UserDir
    $procName = $script:Defaults.ProcName
    if (Get-Process $procName -ErrorAction SilentlyContinue) { throw 'Prison Architect is already running; close it first' }
    $Save = (Resolve-Path -LiteralPath $Save).Path

    $GameDir = Initialize-ScratchGame -GameDir $GameDir
    $exeSha = Set-GameSelection -GameDir $GameDir -Selection $Selection -Patcher $Patcher

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $out = Join-Path $ResultsRoot "$Name-$stamp"
    New-Item -ItemType Directory -Force $out | Out-Null

    $prefs = Join-Path $user 'preferences.txt'
    $cont = Join-Path $user 'continue_game.json'
    $prefsBak = Join-Path $out 'preferences.txt.before'
    $contBak = Join-Path $out 'continue_game.json.before'
    Copy-Item -LiteralPath $prefs $prefsBak -Force
    Copy-Item -LiteralPath $cont $contBak -Force

    $staged = Join-Path $user ("saves\" + $script:Defaults.StagedName + '.prison')
    $autosave = Join-Path $user 'saves\autosave.prison'
    $debug = Join-Path $user 'debug.txt'
    $proc = $null
    $result = [ordered]@{
        Name = $Name; Save = $Save; Selection = $Selection; ExeSha256 = $exeSha; Mods = @(); TimeWarp = $TimeWarp
        Started = $null; LoadedAt = $null; LoadedMap = $null; AutosavesSeen = 0; Ended = $null
        Autosave = $null; Debug = $null; ResultDir = $out; Ok = $false; Note = ''; Snapshots = 'autosave-<n>.prison in ResultDir'
    }
    try {
        Copy-Item -LiteralPath $Save $staged -Force
        if ($TimeWarp -gt 0) {
            # TimeWarpFactor in the save header is the game speed in game minutes per real second (0.125 with the SlowTime mutator).
            $s = [IO.File]::ReadAllText($staged)
            $s = [regex]::Replace($s, '(?m)^TimeWarpFactor\s+\S+', ('TimeWarpFactor       ' + $TimeWarp.ToString('0.0000000', [Globalization.CultureInfo]::InvariantCulture)), 1)
            [IO.File]::WriteAllText($staged, $s, (New-Object Text.UTF8Encoding($false)))
        }
        [IO.File]::WriteAllText($cont, "{`n  `"title`": `"$($script:Defaults.StagedName).prison`",`n  `"date`": `" `"`n}`n")

        $modNames = @()
        foreach ($m in $Mod) {
            $src = (Resolve-Path -LiteralPath $m).Path
            $leaf = Split-Path -Leaf $src
            $dst = Join-Path $user "mods\$leaf"
            if (Test-Path -LiteralPath $dst) { Remove-Item -Recurse -Force -LiteralPath $dst }
            Copy-Item -Recurse -LiteralPath $src $dst
            $modNames += Get-ModName $src
        }
        $result.Mods = $modNames
        $modsLine = if ($modNames.Count) { ($modNames | ForEach-Object { '"' + $_ + '"' }) -join ',' } else { '(empty)' }

        $p = [IO.File]::ReadAllText($prefs)
        $p = $p -replace '(?m)^ScreenWindowed\s+\S+', 'ScreenWindowed       true'
        $p = $p -replace '(?m)^ScreenW\s+\d+', 'ScreenW              1600'
        $p = $p -replace '(?m)^ScreenH\s+\d+', 'ScreenH              900'
        $p = $p -replace '(?m)^AutoSaveTimer\s+\d+', 'AutoSaveTimer        1'
        $p = $p -replace '(?m)^Mods\s+.*$', ('Mods                 ' + $modsLine + '  ')
        [IO.File]::WriteAllText($prefs, $p, (New-Object Text.UTF8Encoding($false)))

        if (Test-Path -LiteralPath $autosave) { Remove-Item -LiteralPath $autosave -Force }
        $result.Started = Get-Date
        $proc = Start-Process -FilePath (Join-Path $GameDir 'Prison Architect64.exe') -ArgumentList '--continuelastsave' -WorkingDirectory $GameDir -PassThru
        $deadline = $result.Started.AddMinutes($MaxMinutes)
        $loadRx = [regex]::Escape($script:Defaults.StagedName + '.prison')
        $seen = 0; $lastWrite = [datetime]::MinValue
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            if ($proc.HasExited) { $result.Note = "game exited early with code $($proc.ExitCode)"; break }
            $lines = @()
            try { $lines = [IO.File]::ReadAllLines($debug) } catch { continue }
            if (-not $result.LoadedMap) {
                $l = $lines | Where-Object { $_ -match "Loading map from '.*$loadRx'" } | Select-Object -First 1
                if ($l) { $result.LoadedMap = $l; $result.LoadedAt = Get-Date; Write-Host "loaded: $l" }
                elseif ($lines | Where-Object { $_ -match 'Failed to launch game through Steam' }) { $result.Note = 'Steam relaunch refused (steam_appid.txt missing?)'; break }
                continue
            }
            # Count autosaves by the file itself: the game's debug.txt can stop being written (seen after
            # five minutes of play) while autosaves continue. The log count is only a floor.
            $logSeen = @($lines | Where-Object { $_ -match "Saving map to '.*autosave\.prison-temp'.*Save completed" }).Count
            $seen = $result.AutosavesSeen
            if (Test-Path -LiteralPath $autosave) {
                $fi = Get-Item -LiteralPath $autosave
                if ($fi.LastWriteTime -gt $result.LoadedAt -and $fi.LastWriteTime -ne $lastWrite) { $lastWrite = $fi.LastWriteTime; $seen++ }
            }
            if ($logSeen -gt $seen) { $seen = $logSeen }
            if ($seen -ne $result.AutosavesSeen) {
                $result.AutosavesSeen = $seen; Write-Host "autosave $seen at $(Get-Date -Format HH:mm:ss)"
                # keep every autosave so a test can look at the timeline, not only the end state
                Start-Sleep -Milliseconds 1500
                try { Copy-Item -LiteralPath $autosave (Join-Path $out ("autosave-{0}.prison" -f $seen)) -Force } catch { }
            }
            if ($seen -ge $Autosaves) { break }
        }
        if (-not $result.LoadedMap -and -not $result.Note) { $result.Note = 'map never loaded before the deadline' }
        elseif ($seen -lt $Autosaves -and -not $result.Note) { $result.Note = "only $seen of $Autosaves autosaves before the deadline" }
    }
    finally {
        if ($proc -and -not $KeepRunning) {
            try { if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; $proc.WaitForExit(10000) | Out-Null } } catch { }
        }
        $result.Ended = Get-Date
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $autosave) { Copy-Item -LiteralPath $autosave (Join-Path $out 'autosave.prison') -Force; $result.Autosave = Join-Path $out 'autosave.prison' }
        if (Test-Path -LiteralPath $debug) { Copy-Item -LiteralPath $debug (Join-Path $out 'debug.txt') -Force; $result.Debug = Join-Path $out 'debug.txt' }
        Copy-Item -LiteralPath $prefsBak $prefs -Force
        Copy-Item -LiteralPath $contBak $cont -Force
        $result.Ok = [bool]($result.LoadedMap -and $result.AutosavesSeen -ge $Autosaves -and $result.Autosave)
        $result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $out 'run.json') -Encoding UTF8
    }
    return [pscustomobject]$result
}
