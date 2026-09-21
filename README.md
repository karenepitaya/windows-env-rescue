# windows-env-rescue

一套面向 Windows 技术用户的分层装机 / 环境迁移 Claude Code skills（PowerShell 引擎可独立运行）。

当前覆盖：

- **L0 地基**：Scoop、PowerShell 7、执行策略、网络闸门
- **L1 终端**：现代 CLI（starship/eza/bat/fzf/zoxide…）+ `$PROFILE` 标记块
- **L2 开发底座**：git、nvm+Node LTS、uv+Python、pnpm、make/cmake
- **L3 AI 编码 CLI**：探测后安装 Claude Code + Pi（其余只观察）
- **体检**：分层 GREEN / YELLOW / RED
- **总入口**：一条 bootstrap（L0→L3→doctor）
- **文件管理层**：Yazi 诊断 / 重装 / 配置（保留）

设计说明见 [DESIGN.md](DESIGN.md)、[docs/compose/spec/env-phase1.md](docs/compose/spec/env-phase1.md) 与 [env-phase2-devtools.md](docs/compose/spec/env-phase2-devtools.md)。

## 前置

```powershell
git --version
# 推荐已有 PowerShell 7；没有也能从 5.1 开始装
```

Claude Code 可选：没有时直接裸跑 `_shared\scripts\` 下的引擎脚本。

## 推荐路径（新机）

```powershell
# 在仓库根目录
pwsh -NoProfile -ExecutionPolicy Bypass -File .\_shared\scripts\bootstrap.ps1
```

或在 Claude Code 中：

```text
/env-bootstrap
```

完成后新开终端窗口；`/env-doctor` 应显示 L0/L1/L2 非 RED（git 身份等可为 YELLOW）。

## Skill 一览

| 命令 | 层 | 作用 | 改系统？ |
| --- | --- | --- | --- |
| `/env-bootstrap` | 编排 | foundation → terminal → devtools → doctor | 会 |
| `/env-foundation` | L0 | scoop + pwsh7 + 策略 + 网络门 | 会 |
| `/env-terminal` | L1 | 现代 CLI + profile 标记块 | 会 |
| `/env-devtools` | L2 | git/nvm+node/uv+python/pnpm/make/cmake | 会 |
| `/env-ai-coding` | L3 | Claude Code + Pi（探测优先；Codex/Kimi 只观察） | 会 |
| `/env-doctor` | 横切 | 分层只读体检 | 不会 |
| `/yazi-detect` | L6 | Yazi 只读诊断 | 不会 |
| `/yazi-install` | L6 | Yazi 清理重装 | 会 |
| `/yazi-config` | L6 | Yazi 主题/预览/快捷键 | 会 |

旧 `/terminal-boost` 已并入 `/env-terminal`（profile 标记自动从 `terminal-boost` 迁移到 `windows-env-rescue`）。

## 长期安装 skills 到 Claude Code

```powershell
$src = "path\to\windows-env-rescue"  # 本仓库克隆路径
$dst = "$env:USERPROFILE\.claude\skills"
$names = @(
  "env-bootstrap", "env-foundation", "env-terminal", "env-devtools", "env-ai-coding", "env-doctor",
  "yazi-detect", "yazi-install", "yazi-config", "_shared"
)
foreach ($name in $names) {
  $target = Join-Path $dst $name
  if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  Copy-Item -Path (Join-Path $src $name) -Destination $target -Recurse
}
```

## 安全约定

- 默认静默按 manifest 安装；失败才停并展示原始输出。
- 破坏性操作前确认；profile **只**替换标记块，写前备份。
- 状态词：`OK` / `PARTIAL` / `FAIL: <reason>`，禁止半成功报成功。
- 纯探测判断是否已安装，不写状态文件。

## Manifest

钦定清单在 `_shared/manifests/`：

- `foundation.toml` — pwsh（required）、git（optional）
- `terminal.toml` — starship（required）+ 现代 CLI（optional）
- `devtools.toml` — git/nvm/uv（required）、make/cmake（optional）；Node 走 nvm，Python 走 uv
- `ai-coding.toml` — Claude Code + Pi（可装）；codex/kimi 仅观察

## 维护者

```text
windows-env-rescue/
├── env-bootstrap/ env-foundation/ env-terminal/ env-devtools/ env-ai-coding/ env-doctor/
├── yazi-detect/ yazi-install/ yazi-config/
└── _shared/
    ├── manifests/
    ├── scripts/
    ├── config/
    └── references/
```

发布前：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\_shared\scripts\validate-release.ps1
```

## 资料来源

- [Yazi 官方文档](https://yazi-rs.github.io/docs/installation/)
- [Scoop](https://scoop.sh/)
- [Agent Skills 规范](https://agentskills.io/specification)

MIT License。

---

# English summary

Windows-focused layered setup suite: foundation (Scoop/PowerShell 7), terminal modern CLIs, layered doctor, one-shot bootstrap, plus the existing Yazi skills. Scripts under `_shared/scripts` run without Claude Code. See DESIGN.md and the phase-1 spec for contracts.
