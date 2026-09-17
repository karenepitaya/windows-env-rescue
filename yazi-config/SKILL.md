---
name: yazi-config
description: Configure, theme, and enhance an ALREADY-WORKING yazi install on Windows - turning "it runs" into "it's a polished daily driver". Use when the user asks to 配置/美化/主题/预览增强 yazi, wants the Catppuccin theme, Markdown preview with glow, fzf/zoxide jumping, handy keybindings, the `y` quit-to-cd shortcut, or says "yazi 能用了但太丑/太原始", "give me the full yazi setup", or wants to switch between a minimal and a complete configuration. PRECONDITION: yazi must be installed and runnable - this skill verifies that first and refuses (pointing to /yazi-install) if not. Re-runnable any time to switch tiers, re-personalize, or add previously skipped optional items (glow Markdown preview, fzf+zoxide jump enhancement). Theme and plugins install from a version-pinned package.toml manifest (ya pkg install) - the exact author-verified revisions, reproducible on every machine. Everything installs defensively: anything that fails to download is skipped and reported, never half-written into config.
license: MIT
compatibility: Windows 10/11. Requires a working yazi install (verified up front) and network access to GitHub for plugins/tools. Scripts run on any PowerShell.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
---

# Yazi Config（配置 / 美化 / 增强）

Take a **verified-working** yazi and make it the setup its author actually uses daily: Catppuccin theme, Markdown rendered by glow in the preview pane, a couple of high-value keybindings, your editor wired in, and the `y` quit-to-cd shortcut. Two tiers, re-runnable, always reversible (config is backed up every run).

## Language

**Conduct the entire interaction in Simplified Chinese (简体中文) by default.** All `AskUserQuestion` options in Chinese with a **（推荐）** default. Commands/paths/code verbatim.

## Core rules

1. **Installation first, configuration second — no exceptions.** Phase C0's verdict gates everything. If yazi isn't installed and healthy, refuse politely and point to `/yazi-install`. Configuring on a broken base is how installs got broken in the first place.
2. **Defensive enhancement: never half-write.** Every plugin/flavor/tool is a GitHub download that can fail. The rule is *install first, reference after*: `theme.toml` is written ONLY after the flavor package installs; the markdown previewer block is appended ONLY after BOTH the piper plugin AND glow are confirmed. A config referencing something absent = startup errors = worse than no config.
3. **Backup before every write.** Timestamped copy of the whole config dir at the start of every run. Switching tiers or re-running must never lose anything.
4. **Stay small even in the complete tier.** The vendored templates are deliberately tiny; yazi's defaults do the heavy lifting. Never add `fetchers`/`preloaders`/extra `[plugin]` blocks beyond what this skill specifies. Never put anything but `[flavor]` in `theme.toml`.
5. **PowerShell, not bash** (`../_shared/references/powershell-vs-bash.md`). Garbled script text = encoding, not failure.
6. **Decisions via `AskUserQuestion`**, recommended default marked, one tap to succeed.
7. **Teach while doing.** One plain-Chinese sentence per component: 这是什么、为什么加、想改去哪改。The goal is a transparent finished product, not a black box.

---

# Procedure

`${CLAUDE_SKILL_DIR}` is this skill's folder. Shared engine: `${CLAUDE_SKILL_DIR}\..\_shared\`.

## Phase C0 — Verify the base（the gate）

"先确认 yazi 本身是健康的，配置才有意义。这一步只读不改。"

```powershell
powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\verify-yazi.ps1"
```

**Execution mode:** run it yourself if you have shell access (Claude Code); "user runs and pastes back" is only the fallback. Then read the output:
- **`VERDICT: NOT-READY`** → refuse to configure. 平实解释列出的原因，然后："先运行 **`/yazi-install`** 把安装修好，再回来跑 `/yazi-config`，一两分钟的事。" **End here.**
- **`VERDICT: READY` + `NETWORK: PROBLEM`** → 说明：最小档不需要网络，可以做；完整档要从 GitHub 拉主题/插件/工具，需要先修网络（代理指引：`scoop config proxy 127.0.0.1:7890`，换自己的端口）。`AskUserQuestion`: **「先修网络再上完整档（推荐）」**／「先用最小档」／「再测一次」.
- **`VERDICT: READY` + `NETWORK: OK`** → continue.

### >>> GATE. READY or nothing gets configured. <<<

## Phase C1 — Choose a tier

两句话介绍："**最小档**＝干净基线，yazi 默认行为＋几行合理设置，永远是安全退路。**完整档**＝作者日常在用的那套：Catppuccin 主题、预览窗里渲染 Markdown、好用的快捷键、接上你的编辑器。" `AskUserQuestion`:
- **「完整推荐档——一步到位的成品（推荐）」**
- 「最小干净档——只要基线」
- 「先讲讲两档的区别」

Re-runs: 先说明当前在哪一档（看 theme.toml/keymap.toml 是否存在即可判断），再问要切换还是重新个性化。

## Phase C2 — Backup（every run, both tiers）

```powershell
$cfg = "$env:APPDATA\yazi\config"
if (Test-Path $cfg) {
    $bak = "$env:APPDATA\yazi\config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $cfg $bak -Recurse -Force; "已备份到: $bak"
} else { New-Item -ItemType Directory -Force -Path $cfg | Out-Null; "新建了配置目录。" }
```

## Phase C3 — Minimal tier（if chosen; then skip to C8）

```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\apply-config.ps1" -Tier Minimal
```
说明：增强件都收回了，备份俱在，随时可再跑本命令切回完整档。Go to C8.

## Phase C4 — Complete tier: choose keymap language

First read `yazi --version`. **快捷键帮助菜单语言。** "yazi 的帮助菜单（按 `~` 或 `F1`）默认显示英文描述。套件提供 Yazi 26.5.6 官方默认键位的中文翻译；升级 Yazi 后，若版本不一致就改用英文小模板，避免旧键位覆盖新行为。"

If the version is exactly 26.5.6, use `AskUserQuestion`:
- **「中文帮助菜单（推荐，Yazi 26.5.6）」** → remember `KeymapLanguage = "zh"`.
- 「保持英文」 → remember `KeymapLanguage = "en"`.

For any other version, explain the compatibility guard and force `KeymapLanguage = "en"`; do not offer the Chinese snapshot.

讲解 keymap（无论选哪个）：自定义绑定：`g h` 回家目录；**`!` 在当前目录打开 PowerShell**。个人项目目录若启用，使用 `g p`，不覆盖 Yazi 默认的 `g d`（Downloads）。

## Phase C5 — Complete tier: Markdown 预览（可选项, glow）

"可选增强：预览窗里直接把 Markdown 渲染成排版好的样子（用 glow），逛笔记和 README 的体验完全不同。" `AskUserQuestion`:
- **「要——预览窗渲染 Markdown（推荐）」**
- 「不用，跳过这项」

If yes:
```powershell
powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\install-preview-tools.ps1"
```
Output ends `PREVIEW-TOOLS: OK` or `PARTIAL`. PARTIAL（几乎都是网络）→ 修代理重跑，或明确告知"这项先跳过，其余继续"。Script also sets `CLICOLOR_FORCE=1`（User）— glow 被管道调用时保持彩色输出的 Windows 正确做法；新窗口才生效。

**Remember the outcome** as `EnableMarkdown = true/false`. If skipped, piper still installs via the manifest below — 它不被 previewer 引用时是惰性的，无副作用，而且让用户以后重跑本 skill 补开 Markdown 预览时无需重新拉插件。

## Phase C6 — Complete tier: theme & plugin（钉死版本的清单安装）

**C6a. 按清单安装（一条命令，可复现）.** 说明："套件自带一份作者机器上验证过的组件清单（catppuccin-mocha 主题 + piper 预览插件，精确到提交号）——装到的就是验证过的那个版本组合，不是 GitHub 上碰巧的最新版。"

```powershell
$cfgDir = "$env:APPDATA\yazi\config"
$dst = Join-Path $cfgDir "package.toml"
$src = "${CLAUDE_SKILL_DIR}\..\_shared\config\package.toml"
if ((Test-Path $dst) -and ((Get-FileHash $dst).Hash -ne (Get-FileHash $src).Hash)) {
    "注意：你已有一份不同的 package.toml（C2 的备份里有原件），将被套件清单覆盖。"
}
Copy-Item $src $dst -Force
ya pkg install
```

- **成功（`$LASTEXITCODE -eq 0`）** → remember `EnableTheme = true`. Markdown 只有 C5 同时成功时才保持 `EnableMarkdown = true`.
- **失败（几乎都是网络）** → remember `EnableTheme = false` and force `EnableMarkdown = false`; 如实报告，稍后生成器不会引用缺失组件。继续 C7。

## Phase C7 — Complete tier: personalize

**C7a. Editor.** Detect first:
```powershell
Get-Command code, nvim -ErrorAction SilentlyContinue | Select-Object Name, Source
```
`AskUserQuestion`（检测到 code 时把 VS Code 设为推荐；都没检测到则记事本为推荐）:
- 「VS Code」 → remember `Editor = "code"`.
- 「Neovim」 → remember `Editor = "nvim"`.
- 「记事本就好（保底）」 → remember `Editor = "notepad"`.
Do not edit TOML here. The generator keeps Notepad as fallback for VS Code and Neovim.

**C7b. 常用项目目录跳转（optional）.** `AskUserQuestion`: **「跳过（推荐——以后随时可加）」**／「我有，帮我加上 `g p` 跳转」. If yes, ask for the path and remember it as `ProjectPath`; do not edit TOML here.

**C7c. `y` 退出跳转函数 + IME 修复.** "退出 yazi 时，PowerShell 跟着停在你最后浏览的目录——单项体验提升最大的一个。附带中文输入法修复：启动 yazi 前自动关输入法，防止 j/k 被吞。" `AskUserQuestion`: **「加上（推荐）」**／「先不用」. If yes, write/refresh the managed profile block — `y`（含 IME 修复）就在块里。**永远不要用 `Add-Content` 往 $PROFILE 手写函数**（无标记、无备份、编码不安全，还会和块里的 `y` 重复定义）：

```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\Update-WerProfileBlock.ps1"
```

最后一行必须是 `PROFILE-BLOCK: OK`。该写入器幂等、自动备份（保留最近 5 份）、保留原文件编码。之后用 `y` 启动（`q` 退出并跳转，`Q` 退出不跳转）；新窗口或 `. $PROFILE` 生效。

**C7d. 快速跳转增强（可选项, fzf + zoxide）.** 说明："yazi 默认键位里 `z` 用 fzf 模糊查找、`Z` 用 zoxide 跳到常去的目录——但这两个工具本体需要安装，zoxide 还要在 PowerShell 里挂上钩子才会记录你去过哪。装上后，在终端里 cd 和在 yazi 里跳转会共用同一份'常去目录'记忆。" `AskUserQuestion`:
- **「装上（推荐——用过就回不去）」**
- 「先不用」

If yes:
```powershell
scoop install fzf zoxide
```
失败（网络）→ 如实报告、跳过本项、流程继续。成功 → zoxide 的 PowerShell 钩子由套件 profile 标记块负责（块里检测到 zoxide 就自动 init 并挂上 `cd`/`z`/`zi`）——**不要手写 `zoxide init` 进 $PROFILE**（会和标记块重复初始化）。若本次流程还没写过标记块，跑一次统一写入器即可：

```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\Update-WerProfileBlock.ps1"
```
告知预期："新窗口生效。zoxide 的'常去目录'数据库是随你日常 cd 慢慢积累的——刚装好时按 `Z` 跳不出几个地方是正常的，用几天就顺了；`z`（fzf 模糊找）则立刻可用。"

**C7e. Generate the complete config once.** Build parameters only from the remembered outcomes, then run the bundled generator:
```powershell
$configParams = @{
    Tier           = "Complete"
    KeymapLanguage = "<zh-or-en>"
    Editor         = "<notepad-code-or-nvim>"
}
if (<markdown-installed-and-selected>) { $configParams.EnableMarkdown = $true }
if (<package-install-succeeded>)       { $configParams.EnableTheme = $true }
if (<project-path-was-provided>)       { $configParams.ProjectPath = "<exact-user-path>" }

pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\apply-config.ps1" @configParams
```
Do not manually append, regex-edit, or reconstruct TOML. The generator starts from vendored templates, writes UTF-8 without BOM, and is safe to re-run.

## Phase C-terminal — Terminal enhancements（optional, complete tier only）

"终端本身也可以增强——现代化的 ls/cat、fzf 模糊查找、智能 cd、好看的提示符、Windows Terminal 快捷键。这套配置和 yazi 独立，即使不用 yazi 也能受益。" `AskUserQuestion`:
- **「全部配上（推荐——体验飞升）」**
- 「只写 profile block（ls/cat/fzf/zoxide）」
- 「跳过，保持原样」

If "全部配上" or "只写 profile block":

**C-terminal-a. Profile block.** "在 PowerShell 配置文件里写入一段标记块，实现：`ls` 带图标、`cat` 语法高亮、fzf 模糊查找（Ctrl+R 历史、Ctrl+T 文件）、zoxide 智能 cd、starship 提示符、y 函数（退出 yazi 跳转目录+IME 修复）。整块可一键删除。"

唯一允许的写法是调统一写入器（幂等、自动备份轮转、保留原编码、自动迁移旧 terminal-boost 标记；**禁止在任何 SKILL/脚本里内联第三份写块逻辑**）：

```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\Update-WerProfileBlock.ps1"
```

最后一行必须是 `PROFILE-BLOCK: OK`；`FAIL` 则如实报告并停下。

If "全部配上":

**C-terminal-b. Windows Terminal keybindings（if Windows Terminal detected）.** 检测 WT settings.json 是否存在：
```powershell
$wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue | Select-Object -First 1
```
If found, "用 vim 风格的快捷键管理面板：Alt+hjkl 切换焦点、Alt+Shift+hjkl 调整大小、Ctrl+W 关闭面板。只改快捷键，不动你的配色和配置。" `AskUserQuestion`:
- **「应用（推荐）」**
- 「不改」

If yes: 备份后**按 `id` 合并**，绝不整体替换 `keybindings` 数组——用户自己的快捷键一条都不能丢。套件条目（`_shared/config/wt-keybindings.json`）覆盖同 `id` 项，其余原样保留；schemes、themes、profiles 一律不动：

```powershell
$wt = (Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Copy-Item $wt "$wt.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
try {
    $json  = Get-Content $wt -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $suite = Get-Content "${CLAUDE_SKILL_DIR}\..\_shared\config\wt-keybindings.json" -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    # settings.json 可能带注释/尾逗号。解析失败 = 保持原样、如实报告，禁止手写重建用户的 JSON。
    "settings.json 解析失败（$($_.Exception.Message)），未做任何修改。备份在 $wt.bak-*"; exit 1
}
$suiteIds = @($suite | ForEach-Object { $_.id })
$prop = if ($json.PSObject.Properties['actions']) { 'actions' } elseif ($json.PSObject.Properties['keybindings']) { 'keybindings' } else { 'actions' }
$existing = @($json.$prop | Where-Object { -not $_.id -or $suiteIds -notcontains $_.id })
$merged = @($existing) + @($suite)
if ($json.PSObject.Properties[$prop]) { $json.$prop = $merged } else { $json | Add-Member -NotePropertyName $prop -NotePropertyValue $merged }
$json | ConvertTo-Json -Depth 32 | Set-Content $wt -Encoding UTF8 -NoNewline
"已合并 $($suite.Count) 条套件快捷键（保留你的 $($existing.Count) 条自定义），备份在 $wt.bak-*"
```

**C-terminal-c. git-delta（if delta was installed）.** "git-delta 让 git diff 输出更漂亮——语法高亮、行号、侧边导航。" `AskUserQuestion`:
- **「设为 git 全局 pager（推荐）」**
- 「不改 git 配置」

If yes:
```powershell
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
```

## Phase C8 — Verify & teach

"关掉所有 PowerShell 窗口，开一个新的（环境变量和 PROFILE 都要新窗口才生效）。"

In the fresh window, have the user run `yazi`（or `y`）and confirm: 主题生效（完整档）；移动到一个 `.md` 文件，预览窗出现渲染后的 Markdown（若 C6 接入了）；图标与图片/PDF 预览正常如前。

Anything off → `../_shared/references/troubleshooting.md`（含 previewer 不生效、glow、主题没变化的对症行）。**Never claim done without this check.**

Then **always** show the cheat sheet `../_shared/references/yazi-cheatsheet.md`，并提一句：`~` 或 `F1` 在 yazi 里看完整帮助。Close warmly: 这套配置就是作者日常在用的形态——每个文件在 `%APPDATA%\yazi\config`，每一行都欢迎打开看、改成自己的口味；改坏了也没事，重跑 `/yazi-config` 即可复原。

---

# Bundled files（shared engine, `..\_shared\`）

- `scripts/verify-yazi.ps1` — the C0 gate（READY/NOT-READY + NETWORK line）.
- `scripts/install-preview-tools.ps1` — glow + CLICOLOR_FORCE（C5, optional item）.
- `scripts/apply-config.ps1` — deterministic minimal/complete config generator; editor/project/Markdown/theme are parameters, never ad-hoc TOML edits.
- `scripts/Update-WerProfileBlock.ps1` — the ONLY allowed `$PROFILE` writer (C7c/C7d/C-terminal-a): idempotent, backup-rotated, encoding-preserving.
- `scripts/validate-release.ps1` — maintainer-only, non-destructive syntax/frontmatter/config-load release check.
- `config/package.toml` — **version-pinned manifest**（piper @598cdb6, catppuccin-mocha @36c49ac — the author-verified combination; C6a installs from this via `ya pkg install`）.
- `config/yazi-minimal.toml`, `config/yazi-complete.toml`, `config/keymap-zh.toml`, `config/keymap-complete.toml`, `config/theme.toml` — vendored tier templates. (`keymap-zh.toml` = 完整中文帮助菜单 + 自定义绑定；`keymap-complete.toml` = 英文帮助 + 自定义绑定。)
- `references/troubleshooting.md`, `references/powershell-vs-bash.md`, `references/yazi-cheatsheet.md`.
