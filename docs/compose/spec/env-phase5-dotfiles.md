---
feature: env-phase5-dotfiles
status: delivered
updated: 2026-09-12
branch: feat/env-phase5
commits: c21ac7f..HEAD
---

# Env Phase 5 — L5 Dotfiles (local export/import)

## Report

**What was built** — L5 `env-dotfiles`：`export-dotfiles.ps1` / `import-dotfiles.ps1` + skill + doctor L5 信息行。导出 profile/git/WT/VS Code/yazi + `scoop export` + `manifest.json`/`inventory.md`；导入写前备份，不自动 scoop 重装。包默认在 `%USERPROFILE%\windows-env-rescue-dotfiles\`。

**Verification** — 本机 export：`EXPORT-DOTFILES: OK (7 items)`（含 scoop-export）。import `-Ids gitconfig,vscode-keybindings`：备份后恢复，`IMPORT-DOTFILES: OK`。doctor L5 GREEN（检测到最新导出包）。修复：`-File -Ids a,b` 逗号串拆分为数组。

**Journey log**

1. scoop 工具配置多不在固定路径；一期只导出钦定命中项 + inventory 观察（`.claude`/`.pi`/`.config`）。
2. import 不替代 bootstrap 重装；`scoop-export.json` 仅作清单参考。
3. `-File` 传数组易变单字符串，脚本内必须 split。

## [S1] Problem

L0–L4 装环境与必要 GUI 后，用户仍需要把**本机配置**（profile、git、终端、编辑器等）导出成可搬运的包，以便换机或重置后恢复。跨机云同步不在一期；一期是**用户目录本地包**。

## [S2] Design

### 决策

| 轴 | 决定 |
| --- | --- |
| 层 | L5 `env-dotfiles` |
| 模式 | **Export** / **Import** 两个引擎脚本 + skill 引导 |
| 包路径 | 默认 `%USERPROFILE%\windows-env-rescue-dotfiles\` |
| 内容 | 见清单；**不含**凭据文件（gh token 等）；git 只导出可公开配置段 |
| scoop | 导出 `scoop-export.json`（apps/buckets 清单）；**导入不自动重装**（重装走 L0–L4） |
| 安全 | Import 前备份目标文件 `*.bak-<ts>`；默认不覆盖除非 `-Force` 或确认 |

### 钦定导出清单（本机探测 + scoop 相关）

| id | 源路径（探测优先级） | 说明 |
| --- | --- | --- |
| `profile` | `$PROFILE` 或 `Documents\PowerShell\*.ps1` | 整份 PowerShell 配置 |
| `gitconfig` | `%USERPROFILE%\.gitconfig` | 全局 git 配置 |
| `wt` | `LocalState\settings.json`（WindowsTerminal 包） | WT 设置 |
| `vscode` | `%APPDATA%\Code\User\settings.json` + `keybindings.json` | VS Code 用户配置 |
| `yazi` | `%APPDATA%\yazi\config\`（目录） | Yazi 配置 |
| `scoop-export` | 由 `scoop export` 生成 | 已装应用清单 |
| `inventory` | 脚本生成 `inventory.md` | 命中/缺失路径 + scoop app 列表 |

可选观察（只写入 inventory，不默认拷贝敏感树）：`.claude/`、`.pi/`、`Local\nvim`、`%USERPROFILE%\.config\*` 列表。

### 脚本

**`export-dotfiles.ps1`**

- 参数 `-OutDir`（默认 `%USERPROFILE%\windows-env-rescue-dotfiles-<ts>` 或固定目录 + 时间戳子包）。
- 复制存在的源到 `OutDir\<id>\...`；写 `manifest.json`（id → 相对路径、原始绝对路径、sha256）。
- `scoop export` → `scoop-export.json`。
- 状态词 `EXPORT-DOTFILES: OK/PARTIAL/FAIL`（无任何命中 → FAIL；部分命中 OK/PARTIAL）。

**`import-dotfiles.ps1`**

- 参数 `-FromDir` 指向导出包；`-Ids profile,gitconfig,...` 可选过滤；`-Force` 覆盖。
- 每项：目标存在则备份再写；目录则复制合并策略：**整目录替换前备份**。
- 不执行 scoop install。
- 状态词 `IMPORT-DOTFILES: OK/PARTIAL/FAIL`。

### Skill `env-dotfiles`

- 何时 export / import；包在哪；哪些会进包、哪些不会。
- 换机建议顺序：新机 L0–L4 → import dotfiles → 新窗口。

### doctor

- **L5** 默认 **YELLOW/信息行**：不作为新机完成线阻塞项（配置是用户数据）。可探测默认包目录是否存在最近导出。
- bootstrap：**不自动跑 export/import**（避免在错误机器上覆盖）。

## [S3] Out of Scope

- 云同步 / git remote 自动推送
- 密钥与 token 迁移
- 自动 scoop 重装（由 bootstrap 层负责环境）
- 浏览器扩展、WSL 发行版

## Tasks

- [x] T1: export-dotfiles.ps1 + 清单 — acceptance: 能在本机导出 profile/git/WT/vscode/yazi/scoop-export + manifest/inventory (covers: S2)
- [x] T2: import-dotfiles.ps1 — acceptance: 从包恢复；写前备份；-Ids/-Force 行为正确 (covers: S2; depends: T1)
- [x] T3: env-dotfiles/SKILL.md + doctor L5 信息行 — acceptance: skill 文档完整；doctor 有 L5 行 (covers: S2)
- [x] T4: validate/README/DESIGN — acceptance: 文档与校验覆盖 L5 (covers: S2; depends: T1)
- [x] T5: 端到端 — acceptance: 本机 export 产出包；import 到临时目录或 dry 语义可验证；Report 记录结果 (covers: S2; depends: T2)
