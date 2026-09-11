<#
.SYNOPSIS
  windows-env-rescue — L0+L1 bootstrap orchestrator.

.DESCRIPTION
  Runs: install-foundation.ps1 -> install-terminal-tools.ps1 -> doctor.ps1
  FAIL stops later install layers; PARTIAL continues.
  Exit codes:
    0 = all install layers OK and doctor not RED
    2 = some PARTIAL (or doctor YELLOW with no FAIL)
    1 = any FAIL or doctor RED
#>

$ErrorActionPreference = 'Continue'
$scripts = $PSScriptRoot

function Invoke-WerScript([string]$Name) {
    $path = Join-Path $scripts $Name
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Output "BOOTSTRAP: FAIL: missing script $Name"
        return 1
    }
    Write-Output ""
    Write-Output ">>>>>> $Name"
    & $path
    return $LASTEXITCODE
}

Write-Output "########## windows-env-rescue bootstrap ##########"
Write-Output "Order: foundation -> terminal -> doctor"

$foundationExit = Invoke-WerScript 'install-foundation.ps1'
$terminalExit = 0
$doctorExit = 0

if ($foundationExit -eq 1) {
    Write-Output "foundation FAIL — skipping terminal install; running doctor for summary."
} else {
    # Re-exec terminal installer in pwsh 7 when available
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    $termPath = Join-Path $scripts 'install-terminal-tools.ps1'
    if ($pwsh) {
        Write-Output ""
        Write-Output ">>>>>> install-terminal-tools.ps1 (pwsh)"
        & pwsh -NoProfile -File $termPath
        $terminalExit = $LASTEXITCODE
    } else {
        Write-Output ""
        Write-Output ">>>>>> install-terminal-tools.ps1"
        & $termPath
        $terminalExit = $LASTEXITCODE
    }
}

Write-Output ""
Write-Output ">>>>>> doctor.ps1"
& (Join-Path $scripts 'doctor.ps1')
$doctorExit = $LASTEXITCODE

Write-Output ""
Write-Output "Summary: foundation=$foundationExit terminal=$terminalExit doctor=$doctorExit"

if ($foundationExit -eq 1 -or $terminalExit -eq 1 -or $doctorExit -eq 1) {
    Write-Output "BOOTSTRAP: FAIL"
    exit 1
}
if ($foundationExit -eq 2 -or $terminalExit -eq 2) {
    Write-Output "BOOTSTRAP: PARTIAL"
    exit 2
}
Write-Output "BOOTSTRAP: OK"
exit 0
