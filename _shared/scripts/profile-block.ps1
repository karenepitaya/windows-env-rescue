# >>> windows-env-rescue >>>
# Managed by the windows-env-rescue suite (env-terminal). To uninstall, delete this
# whole block (from the >>> line to the <<< line). Every feature is guarded by a
# tool-presence check, so this block stays safe even if a tool is missing or later
# removed.

# --- yazi : `y` quit-to-cd with IME fix ------------------------------------
# Disables Chinese IME before launching yazi (prevents j/k key interception),
# restores IME state on exit. Uses --cwd-file to follow the user's final directory.
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    # Guard on the type itself: Add-Type throws a non-terminating error on
    # duplicate type names that try/catch cannot suppress, and it treats
    # byte-different sources (e.g. LF vs CRLF) as different code.
    if (-not ('IMECtrl' -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class IMECtrl {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("imm32.dll")]
    public static extern IntPtr ImmGetContext(IntPtr hWnd);
    [DllImport("imm32.dll")]
    public static extern bool ImmGetOpenStatus(IntPtr hIMC);
    [DllImport("imm32.dll")]
    public static extern bool ImmSetOpenStatus(IntPtr hIMC, bool fOpen);
    [DllImport("imm32.dll")]
    public static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hIMC);
}
"@
    }

    function y {
        $hwnd = [IMECtrl]::GetForegroundWindow()
        $hIMC = [IMECtrl]::ImmGetContext($hwnd)
        $imeWasOpen = [IMECtrl]::ImmGetOpenStatus($hIMC)
        if ($imeWasOpen) { [IMECtrl]::ImmSetOpenStatus($hIMC, $false) | Out-Null }
        [IMECtrl]::ImmReleaseContext($hwnd, $hIMC) | Out-Null
        try {
            $tmp = [System.IO.Path]::GetTempFileName()
            yazi $args --cwd-file="$tmp"
            $cwd = Get-Content -Path $tmp -Encoding UTF8
            if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
                Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
            }
            Remove-Item -Path $tmp
        } finally {
            if ($imeWasOpen) {
                $hwnd = [IMECtrl]::GetForegroundWindow()
                $hIMC = [IMECtrl]::ImmGetContext($hwnd)
                [IMECtrl]::ImmSetOpenStatus($hIMC, $true) | Out-Null
                [IMECtrl]::ImmReleaseContext($hwnd, $hIMC) | Out-Null
            }
        }
    }
}

# --- eza / lsd : modern `ls` ----------------------------------------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first @args }
    function ll { eza -l  --icons --group-directories-first --git @args }
    function la { eza -la --icons --group-directories-first --git @args }
    function lt { eza --tree --level=2 --icons @args }
}
elseif (Get-Command lsd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { lsd --group-directories-first @args }
    function ll { lsd -l  --group-directories-first @args }
    function la { lsd -la --group-directories-first @args }
    function lt { lsd --tree --depth 2 @args }
}

# --- bat : better `cat` (paging off so it behaves like cat) ----------------
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat --paging=never @args }
}

# --- starship : prompt. Only activates if you actually installed it ---------
# MUST init BEFORE zoxide — starship replaces prompt entirely;
# zoxide wraps the existing prompt to inject its hook, so it needs to run second.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# --- zoxide : smarter cd. `cd` overridden; also `z` / `zi` available ---------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
    # --cmd cd only creates cd/cdi; add z/zi as convenience aliases
    Set-Alias -Name z  -Value __zoxide_z  -Option AllScope -Scope Global -Force
    Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
    # Record the startup directory (hook only fires on subsequent cd's)
    $startupDir = if ($PWD.Provider.Name -eq 'FileSystem') { $PWD.ProviderPath } else { $null }
    if ($startupDir) { zoxide add -- $startupDir }
}

# --- PSReadLine : history-aware completion + arrow key bindings -------------
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    try { Set-PSReadLineOption -PredictionSource History }      catch {}
    try { Set-PSReadLineOption -PredictionViewStyle ListView }  catch {}
}

# --- fzf : Catppuccin Mocha colours + Ctrl+R / Ctrl+T key bindings ----------
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = @'
--height 40% --layout reverse --border --info inline
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
--color=selected-bg:#45475a
'@
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
    }

    # Ctrl+R : fuzzy-search command history, drop the choice onto the line
    Set-PSReadLineKeyHandler -Key 'Ctrl+r' -BriefDescription 'fzf-history' -ScriptBlock {
        $line = ''; $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $picked = Get-Content (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue |
            Where-Object { $_ -and ($_ -notmatch '^\s*$') } |
            Select-Object -Unique |
            fzf --tac --no-sort --query "$line"
        if ($picked) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($picked)
        }
    }

    # Ctrl+T : fuzzy-pick file(s), insert their paths at the cursor
    Set-PSReadLineKeyHandler -Key 'Ctrl+t' -BriefDescription 'fzf-file' -ScriptBlock {
        $items = if (Get-Command fd -ErrorAction SilentlyContinue) {
            fd --type f --hidden --exclude .git
        } else {
            Get-ChildItem -Recurse -File -Name -ErrorAction SilentlyContinue
        }
        $picked = $items | fzf --multi
        if ($picked) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert((@($picked) -join ' '))
        }
    }
}
# <<< windows-env-rescue <<<
