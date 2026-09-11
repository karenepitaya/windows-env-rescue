---
feature: env-phase1
status: delivered
updated: 2026-09-12
branch: feat/env-phase1
commits: 13deebd..<HEAD>
---

# Windows Env Rescue — Phase 1 (Foundation + Terminal + Bootstrap)

## Report

**What was built** — 一层可裸跑的 PowerShell 引擎加四个 skill：`install-foundation.ps1`（scoop/pwsh7/策略/网络门）、manifest 驱动的 `install-terminal-tools.ps1`（含 `windows-env-rescue` profile 标记与旧 `terminal-boost` 迁移）、分层 `doctor.ps1`、编排 `bootstrap.ps1`。钦定清单在 `_shared/manifests/`。`terminal-boost` skill 删除；README/校验脚本改为 `windows-env-rescue`。一期完成线为终端就绪（L0+L1 无 RED）。

**Verification** — 本机 Windows 上：`Import-WerManifest` 解析 foundation(2)/terminal(13 tools) PASS；`install-foundation` 已就绪幂等 `OK` exit 0；`install-terminal-tools` 迁移后再次替换 `OK` exit 0；profile 替换单元验证 `twice_eq_once=True`、`$_` 管道原样、legacy 迁移后稳定；`doctor` L0/L1/L6 全 GREEN exit 0；`bootstrap` 全链路 `BOOTSTRAP: OK` exit 0；`validate-release` 新结构与 parse PASS（yazi complete-zh `yazi --debug` 超时为 PRE-EXISTING，未阻断）。

**Journey log**

1. Review 抓到 C1：`[regex]::Replace` 把 profile 里的 `$_` 当替换变量，第二次写入会损坏块——改用 MatchEvaluator 并归一尾部换行后才幂等。
2. bootstrap 把子脚本 stdout 和 `$LASTEXITCODE` 混进同一返回值；改为 `Out-Host` + 直接读 `$LASTEXITCODE`。
3. `terminal-boost`→`env-terminal` 时保留脚本文件名 `install-terminal-tools.ps1`，降低 yazi-install 回归面。
4. validate-release 对 terminal 工具的检查从硬编码脚本文本改为 `terminal.toml` 清单，避免引擎改读 manifest 后误报。
5. 沙箱禁止本会话 `git worktree add`，worktree 需用户手建——跨 agent 协作时的固定约束。

## [S1] Problem

技术用户拿到新 Windows 机（或重置后）需要从零重现一套「标准环境」：能用的 scoop/pwsh7、顺眼的终端与现代 CLI。现有仓库只覆盖 yazi 救援与旧版 terminal-boost，缺少：

- 可独立于 Claude Code 运行的安装引擎
- 按层验收的整机体检
- 一条从零到「终端就绪」的总入口

目标故事：在干净或半残 Windows 上跑通 bootstrap（或分层 skill），`env-doctor` 显示 L0/L1 全绿，即可开始日常终端工作。不做旧机文件搬家。

## [S2] Design

### 产品决策（已 grill）

| 轴 | 决定 |
| --- | --- |
| 内核 | 新机从零重现标准环境 |
| 真相源 | 仓库内钦定 manifests（`_shared/manifests/*.toml`） |
| 架构 | PowerShell 脚本为引擎，可裸跑；SKILL.md 仅中文引导/闸门/失败解读 |
| 入口 | 一期含 `bootstrap.ps1` + `/env-bootstrap` |
| 状态 | 纯探测，无状态文件 |
| 一期完成线 | L0 + L1 全绿（终端就绪） |

### 分层契约

```text
L0  env-foundation   scoop · pwsh7 · 执行策略 · UTF-8 · 网络探测
L1  env-terminal     WT 字体/快捷键 · starship · eza/bat/fzf/zoxide · profile 标记块
横切  env-doctor      按层 GREEN / YELLOW / RED / UNKNOWN
总入口 env-bootstrap  foundation → terminal → doctor；FAIL 停，PARTIAL 可继续并汇总标黄
```

L2+（devtools / ai-coding / apps / dotfiles）不在本 feature 实现。

### 交互与状态协议

1. 默认按 manifest 静默安装；网络/权限/冲突/非零退出才停并展示原始输出。
2. 破坏性操作（删目录、卸载、改 profile 标记块外内容）前唯一确认。标记块内幂等替换不需要确认。
3. 脚本最后一行状态词：`OK` / `PARTIAL` / `FAIL: <reason>`。禁止半成功报成功。
4. 幂等：已满足验收则跳过；重复跑不得产生重复 profile 块。
5. 语言：交互中文；命令/路径/包名原文。
6. 装机脚本要求 pwsh 7+；doctor 探测可在 5.1 跑（部分节可能 UNKNOWN）。

### Manifest 方言

路径：`_shared/manifests/foundation.toml`、`_shared/manifests/terminal.toml`。

```toml
schema = 1
name = "foundation"

[[tool]]
id = "pwsh"
scoop = "pwsh"
required = true
verify = "pwsh -NoProfile -Command \"$PSVersionTable.PSVersion.Major -ge 7\""

[[tool]]
id = "git"
scoop = "git"
required = false
verify = "git --version"
```

规则：

- `required = true` 失败 → 该层 `FAIL`，不写后续配置。
- `required = false` 失败 → 跳过，层状态 `PARTIAL`。
- `verify` 必须是可执行验收，不能只用 `Get-Command` 存在性。
- foundation 的 scoop 引导（若 scoop 本身缺失）写在脚本内，不做成 scoop 包条目。

### L0 env-foundation

脚本：`_shared/scripts/install-foundation.ps1`

1. 检测 scoop / pwsh7 / 执行策略 / 网络。
2. 网络：HTTPS 探测 `get.scoop.sh`、`github.com`、`raw.githubusercontent.com`、`objects.githubusercontent.com`；任一失败且需下载 → `FAIL` 并给代理指引（`scoop config proxy host:port`）。已全部就绪且无需下载时可跳过网络硬门。
3. 缺 scoop → 官方安装（`RemoteSigned` + `get.scoop.sh`）。
4. 按 manifest 装缺失的 required 包（至少 pwsh；git 为 required=false）。
5. 确保 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`（已满足则跳过）。
6. UTF-8：脚本内 `[Console]::OutputEncoding` / `$OutputEncoding` 自愈；文档说明新窗口约定。
7. 验收输出以 `install-foundation` 状态词结束。

Skill：`env-foundation/SKILL.md` — 解释、失败解读、代理引导；默认调脚本，不逐步 AskUserQuestion。

### L1 env-terminal

脚本：`_shared/scripts/install-terminal-tools.ps1`（改造现有）+ 可选 `apply-wt-settings.ps1`

1. 读 `terminal.toml` 安装：required 至少 starship；optional 含 eza、bat、fzf、zoxide、fd、ripgrep（以 manifest 为准，实现时写入钦定集合）。
2. Profile 标记块：`_shared/scripts/profile-block.ps1` 写入 `$PROFILE`，标记：
   - start: `# >>> windows-env-rescue >>>`
   - end: `# <<< windows-env-rescue <<<`
3. 若检测到旧标记 `# >>> terminal-boost >>>`…`# <<< terminal-boost <<<`，替换为新块（迁移一次）。
4. 写 profile 前备份 `*.bak-<timestamp>`。
5. Windows Terminal：若检测到 `settings.json`，脚本尝试合并字体为 Maple Mono NF CN（若已装）或跳过字体步骤；失败不阻塞层 FAIL，降级为文档/GUI 指引。快捷键仍可选，沿用 `_shared/config/wt-keybindings.json`，失败跳过。
6. 字体：复用现有 nerd-font 安装路径（Maple-Mono-NF-CN）；已装则跳过。
7. `zoxide` 若装上，profile 块内已含 hook（与现 profile-block 一致）。

Skill：`env-terminal/SKILL.md`。旧 `terminal-boost/` 目录删除；README/引用改为 env-terminal。

### L-横切 env-doctor

脚本：`_shared/scripts/doctor.ps1`（由现 diagnose 演进，yazi 专节保留为可选层）

输出契约（stdout）：

```text
L0 foundation  GREEN   scoop+pwsh7 OK
L1 terminal    YELLOW  starship missing
L6 yazi        RED     yazi not found
```

- GREEN：该层全部 required verify 通过。
- YELLOW：仅 optional 缺失。
- RED：required 缺失。
- 未执行/异常的探测：`UNKNOWN`，禁止猜 GREEN。
- 退出码：全 GREEN 或仅 YELLOW → 0；存在 RED → 1。（便于 bootstrap 判断）

Skill：`env-doctor/SKILL.md`。现有 yazi 诊断能力不回归：doctor 可输出 yazi 行；`/yazi-detect` 继续可用。

### 总入口 env-bootstrap

脚本：`_shared/scripts/bootstrap.ps1`

顺序：`install-foundation.ps1` → `install-terminal-tools.ps1` → `doctor.ps1`

- 任一层 `FAIL` → 停止后续安装层，仍尝试 doctor 汇总，bootstrap 自身以非零退出。
- `PARTIAL` → 继续下一层，最终汇总标黄，退出码 0（或约定 2 表示 PARTIAL，实现时固定一种并写进脚本头注释与 skill）。
- Skill：`env-bootstrap/SKILL.md` 解释阶段与结果。

### 仓库改名

同一 feature 内完成：

- 目录名与 GitHub 仓库名 → `windows-env-rescue`（若 GitHub rename 需凭据，脚本/任务不阻塞代码合并；本地与文档先改）。
- README 标题、clone URL、路径引用更新。
- AGENTS.md / DESIGN.md 中旧名保留一处「历史名」说明即可。

### 与 yazi 的边界

- `yazi-detect` / `yazi-install` / `yazi-config` 的 skill 与专用脚本路径保持可运行。
- 共享脚本若改名/改标记，同步改 yazi SKILL.md 中的引用。
- `validate-release.ps1` 更新以覆盖新 skill 与 manifest 存在性。

## [S3] Out of Scope

- env-devtools / env-ai-coding / env-apps / env-dotfiles 实现
- 旧机 capture/restore、跨机同步
- 一键改 GitHub 远程并 push（本地改名与文档在 scope；远程 rename/push 由用户决定）
- winget 作为主安装路径
- 状态文件、用户私有 manifest 合并
- git 身份、语言运行时、GUI 应用清单
- 非 Windows 平台

## Tasks

- [x] T1: 写入 foundation/terminal manifests 与目录骨架 — acceptance: `_shared/manifests/foundation.toml`、`terminal.toml` 存在且 schema 字段符合 [S2]；skill 目录 env-foundation/env-terminal/env-doctor/env-bootstrap 各有 SKILL.md 骨架 (covers: S2)
- [x] T2: 实现 `install-foundation.ps1` — acceptance: 脚本按 [S2] L0 逻辑存在；以 `-WhatIf` 或文档化 dry-run/已就绪路径可在本机验证幂等跳过；结束状态词契约成立 (covers: S2)
- [x] T3: 改造 terminal 安装与 profile 标记 — acceptance: `install-terminal-tools.ps1` 读 terminal.toml；profile 使用 windows-env-rescue 标记；旧 terminal-boost 标记可迁移；重复跑无重复块 (covers: S2; depends: T1)
- [x] T4: 实现 `doctor.ps1` 分层输出 — acceptance: 输出含 L0/L1 行与 GREEN/YELLOW/RED/UNKNOWN；yazi 行不破坏 `/yazi-detect` 既有脚本；退出码约定可测 (covers: S2; depends: T1)
- [x] T5: 实现 `bootstrap.ps1` 与 `env-bootstrap` skill — acceptance: 按 foundation→terminal→doctor 串联；FAIL 停装并 doctor 汇总；文档写明退出码 (covers: S2; depends: T2, T3, T4)
- [x] T6: 四个新 SKILL.md 写全并接线 `_shared` — acceptance: 每个 skill 说明何时用、裸跑命令、失败时下一步；frontmatter name/description 符合 Agent Skills 习惯 (covers: S2)
- [x] T7: 移除 terminal-boost、更新引用 — acceptance: 仓库内无指向 terminal-boost 作为活动 skill 的文档；profile 迁移说明在 env-terminal skill 中 (covers: S2; depends: T3)
- [x] T8: 仓库与文档改名 windows-env-rescue — acceptance: README 标题/结构/命令中的套件名一致；本地 git 可在分支上工作不依赖远程已改名 (covers: S2)
- [x] T9: 更新 validate-release 覆盖新结构 — acceptance: 对本分支运行校验脚本通过或明确列出仅环境缺依赖的跳过项 (covers: S2; depends: T1, T6)
- [x] T10: 端到端验证记录 — acceptance: 在可用 Windows 上至少完成「doctor 一次 + foundation/terminal 已就绪时幂等跳过」实测；结果记入 Report (covers: S2; depends: T5)
