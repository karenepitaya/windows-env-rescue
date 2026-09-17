---
name: yazi-install
description: Diagnose, clean up, and correctly (re)install the yazi file manager on Windows when a previous (often AI-assisted) installation left it unusable, or when installing fresh. Use WHENEVER the user says yazi was installed but won't run / won't open / can't be found / has no file previews / shows boxes or garbled icons / throws TOML parse errors, or "Claude installed yazi and it's broken", "帮我重装 yazi", "yazi 打不开/坏了/装不上". Self-contained: runs its own read-only diagnosis first (never assumes /yazi-detect ran), enforces a network gate BEFORE any deletion, standardizes on scoop, installs preview deps and a Nerd Font, writes a minimal baseline config, and verifies. On failure it always offers a one-shot cleanup so the user can start over. Configuration/theming/plugins belong to /yazi-config, which this skill points to at the end.
license: MIT
compatibility: Windows 10/11. Diagnosis runs on any PowerShell; install scripts require PowerShell 7+ (pwsh) and guide the user to it if missing. Needs network access to GitHub (gated up front).
metadata:
  author: karenepitaya
  suite: windows-env-rescue
---

# Yazi Install（诊断 + 清理 + 重装 + 验证）

Fix or freshly install yazi on Windows. Typical user: **non-technical and frustrated** — a previous tool installed yazi some unknown way, maybe broke the config, and now it won't run, won't preview, or looks broken.

The job: **diagnose → network gate → pwsh gate → report & approve → clean removal → scoop install (deps + Nerd Font) → minimal config → verify**, pausing for confirmation between phases. **Success ends by pointing to `/yazi-config`; failure always ends with a way out (fix guidance or one-shot cleanup).**

## Language

**Conduct the entire interaction in Simplified Chinese (简体中文) by default.** Every explanation, every `AskUserQuestion` prompt and option label in Chinese (the labels below already are). Commands/paths/code verbatim. Only switch if the user clearly writes in another language and keeps doing so.

## Core rules

1. **Do not improvise.** A previous assistant broke this by being "clever". Use the commands and bundled scripts verbatim. Stop at every gate until the user replies. If reality doesn't match this skill, report and ask.
2. **PowerShell, not bash.** Never `grep`/`which`/`rm -rf`/`&&`/`mkdir -p`… If a command fails, suspect bash syntax first: `../_shared/references/powershell-vs-bash.md`.
3. **Garbled text (`锘`,`鈻`,`□`) in script output = display encoding, not failure.** The scripts re-apply UTF-8. Boxes *inside yazi's UI* = Nerd Font issue (Phase 6b/6f), a different thing.
4. **scoop is the only install method.** Never fall back to winget/cargo/manual to "get around" a problem.
5. **Network gate before any deletion (Phase 2).** Everything downloads from GitHub; discovering a blocked network AFTER removing the user's yazi strands them. Never proceed past Phase 2 with a red network.
6. **Config stays minimal here.** Phase 6e writes the tiny baseline only. No `[plugin]`, no previewers, no theme — that's `/yazi-config`'s job, on top of a VERIFIED install.
7. **Never claim success without Phase 7.** Verification includes icons rendering, not just previews.
8. **Every decision goes through `AskUserQuestion`** — 2–4 short Chinese options, safest marked **（推荐）**. Never a plain prose "要继续吗？".
9. **Never leave the user stranded (Phase 8).** If anything fails and can't be walked back via troubleshooting, offer the one-shot cleanup so they can start over clean.

## How to treat the user

Lead every step with one or two plain Chinese sentences: what, why, what they get. Recommended defaults always. The mess was the previous tool's fault, never theirs. When introducing scoop: 它把程序装进你自己的用户目录——不需要管理员、不污染系统、随时可整体移除、自动管理 PATH。

---

# Procedure

`${CLAUDE_SKILL_DIR}` is this skill's folder. Shared engine: `${CLAUDE_SKILL_DIR}\..\_shared\`.

## Phase 0 — Confirm the plan

两句话说明："你的 yazi 现在装得有问题/还没装好。我会先检查现状、确认能联网，再清理干净、用简单可靠的方式装好——每一步都讲清楚，删任何东西之前都先给你看。" Then `AskUserQuestion`:
- **「听起来不错——用 scoop，安全又省事（推荐）」**
- 「先跟我讲讲细节」

### >>> GATE. Wait for the selection. <<<

## Phase 1 — Diagnose (read-only)

"这一步只查看系统，什么都不改、不删。" Run:

```powershell
powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\diagnose.ps1"
```

**Execution mode:** run it yourself if you have shell access (Claude Code); only fall back to "user runs and pastes back" when you cannot execute commands. Sections printing `[CHECK FAILED]` are UNCHECKED — treat them as unknown, never as OK; if a failed section is one the gates depend on (network, pwsh), re-run the script in pwsh 7 before judging.

### >>> STOP. No report, no Phase 2. <<<

## Phase 2 — NETWORK GATE (mandatory, before any deletion)

Read the report's network section FIRST (real HTTPS checks against get.scoop.sh / github.com / raw.githubusercontent.com / objects.githubusercontent.com).

- **All reachable** → "联网正常，可以从 GitHub 下载"，continue.
- **Any failing** → **HARD STOP.** Explain: 我们要装的所有东西都从 GitHub 下载，现在连不上——几乎一定是代理/防火墙/国内网络问题，不是 yazi 的问题。现在动手清理只会更糟（删了旧的、新的装不上）。`AskUserQuestion`:
  - **「我用代理——告诉我怎么让 scoop 走代理（推荐）」** → `scoop config proxy 127.0.0.1:7890`（换成自己的 host:port，Clash/V2Ray 常见），然后重跑 diagnose 确认变绿。
  - 「我没有代理，帮我想办法」→ 打开 VPN/代理、或换可达 GitHub 的网络；scoop 代理文档：https://github.com/ScoopInstaller/Scoop/wiki/Using-Scoop-behind-a-proxy
  - 「再测一次」→ 重跑 diagnose。

### >>> MANDATORY GATE. Green network or nothing gets deleted. <<<

## Phase 3 — PowerShell 7 gate

Read the report's pwsh section:
- Already in pwsh 7+ → continue.
- pwsh installed but they're in 5.1 → "你装了 PowerShell 7 但没在用。运行 `pwsh`（或开始菜单找 PowerShell 7），我们在那继续。"
- Not found → explain warmly（UTF-8/中文处理更好、少踩旧坑——正是他们在受的罪），`AskUserQuestion`:
  - **「用 scoop 装 PowerShell 7（推荐——和后面步骤一致）」**（scoop 缺失则先做 Phase 6a 的 scoop 安装，再 `scoop install pwsh`）
  - 「改用 winget 装」→ `winget install --id Microsoft.PowerShell`
  - 「先跟我讲讲」

### >>> GATE. Install scripts refuse on 5.1; get them into pwsh first. <<<

## Phase 4 — Report findings, get approval to clean

Interpret the report（guide: `../_shared/references/troubleshooting.md`）in plain Chinese: 装没装、装在哪、怎么装的、坏在哪、字体状态。Then `AskUserQuestion`:
- **「全部清掉、用 scoop 正确重装（推荐——一次性解决）」**
- 「等一下，我有疑问」

混用安装方式正是这类损坏的常见根源，统一到 scoop 是可靠修法。

### >>> APPROVAL GATE — point of no return for deletion. <<<

## Phase 5 — Clean removal

Run only what matches the findings. Announce each: "这一步会删除 X。"

**5a. Backup config:**
```powershell
$cfg = "$env:APPDATA\yazi\config"
if (Test-Path $cfg) {
    $bak = "$env:APPDATA\yazi\config-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $cfg $bak -Recurse -Force; "Backed up to: $bak"
} else { "No config to back up." }
```

**5b. Remove config folder:**
```powershell
$cfg = "$env:APPDATA\yazi\config"
if (Test-Path $cfg) { Remove-Item $cfg -Recurse -Force; "Removed (backup kept)." } else { "No config folder." }
```

**5c. Uninstall yazi — ONLY the matching line:**
- scoop: `scoop uninstall yazi`
- winget: `winget uninstall --id sxyazi.yazi`
- cargo: `cargo uninstall yazi-fm; cargo uninstall yazi-cli`
- manual/unknown: do NOT guess-delete; show the path, confirm, then `Remove-Item "<path>" -Force`.

**5d. Confirm gone:**
```powershell
Get-Command yazi -ErrorAction SilentlyContinue | Select-Object Name, Source
```
Still found → report the path and ask（可能有第二份拷贝）.

### >>> STOP. 5d must return nothing. <<<

## Phase 6 — Install with scoop

**6a. Ensure scoop.**
```powershell
Get-Command scoop -ErrorAction SilentlyContinue | Select-Object Source
```
Missing → "它装进你自己的用户目录，无需管理员":
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```
Group Policy blocks → `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` then retry. Network error → should have been caught at Phase 2; recheck. After install re-check; still missing → fresh window (PATH refresh).

**6b. Deps + Nerd Font（only what's missing）:**
```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\install-deps.ps1"
```
Packages: `yazi fd ripgrep 7zip imagemagick ffmpeg poppler resvg jq git`（搜索、压缩包、图片/视频/PDF/SVG/JSON 预览；git 提供 6d 需要的 file.exe）。Font: adds `nerd-fonts` bucket, installs **`Maple-Mono-NF-CN`**（族名 **"Maple Mono NF CN"**，图标+中文一套字体全包，2:1 对齐）。Win10 1809+/Win11 按用户安装免管理员；更老的系统 manifest 会要求管理员——如实告知，让用户仅为字体步骤开一个管理员 pwsh。Script also auto-sets `YAZI_FILE_ONE`.
The script must end with `INSTALL-DEPS: OK`. `INSTALL-DEPS: PARTIAL` or a non-zero exit means do not continue as if installation succeeded; report the missing item and follow troubleshooting.

**6b-terminal. Terminal-boost tools（optional）.** "除了 yazi 的依赖，还有一套现代终端工具（eza 替代 ls、bat 替代 cat、starship 提示符等），能让日常命令行体验大幅提升。" `AskUserQuestion`:
- **「装上——一步到位（推荐）」**
- 「先不用，只装 yazi 的」

If yes:
```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\install-terminal-tools.ps1"
```
Output ends `INSTALL-TERMINAL-TOOLS: OK` or `PARTIAL`. PARTIAL → report missing items; continue regardless (these are enhancements, not yazi dependencies).

**6c. Verify binary:** `yazi --version`

**6d. Verify YAZI_FILE_ONE:**
```powershell
$existing = [Environment]::GetEnvironmentVariable("YAZI_FILE_ONE", "User")
if ($existing -and (Test-Path $existing)) { "Already set and valid: $existing" } else { "Needs setting" }
```
Needs setting →
```powershell
pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\set-yazi-file-one.ps1"
```
Then: **"关掉所有 PowerShell 窗口重开一个——这个设置只在新窗口生效。"** Not optional.

**6e. Write the minimal baseline config（copy verbatim from the vendored template, add NOTHING）:**
```powershell
$cfgDir = "$env:APPDATA\yazi\config"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item "${CLAUDE_SKILL_DIR}\..\_shared\config\yazi-minimal.toml" "$cfgDir\yazi.toml" -Force
"Wrote minimal yazi.toml"
```

**6f. Point the terminal at the font.** "字体装好了，但还得让终端用上它，图标才会显示。" Windows Terminal GUI（recommended, zero-risk）: `Ctrl+,` → 设置 → 默认值 → 外观 → 字体（勾选「显示所有字体」） → 选择 **Maple Mono NF CN** → 保存 → 重开标签页。Other terminals: same idea, offer to look up specifics.

### >>> STOP. Fresh window + font set before Phase 7. <<<

## Phase 7 — Verify

**7a.** `$env:YAZI_FILE_ONE` prints a path（blank = window not reopened）.
**7b.** `yazi --debug 2>&1 | Select-Object -First 40` — no `TOML parse error`, no `Press <Enter>`, `YAZI_FILE_ONE` not `None`.
**7c.** `yazi` — user checks: 图标是否正常（方块 ⇒ 回 6f，不是 yazi 的问题）；图片/PDF/文本预览是否出现；`q` 退出.
**7d.** All good → 热情收尾，go to Phase 8-success. Something fails → do NOT improvise: match `../_shared/references/troubleshooting.md` and walk it back. Unfixable → Phase 8-failure.

## Phase 8 — Exit（never strand the user）

**Success:** "核心安装完成，能跑、图标和预览都正常。想要更好看、更顺手（主题、Markdown 预览、快捷键）？运行 **`/yazi-config`**，一两分钟配完。"

**Failure（any phase, after troubleshooting fails）:** `AskUserQuestion`:
- **「一键清理，恢复干净状态，改天再战（推荐）」** →
  ```powershell
  pwsh -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\cleanup.ps1"
  ```
  读取最后一行：只有 `CLEANUP: DONE` 才能说环境已干净；`CLEANUP: PARTIAL` 表示仍有非 scoop 副本或卸载失败，必须如实报告路径/错误，不能宣称完成。
- 「再试试别的修法」→ 回 troubleshooting 对症走。
- 「保持现状，我自己处理」→ 如实总结当前状态（什么装了、什么没装、备份在哪）。

---

# Bundled files（shared engine, `..\_shared\`）

- `scripts/diagnose.ps1` — read-only diagnosis: PATH/install method/config/`yazi --debug`/HTTPS network（4 endpoints + proxy detection）/pwsh detection/font detection/YAZI_FILE_ONE.
- `scripts/install-deps.ps1` — missing-only deps + Maple Mono NF CN + auto YAZI_FILE_ONE. pwsh-only（5.1 上温和拒绝并指路）.
- `scripts/set-yazi-file-one.ps1` — standalone preview wiring fallback. Any PowerShell.
- `scripts/cleanup.ps1` — the Phase 8 one-shot reset. Any PowerShell.
- `config/yazi-minimal.toml` — the 6e baseline.
- `references/powershell-vs-bash.md`, `references/troubleshooting.md`.
