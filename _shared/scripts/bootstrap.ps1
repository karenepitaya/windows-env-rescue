<#
.SYNOPSIS
  windows-env-rescue — L0+L1 bootstrap orchestrator.

.DESCRIPTION
  Runs: install-foundation.ps1 -> install-terminal-tools.ps1 -> doctor.ps1
  FAIL stops later install layers; PARTIAL continues.
  Exit codes:
    0 = all install layers OK and doctor not RED (YELLOW allowed)
    2 = some install layer PARTIAL (no FAIL)
    1 = any install FAIL or doctor RED
#>

$ErrorActionPreference = 'Continue'
$scripts = $PSScriptRoot

Write-Host "########## windows-env-rescue bootstrap ##########"
Write-Host "Order: foundation -> terminal -> doctor"

$foundationExit = 0
$terminalExit = 0
$doctorExit = 0

Write-Host ""
Write-Host ">>>>>> install-foundation.ps1"
& (Join-Path $scripts 'install-foundation.ps1') | Out-Host
$foundationExit = $LASTEXITCODE

if ($foundationExit -eq 1) {
    Write-Host "foundation FAIL — skipping terminal install; running doctor for summary."
} else {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    $termPath = Join-Path $scripts 'install-terminal-tools.ps1'
    Write-Host ""
    if ($pwsh) {
        Write-Host ">>>>>> install-terminal-tools.ps1 (pwsh)"
        & pwsh -NoProfile -File $termPath | Out-Host
    } else {
        Write-Host ">>>>>> install-terminal-tools.ps1"
        & $termPath | Out-Host
    }
    $terminalExit = $LASTEXITCODE
}

Write-Host ""
Write-Host ">>>>>> doctor.ps1"
& (Join-Path $scripts 'doctor.ps1') | Out-Host
$doctorExit = $LASTEXITCODE

Write-Host ""
Write-Host "Summary: foundation=$foundationExit terminal=$terminalExit doctor=$doctorExit"

if ($foundationExit -eq 1 -or $terminalExit -eq 1 -or $doctorExit -eq 1) {
    Write-Host "BOOTSTRAP: FAIL"
    exit 1
}
if ($foundationExit -eq 2 -or $terminalExit -eq 2) {
    Write-Host "BOOTSTRAP: PARTIAL"
    exit 2
}
Write-Host "BOOTSTRAP: OK"
exit 0
