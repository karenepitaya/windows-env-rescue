<#
.SYNOPSIS
  windows-env-rescue — L4 GUI apps installer (scoop extras).

.DESCRIPTION
  Detect-first scoop installs for curated apps: vscode, cc-switch, chatgpt.
  Status: INSTALL-APPS: OK | PARTIAL | FAIL: <reason>
  Exit: 0 OK, 2 PARTIAL, 1 FAIL.
#>
[CmdletBinding()]
param(
    [switch]$SkipVscode,
    [switch]$SkipCcSwitch,
    [switch]$SkipChatgpt
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

function Update-WerScoopPath {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH', 'User')
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        $root = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
        $shims = Join-Path $root 'shims'
        if ($root -and (Test-Path $shims) -and $env:PATH -notlike "*$shims*") {
            $env:PATH = "$shims;$env:PATH"
        }
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

function Test-WerScoopInstalled([string]$Pkg) {
    $out = @(scoop list 2>$null | Out-String)
    return ($out -match [regex]::Escape($Pkg))
}

Set-WerUtf8
Write-Output "===== windows-env-rescue apps ====="

$shared = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')
$manifest = Import-WerManifest -Path (Join-Path $shared 'manifests\apps.toml')
Write-Output "Manifest: $($manifest.Name)"

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Output "scoop missing — run /env-foundation first."
    Write-Output "INSTALL-APPS: FAIL: scoop missing"
    exit 1
}

Update-WerScoopPath

$buckets = @(scoop bucket list 2>$null | Out-String)
if (($buckets -join "`n") -notmatch 'extras') {
    Write-Output "Adding scoop bucket 'extras'..."
    scoop bucket add extras
    if ($LASTEXITCODE -ne 0) {
        Write-Output "INSTALL-APPS: FAIL: cannot add extras bucket"
        exit 1
    }
}

$failRequired = @()
foreach ($tool in $manifest.Tools) {
    $id = $tool['id']
    $bin = $tool['binary']
    $pkg = $tool['scoop']
    $req = [bool]$tool['required']
    $verify = $tool['verify']
    if (-not $pkg) { continue }

    $skip = ($id -eq 'vscode' -and $SkipVscode) -or
            ($id -eq 'cc-switch' -and $SkipCcSwitch) -or
            ($id -eq 'chatgpt' -and $SkipChatgpt)
    if ($skip) {
        Write-Output "SKIP    $pkg"
        if ($req -and $status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }

    $binOk = $bin -and (Test-WerCmd $bin)
    $verifyOk = $false
    if ($binOk -and $verify) { $verifyOk = Test-WerVerify $verify }
    $scoopOk = Test-WerScoopInstalled $pkg

    if ($verify -and $binOk -and $verifyOk) {
        Write-Output "OK      $pkg ($bin)"
        continue
    }
    if (-not $verify -and ($binOk -or $scoopOk)) {
        Write-Output "OK      $pkg (verify limited; scoop/bin present)"
        if ($id -eq 'chatgpt') {
            Write-Output "  note: some extras chatgpt manifests may still launch Store/web installer."
            Write-Output "        Confirm the app appears in Start Menu if you must avoid Microsoft Store."
        }
        continue
    }

    Write-Output "MISSING $pkg (scoop extras) required=$req"
    scoop install $pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Output "  scoop install $pkg failed"
        if ($req) { $failRequired += $pkg } elseif ($status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }
    Update-WerScoopPath
    $binOk = $bin -and (Test-WerCmd $bin)
    $scoopOk = Test-WerScoopInstalled $pkg
    $verifyOk = $false
    if ($binOk -and $verify) { $verifyOk = Test-WerVerify $verify }

    $ok = $false
    if ($verify) { $ok = $binOk -and $verifyOk }
    else { $ok = $binOk -or $scoopOk }

    if (-not $ok) {
        Write-Output "  post-install check failed: $pkg"
        if ($req) { $failRequired += $pkg } elseif ($status -eq 'OK') { $status = 'PARTIAL' }
    } else {
        Write-Output "  installed OK: $pkg"
        if ($id -eq 'chatgpt' -and -not $verify) {
            Write-Output "  note: chatgpt verify limited — check Start Menu; Store redirect possible."
            if ($status -eq 'OK') { $status = 'PARTIAL' }
        }
    }
}

Write-Output ""
if ($failRequired.Count -gt 0) {
    Write-Output "INSTALL-APPS: FAIL: required missing: $($failRequired -join ', ')"
    exit 1
}
if ($status -eq 'OK') {
    Write-Output "INSTALL-APPS: OK"
    exit 0
}
Write-Output "INSTALL-APPS: PARTIAL"
exit 2
