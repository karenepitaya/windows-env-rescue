<#
.SYNOPSIS
  windows-env-rescue — L0–L3 bootstrap orchestrator.

.DESCRIPTION
  Order: foundation -> terminal -> devtools -> ai-coding -> doctor
  Any install-layer FAIL skips higher install layers; doctor always runs last.
  Exit codes:
    0 = all install layers OK and doctor not RED (YELLOW allowed)
    2 = some install layer PARTIAL (no FAIL)
    1 = any install FAIL or doctor RED
#>

$ErrorActionPreference = 'Continue'
$scripts = $PSScriptRoot

Write-Host "########## windows-env-rescue bootstrap ##########"
Write-Host "Order: foundation -> terminal -> devtools -> ai-coding -> doctor"

$foundationExit = 0
$terminalExit = 0
$devtoolsExit = 0
$aiExit = 0
$doctorExit = 0
$skipRest = $false

function Invoke-WerInstaller([string]$FileName, [string[]]$ExtraArgs = @()) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    $path = Join-Path $scripts $FileName
    Write-Host ""
    if ($pwsh) {
        Write-Host ">>>>>> $FileName (pwsh)"
        if ($ExtraArgs.Count -gt 0) {
            & pwsh -NoProfile -File $path @ExtraArgs | Out-Host
        } else {
            & pwsh -NoProfile -File $path | Out-Host
        }
    } else {
        Write-Host ">>>>>> $FileName"
        if ($ExtraArgs.Count -gt 0) {
            & $path @ExtraArgs | Out-Host
        } else {
            & $path | Out-Host
        }
    }
    return $LASTEXITCODE
}

function Update-WerBootstrapPath {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH', 'User')
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    if ((Test-Path $localBin) -and $env:PATH -notlike "*$localBin*") {
        $env:PATH = "$localBin;$env:PATH"
    }
}

Write-Host ""
Write-Host ">>>>>> install-foundation.ps1"
& (Join-Path $scripts 'install-foundation.ps1') | Out-Host
$foundationExit = $LASTEXITCODE
if ($foundationExit -eq 1) {
    $skipRest = $true
    Write-Host "foundation FAIL — skipping higher install layers; running doctor."
}

if (-not $skipRest) {
    Update-WerBootstrapPath
    $terminalExit = Invoke-WerInstaller 'install-terminal-tools.ps1'
    if ($terminalExit -eq 1) {
        $skipRest = $true
        Write-Host "terminal FAIL — skipping higher install layers; running doctor."
    }
}

if (-not $skipRest) {
    Update-WerBootstrapPath
    # Git identity stays user-guided; bootstrap does not invent identity.
    $devtoolsExit = Invoke-WerInstaller 'install-devtools.ps1' @('-SkipOptional')
    if ($devtoolsExit -eq 1) {
        $skipRest = $true
        Write-Host "devtools FAIL — skipping ai-coding; running doctor."
    }
}

if (-not $skipRest) {
    Update-WerBootstrapPath
    $aiExit = Invoke-WerInstaller 'install-ai-coding.ps1'
}

Write-Host ""
Write-Host ">>>>>> doctor.ps1"
Update-WerBootstrapPath
& (Join-Path $scripts 'doctor.ps1') | Out-Host
$doctorExit = $LASTEXITCODE

Write-Host ""
Write-Host "Summary: foundation=$foundationExit terminal=$terminalExit devtools=$devtoolsExit ai-coding=$aiExit doctor=$doctorExit"

if ($foundationExit -eq 1 -or $terminalExit -eq 1 -or $devtoolsExit -eq 1 -or $aiExit -eq 1 -or $doctorExit -eq 1) {
    Write-Host "BOOTSTRAP: FAIL"
    exit 1
}
if ($foundationExit -eq 2 -or $terminalExit -eq 2 -or $devtoolsExit -eq 2 -or $aiExit -eq 2) {
    Write-Host "BOOTSTRAP: PARTIAL"
    exit 2
}
Write-Host "BOOTSTRAP: OK"
exit 0
