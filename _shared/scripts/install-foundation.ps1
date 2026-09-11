<#
.SYNOPSIS
  windows-env-rescue — L0 foundation installer (scoop, pwsh7, policy, network gate).

.DESCRIPTION
  Engine script. Safe to run without Claude Code. Idempotent.
  Ends with one of:
    INSTALL-FOUNDATION: OK
    INSTALL-FOUNDATION: PARTIAL
    INSTALL-FOUNDATION: FAIL: <reason>
  Exit codes: 0 = OK, 2 = PARTIAL, 1 = FAIL.

.NOTES
  Requires Windows. Install path targets PowerShell 7+; bootstrap may start from 5.1
  to install pwsh via scoop only after scoop exists — if scoop is missing we still
  try the official installer from 5.1/7.
#>

$ErrorActionPreference = 'Continue'
$status = 'OK'

function Set-WerUtf8 {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
        chcp 65001 > $null
    } catch { }
}

function Test-WerNetwork {
    $urls = @(
        'https://get.scoop.sh',
        'https://github.com',
        'https://raw.githubusercontent.com',
        'https://objects.githubusercontent.com'
    )
    $blocked = @()
    foreach ($u in $urls) {
        try {
            $null = Invoke-WebRequest -Uri $u -Method Head -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
            Write-Output "  [OK]      $u"
        } catch {
            if ($null -ne $_.Exception.Response) {
                Write-Output "  [OK*]     $u  (reached; non-2xx)"
            } else {
                Write-Output "  [BLOCKED] $u"
                Write-Output "            $($_.Exception.Message)"
                $blocked += $u
            }
        }
    }
    return ,$blocked
}

function Test-WerVerify([string]$Verify) {
    if ([string]::IsNullOrWhiteSpace($Verify)) { return $false }
    try {
        cmd /c "$Verify" > $null 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

Set-WerUtf8
Write-Output "===== windows-env-rescue foundation ====="

$shared = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $shared 'manifests\foundation.toml'
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')

$manifest = Import-WerManifest -Path $manifestPath
Write-Output "Manifest: $($manifest.Name) schema=$($manifest.Schema)"

# --- scoop ---
$scoop = Get-Command scoop -ErrorAction SilentlyContinue
if (-not $scoop) {
    Write-Output "scoop missing — bootstrapping (user-scope, no admin)..."
    $needDownload = $true
} else {
    Write-Output "scoop: $($scoop.Source)"
    $needDownload = $false
}

# Only hard-gate network when we must download
$mustFetch = $needDownload
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    if ($bin -and -not (Get-Command $bin -ErrorAction SilentlyContinue)) {
        $mustFetch = $true
        break
    }
}

if ($mustFetch) {
    Write-Output ""
    Write-Output "Network gate (HTTPS):"
    $blocked = Test-WerNetwork
    if ($blocked.Count -gt 0) {
        Write-Output ""
        Write-Output "Network blocked. Configure a proxy, then re-run:"
        Write-Output "  scoop config proxy 127.0.0.1:7890   # host:port as appropriate"
        Write-Output "INSTALL-FOUNDATION: FAIL: network unreachable ($($blocked -join ', '))"
        exit 1
    }
}

if (-not $scoop) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    } catch {
        Write-Output "WARNING: could not set RemoteSigned: $($_.Exception.Message)"
        $status = 'PARTIAL'
    }
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if (-not $scoop) {
        Write-Output "scoop install finished but scoop is not on PATH. Open a new window and re-run."
        Write-Output "INSTALL-FOUNDATION: FAIL: scoop not available after bootstrap"
        exit 1
    }
    Write-Output "scoop installed: $($scoop.Source)"
}

# Refresh PATH for current session (scoop shims)
$scoopRoot = Split-Path (Split-Path $scoop.Source -Parent) -Parent
if ($scoopRoot -and $env:PATH -notlike "*$scoopRoot*") {
    $env:PATH = "$scoopRoot\shims;$env:PATH"
}

# Execution policy
try {
    $pol = Get-ExecutionPolicy -Scope CurrentUser
    if ($pol -eq 'Undefined' -or $pol -eq 'Restricted') {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Output "ExecutionPolicy CurrentUser -> RemoteSigned"
    } else {
        Write-Output "ExecutionPolicy CurrentUser: $pol"
    }
} catch {
    Write-Output "WARNING: execution policy check failed: $($_.Exception.Message)"
    if ($status -eq 'OK') { $status = 'PARTIAL' }
}

# Packages from manifest
$missingRequired = @()
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    $pkg = $tool['scoop']
    $req = [bool]$tool['required']
    $verify = $tool['verify']
    $present = $bin -and (Get-Command $bin -ErrorAction SilentlyContinue)
    if ($present) {
        Write-Output "OK      $bin"
        continue
    }
    Write-Output "MISSING $bin (scoop: $pkg) required=$req"
    scoop install $pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Output "  scoop install $pkg failed (exit $LASTEXITCODE)"
        if ($req) { $missingRequired += $bin }
        elseif ($status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }
    # re-add shims path in case scoop just installed (custom SCOOP root safe)
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        $scoopRoot = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
        $shims = Join-Path $scoopRoot 'shims'
        if ($scoopRoot -and (Test-Path $shims) -and $env:PATH -notlike "*$shims*") {
            $env:PATH = "$shims;$env:PATH"
        }
    }
    $ok = Test-WerVerify $verify
    if (-not $ok) {
        # fallback: binary presence
        $ok = [bool](Get-Command $bin -ErrorAction SilentlyContinue)
    }
    if (-not $ok) {
        Write-Output "  verify failed after install: $bin"
        if ($req) { $missingRequired += $bin }
        elseif ($status -eq 'OK') { $status = 'PARTIAL' }
    } else {
        Write-Output "  installed OK: $bin"
    }
}

# Final verify pass
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    $req = [bool]$tool['required']
    $verify = $tool['verify']
    if (-not $bin) { continue }
    $present = [bool](Get-Command $bin -ErrorAction SilentlyContinue)
    $verified = $present
    if ($present -and $verify) { $verified = Test-WerVerify $verify }
    if ($req -and -not $verified) {
        if ($missingRequired -notcontains $bin) { $missingRequired += $bin }
    } elseif (-not $verified -and $status -eq 'OK') {
        $status = 'PARTIAL'
    }
}

if ($missingRequired.Count -gt 0) {
    Write-Output "INSTALL-FOUNDATION: FAIL: required missing: $($missingRequired -join ', ')"
    exit 1
}

Write-Output ""
if ($status -eq 'OK') {
    Write-Output "INSTALL-FOUNDATION: OK"
    exit 0
} else {
    Write-Output "INSTALL-FOUNDATION: PARTIAL"
    exit 2
}
