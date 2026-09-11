<#
.SYNOPSIS
  windows-env-rescue — layered doctor (GREEN / YELLOW / RED / UNKNOWN).

.DESCRIPTION
  Read-only. Prints one line per layer and exits 0 if no RED, else 1.
  Lines look like:
    L0 foundation  GREEN   scoop+pwsh7 OK
  Unchecked probes must be UNKNOWN, never GREEN.

.EXAMPLE
  pwsh -NoProfile -File doctor.ps1
#>

$ErrorActionPreference = 'Continue'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 > $null
} catch { }

$shared = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')

$hasRed = $false
$hasYellow = $false

function Write-Layer([string]$Id, [string]$Name, [string]$State, [string]$Detail) {
    if ($State -eq 'RED') { $script:hasRed = $true }
    if ($State -eq 'YELLOW') { $script:hasYellow = $true }
    Write-Output ("{0,-18} {1,-7} {2}" -f "$Id $Name", $State, $Detail)
}

function Test-VerifyLine([string]$Verify) {
    if ([string]::IsNullOrWhiteSpace($Verify)) { return $false }
    try {
        cmd /c "$Verify" > $null 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Get-ManifestLayerState([string]$ManifestPath) {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return @{ State = 'UNKNOWN'; Detail = "manifest missing: $ManifestPath" }
    }
    try {
        $m = Import-WerManifest -Path $ManifestPath
    } catch {
        return @{ State = 'UNKNOWN'; Detail = "manifest parse error: $($_.Exception.Message)" }
    }
    $missReq = @()
    $missOpt = @()
    foreach ($tool in $m.Tools) {
        $bin = $tool['binary']
        $req = [bool]$tool['required']
        $verify = $tool['verify']
        if (-not $bin) { continue }
        $present = [bool](Get-Command $bin -ErrorAction SilentlyContinue)
        $ok = $present
        if ($present -and $verify) { $ok = Test-VerifyLine $verify }
        if (-not $ok) {
            if ($req) { $missReq += $bin } else { $missOpt += $bin }
        }
    }
    if ($missReq.Count -gt 0) {
        return @{ State = 'RED'; Detail = "missing required: $($missReq -join ', ')" }
    }
    if ($missOpt.Count -gt 0) {
        return @{ State = 'YELLOW'; Detail = "missing optional: $($missOpt -join ', ')" }
    }
    return @{ State = 'GREEN'; Detail = 'all required+optional verify OK' }
}

Write-Output "########## windows-env-rescue doctor ##########"

# L0 foundation
$foundationPath = Join-Path $shared 'manifests\foundation.toml'
$fs = Get-ManifestLayerState $foundationPath
# scoop special-case (not a scoop package)
$scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
if ($fs.State -eq 'GREEN' -and -not $scoopCmd) {
    $fs = @{ State = 'RED'; Detail = 'scoop not on PATH' }
} elseif ($fs.State -eq 'YELLOW' -and -not $scoopCmd) {
    $fs = @{ State = 'RED'; Detail = 'scoop not on PATH' }
} elseif ($fs.State -eq 'GREEN') {
    $fs = @{ State = 'GREEN'; Detail = 'scoop+pwsh OK' }
}
Write-Layer 'L0' 'foundation' $fs.State $fs.Detail

# L1 terminal
$terminalPath = Join-Path $shared 'manifests\terminal.toml'
$ts = Get-ManifestLayerState $terminalPath
$profileDetail = ''
if ($ts.State -ne 'UNKNOWN') {
    $profilePath = $PROFILE
    if (Test-Path -LiteralPath $profilePath) {
        $content = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content -match [regex]::Escape('# >>> windows-env-rescue >>>')) {
            $profileDetail = '; profile block present'
        } elseif ($content -match [regex]::Escape('# >>> terminal-boost >>>')) {
            $profileDetail = '; legacy terminal-boost block (migrate)'
            if ($ts.State -eq 'GREEN') { $ts = @{ State = 'YELLOW'; Detail = $ts.Detail + $profileDetail } }
            else { $ts.Detail += $profileDetail }
        } else {
            $profileDetail = '; profile block absent'
            if ($ts.State -eq 'GREEN') { $ts = @{ State = 'YELLOW'; Detail = 'tools OK but profile block absent' } }
            else { $ts.Detail += $profileDetail }
        }
    } else {
        $profileDetail = '; no PROFILE file'
        if ($ts.State -eq 'GREEN') { $ts = @{ State = 'YELLOW'; Detail = 'tools OK but no PROFILE' } }
    }
}
Write-Layer 'L1' 'terminal' $ts.State $ts.Detail

# L6 yazi (optional informational)
$yaziCmd = Get-Command yazi -ErrorAction SilentlyContinue
if ($yaziCmd) {
    Write-Layer 'L6' 'yazi' 'GREEN' "found $($yaziCmd.Source)"
} else {
    Write-Layer 'L6' 'yazi' 'YELLOW' 'not installed (optional; use /yazi-install)'
}

Write-Output ""
Write-Output "Legend: GREEN=all good  YELLOW=optional gap  RED=required missing  UNKNOWN=not checked"
if ($hasRed) {
    Write-Output "DOCTOR: RED"
    exit 1
}
if ($hasYellow) {
    Write-Output "DOCTOR: YELLOW"
    exit 0
}
Write-Output "DOCTOR: GREEN"
exit 0
