<#
.SYNOPSIS
  Parse a windows-env-rescue TOML manifest (subset) into objects.

.DESCRIPTION
  Supports: top-level key = value, [[tool]] array-of-tables, [section] tables
  with key = value. Values: bare words, true/false, and double-quoted strings
  with \" escapes. Not a general TOML parser — only what our manifests need.

  Dot-source this file, then: $m = Import-WerManifest -Path <file>
  Returns a hashtable: Schema, Name, Tools (array of hashtables), Profile (hashtable or $null), Raw
#>

function Import-WerManifest {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $result = @{
        Schema  = $null
        Name    = $null
        Tools   = [System.Collections.Generic.List[hashtable]]::new()
        Profile = $null
        Raw     = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
    }

    $section = $null   # current table name, or $null for root
    $currentTool = $null
    $currentTable = $null

    function Convert-WerValue([string]$raw) {
        $raw = $raw.Trim()
        if ($raw -match '^"(.*)"$') {
            $inner = $Matches[1]
            return ($inner -replace '\\"', '"')
        }
        if ($raw -eq 'true') { return $true }
        if ($raw -eq 'false') { return $false }
        if ($raw -match '^\d+$') { return [int]$raw }
        return $raw
    }

    foreach ($line in $lines) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }

        if ($t -match '^\[\[([^\]]+)\]\]$') {
            $name = $Matches[1].Trim()
            if ($name -eq 'tool') {
                $currentTool = @{}
                $result.Tools.Add($currentTool)
                $currentTable = $null
                $section = 'tool'
            } else {
                $currentTool = $null
                $currentTable = @{}
                $result[$name] = $currentTable
                $section = $name
            }
            continue
        }

        if ($t -match '^\[([^\]]+)\]$') {
            $name = $Matches[1].Trim()
            $currentTool = $null
            $currentTable = @{}
            $result[$name] = $currentTable
            $section = $name
            continue
        }

        if ($t -match '^([A-Za-z0-9_]+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $val = Convert-WerValue $Matches[2]
            if ($section -eq 'tool' -and $null -ne $currentTool) {
                $currentTool[$key] = $val
            } elseif ($null -ne $currentTable) {
                $currentTable[$key] = $val
            } else {
                if ($key -eq 'schema') { $result.Schema = $val }
                elseif ($key -eq 'name') { $result.Name = $val }
                else { $result[$key] = $val }
            }
        }
    }

    return $result
}
