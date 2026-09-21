<#
.SYNOPSIS
  windows-env-rescue — L5 import local dotfiles package.

.DESCRIPTION
  Restores files from an export package. Backs up targets before overwrite.
  Does not run scoop install. Status: IMPORT-DOTFILES: OK|PARTIAL|FAIL
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FromDir,
    [string[]]$Ids,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$status = 'OK'

function Set-WerUtf8 {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        chcp 65001 > $null
    } catch { }
}

Set-WerUtf8
Write-Output "===== windows-env-rescue import-dotfiles ====="

# -File invocation may pass -Ids as a single comma-separated string
if ($Ids) {
    $Ids = @($Ids | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if (-not (Test-Path -LiteralPath $FromDir)) {
    Write-Output "IMPORT-DOTFILES: FAIL: package not found: $FromDir"
    exit 1
}
$manPath = Join-Path $FromDir 'manifest.json'
if (-not (Test-Path -LiteralPath $manPath)) {
    Write-Output "IMPORT-DOTFILES: FAIL: manifest.json missing in package"
    exit 1
}
$manifest = Get-Content -LiteralPath $manPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest -isnot [System.Array]) { $manifest = @($manifest) }

$wt = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue |
    Select-Object -First 1

function Get-WerImportTarget([string]$Id) {
    switch ($Id) {
        'profile' {
            if ($PROFILE) { return $PROFILE }
            return (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
        }
        'gitconfig' { return (Join-Path $env:USERPROFILE '.gitconfig') }
        'wt' {
            if ($wt) { return (Join-Path $wt.FullName 'LocalState\settings.json') }
            return $null
        }
        'vscode-settings' { return (Join-Path $env:APPDATA 'Code\User\settings.json') }
        'vscode-keybindings' { return (Join-Path $env:APPDATA 'Code\User\keybindings.json') }
        'yazi' { return (Join-Path $env:APPDATA 'yazi\config') }
        'scoop-export' { return $null } # inventory only
        default { return $null }
    }
}

$restored = 0
$skipped = @()
$failed = @()

foreach ($entry in $manifest) {
    $id = [string]$entry.id
    if (-not $id) { $id = [string]$entry.Id }
    if ($Ids -and $Ids.Count -gt 0 -and ($Ids -notcontains $id)) {
        continue
    }
    if ($id -eq 'scoop-export') {
        Write-Output "skip  scoop-export (use L0-L4/bootstrap to reinstall tools; package has scoop-export.json for reference)"
        $skipped += $id
        continue
    }

    $exported = [string]$entry.exported
    $kind = [string]$entry.kind
    if (-not $exported -or -not (Test-Path -LiteralPath $exported)) {
        Write-Output "miss  $id (not in package)"
        $skipped += $id
        continue
    }

    $target = Get-WerImportTarget $id
    if (-not $target) {
        Write-Output "skip  $id (no target on this machine)"
        $skipped += $id
        if ($status -eq 'OK') { $status = 'PARTIAL' }
        continue
    }

    $targetExists = Test-Path -LiteralPath $target
    if ($targetExists -and -not $Force) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $bak = "$target.bak-$ts"
        if ($kind -eq 'dir') {
            Copy-Item -LiteralPath $target -Destination $bak -Recurse -Force
        } else {
            Copy-Item -LiteralPath $target -Destination $bak -Force
        }
        Write-Output "backup $target -> $bak"
    }

    try {
        $parent = Split-Path $target -Parent
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        if ($kind -eq 'dir') {
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            Copy-Item -LiteralPath $exported -Destination $target -Recurse -Force
        } else {
            # exported may be a folder containing the file
            $srcFile = $exported
            if (Test-Path $exported -PathType Container) {
                $leaf = Get-ChildItem -LiteralPath $exported -File | Select-Object -First 1
                if ($leaf) { $srcFile = $leaf.FullName }
            }
            Copy-Item -LiteralPath $srcFile -Destination $target -Force
        }
        Write-Output "ok    $id -> $target"
        $restored++
    } catch {
        Write-Output "fail  $id : $($_.Exception.Message)"
        $failed += $id
    }
}

Write-Output ""
Write-Output "restored=$restored skipped=$($skipped -join ',') failed=$($failed -join ',')"
Write-Output "Open a new terminal after import."
if ($failed.Count -gt 0) {
    Write-Output "IMPORT-DOTFILES: FAIL: $($failed -join ', ')"
    exit 1
}
if ($restored -eq 0) {
    Write-Output "IMPORT-DOTFILES: FAIL: nothing restored"
    exit 1
}
if ($status -eq 'OK') {
    Write-Output "IMPORT-DOTFILES: OK"
    exit 0
}
Write-Output "IMPORT-DOTFILES: PARTIAL"
exit 2
