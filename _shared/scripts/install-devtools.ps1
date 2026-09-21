<#
.SYNOPSIS
  windows-env-rescue — L2 devtools installer (git, nvm/node, uv/python, pnpm, make/cmake).

.DESCRIPTION
  Engine script. Idempotent. Status words:
    INSTALL-DEVTOOLS: OK | PARTIAL | FAIL: <reason>
  Exit codes: 0 OK, 2 PARTIAL, 1 FAIL.

.PARAMETER GitName
  Optional. git config --global user.name when identity is missing.

.PARAMETER GitEmail
  Optional. git config --global user.email when identity is missing.

.PARAMETER UvPython
  Optional. Python version for uv (default from manifest, usually 3.12).

.PARAMETER SkipPnpm
  Skip corepack/pnpm setup.
#>
[CmdletBinding()]
param(
    [string]$GitName,
    [string]$GitEmail,
    [string]$UvPython,
    [switch]$SkipPnpm,
    [switch]$SkipOptional
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

function Update-WerPathFromUserEnv {
    # Rebuild from persisted env, then re-append anything this process already had
    # that looks like scoop/nvm (Machine+User alone can drop session shims).
    $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $base = @($machine, $user) -join ';'
    $extra = @()
    foreach ($seg in ($env:PATH -split ';')) {
        if (-not $seg) { continue }
        if ($seg -match 'scoop\\shims' -or $seg -match 'nvm' -or $seg -match 'nodejs') {
            if ($base -notlike "*$seg*") { $extra += $seg }
        }
    }
    $env:PATH = (@($extra) + @($base)) -join ';'
    foreach ($key in @('NVM_HOME', 'NVM_SYMLINK', 'SCOOP', 'UV')) {
        $val = [Environment]::GetEnvironmentVariable($key, 'User')
        if (-not $val) { $val = [Environment]::GetEnvironmentVariable($key, 'Machine') }
        if ($val) { Set-Item -Path "env:$key" -Value $val -ErrorAction SilentlyContinue }
    }
    $nvmLink = [Environment]::GetEnvironmentVariable('NVM_SYMLINK', 'User')
    if (-not $nvmLink) { $nvmLink = [Environment]::GetEnvironmentVariable('NVM_SYMLINK', 'Machine') }
    if ($nvmLink -and $env:PATH -notlike "*$nvmLink*") {
        $env:PATH = "$nvmLink;$env:PATH"
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
        'https://objects.githubusercontent.com'
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

Set-WerUtf8
Write-Output "===== windows-env-rescue devtools ====="

$shared = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')
$manifestPath = Join-Path $shared 'manifests\devtools.toml'
$manifest = Import-WerManifest -Path $manifestPath
Write-Output "Manifest: $($manifest.Name)"

if (-not (Test-WerCmd 'scoop')) {
    Write-Output "scoop missing — run /env-foundation first."
    Write-Output "INSTALL-DEVTOOLS: FAIL: scoop missing"
    exit 1
}

$pyVer = $UvPython
if (-not $pyVer -and $manifest.Post -and $manifest.Post['uv_python']) {
    $pyVer = [string]$manifest.Post['uv_python']
}
if (-not $pyVer) { $pyVer = '3.12' }

$needFetch = $false
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    if (-not $bin) { continue }
    $req = [bool]$tool['required']
    if ($SkipOptional -and -not $req) { continue }
    if (-not (Test-WerCmd $bin)) { $needFetch = $true; break }
}
if (-not (Test-WerCmd 'node')) { $needFetch = $true }

if ($needFetch) {
    Write-Output "Network gate:"
    $blocked = Test-WerNetwork
    if ($blocked.Count -gt 0) {
        Write-Output "Blocked: $($blocked -join ', ')"
        Write-Output "Set scoop proxy (e.g. scoop config proxy 127.0.0.1:7890) and re-run."
        Write-Output "INSTALL-DEVTOOLS: FAIL: network unreachable"
        exit 1
    }
}

$requiredFail = @()
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    $pkg = $tool['scoop']
    $req = [bool]$tool['required']
    if (-not $bin) { continue }
    if (Test-WerCmd $bin) {
        Write-Output "OK      $bin"
        continue
    }
    Write-Output "MISSING $bin (scoop: $pkg) required=$req"
    if (-not $req -and $SkipOptional) {
        Write-Output "  skip optional (-SkipOptional)"
        if ($status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }
    # Ensure main bucket once before any install (clean machines)
    if (-not (Get-Variable -Name werBucketChecked -Scope Script -ErrorAction SilentlyContinue)) {
        $buckets = @(scoop bucket list 2>$null | Out-String)
        if (($buckets -join "`n") -notmatch 'main') {
            Write-Output "Adding scoop bucket 'main'..."
            scoop bucket add main
        }
        $script:werBucketChecked = $true
    }
    scoop install $pkg
    if ($LASTEXITCODE -ne 0) {
        if ($req) { $requiredFail += $bin }
        elseif ($status -eq 'OK') { $status = 'PARTIAL' }
    }
}

Update-WerPathFromUserEnv
# scoop shims if still missing
$scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
if ($scoopCmd) {
    $scoopRoot = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
    $shims = Join-Path $scoopRoot 'shims'
    if ($scoopRoot -and (Test-Path $shims) -and $env:PATH -notlike "*$shims*") {
        $env:PATH = "$shims;$env:PATH"
    }
}

# Re-check required scoop tools
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    if (-not $bin -or -not [bool]$tool['required']) { continue }
    if (-not (Test-WerCmd $bin)) {
        if ($requiredFail -notcontains $bin) { $requiredFail += $bin }
    }
}
if ($requiredFail.Count -gt 0) {
    Write-Output "INSTALL-DEVTOOLS: FAIL: required missing: $($requiredFail -join ', ')"
    exit 1
}

# --- nvm / node ---
Update-WerPathFromUserEnv
if (-not (Test-WerCmd 'nvm')) {
    Write-Output "nvm not visible after install/PATH refresh."
    Write-Output "Open a new shell and re-run, or check scoop nvm install output."
    Write-Output "INSTALL-DEVTOOLS: FAIL: nvm not on PATH"
    exit 1
}

$nvmChannel = 'lts'
if ($manifest.Post -and $manifest.Post['nvm_channel']) { $nvmChannel = [string]$manifest.Post['nvm_channel'] }

Write-Output "nvm version: $(nvm version 2>&1 | Select-Object -First 1)"
$installed = @()
try { $installed = @(nvm list 2>&1 | Out-String) } catch { $installed = @() }
if (($installed -join "`n") -notmatch '\d+\.\d+\.\d+') {
    Write-Output "No Node via nvm yet — nvm install $nvmChannel"
    nvm install $nvmChannel
    if ($LASTEXITCODE -ne 0) {
        Write-Output "nvm install $nvmChannel failed"
        Write-Output "INSTALL-DEVTOOLS: FAIL: nvm install $nvmChannel"
        exit 1
    }
} else {
    Write-Output "nvm already has Node versions listed"
}

nvm use $nvmChannel 2>&1 | Out-Host
Update-WerPathFromUserEnv

if (-not (Test-WerCmd 'node')) {
    Write-Output "node still not on PATH after nvm use $nvmChannel"
    Write-Output "New shell required for NVM_SYMLINK to resolve; re-run this script in a fresh pwsh."
    Write-Output "INSTALL-DEVTOOLS: FAIL: node not on PATH"
    exit 1
}
Write-Output "node: $(node --version)"
Write-Output "npm : $(npm --version 2>&1 | Select-Object -First 1)"

# --- pnpm via corepack ---
if (-not $SkipPnpm -and $manifest.Post -and [bool]$manifest.Post['pnpm']) {
    if (Test-WerCmd 'corepack') {
        try {
            corepack enable
            if (-not (Test-WerCmd 'pnpm')) {
                corepack prepare pnpm@latest --activate
            }
        } catch {
            Write-Output "corepack/pnpm setup warning: $($_.Exception.Message)"
        }
    }
    if (-not (Test-WerCmd 'pnpm')) {
        Write-Output "pnpm not available (corepack) — optional PARTIAL"
        if ($status -eq 'OK') { $status = 'PARTIAL' }
    } else {
        Write-Output "pnpm: $(pnpm --version 2>&1 | Select-Object -First 1)"
    }
}

# --- uv python ---
if (Test-WerCmd 'uv') {
    Write-Output "uv: $(uv --version 2>&1 | Select-Object -First 1)"
    $havePy = $false
    try {
        $null = uv python find $pyVer 2>&1
        if ($LASTEXITCODE -eq 0) { $havePy = $true }
    } catch { }
    if (-not $havePy) {
        Write-Output "uv python install $pyVer"
        uv python install $pyVer
        if ($LASTEXITCODE -ne 0) {
            Write-Output "uv python install $pyVer failed (PARTIAL)"
            if ($status -eq 'OK') { $status = 'PARTIAL' }
        } else {
            Write-Output "uv python $pyVer ready"
        }
    } else {
        Write-Output "uv python $pyVer already available"
    }
} else {
    if ($status -eq 'OK') { $status = 'PARTIAL' }
}

# --- git identity ---
$gitName = $null
$gitEmail = $null
try { $gitName = (git config --global user.name 2>$null) } catch { }
try { $gitEmail = (git config --global user.email 2>$null) } catch { }

if (-not [string]::IsNullOrWhiteSpace($gitName) -and -not [string]::IsNullOrWhiteSpace($gitEmail)) {
    Write-Output "git identity: $gitName <$gitEmail>"
} elseif (-not [string]::IsNullOrWhiteSpace($GitName) -and -not [string]::IsNullOrWhiteSpace($GitEmail)) {
    git config --global user.name $GitName
    $nameCode = $LASTEXITCODE
    git config --global user.email $GitEmail
    $emailCode = $LASTEXITCODE
    $gitName = git config --global user.name
    $gitEmail = git config --global user.email
    if ($nameCode -ne 0 -or $emailCode -ne 0 -or
        [string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        Write-Output "git identity write failed (nameCode=$nameCode emailCode=$emailCode name='$gitName' email='$gitEmail')"
        if ($status -eq 'OK') { $status = 'PARTIAL' }
    } else {
        Write-Output "git identity set: $gitName <$gitEmail>"
    }
} else {
    Write-Output "git identity missing."
    Write-Output "  git config --global user.name  \"Your Name\""
    Write-Output "  git config --global user.email \"you@example.com\""
    Write-Output "Or re-run with -GitName / -GitEmail (skill /env-devtools can prompt)."
    if ($status -eq 'OK') { $status = 'PARTIAL' }
}

# Final required verify — run real commands, not mere presence
$fail = @()
foreach ($tool in $manifest.Tools) {
    if (-not [bool]$tool['required']) { continue }
    $bin = $tool['binary']
    $verify = $tool['verify']
    if (-not $bin) { continue }
    $ok = Test-WerCmd $bin
    if ($ok -and $verify) { $ok = Test-WerVerify $verify }
    if (-not $ok) { $fail += $bin }
}
if (-not (Test-WerCmd 'node') -or -not (Test-WerVerify 'node --version')) { $fail += 'node' }
if ($fail.Count -gt 0) {
    Write-Output "INSTALL-DEVTOOLS: FAIL: verify failed: $($fail -join ', ')"
    exit 1
}

# Re-read identity once more — OK requires a usable git identity or explicit PARTIAL
$gitName = $null; $gitEmail = $null
try { $gitName = (git config --global user.name 2>$null) } catch { }
try { $gitEmail = (git config --global user.email 2>$null) } catch { }
if ([string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
    Write-Output "git identity still missing after setup"
    if ($status -eq 'OK') { $status = 'PARTIAL' }
}

Write-Output ""
if ($status -eq 'OK') {
    Write-Output "INSTALL-DEVTOOLS: OK"
    exit 0
}
Write-Output "INSTALL-DEVTOOLS: PARTIAL"
exit 2
