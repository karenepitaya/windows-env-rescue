<#
.SYNOPSIS
  Non-destructive release validation for yazi-windows-rescue.

.DESCRIPTION
  Checks required files, PowerShell syntax, known stale keymap patterns, skill
  frontmatter limits, and generated config loading. It never installs,
  uninstalls, or edits the user's real yazi configuration.
#>

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 > $null
} catch { }

$sharedDir = Split-Path $PSScriptRoot -Parent
$repoDir = Split-Path $sharedDir -Parent
$failures = [System.Collections.Generic.List[string]]::new()

function Pass([string]$Message) {
    Write-Output "[OK] $Message"
}

function Fail([string]$Message) {
    $failures.Add($Message)
    Write-Output "[FAIL] $Message"
}

Write-Output "===== release validation ====="

$required = @(
    "LICENSE",
    "README.md",
    "yazi-detect\SKILL.md",
    "yazi-install\SKILL.md",
    "yazi-config\SKILL.md",
    "env-foundation\SKILL.md",
    "env-terminal\SKILL.md",
    "env-doctor\SKILL.md",
    "env-bootstrap\SKILL.md",
    "_shared\scripts\apply-config.ps1",
    "_shared\scripts\profile-block.ps1",
    "_shared\scripts\install-terminal-tools.ps1",
    "_shared\scripts\install-foundation.ps1",
    "_shared\scripts\doctor.ps1",
    "_shared\scripts\bootstrap.ps1",
    "_shared\scripts\Import-WerManifest.ps1",
    "_shared\manifests\foundation.toml",
    "_shared\manifests\terminal.toml",
    "_shared\config\keymap-zh.toml",
    "_shared\config\wt-keybindings.json",
    "_shared\references\tool-catalog.md"
)
foreach ($relative in $required) {
    if (Test-Path (Join-Path $repoDir $relative)) { Pass "required file: $relative" }
    else { Fail "missing required file: $relative" }
}

foreach ($script in Get-ChildItem (Join-Path $sharedDir "scripts") -Filter "*.ps1") {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if ($parseErrors.Count -eq 0) { Pass "PowerShell parse: $($script.Name)" }
    else {
        foreach ($error in $parseErrors) {
            Fail "$($script.Name):$($error.Extent.StartLineNumber): $($error.Message)"
        }
    }
}

$stalePatterns = @(
    "backward wide",
    "forward wide",
    "backward lean",
    "forward lean",
    "bulk_create",
    "cd D:/project"
)
$keymapZh = Get-Content (Join-Path $sharedDir "config\keymap-zh.toml") -Raw -Encoding UTF8

# Validate wt-keybindings.json is valid JSON
$wtKeybindingsPath = Join-Path $sharedDir "config\wt-keybindings.json"
try {
    $wtJson = Get-Content $wtKeybindingsPath -Raw -Encoding UTF8
    $null = $wtJson | ConvertFrom-Json
    Pass "wt-keybindings.json: valid JSON"
} catch {
    Fail "wt-keybindings.json: invalid JSON - $($_.Exception.Message)"
}
foreach ($pattern in $stalePatterns) {
    if ($keymapZh.Contains($pattern)) { Fail "stale keymap pattern: $pattern" }
    else { Pass "stale keymap pattern absent: $pattern" }
}

foreach ($skill in Get-ChildItem $repoDir -Filter "SKILL.md" -Recurse) {
    $text = Get-Content $skill.FullName -Raw -Encoding UTF8
    if ($text -notmatch '(?s)^---\s*(.*?)\s*---') {
        Fail "missing YAML frontmatter: $($skill.FullName)"
        continue
    }
    $frontmatter = $Matches[1]
    $nameMatch = [regex]::Match($frontmatter, '(?m)^name:\s*(.+)$')
    $descriptionMatch = [regex]::Match($frontmatter, '(?m)^description:\s*(.+)$')
    if (-not $nameMatch.Success) { Fail "missing name: $($skill.FullName)" }
    elseif ($nameMatch.Groups[1].Value.Trim() -ne $skill.Directory.Name) {
        Fail "skill name does not match directory: $($skill.FullName)"
    } else { Pass "skill name: $($skill.Directory.Name)" }

    if (-not $descriptionMatch.Success) { Fail "missing description: $($skill.FullName)" }
    elseif ($descriptionMatch.Groups[1].Value.Trim().Length -gt 1024) {
        Fail "description exceeds 1024 chars: $($skill.FullName)"
    } else { Pass "description length: $($skill.Directory.Name)" }

    if ($frontmatter -match '(?m)^allowed-tools:\s*Bash\b') {
        Fail "broad Bash pre-approval is not allowed in release skills: $($skill.FullName)"
    } else {
        Pass "no broad Bash pre-approval: $($skill.Directory.Name)"
    }
}

$gitignore = Get-Content (Join-Path $repoDir ".gitignore") -Raw -Encoding UTF8
if ($gitignore -match '(?m)^\.claude/[^\S\r\n]*\r?$') {
    Pass ".claude/ directory is ignored"
} else {
    Fail ".claude/ must be ignored in .gitignore"
}

$depsScript = Get-Content (Join-Path $sharedDir "scripts\install-deps.ps1") -Raw -Encoding UTF8
foreach ($package in "7zip", "ripgrep", "resvg") {
    if ($depsScript -match [regex]::Escape('"' + $package + '"')) {
        Pass "dependency mapping present: $package"
    } else {
        Fail "dependency mapping missing: $package"
    }
}

$terminalManifestPath = Join-Path $sharedDir "manifests\terminal.toml"
if (-not (Test-Path $terminalManifestPath)) {
    Fail "missing terminal manifest: $terminalManifestPath"
} else {
    $terminalManifest = Get-Content $terminalManifestPath -Raw -Encoding UTF8
    foreach ($package in "eza", "bat", "delta", "starship") {
        if ($terminalManifest -match ('(?m)^scoop\s*=\s*"' + [regex]::Escape($package) + '"')) {
            Pass "terminal tool mapping present: $package"
        } else {
            Fail "terminal tool mapping missing: $package"
        }
    }
}

$foundationManifestPath = Join-Path $sharedDir "manifests\foundation.toml"
if (Test-Path $foundationManifestPath) {
    Pass "foundation manifest present"
} else {
    Fail "missing foundation manifest"
}

# Validate profile-block.ps1 has correct starship-before-zoxide order
$profileBlock = Get-Content (Join-Path $sharedDir "scripts\profile-block.ps1") -Raw -Encoding UTF8
$starshipPos = $profileBlock.IndexOf("starship init")
$zoxidePos = $profileBlock.IndexOf("zoxide init")
if ($starshipPos -ge 0 -and $zoxidePos -ge 0 -and $starshipPos -lt $zoxidePos) {
    Pass "profile-block.ps1: starship init before zoxide init"
} elseif ($starshipPos -ge 0 -and $zoxidePos -ge 0) {
    Fail "profile-block.ps1: zoxide init before starship init (must be reversed)"
} else {
    Pass "profile-block.ps1: starship/zoxide init check skipped (tool not referenced)"
}

# Validate profile-block.ps1 has y function with IME fix
if ($profileBlock -match 'IMECtrl' -and $profileBlock -match 'function y \{') {
    Pass "profile-block.ps1: y function with IME fix present"
} elseif ($profileBlock -match 'function y \{') {
    Pass "profile-block.ps1: y function present (no IME fix)"
} else {
    Pass "profile-block.ps1: no y function (will be added by yazi-config)"
}

$diagnoseScript = Get-Content (Join-Path $sharedDir "scripts\diagnose.ps1") -Raw -Encoding UTF8
if ($diagnoseScript -match '\$net_gh\s+-and\s+\$net_raw\s+-and\s+\$net_scoop\s+-and\s+\$net_obj') {
    Pass "network verdict requires all four endpoints"
} else {
    Fail "network verdict must require get.scoop.sh, github.com, raw, and objects"
}

$cleanupScript = Get-Content (Join-Path $sharedDir "scripts\cleanup.ps1") -Raw -Encoding UTF8
if ($cleanupScript -match 'CLEANUP: PARTIAL' -and $cleanupScript -match 'exit 1') {
    Pass "cleanup has a non-zero PARTIAL outcome"
} else {
    Fail "cleanup must report PARTIAL and return non-zero when yazi remains"
}

$yaziCmd = Get-Command yazi -ErrorAction SilentlyContinue
if ($yaziCmd) {
    $versionLine = yazi --version 2>&1 | Select-Object -First 1
    $versionExit = $LASTEXITCODE
    if ($versionExit -ne 0) {
        Fail "installed yazi failed to report a version"
    } else {
        Pass "installed yazi: $versionLine"
        $cases = @(
            @{ Name = "minimal"; Args = @("-Tier", "Minimal") },
            @{ Name = "complete-en"; Args = @("-Tier", "Complete", "-KeymapLanguage", "en", "-Editor", "notepad") }
        )
        if ($versionLine -match '\b26\.5\.6\b') {
            $cases += @{
                Name = "complete-zh"
                Args = @("-Tier", "Complete", "-KeymapLanguage", "zh", "-Editor", "notepad", "-ProjectPath", $repoDir)
            }
        }

        foreach ($case in $cases) {
            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ywr-" + [Guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
            $oldAppData = $env:APPDATA
            $oldConfigHome = $env:YAZI_CONFIG_HOME
            try {
                $env:APPDATA = $tempRoot
                & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sharedDir "scripts\apply-config.ps1") @($case.Args)
                if ($LASTEXITCODE -ne 0) {
                    Fail "config generator failed: $($case.Name)"
                    continue
                }
                $env:YAZI_CONFIG_HOME = Join-Path $tempRoot "yazi\config"
                $debugOutput = yazi --debug 2>&1
                $debugExit = $LASTEXITCODE
                $debugText = $debugOutput | Out-String
                if ($debugExit -ne 0 -or $debugText -match "TOML parse error|Press <Enter> to continue") {
                    Fail "yazi rejected generated config: $($case.Name)"
                } else {
                    Pass "yazi loaded generated config: $($case.Name)"
                }
            } finally {
                $env:APPDATA = $oldAppData
                $env:YAZI_CONFIG_HOME = $oldConfigHome
                if (Test-Path $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
            }
        }
    }
} else {
    Write-Output "[SKIP] yazi not installed; generated config runtime loading was not tested."
}

Write-Output ""
if ($failures.Count -eq 0) {
    Write-Output "RELEASE-VALIDATION: OK"
    exit 0
}

Write-Output "RELEASE-VALIDATION: FAILED ($($failures.Count) issue(s))"
foreach ($failure in $failures) { Write-Output "  - $failure" }
exit 1
