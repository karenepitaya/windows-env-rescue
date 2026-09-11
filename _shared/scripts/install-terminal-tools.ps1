<#
.SYNOPSIS
  windows-env-rescue — L1 terminal tools installer (manifest-driven).

.DESCRIPTION
  Reads _shared/manifests/terminal.toml, installs missing scoop packages, then
  writes/refreshes the managed profile block (windows-env-rescue markers).
  Migrates a legacy terminal-boost profile block when present.
  Ends with:
    INSTALL-TERMINAL-TOOLS: OK | PARTIAL | FAIL: <reason>
  Exit codes: 0 OK, 2 PARTIAL, 1 FAIL.

.NOTES
  Prefer PowerShell 7+. Safe to re-run (idempotent profile block replace).
#>

$ErrorActionPreference = 'Continue'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    chcp 65001 > $null
} catch { }

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Output "This step needs PowerShell 7 (pwsh)."
    Write-Output "INSTALL-TERMINAL-TOOLS: FAIL: PowerShell 7+ required"
    exit 1
}

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Output "ERROR: scoop is not installed. Run install-foundation.ps1 first."
    Write-Output "INSTALL-TERMINAL-TOOLS: FAIL: scoop missing"
    exit 1
}

$shared = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Import-WerManifest.ps1')
$manifestPath = Join-Path $shared 'manifests\terminal.toml'
$manifest = Import-WerManifest -Path $manifestPath

Write-Output "===== windows-env-rescue terminal ====="
Write-Output "Manifest: $($manifest.Name)"

$missingPkgs = [System.Collections.Generic.List[string]]::new()
$requiredFail = @()

foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    $pkg = $tool['scoop']
    $req = [bool]$tool['required']
    if (-not $bin) { continue }
    if (Get-Command $bin -ErrorAction SilentlyContinue) {
        Write-Output ("OK       {0,-10} scoop={1}" -f $bin, $pkg)
    } else {
        Write-Output ("MISSING  {0,-10} scoop={1} required={2}" -f $bin, $pkg, $req)
        if ($missingPkgs -notcontains $pkg) { $missingPkgs.Add($pkg) }
    }
}

$status = 'OK'

if ($missingPkgs.Count -gt 0) {
    $buckets = @(scoop bucket list 2>$null | Out-String)
    if (($buckets -join "`n") -notmatch 'main') {
        Write-Output "Adding scoop bucket 'main'..."
        scoop bucket add main
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: failed to add main bucket"
            Write-Output "INSTALL-TERMINAL-TOOLS: FAIL: scoop bucket main"
            exit 1
        }
    }
    Write-Output "Installing: $($missingPkgs -join ' ')"
    foreach ($pkg in $missingPkgs) {
        scoop install $pkg
        if ($LASTEXITCODE -ne 0) {
            Write-Output "  install failed: $pkg (exit $LASTEXITCODE)"
            $tool = $manifest.Tools | Where-Object { $_['scoop'] -eq $pkg } | Select-Object -First 1
            if ($tool -and [bool]$tool['required']) {
                $requiredFail += $tool['binary']
            } else {
                $status = 'PARTIAL'
            }
        }
    }
# Refresh PATH for custom scoop roots (not only default USERPROFILE\scoop)
$scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
if ($scoopCmd) {
    $scoopRoot = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
    $shims = Join-Path $scoopRoot 'shims'
    if ($scoopRoot -and (Test-Path $shims) -and $env:PATH -notlike "*$shims*") {
        $env:PATH = "$shims;$env:PATH"
    }
}
}

# Re-check
$stillReq = @()
foreach ($tool in $manifest.Tools) {
    $bin = $tool['binary']
    if (-not $bin) { continue }
    if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) {
        if ([bool]$tool['required']) { $stillReq += $bin }
        elseif ($status -eq 'OK') { $status = 'PARTIAL' }
    }
}
if ($requiredFail.Count -gt 0 -or $stillReq.Count -gt 0) {
    $all = @($requiredFail + $stillReq | Select-Object -Unique)
    Write-Output "INSTALL-TERMINAL-TOOLS: FAIL: required missing: $($all -join ', ')"
    exit 1
}

# --- Profile block ---
$profilePath = $PROFILE
$blockFile = Join-Path $shared 'scripts\profile-block.ps1'
if (-not (Test-Path -LiteralPath $blockFile)) {
    Write-Output "INSTALL-TERMINAL-TOOLS: FAIL: profile-block.ps1 missing"
    exit 1
}
$block = Get-Content -LiteralPath $blockFile -Raw -Encoding UTF8

$start = if ($manifest.Profile -and $manifest.Profile['start']) { $manifest.Profile['start'] } else { '# >>> windows-env-rescue >>>' }
$end   = if ($manifest.Profile -and $manifest.Profile['end']) { $manifest.Profile['end'] } else { '# <<< windows-env-rescue <<<' }
$legacyStart = '# >>> terminal-boost >>>'
$legacyEnd   = '# <<< terminal-boost <<<'

if (-not (Test-Path -LiteralPath $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Output "Created $profilePath"
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $profilePath -Destination "$profilePath.bak-$ts" -Force
Write-Output "Backed up profile to $profilePath.bak-$ts"

$content = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
if ($null -eq $content) { $content = '' }

function Set-WerProfileRegion([string]$Body, [string]$StartMark, [string]$EndMark, [string]$NewBlock) {
    if ($Body -notmatch [regex]::Escape($StartMark)) { return $null }
    $normalized = $NewBlock.TrimEnd("`r", "`n")
    # Consume trailing newlines after end marker so re-runs are byte-stable.
    $pattern = '(?s)' + [regex]::Escape($StartMark) + '.*?' + [regex]::Escape($EndMark) + '[\r\n]*'
    # MatchEvaluator required: string replacement would expand $_ $& $1 inside the block.
    return [regex]::Replace($Body, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $normalized + "`r`n" })
}

$newContent = Set-WerProfileRegion $content $start $end $block
if ($null -ne $newContent) {
    Write-Output "Replaced existing windows-env-rescue block"
} else {
    $newContent = Set-WerProfileRegion $content $legacyStart $legacyEnd $block
    if ($null -ne $newContent) {
        Write-Output "Migrated legacy terminal-boost block -> windows-env-rescue"
    } else {
        $newContent = $content.TrimEnd() + "`n`n" + $block
        Write-Output "Appended windows-env-rescue block"
    }
}

Set-Content -LiteralPath $profilePath -Value $newContent -NoNewline -Encoding UTF8

Write-Output ""
if ($status -eq 'OK') {
    Write-Output "INSTALL-TERMINAL-TOOLS: OK"
    exit 0
}
Write-Output "INSTALL-TERMINAL-TOOLS: PARTIAL"
exit 2
