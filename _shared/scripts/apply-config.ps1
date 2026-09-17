<#
.SYNOPSIS
  Deterministically writes the yazi-windows-rescue minimal or complete config.

.DESCRIPTION
  Avoids ad-hoc TOML editing by generating all suite-managed files from vendored
  templates. The script backs up the existing config dir itself before any write
  (timestamped copy, rotated to keep the newest 5), so bare runs are safe too.
  Re-running is idempotent.
#>

[CmdletBinding()]
param(
    [ValidateSet("Minimal", "Complete")]
    [string]$Tier = "Complete",

    [ValidateSet("zh", "en")]
    [string]$KeymapLanguage = "zh",

    [ValidateSet("notepad", "code", "nvim")]
    [string]$Editor = "notepad",

    [string]$ProjectPath,

    [switch]$EnableMarkdown,

    [switch]$EnableTheme
)

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 > $null
} catch { }

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Content.TrimEnd() + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding $false)
    )
}

function Convert-ToTomlSingleQuoted([string]$Value) {
    return $Value.Replace("'", "''")
}

$sharedDir = Split-Path $PSScriptRoot -Parent
$templateDir = Join-Path $sharedDir "config"
$cfgDir = Join-Path $env:APPDATA "yazi\config"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null

# Self-backup before any write/delete (never rely on the caller; rotate to 5).
if (Get-ChildItem $cfgDir -Force -ErrorAction SilentlyContinue) {
    $bak = "$env:APPDATA\yazi\config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $cfgDir $bak -Recurse -Force
    Write-Output "backup: $bak"
    $old = Get-ChildItem "$env:APPDATA\yazi" -Directory -Filter 'config-backup-*' -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -Skip 5
    foreach ($f in $old) { Remove-Item $f.FullName -Recurse -Force; Write-Output "rotated old backup: $($f.Name)" }
}

if ($Tier -eq "Minimal") {
    Copy-Item (Join-Path $templateDir "yazi-minimal.toml") (Join-Path $cfgDir "yazi.toml") -Force
    foreach ($name in "keymap.toml", "theme.toml", "package.toml") {
        $path = Join-Path $cfgDir $name
        if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
    }
    Write-Output "CONFIG: MINIMAL"
    exit 0
}

if ($KeymapLanguage -eq "zh") {
    $versionLine = yazi --version 2>&1 | Select-Object -First 1
    $versionExit = $LASTEXITCODE
    if ($versionExit -ne 0 -or $versionLine -notmatch '\b26\.5\.6\b') {
        throw "The Chinese keymap is pinned to Yazi 26.5.6. Current version: $versionLine. Use -KeymapLanguage en."
    }
}

if ($Editor -ne "notepad" -and -not (Get-Command $Editor -ErrorAction SilentlyContinue)) {
    throw "Selected editor '$Editor' is not available on PATH."
}

if ($ProjectPath) {
    if (-not [System.IO.Path]::IsPathRooted($ProjectPath)) {
        throw "ProjectPath must be an absolute Windows path."
    }
    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
        throw "ProjectPath does not exist or is not a directory: $ProjectPath"
    }
}

if ($EnableMarkdown) {
    $piperPath = Join-Path $cfgDir "plugins\piper.yazi"
    if (-not (Get-Command glow -ErrorAction SilentlyContinue)) {
        throw "Markdown preview requested, but glow is not available on PATH."
    }
    if (-not (Test-Path -LiteralPath $piperPath -PathType Container)) {
        throw "Markdown preview requested, but piper.yazi is not installed at $piperPath."
    }
}

if ($EnableTheme) {
    $flavorPath = Join-Path $cfgDir "flavors\catppuccin-mocha.yazi"
    if (-not (Test-Path -LiteralPath $flavorPath -PathType Container)) {
        throw "Theme requested, but catppuccin-mocha.yazi is not installed at $flavorPath."
    }
}

$yazi = Get-Content (Join-Path $templateDir "yazi-complete.toml") -Raw -Encoding UTF8
$editorLines = switch ($Editor) {
    "code" {
        @(
            '    { run = ''code %s'', desc = "VS Code", for = "windows", orphan = true },'
            '    { run = ''notepad %s'', desc = "Notepad", for = "windows", orphan = true },'
        )
    }
    "nvim" {
        @(
            '    { run = ''nvim %s'', desc = "Neovim", for = "windows", block = true },'
            '    { run = ''notepad %s'', desc = "Notepad", for = "windows", orphan = true },'
        )
    }
    default {
        @('    { run = ''notepad %s'', desc = "Notepad", for = "windows", orphan = true },')
    }
}
$opener = "[opener]`nedit = [`n$($editorLines -join "`n")`n]"
$openerPattern = [regex]::new('(?ms)^\[opener\]\s*edit\s*=\s*\[.*?^\]')
$yazi = $openerPattern.Replace($yazi, $opener, 1)

if ($EnableMarkdown) {
    $yazi += @'

[[plugin.prepend_previewers]]
url = "*.md"
run = 'piper -- glow -w=$w -s=dark "$1"'
'@
}
Write-Utf8NoBom (Join-Path $cfgDir "yazi.toml") $yazi

$keymapTemplate = if ($KeymapLanguage -eq "zh") { "keymap-zh.toml" } else { "keymap-complete.toml" }
$keymap = Get-Content (Join-Path $templateDir $keymapTemplate) -Raw -Encoding UTF8
if ($ProjectPath) {
    $resolved = [System.IO.Path]::GetFullPath($ProjectPath).Replace("\", "/")
    $escaped = Convert-ToTomlSingleQuoted $resolved
    $entry = '    { on = ["g", "p"], run = ''cd "' + $escaped + '"'', desc = "Go to project directory" },'
    $keymapStart = [regex]::new('(?m)^(prepend_keymap\s*=\s*\[)\r?$')
    if (-not $keymapStart.IsMatch($keymap)) {
        throw "Could not find the managed prepend_keymap array in $keymapTemplate."
    }
    # Group 1 excludes the line's CR: re-inserting $0 verbatim on a CRLF template
    # would emit a stray \r ("prepend_keymap = [\r\r\n") and break TOML parsing.
    $keymap = $keymapStart.Replace($keymap, ('$1' + [Environment]::NewLine + $entry), 1)
}
Write-Utf8NoBom (Join-Path $cfgDir "keymap.toml") $keymap

if ($EnableTheme) {
    Copy-Item (Join-Path $templateDir "theme.toml") (Join-Path $cfgDir "theme.toml") -Force
} else {
    $theme = Join-Path $cfgDir "theme.toml"
    if (Test-Path $theme) { Remove-Item -LiteralPath $theme -Force }
}

Write-Output "CONFIG: COMPLETE"
Write-Output "  keymap: $KeymapLanguage"
Write-Output "  editor: $Editor"
Write-Output "  markdown: $([bool]$EnableMarkdown)"
Write-Output "  theme: $([bool]$EnableTheme)"
if ($ProjectPath) { Write-Output "  project shortcut: g p -> $resolved" }
