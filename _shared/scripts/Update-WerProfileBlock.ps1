<#
.SYNOPSIS
  windows-env-rescue — the ONE writer for the managed PowerShell profile block.

.DESCRIPTION
  Every layer that touches $PROFILE must go through this script. Never append to
  or regex-edit $PROFILE from a SKILL.md or another script.

  Guarantees:
  - Encoding-safe: the profile is read as raw bytes; UTF-8 (BOM or not) is
    detected with a strict decoder, anything else falls back to the system ANSI
    codepage (GBK on zh-CN machines). The file is written back in the SAME
    encoding, so content outside the markers survives untouched.
  - Idempotent: replaces the region between the markers byte-stably; migrates
    the legacy terminal-boost markers; appends only when no markers exist.
  - Reversible: timestamped backup before every write, rotated to keep the
    newest 5 (override with -KeepBackups).

  Last line: PROFILE-BLOCK: OK | FAIL: <reason>   Exit: 0 / 1.
#>

[CmdletBinding()]
param(
    [string]$ProfilePath = $PROFILE,
    [string]$BlockFile = (Join-Path $PSScriptRoot 'profile-block.ps1'),
    [string]$StartMark  = '# >>> windows-env-rescue >>>',
    [string]$EndMark    = '# <<< windows-env-rescue <<<',
    [string]$LegacyStart = '# >>> terminal-boost >>>',
    [string]$LegacyEnd   = '# <<< terminal-boost <<<',
    [int]$KeepBackups = 5
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Read-WerTextPreservingEncoding([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return @{ Text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3); Encoding = (New-Object System.Text.UTF8Encoding $true) }
    }
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try {
        $t = $strict.GetString($bytes)
        return @{ Text = $t; Encoding = (New-Object System.Text.UTF8Encoding $false) }
    } catch [System.Text.DecoderFallbackException] {
        # NOTE: Encoding.Default is UTF-8 on .NET Core/pwsh — the real ANSI
        # codepage (936 on zh-CN) must go through the codepages provider.
        [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
        $ansi = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
        return @{ Text = $ansi.GetString($bytes); Encoding = $ansi }
    }
}

function Backup-WerProfile([string]$Path, [int]$Keep) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = "$Path.bak-$ts"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    Write-Output "Backed up profile to $bak"
    $old = Get-ChildItem -LiteralPath (Split-Path $Path -Parent) -Filter "$(Split-Path $Path -Leaf).bak-*" -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -Skip $Keep
    foreach ($f in $old) { Remove-Item -LiteralPath $f.FullName -Force; Write-Output "Rotated old backup: $($f.Name)" }
}

function Set-WerProfileRegion([string]$Body, [string]$StartMark, [string]$EndMark, [string]$NewBlock, [string]$NewLine) {
    if ($Body -notmatch [regex]::Escape($StartMark)) { return $null }
    # Normalize the block to the file's own newline style: byte-mismatched
    # line endings make identical code "different" to Add-Type.
    $normalized = ($NewBlock.TrimEnd("`r", "`n") -replace "`r`n", "`n") -replace "`n", $NewLine
    # Consume trailing newlines after end marker so re-runs are byte-stable.
    $pattern = '(?s)' + [regex]::Escape($StartMark) + '.*?' + [regex]::Escape($EndMark) + '[\r\n]*'
    # MatchEvaluator required: string replacement would expand $_ $& $1 inside the block.
    return [regex]::Replace($Body, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $normalized + $NewLine })
}

try {
    if (-not (Test-Path -LiteralPath $BlockFile)) {
        Write-Output "PROFILE-BLOCK: FAIL: block file missing: $BlockFile"
        exit 1
    }
    $blockRaw = Read-WerTextPreservingEncoding $BlockFile
    $block = $blockRaw.Text

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
        Write-Output "Created $ProfilePath"
    }

    $existing = Read-WerTextPreservingEncoding $ProfilePath
    $content = $existing.Text
    # Follow the file's dominant newline style; default to CRLF on Windows.
    $nl = if ($content -match "`r`n" -or $content.Length -eq 0) { "`r`n" } else { "`n" }

    if ($content.Length -gt 0) { Backup-WerProfile $ProfilePath $KeepBackups }

    $newContent = Set-WerProfileRegion $content $StartMark $EndMark $block $nl
    if ($null -ne $newContent) {
        Write-Output "Replaced existing windows-env-rescue block"
    } else {
        $newContent = Set-WerProfileRegion $content $LegacyStart $LegacyEnd $block $nl
        if ($null -ne $newContent) {
            Write-Output "Migrated legacy terminal-boost block -> windows-env-rescue"
        } else {
            $normalizedBlock = ($block.TrimEnd("`r", "`n") -replace "`r`n", "`n") -replace "`n", $nl
            $newContent = $content.TrimEnd() + $nl + $nl + $normalizedBlock + $nl
            Write-Output "Appended windows-env-rescue block"
        }
    }

    [System.IO.File]::WriteAllText($ProfilePath, $newContent, $existing.Encoding)
    Write-Output "PROFILE-BLOCK: OK"
    exit 0
} catch {
    Write-Output "PROFILE-BLOCK: FAIL: $($_.Exception.Message)"
    exit 1
}
