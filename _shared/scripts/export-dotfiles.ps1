<#
.SYNOPSIS
  windows-env-rescue — L5 export local dotfiles package.

.DESCRIPTION
  Copies curated config paths into a portable folder + manifest + scoop export.
  Does not upload anywhere. Status: EXPORT-DOTFILES: OK|PARTIAL|FAIL
#>
[CmdletBinding()]
param(
    [string]$OutDir
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

function Get-WerSha256([string]$Path) {
    try { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash } catch { $null }
}

Set-WerUtf8
Write-Output "===== windows-env-rescue export-dotfiles ====="

if (-not $OutDir) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $env:USERPROFILE "windows-env-rescue-dotfiles\$stamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Output "OutDir: $OutDir"

$wt = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue |
    Select-Object -First 1
$wtSettings = if ($wt) { Join-Path $wt.FullName 'LocalState\settings.json' } else { $null }

$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    $alt = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    if (Test-Path $alt) { $profilePath = $alt }
}

$items = @(
    @{ Id = 'profile'; Kind = 'file'; Source = $profilePath },
    @{ Id = 'gitconfig'; Kind = 'file'; Source = (Join-Path $env:USERPROFILE '.gitconfig') },
    @{ Id = 'wt'; Kind = 'file'; Source = $wtSettings },
    @{ Id = 'vscode-settings'; Kind = 'file'; Source = (Join-Path $env:APPDATA 'Code\User\settings.json') },
    @{ Id = 'vscode-keybindings'; Kind = 'file'; Source = (Join-Path $env:APPDATA 'Code\User\keybindings.json') },
    @{ Id = 'yazi'; Kind = 'dir'; Source = (Join-Path $env:APPDATA 'yazi\config') }
)

$manifest = [System.Collections.Generic.List[hashtable]]::new()
$hit = 0
$miss = @()

foreach ($item in $items) {
    $src = $item.Source
    $id = $item.Id
    if (-not $src -or -not (Test-Path -LiteralPath $src)) {
        Write-Output "miss  $id"
        $miss += $id
        continue
    }
    $dest = Join-Path $OutDir $id
    if ($item.Kind -eq 'dir') {
        Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
        Write-Output "copy  $id (dir) -> $dest"
    } else {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        $leaf = Split-Path $src -Leaf
        $target = Join-Path $dest $leaf
        Copy-Item -LiteralPath $src -Destination $target -Force
        Write-Output "copy  $id -> $target"
        $manifest.Add(@{
            id = $id
            kind = 'file'
            source = $src
            exported = $target
            sha256 = (Get-WerSha256 $target)
        })
        $hit++
        continue
    }
    $manifest.Add(@{
        id = $id
        kind = 'dir'
        source = $src
        exported = $dest
        sha256 = $null
    })
    $hit++
}

# scoop export
$scoopJson = Join-Path $OutDir 'scoop-export.json'
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    try {
        scoop export | Set-Content -LiteralPath $scoopJson -Encoding UTF8
        Write-Output "copy  scoop-export -> $scoopJson"
        $manifest.Add(@{ id = 'scoop-export'; kind = 'file'; source = 'scoop export'; exported = $scoopJson; sha256 = (Get-WerSha256 $scoopJson) })
        $hit++
    } catch {
        Write-Output "warn  scoop export failed: $($_.Exception.Message)"
        if ($status -eq 'OK') { $status = 'PARTIAL' }
    }
} else {
    Write-Output "miss  scoop (no export)"
    $miss += 'scoop-export'
}

# inventory (observe-only paths)
$observe = @(
    (Join-Path $env:USERPROFILE '.claude'),
    (Join-Path $env:USERPROFILE '.pi'),
    (Join-Path $env:USERPROFILE '.claude.json'),
    (Join-Path $env:LOCALAPPDATA 'nvim'),
    (Join-Path $env:USERPROFILE '.config')
)
$inv = [System.Text.StringBuilder]::new()
[void]$inv.AppendLine("# windows-env-rescue dotfiles inventory")
[void]$inv.AppendLine("exported_at: $(Get-Date -Format o)")
[void]$inv.AppendLine("")
[void]$inv.AppendLine("## Exported")
foreach ($m in $manifest) { [void]$inv.AppendLine("- $($m.id) <- $($m.source)") }
[void]$inv.AppendLine("")
[void]$inv.AppendLine("## Missing (not exported)")
foreach ($m in $miss) { [void]$inv.AppendLine("- $m") }
[void]$inv.AppendLine("")
[void]$inv.AppendLine("## Observe-only (not copied by default)")
foreach ($o in $observe) {
    if (Test-Path -LiteralPath $o) { [void]$inv.AppendLine("- HIT $o") } else { [void]$inv.AppendLine("- miss $o") }
}
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    [void]$inv.AppendLine("")
    [void]$inv.AppendLine("## Scoop apps (from export)")
    try {
        $json = Get-Content $scoopJson -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($a in $json.apps) { [void]$inv.AppendLine("- $($a.Name) $($a.Version)") }
    } catch {}
}
$invPath = Join-Path $OutDir 'inventory.md'
Set-Content -LiteralPath $invPath -Value $inv.ToString() -Encoding UTF8
Write-Output "write inventory -> $invPath"

$manPath = Join-Path $OutDir 'manifest.json'
($manifest | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $manPath -Encoding UTF8
Write-Output "write manifest -> $manPath"

Write-Output ""
Write-Output "Note: secrets/tokens are not curated into this package. Review before sharing."
if ($hit -eq 0) {
    Write-Output "EXPORT-DOTFILES: FAIL: nothing exported"
    exit 1
}
if ($status -eq 'OK') {
    Write-Output "EXPORT-DOTFILES: OK  ($hit items)"
    exit 0
}
Write-Output "EXPORT-DOTFILES: PARTIAL  ($hit items)"
exit 2
