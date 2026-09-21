<#
.SYNOPSIS
  windows-env-rescue — L3 AI coding CLI installer (Claude Code + Pi).

.DESCRIPTION
  Detect-first: skip tools that already verify. Install missing required tools
  via official native PowerShell installers. Observe-only tools (codex/kimi)
  are reported and never installed.
  Status: INSTALL-AI-CODING: OK | PARTIAL | FAIL: <reason>
  Exit: 0 OK, 2 PARTIAL, 1 FAIL.
#>
[CmdletBinding()]
param(
    [switch]$SkipClaude,
    [switch]$SkipPi
)

$ErrorActionPreference = 'Continue'
$status = 'OK'

function Set-WerUtf8 {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        chcp 65001 > $null
    } catch { }
}

function Update-WerAiPath {
    $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = @($machine, $user) -join ';'
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    if ((Test-Path $localBin) -and $env:PATH -notlike "*$localBin*") {
        $env:PATH = "$localBin;$env:PATH"
    }
}

function Test-WerCmd([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-WerVerify([string]$Verify) {
    if ([string]::IsNullOrWhiteSpace($Verify)) { return $false }
    try {
        cmd /c "$Verify" > $null 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Test-WerNetwork {
    $urls = @(
        'https://get.scoop.sh',
        'https://github.com',
        'https://raw.githubusercontent.com',
        'https://objects.githubusercontent.com',
        'https://claude.ai',
        'https://pi.dev'
    )
    $blocked = @()
    foreach ($u in $urls) {
        try {
            $null = Invoke-WebRequest -Uri $u -Method Head -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
        } catch {
            if ($null -eq $_.Exception.Response) { $blocked += $u }
        }
    }
    return ,$blocked
}

function Install-WerNativePs1([string]$Url) {
    Write-Output "  install via $Url"
    try {
        $script = Invoke-RestMethod -Uri $Url -TimeoutSec 60
        & ([scriptblock]::Create($script))
        return ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
    } catch {
        Write-Output "  installer error: $($_.Exception.Message)"
        return $false
    }
}

Set-WerUtf8
Write-Output "===== windows-env-rescue ai-coding ====="

$shared = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')
$manifest = Import-WerManifest -Path (Join-Path $shared 'manifests\ai-coding.toml')
Write-Output "Manifest: $($manifest.Name)"

Update-WerAiPath

$tools = @($manifest.Tools)
$observe = @()
foreach ($k in @('observe', 'Observes', 'observes')) {
    if ($manifest.ContainsKey($k) -and $manifest[$k] -is [System.Collections.IEnumerable] -and $manifest[$k] -isnot [string]) {
        $observe = @($manifest[$k])
    }
}
# Import-WerManifest stores [[observe]] as array under key 'observe'
if ($observe.Count -eq 0 -and $manifest['observe']) {
    $observe = @($manifest['observe'])
}

function Get-WerObserveList {
    $raw = Get-Content (Join-Path $shared 'manifests\ai-coding.toml') -Raw -Encoding UTF8
    $list = @()
    $parts = [regex]::Split($raw, '\[\[observe\]\]')
    if ($parts.Count -le 1) { return ,$list }
    foreach ($p in $parts[1..($parts.Count - 1)]) {
        if ($p -match '(?m)^binary\s*=\s*"([^"]+)"') { $list += $Matches[1] }
    }
    return ,$list
}

$observeBins = Get-WerObserveList

$failRequired = @()
foreach ($tool in $tools) {
    $id = $tool['id']
    $bin = $tool['binary']
    $req = [bool]$tool['required']
    $verify = $tool['verify']
    $url = $tool['url']
    if (-not $bin) { continue }

    $skip = ($id -eq 'claude-code' -and $SkipClaude) -or ($id -eq 'pi' -and $SkipPi)
    if ($skip) {
        Write-Output "SKIP    $bin (-Skip*)"
        if ($req -and $status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }

    $present = Test-WerCmd $bin
    $ok = $present
    if ($present -and $verify) { $ok = Test-WerVerify $verify }
    if ($ok) {
        $ver = cmd /c "$verify" 2>&1 | Select-Object -First 1
        Write-Output "OK      $bin  $ver"
        continue
    }

    Write-Output "MISSING $bin (required=$req)"
    $blocked = Test-WerNetwork
    if ($blocked.Count -gt 0) {
        Write-Output "  network blocked: $($blocked -join ', ')"
        if ($req) { $failRequired += $bin } elseif ($status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }

    $installed = $false
    if ($tool['install'] -eq 'native-ps1' -and $url) {
        $installed = Install-WerNativePs1 $url
    } elseif ($url) {
        $installed = Install-WerNativePs1 $url
    }

    Update-WerAiPath
    $ok2 = Test-WerCmd $bin
    if ($ok2 -and $verify) { $ok2 = Test-WerVerify $verify }
    if (-not $ok2) {
        # npm fallback for pi only
        if ($bin -eq 'pi' -and (Test-WerCmd 'npm')) {
            Write-Output "  try npm fallback @earendil-works/pi-coding-agent"
            npm install -g --ignore-scripts '@earendil-works/pi-coding-agent'
            Update-WerAiPath
            $ok2 = Test-WerCmd $bin
            if ($ok2 -and $verify) { $ok2 = Test-WerVerify $verify }
        }
    }
    if (-not $ok2) {
        Write-Output "  verify failed after install: $bin"
        if ($req) { $failRequired += $bin } elseif ($status -eq 'OK') { $status = 'PARTIAL' }
    } else {
        Write-Output "  installed OK: $bin"
    }
}

Write-Output ""
Write-Output "Observe-only (never auto-installed):"
foreach ($ob in $observeBins) {
    if (Test-WerCmd $ob) {
        Write-Output "  present $ob"
    } else {
        Write-Output "  absent  $ob"
    }
}

# Final verify — real commands
Update-WerAiPath
$fail = @()
foreach ($tool in $tools) {
    if (-not [bool]$tool['required']) { continue }
    $bin = $tool['binary']
    $verify = $tool['verify']
    $id = $tool['id']
    if (($id -eq 'claude-code' -and $SkipClaude) -or ($id -eq 'pi' -and $SkipPi)) {
        continue
    }
    if (-not $bin) { continue }
    $ok = Test-WerCmd $bin
    if ($ok -and $verify) { $ok = Test-WerVerify $verify }
    if (-not $ok) { $fail += $bin }
}
if ($fail.Count -gt 0) {
    Write-Output "INSTALL-AI-CODING: FAIL: verify failed: $($fail -join ', ')"
    exit 1
}

Write-Output ""
Write-Output "Note: authentication is not part of this installer. Run 'claude' or 'pi' after install."
if ($status -eq 'OK') {
    Write-Output "INSTALL-AI-CODING: OK"
    exit 0
}
Write-Output "INSTALL-AI-CODING: PARTIAL"
exit 2
