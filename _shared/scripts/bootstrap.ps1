<#
.SYNOPSIS
  windows-env-rescue — L0–L2 bootstrap orchestrator.

.DESCRIPTION
  Runs: install-foundation.ps1 -> install-terminal-tools.ps1 -> install-devtools.ps1 -> doctor.ps1
  Any install-layer FAIL skips higher install layers; doctor always runs last.
  Exit codes:
    0 = all install layers OK and doctor not RED (YELLOW allowed)
    2 = some install layer PARTIAL (no FAIL)
    1 = any install FAIL or doctor RED
#>

$ErrorActionPreference = 'Continue'
$scripts = $PSScriptRoot

Write-Host "########## windows-env-rescue bootstrap ##########"
Write-Host "Order: foundation -> terminal -> devtools -> doctor"

$foundationExit = 0
$terminalExit = 0
$devtoolsExit = 0
$doctorExit = 0
$skipRest = $false

function Invoke-WerInstaller([string]$FileName) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    $path = Join-Path $scripts $FileName
    Write-Host ""
    if ($pwsh) {
        Write-Host ">>>>>> $FileName (pwsh)"
        & pwsh -NoProfile -File $path | Out-Host
    } else {
        Write-Host ">>>>>> $FileName"
        & $path | Out-Host
    }
    return $LASTEXITCODE
}

function Update-WerBootstrapPath {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH', 'User')
}

Write-Host ""
Write-Host ">>>>>> install-foundation.ps1"
& (Join-Path $scripts 'install-foundation.ps1') | Out-Host
$foundationExit = $LASTEXITCODE
if ($foundationExit -eq 1) {
    $skipRest = $true
    Write-Host "foundation FAIL — skipping terminal/devtools; running doctor."
}

if (-not $skipRest) {
    Update-WerBootstrapPath
    $terminalExit = Invoke-WerInstaller 'install-terminal-tools.ps1'
    if ($terminalExit -eq 1) {
        $skipRest = $true
        Write-Host "terminal FAIL — skipping devtools; running doctor."
    }
}

if (-not $skipRest) {
    Update-WerBootstrapPath
    $devtoolsExit = Invoke-WerInstaller 'install-devtools.ps1'
}

Write-Host ""
Write-Host ">>>>>> doctor.ps1"
Update-WerBootstrapPath
& (Join-Path $scripts 'doctor.ps1') | Out-Host
$doctorExit = $LASTEXITCODE

Write-Host ""
Write-Host "Summary: foundation=$foundationExit terminal=$terminalExit devtools=$devtoolsExit doctor=$doctorExit"

if ($foundationExit -eq 1 -or $terminalExit -eq 1 -or $devtoolsExit -eq 1 -or $doctorExit -eq 1) {
    Write-Host "BOOTSTRAP: FAIL"
    exit 1
}
if ($foundationExit -eq 2 -or $terminalExit -eq 2 -or $devtoolsExit -eq 2) {
    Write-Host "BOOTSTRAP: PARTIAL"
    exit 2
}
Write-Host "BOOTSTRAP: OK"
exit 0
