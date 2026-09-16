<#
.SYNOPSIS
  Parse a Prison Architect save (.prison, plain text BEGIN/END blocks) into nested ordered hashtables,
  plus helpers to pull objects out of it.

.DESCRIPTION
  Dot-source this file:  . .\Parse-PrisonSave.ps1
  Then:
    $save = ConvertFrom-PrisonSave 'C:\...\saves\autosave.prison'
    $save.TimeIndex                                  # top-level scalar (string)
    $save.Thermometer.StaffMoraleDesired
    Get-PrisonObjects $save -Type Prisoner           # every object block with Type Prisoner
    (Get-PrisonObjects $save -Type Guard).Count
    Get-PrisonObjects $save -Type Prisoner | Where-Object { $_.StatusEffects.surrendered }

  Layout: every block becomes an ordered hashtable. Scalars are stored as strings under their key
  ("Id.i", "Pos.x", ...). Child blocks are stored under their name ("[i 519]", "StatusEffects",
  "Bio", ...). A block's own name is kept in the "_name" entry. Quoted values lose their quotes.
  Duplicate child names inside one block get a "#2", "#3" suffix (does not happen in normal saves).

  Numbers: use ToDouble / ToInt on the strings, or [double]$x, which PowerShell does fine for the
  save's decimal notation.
#>

function ConvertFrom-PrisonSave {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)] [string] $Path)
    $Path = (Resolve-Path -LiteralPath $Path).Path
    $root = [ordered]@{ _name = '<root>' }
    $stack = New-Object System.Collections.Generic.Stack[object]
    $node = $root
    $tokenRx = [regex]'"[^"]*"|\S+'
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $lineNo++
        if ($line.Length -eq 0) { continue }
        $m = $tokenRx.Matches($line)
        $n = $m.Count
        $i = 0
        while ($i -lt $n) {
            $t = $m[$i].Value
            if ($t -eq 'BEGIN') {
                if ($i + 1 -ge $n) { throw "line ${lineNo}: BEGIN without a name" }
                $name = $m[$i + 1].Value.Trim('"')
                $child = [ordered]@{ _name = $name }
                $key = $name; $k = 2
                while ($node.Contains($key)) { $key = "$name#$k"; $k++ }
                $node[$key] = $child
                $stack.Push($node)
                $node = $child
                $i += 2
            }
            elseif ($t -eq 'END') {
                if ($stack.Count -eq 0) { throw "line ${lineNo}: END without BEGIN" }
                $node = $stack.Pop()
                $i += 1
            }
            else {
                if ($i + 1 -ge $n) { throw "line ${lineNo}: key '$t' without a value" }
                $node[$t] = $m[$i + 1].Value.Trim('"')
                $i += 2
            }
        }
    }
    if ($stack.Count -ne 0) { throw "unbalanced BEGIN/END, $($stack.Count) block(s) left open" }
    return $root
}

function Get-PrisonBlocks {
    <# Child blocks (hashtables) of a block, in file order. #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)] $Block)
    foreach ($e in $Block.GetEnumerator()) {
        if ($e.Value -is [System.Collections.IDictionary]) { $e.Value }
    }
}

function Get-PrisonObjects {
    <# Entries of the Objects block, optionally filtered by Type (wildcards allowed). #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] $Save,
        [string] $Type
    )
    $objs = $Save['Objects']
    if ($null -eq $objs) { return }
    foreach ($o in (Get-PrisonBlocks $objs)) {
        if (-not $o.Contains('Type')) { continue }
        if ($Type -and ($o['Type'] -notlike $Type)) { continue }
        $o
    }
}

function Get-PrisonValue {
    <# Nested lookup with a dotted path of block names, e.g. 'Thermometer', or 'Objects.[i 519].Bio.Forname'.
       Returns $null when any step is missing. Path segments that contain dots (Id.i) can be given as the
       last segment only. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)] $Block,
        [Parameter(Mandatory, Position = 1)] [string[]] $Path
    )
    $cur = $Block
    foreach ($seg in $Path) {
        if ($null -eq $cur -or -not ($cur -is [System.Collections.IDictionary]) -or -not $cur.Contains($seg)) { return $null }
        $cur = $cur[$seg]
    }
    return $cur
}

function ToDouble([string] $s) {
    if ([string]::IsNullOrEmpty($s)) { return [double]::NaN }
    return [double]::Parse($s, [Globalization.CultureInfo]::InvariantCulture)
}
function ToInt([string] $s) { return [int][double]::Parse($s, [Globalization.CultureInfo]::InvariantCulture) }

function Get-PrisonSummary {
    <# One-screen summary of a save, for logs. #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)] $Save)
    $objs = @(Get-PrisonObjects $Save)
    $byType = $objs | Group-Object { $_['Type'] } | Sort-Object Count -Descending
    [pscustomobject]@{
        TimeIndex   = ToDouble $Save['TimeIndex']
        Day         = [math]::Floor((ToDouble $Save['TimeIndex']) / 1440)
        Objects     = $objs.Count
        Prisoners   = @($objs | Where-Object { $_['Type'] -eq 'Prisoner' }).Count
        Guards      = @($objs | Where-Object { $_['Type'] -in 'Guard', 'ArmedGuard' }).Count
        StaffMorale = (Get-PrisonValue $Save 'Thermometer', 'StaffMorale')
        TopTypes    = ($byType | Select-Object -First 8 | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '
    }
}
