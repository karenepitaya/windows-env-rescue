<#
.SYNOPSIS
  Yazi suite - one-shot cleanup / reset ("clean slate" option).
  Used when /yazi-install fails partway, or the user wants to start over.
  - Backs up then removes the yazi config folder
  - Uninstalls yazi itself (only if scoop owns it; otherwise reports the path
    and refuses to guess-delete)
  - Leaves shared tools (git, ffmpeg, scoop itself, fonts) alone: they are
    harmless standalone and may be used by other things
  Prints what it did, plus optional removal commands for everything else.
  Ends with CLEANUP: DONE only when no yazi executable remains on PATH.
  Otherwise ends with CLEANUP: PARTIAL and returns exit code 1.
.NOTES
  Works on Windows PowerShell 5.1 and pwsh 7+.
#>
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 > $null
} catch { }

try {

Write-Output "===== yazi cleanup / reset ====="
$cleanupOk = $true

# 1. Backup + remove config
$cfg = "$env:APPDATA\yazi\config"
if (Test-Path $cfg) {
    $bak = "$env:APPDATA\yazi\config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $cfg $bak -Recurse -Force
    Write-Output "config: backed up to $bak"
    Remove-Item $cfg -Recurse -Force
    Write-Output "config: removed (backup kept)."
} else {
    Write-Output "config: no config folder found."
}

# 2. Uninstall yazi (scoop-owned only)
$scoopHasYazi = $false
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    $hit = scoop list 2>$null | Select-String -Pattern "^yazi\s|/yazi\s|\byazi\b"
    if ($hit) { $scoopHasYazi = $true }
}
if ($scoopHasYazi) {
    Write-Output "yazi: scoop owns it -> uninstalling..."
    scoop uninstall yazi
    if ($LASTEXITCODE -eq 0) { Write-Output "yazi: uninstalled." }
    else {
        $cleanupOk = $false
        Write-Output "WARNING: scoop uninstall yazi exited $LASTEXITCODE. Re-run, or check 'scoop list'."
    }
} else {
    $yaziCmd = Get-Command yazi -ErrorAction SilentlyContinue
    if ($yaziCmd) {
        $cleanupOk = $false
        Write-Output "yazi: found at $($yaziCmd.Source) but scoop does not own it."
        Write-Output "  -> NOT deleting automatically. If you want it gone, confirm the path and remove it yourself,"
        Write-Output "     or tell Claude and it will walk you through it."
    } else {
        Write-Output "yazi: not found on PATH. Nothing to uninstall."
    }
}

# 3. What we deliberately keep, and how to remove it if you insist
Write-Output ""
Write-Output "Kept on purpose (harmless, possibly used elsewhere):"
Write-Output "  - scoop itself, git, ffmpeg, 7zip, imagemagick, poppler, fd, ripgrep, resvg, jq, glow, the Nerd Font"
Write-Output "  - YAZI_FILE_ONE / CLICOLOR_FORCE environment variables"
Write-Output "Optional removal commands if you want a deeper clean:"
Write-Output "  scoop uninstall glow fd ripgrep resvg jq poppler imagemagick ffmpeg 7zip"
Write-Output '  [Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $null, "User")'
Write-Output '  [Environment]::SetEnvironmentVariable("CLICOLOR_FORCE", $null, "User")'

Write-Output ""
$remaining = Get-Command yazi -ErrorAction SilentlyContinue
if ($remaining) {
    $cleanupOk = $false
    Write-Output "WARNING: yazi is still on PATH at $($remaining.Source)"
}

if ($cleanupOk) {
    Write-Output "CLEANUP: DONE - yazi config is removed and no yazi executable remains on PATH."
    exit 0
} else {
    Write-Output "CLEANUP: PARTIAL - config was handled, but yazi was not fully removed. Review the warning above."
    exit 1
}

} catch {
    Write-Output ""
    Write-Output "ERROR: cleanup.ps1 failed unexpectedly: $($_.Exception.Message)"
    Write-Output "Report at: https://github.com/karenepitaya/windows-env-rescue/issues"
    exit 1
}
