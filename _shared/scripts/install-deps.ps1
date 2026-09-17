<#
.SYNOPSIS
  Yazi Windows Rescue — dependency + Nerd Font check + install.
  Detects which yazi dependencies are present and installs ONLY the missing ones via scoop,
  then installs a Nerd Font so yazi's icons render (instead of tofu boxes).

.DESCRIPTION
  Run from PowerShell 7+ (pwsh) AFTER scoop is confirmed installed.
  - Prints each dependency as OK or MISSING (with what it's for).
  - Installs only the missing scoop packages (scoop skips anything already installed anyway).
  - Adds the 'nerd-fonts' bucket and installs a Nerd Font (Maple-Mono-NF-CN) if absent.
  - Auto-sets YAZI_FILE_ONE if not already configured.
  - Idempotent: safe to run more than once.

  Dependencies and the scoop package that provides each:
    yazi        -> yazi         (the file manager)
    fd          -> fd           (file search inside yazi)
    magick      -> imagemagick  (image previews)
    ffmpeg      -> ffmpeg       (video thumbnail previews)
    7z          -> 7zip         (archive preview and extraction)
    pdftoppm    -> poppler      (PDF previews)
    jq          -> jq           (JSON pretty previews)
    rg          -> ripgrep      (file content search)
    resvg       -> resvg        (SVG previews)
    git         -> git          (provides file.exe used for MIME detection)
  Plus a Nerd Font:
    Maple-Mono-NF-CN -> nerd-fonts/Maple-Mono-NF-CN   (icons + CJK; what yazi draws in the file list)

.NOTES
  Designed for PowerShell 7+. If run on Windows PowerShell 5.1, it will explain
  how to get pwsh and exit gently (rather than throwing a #requires error).

  Font note: on Windows 10 (1809+) and Windows 11, fonts install for the current
  user WITHOUT admin rights. On older Windows, font install needs an elevated shell.
  Installing the font is necessary but NOT sufficient — the terminal must also be
  set to use that font (handled in the yazi-install skill, Phase 6f).
#>

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    chcp 65001 > $null
} catch { }

$setupOk = $true

# --- Soft PowerShell 7+ check: guide, don't just fail ---
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Output "===== This step needs PowerShell 7 (pwsh) ====="
    Write-Output "You're currently running Windows PowerShell $($PSVersionTable.PSVersion) (the old, built-in one)."
    Write-Output ""
    Write-Output "Why it matters: this skill uses PowerShell 7 (pwsh) on purpose. PowerShell 7 handles"
    Write-Output "UTF-8 and Chinese text far better and avoids many legacy quirks that cause exactly the"
    Write-Output "kind of breakage we're fixing. The install step is written for it."
    Write-Output ""
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-Output "Good news: PowerShell 7 is already installed at: $($pwshCmd.Source)"
        Write-Output "What to do: close this window, open PowerShell 7 (run 'pwsh', or find it in the Start Menu),"
        Write-Output "and run this script again from there."
    } else {
        Write-Output "PowerShell 7 doesn't appear to be installed yet. Install it (any one of these):"
        Write-Output "  - scoop install pwsh        (matches this skill's scoop-based approach; recommended)"
        Write-Output "  - winget install --id Microsoft.PowerShell"
        Write-Output "  - MSI: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows"
        Write-Output ""
        Write-Output "After installing, close this window, start PowerShell 7 by running 'pwsh', then run this script again."
    }
    Write-Output ""
    Write-Output "(Nothing was installed or changed. This was only a version check.)"
    Write-Output "INSTALL-DEPS: PARTIAL"
    exit 1
}

try {

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Output "ERROR: scoop is not installed yet. Install scoop first (run the scoop install step in the yazi-install skill first), then re-run this."
    Write-Output "  Quick install: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
    Write-Output "  Scoop docs: https://scoop.sh/"
    Write-Output "INSTALL-DEPS: PARTIAL"
    exit 1
}

# command-name -> @(scoop-package, human description)
$deps = [ordered]@{
    "yazi"     = @("yazi",        "the file manager itself")
    "fd"       = @("fd",          "file search inside yazi")
    "magick"   = @("imagemagick", "image previews")
    "ffmpeg"   = @("ffmpeg",      "video thumbnail previews")
    "7z"       = @("7zip",        "archive preview and extraction")
    "pdftoppm" = @("poppler",     "PDF previews")
    "jq"       = @("jq",          "JSON pretty previews")
    "rg"       = @("ripgrep",     "file content search")
    "resvg"    = @("resvg",       "SVG previews")
    "git"      = @("git",         "provides file.exe for MIME detection")
}

# Smart git detection: if user cloned this repo, they almost certainly have git.
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    Write-Output "NOTE: git is already available ($($gitCmd.Source)). Since you cloned this repo, this is expected."
}

Write-Output ""
Write-Output "===== Dependency status ====="
$missingPkgs = @()
foreach ($cmd in $deps.Keys) {
    $pkg  = $deps[$cmd][0]
    $desc = $deps[$cmd][1]
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Output ("OK       {0,-10} -> {1}" -f $cmd, $found.Source)
    } else {
        Write-Output ("MISSING  {0,-10} ({1}) -> will install scoop package '{2}'" -f $cmd, $desc, $pkg)
        if ($missingPkgs -notcontains $pkg) { $missingPkgs += $pkg }
    }
}

Write-Output ""
if ($missingPkgs.Count -eq 0) {
    Write-Output "All command-line dependencies already present. Nothing to install."
} else {
    # Verify scoop 'main' bucket exists (needed for most packages)
    $buckets = scoop bucket list 2>$null
    if ($buckets -notmatch 'main') {
        Write-Output "Scoop 'main' bucket is missing. Adding it..."
        scoop bucket add main
        if ($LASTEXITCODE -ne 0) {
            Write-Output ""
            Write-Output "ERROR: Failed to add the 'main' scoop bucket."
            Write-Output "Why it matters: Without the main bucket, scoop cannot find most packages (yazi, fd, jq, etc.)."
            Write-Output "What to do: Run 'scoop bucket add main' manually. If it fails, check your network/proxy settings."
            Write-Output "  -> Scoop proxy docs: https://github.com/ScoopInstaller/Scoop/wiki/Using-Scoop-behind-a-proxy"
            Write-Output "INSTALL-DEPS: PARTIAL"
            exit 1
        }
    }

    Write-Output "Installing missing packages: $($missingPkgs -join ' ')"
    Write-Output "Running: scoop install $($missingPkgs -join ' ')"
    Write-Output ""
    scoop install @missingPkgs
    $installExitCode = $LASTEXITCODE
    Write-Output ""

    if ($installExitCode -ne 0) {
        $setupOk = $false
        Write-Output "WARNING: scoop install finished with exit code $installExitCode. Some packages may have failed."
        Write-Output "What to do: Re-run this script to check which packages are still missing."
        Write-Output "  If a specific package keeps failing, try installing it manually:"
        foreach ($pkg in $missingPkgs) {
            Write-Output "    scoop install $pkg"
        }
        Write-Output "  -> Scoop troubleshooting: https://github.com/ScoopInstaller/Scoop/wiki/Troubleshooting"
    } else {
        Write-Output "All packages installed successfully."
    }
    Write-Output "Re-run this script to confirm everything now shows OK."
}

# ===== Nerd Font (yazi's icons) =====
# Without a Nerd Font, yazi's file-type icons render as tofu boxes (square boxes) —
# the UI looks broken even though yazi works. Install one here. NOTE: this is only
# half the job; the terminal must also be set to use this font (the yazi-install skill, Phase 6f).
Write-Output ""
Write-Output "===== Nerd Font (so yazi shows icons, not tofu boxes) ====="
$fontPkg  = "Maple-Mono-NF-CN"
$fontFace = "Maple Mono NF CN"   # <- the font-face name to select in the terminal
# Maple Mono NF CN bundles Nerd Font icons AND full CJK (中文) with perfect 2:1
# alignment, so icons and Chinese filenames render in ONE face — ideal here.

$fontAlreadyInstalled = $false
try {
    $fontList = scoop list $fontPkg 2>$null | Select-String -Pattern $fontPkg
    if ($fontList) { $fontAlreadyInstalled = $true }
} catch { }

if ($fontAlreadyInstalled) {
    Write-Output "Nerd Font already installed via scoop: $fontPkg ($fontFace)."
} else {
    $bucketsNow = scoop bucket list 2>$null
    if ($bucketsNow -notmatch 'nerd-fonts') {
        Write-Output "Adding the 'nerd-fonts' scoop bucket..."
        scoop bucket add nerd-fonts
        if ($LASTEXITCODE -ne 0) {
            $setupOk = $false
            Write-Output "WARNING: could not add the 'nerd-fonts' bucket (network/proxy?). Skipping font install."
            Write-Output "  yazi will still work; its icons will look wrong until a Nerd Font is installed + selected."
        }
    }

    $bucketsNow = scoop bucket list 2>$null
    if ($bucketsNow -match 'nerd-fonts') {
        Write-Output "Installing $fontPkg (this provides the icons yazi draws)..."
        scoop install "nerd-fonts/$fontPkg"
        $fontExit = $LASTEXITCODE
        if ($fontExit -ne 0) {
            $setupOk = $false
            Write-Output ""
            Write-Output "WARNING: the font install did not complete cleanly (exit code $fontExit)."
            Write-Output "  - On Windows 10 (1809+) and Windows 11, fonts install for your user WITHOUT admin rights."
            Write-Output "  - On older Windows, open an Administrator PowerShell and run: scoop install nerd-fonts/$fontPkg"
            Write-Output "  yazi itself still works; only its icons will look wrong until the font is installed and selected."
        } else {
            Write-Output "Font installed: $fontFace"
        }
    }
}
Write-Output ""
Write-Output "IMPORTANT (manual, one-time): installing the font is NOT enough — set your terminal to USE it."
Write-Output "  Windows Terminal: Settings (Ctrl+,) -> Defaults -> Appearance -> Font (check 'Show all fonts') -> choose '$fontFace'."
Write-Output "  Other terminals (Alacritty / WezTerm / Ghostty / etc.): set their font to '$fontFace'."
Write-Output "  Until you do this, yazi will keep showing tofu boxes instead of icons."

# Auto-set YAZI_FILE_ONE if not already configured
Write-Output ""
Write-Output "===== YAZI_FILE_ONE setup ====="
$existingYfo = [Environment]::GetEnvironmentVariable("YAZI_FILE_ONE", "User")
if ($existingYfo -and (Test-Path $existingYfo)) {
    Write-Output "YAZI_FILE_ONE already set and valid: $existingYfo"
} else {
    $fileExe = $null

    # Method 1: scoop's git
    $scoopGitFile = "$env:USERPROFILE\scoop\apps\git\current\usr\bin\file.exe"
    if (Test-Path $scoopGitFile) {
        $fileExe = $scoopGitFile
        Write-Output "Found file.exe via scoop git: $fileExe"
    }

    # Method 2: git on PATH -> derive file.exe location
    if (-not $fileExe) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $gitDir = Split-Path (Split-Path $gitCmd.Source)
            $candidate = Join-Path $gitDir "usr\bin\file.exe"
            if (Test-Path $candidate) {
                $fileExe = $candidate
                Write-Output "Found file.exe via git on PATH: $fileExe"
            }
        }
    }

    # Method 3: common Git for Windows install paths
    if (-not $fileExe) {
        $candidates = @(
            "$env:ProgramFiles\Git\usr\bin\file.exe",
            "${env:ProgramFiles(x86)}\Git\usr\bin\file.exe"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $fileExe = $c
                Write-Output "Found file.exe at standard install path: $fileExe"
                break
            }
        }
    }

    if ($fileExe) {
        [Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $fileExe, "User")
        Write-Output ""
        Write-Output "SUCCESS: YAZI_FILE_ONE set to: $fileExe"
        Write-Output "IMPORTANT: Close ALL PowerShell windows and open a new one for this to take effect."
    } else {
        $setupOk = $false
        Write-Output ""
        Write-Output "Could not auto-detect git's file.exe."
        Write-Output "Why it matters: Without file.exe, yazi cannot detect file types for previews."
        Write-Output ""
        Write-Output "To set it manually, run this command in a new PowerShell window:"
        Write-Output '  [Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", "$env:USERPROFILE\scoop\apps\git\current\usr\bin\file.exe", "User")'
        Write-Output ""
        Write-Output "Or run the standalone helper script:"
        Write-Output "  pwsh -File set-yazi-file-one.ps1"
        Write-Output ""
        Write-Output "After setting, close ALL PowerShell windows and open a new one."
    }
}

$stillMissing = @()
foreach ($cmd in $deps.Keys) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $stillMissing += $cmd
    }
}
if ($stillMissing.Count -gt 0) {
    $setupOk = $false
    Write-Output ""
    Write-Output "Still missing after install attempt: $($stillMissing -join ', ')"
}

$finalYfo = [Environment]::GetEnvironmentVariable("YAZI_FILE_ONE", "User")
if (-not $finalYfo -or -not (Test-Path $finalYfo)) {
    $setupOk = $false
}

Write-Output ""
if ($setupOk) {
    Write-Output "INSTALL-DEPS: OK"
    exit 0
} else {
    Write-Output "INSTALL-DEPS: PARTIAL"
    exit 1
}

} catch {
    Write-Output ""
    Write-Output "ERROR: install-deps.ps1 failed unexpectedly."
    Write-Output "What happened: $($_.Exception.Message)"
    Write-Output "Why it matters: Dependencies may be partially installed. Your yazi setup may be incomplete."
    Write-Output "What to do: Re-run this script. If it keeps failing, report this error at:"
    Write-Output "  https://github.com/karenepitaya/windows-env-rescue/issues"
    Write-Output "INSTALL-DEPS: PARTIAL"
    exit 1
}
