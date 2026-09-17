# DESIGN — windows-env-rescue

Windows 技术用户分层装机 / 环境迁移 skill 套件。一期实现以 `docs/compose/spec/env-phase1.md` 为权威契约；本文保留总体架构与二期边界。

一期增量：bootstrap 总入口进一期；PowerShell 脚本为可裸跑引擎；完成线 = 终端就绪（L0+L1 无 RED）。

## 0. 设计公理与强制原则

三条公理（不可妥协，一切设计从这里推导）：

- **公理 A：必须假设用户环境是非常乱的。** 已有配置、混合换行、非 UTF-8 编码、装了一半的工具、手改过的 profile，都是常态而非例外。
- **公理 B：安全大于功能。** 功能缺失可以补，用户环境弄坏回不来。
- **公理 C：面向用户。** 用户不该被迫做技术决策，不该读日志墙。

由公理推出的强制原则：

| # | 原则 | 来源 | 级别 |
| --- | --- | --- | --- |
| 1 | **只探测，不假设**：PATH、编码、换行、已有配置全部运行时探测；代码中禁止"用户应该是……"的隐含前提 | A | 红线 |
| 2 | **与未知共存**：标记块外不认识的代码一律视为用户的，神圣不可动；无法安全处理时跳过并如实报告，不"帮忙修" | A | 强约束 |
| 3 | **幂等且可重入**：从任何脏状态重跑都收敛到同一结果，中途失败不留半成品 | A | 强约束 |
| 4 | **失败默认安全**：任何一步失败则回滚或保持原状；宁可不装，不可装坏 | B | 红线 |
| 5 | **零不可逆操作**：每次写入必有备份与卸载路径；批量产物（如 `.bak`）必须有数量上限 | B | 强约束 |
| 6 | **禁止谎报**：探测失败报 `UNKNOWN`，状态词诚实；禁止把半成功当成功、把未测当 GREEN | B | 红线 |
| 7 | **最小权限**：只动用户级配置，永不请求管理员 | B | 强约束 |
| 8 | **替用户做完决策**：默认值必须是安全值；换行、编码、顺序等技术细节是内部问题，不抛给用户 | C | 强约束 |
| 9 | **输出是结论不是日志**：一句话状态 + 下一步指向；细节进 `--verbose` | C | 强约束 |
| 10 | **可解释可卸载**：用户看到每段写入都知道是什么、怎么去掉 | C | 强约束 |

功能层面的两条补充原则：

- **稳定优先于最新**：manifest 锁定作者机器验证过的版本组合；不追最新版，升级版本是一次显式的、经过验证的 manifest 变更，而不是装机时的隐式行为。
- **探测先行，doctor 全程有效**：任何 skill 的第一步必须是梳理当前系统环境（复用 env-doctor 的探测函数，禁止各 skill 自造探测逻辑）；doctor 必须在任何阶段有效——未装、装一半、已装、损坏状态下都能正确输出分层状态。

红线规则：违反原则 1、4、6 的代码/PR 一律拒收，无例外。其余为强约束，违反需在 PR 中书面说明理由。

## 1. 定位

- **给谁用**：作者本人及同类技术用户。懂终端，要可复现、可审查、可单独重跑。
- **解决什么**：新 Windows 机从零到「终端就绪」（一期）；旧机损坏后的分层重装。分层 skill 可单独跑，`/env-bootstrap` 提供一期总入口。
- **不是什么**：不是通用配置管理器（Ansible 替代品）；一期不做跨机云同步。

## 2. 架构

按层拆 skill，层间单向依赖（上层可假设下层已绿，doctor 可验证）：

```text
L0  env-foundation   scoop · pwsh7 · 执行策略 · UTF-8 · PATH/环境变量卫生
L1  env-terminal     WT · 字体 · starship · eza/bat/fzf/zoxide · profile 标记块
L2  env-devtools     git · node · python(uv) · 常用 CLI          [二期]
L3  env-ai-coding    Claude Code · Codex · Kimi Code · …          [二期]
L4  env-apps         VS Code · 浏览器等 GUI                       [二期]
L5  env-dotfiles     本机 profile/编辑器/git 配置 导出·导入         [二期，跨机同步三期]
L6  yazi-*           文件管理（detect / install / config，保留）    [已有]
横切  env-doctor      整机分层体检（绿/黄/红 + 修复指引）
```

### 2.1 一期范围

| 交付 | 内容 |
| --- | --- |
| 仓库改名 | `yazi-windows-rescue` → `windows-env-rescue`（GitHub 同步改） |
| `env-foundation` | 装 scoop / pwsh7；执行策略；UTF-8；PATH 刷新约定；幂等 |
| `env-terminal` | 升级现 `terminal-boost`：工具清单走 manifest；WT 字体与快捷键；profile 标记块 |
| `env-doctor` | 扩展现 `diagnose.ps1`：按层输出状态，不只服务 yazi |
| 协议落地 | manifest 方言、统一退出码/状态词、`_shared` 目录重组 |
| 文档 | README 重写；保留 yazi 用法段落 |

### 2.2 明确推迟

- L2–L5 功能实现（只预留目录与 manifest 空壳）
- 一键 `/bootstrap` 编排入口
- 跨机 dotfiles 同步（网盘 / git remote）
- 非 scoop 安装路径（winget 仅作 GUI 二期备选，不进一期）

## 3. 交互协议（全套件强制）

1. **Manifest 优先**：装什么、什么版本，写在 `_shared/manifests/*.toml`。默认静默执行。
2. **失败才停**：网络、权限、冲突、脚本非零退出 → 展示原始输出 + 一条修复建议，等待用户。
3. **唯一破坏性确认**：删除、覆盖 profile 非标记区、卸载前必须确认。标记块内替换不需要（幂等）。
4. **状态词统一**：脚本最后一行 `OK` / `PARTIAL` / `FAIL: <reason>`。禁止半成功当成功。
5. **幂等**：已装且版本满足则跳过；配置写入用标记块或先备份再写。
6. **语言**：交互默认简体中文；命令、路径、包名保持原文。
7. **PowerShell only**：不用 bash 语法；装机脚本要求 pwsh 7+，诊断可在 5.1 跑。

## 4. Manifest 方言

与现有 yazi `package.toml` 同思路：**作者机器验证过的组合，可复现**。

```toml
# _shared/manifests/terminal.toml（示意，非最终）
schema = 1
name = "terminal"

[[tool]]
id = "eza"
scoop = "eza"
required = false
verify = "eza --version"

[[tool]]
id = "starship"
scoop = "starship"
required = true
verify = "starship --version"

[profile]
block_file = "scripts/profile-block.ps1"
start = "# >>> windows-env-rescue >>>"
end = "# <<< windows-env-rescue <<<"
```

约定：

- `required = true` 失败 → 该层 `FAIL`，不继续写配置。
- `required = false` 失败 → 跳过该项，层状态 `PARTIAL`。
- `verify` 是安装后的独立验收命令，不用「命令存在」代替「能跑」。
- 插件 / 字体等非 scoop 资产用 `[download]` 段扩展（一期仅终端字体用到）。

## 5. 目录结构（目标）

```text
windows-env-rescue/
├── AGENTS.md
├── DESIGN.md
├── README.md
├── LICENSE
├── env-foundation/
│   └── SKILL.md
├── env-terminal/
│   └── SKILL.md
├── env-doctor/
│   └── SKILL.md
├── yazi-detect/          # 保留
├── yazi-install/         # 保留
├── yazi-config/          # 保留
├── env-devtools/         # 二期占位（可先空目录或延后创建）
├── env-ai-coding/        # 二期
├── env-apps/             # 二期
├── env-dotfiles/         # 二期
└── _shared/
    ├── manifests/        # foundation.toml, terminal.toml, …
    ├── scripts/          # 可复用 PowerShell
    ├── config/           # 模板（yazi、WT keybindings、profile 片段）
    └── references/       # troubleshooting、cheatsheet、powershell-vs-bash
```

命名：skill 目录名 = skill id = slash 命令名。新层一律 `env-` 前缀，避免与用户已有 skill 冲突。

## 6. 现有资产迁移

| 现有 | 处理 |
| --- | --- |
| `terminal-boost/` | 内容并入 `env-terminal`；旧 id 删除或留 redirect 说明一版后删 |
| `_shared/scripts/install-terminal-tools.ps1` | 改读 manifest；保留脚本名一版 |
| `_shared/scripts/profile-block.ps1` | 标记改为 `windows-env-rescue`；兼容旧 `terminal-boost` 标记时迁移替换 |
| `_shared/scripts/diagnose.ps1` | 拆成层探测函数，由 `env-doctor` 编排；yazi 相关探测保留 |
| `_shared/scripts/install-deps.ps1` 等 yazi 专用 | 留在原路径，由 yazi-install 继续引用 |
| `yazi-*/SKILL.md` | 路径变量 `${CLAUDE_SKILL_DIR}\..\_shared\` 不变则可不动；README 引用更新 |
| 仓库名 / 远程 | `git remote` → `windows-env-rescue`；GitHub rename；README 标题与 clone URL |

## 7. env-foundation 职责细则

1. 检测是否已有 scoop / pwsh7 / git，缺才装。
2. `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`（已满足则跳过）。
3. scoop 官方安装脚本；失败给代理指引（复用现有 4 端点探测思路）。
4. `scoop install pwsh git`（manifest 驱动）。
5. 写入 UTF-8 与相关环境变量的约定（脚本内自愈 + 文档说明新窗口生效）。
6. 验收：`scoop --version`、`pwsh -NoProfile -Command '$PSVersionTable.PSVersion'` 均 OK。

不负责：终端美化、开发语言、GUI 应用。

## 8. env-doctor 输出契约

每层一行或一小节：

```text
L0 foundation  GREEN   scoop+pwsh7 OK
L1 terminal    YELLOW  starship missing
L6 yazi        RED     yazi not found
```

- GREEN：该层验收命令全部通过。
- YELLOW：非关键缺失，可继续但建议补齐。
- RED：关键缺失，指到对应 `/env-*` skill。
- 某项未测：`UNKNOWN`，禁止猜成 GREEN。

## 9. 安全与可逆

- 任何删除/卸载：先展示将动的路径，确认后执行。
- profile：只动标记块；块外内容永不改写。写前备份 `*.bak-<timestamp>`。
- 环境变量：只设已知键，不整体替换 PATH。
- 清理脚本保留 yazi 现有 `CLEANUP: DONE/PARTIAL` 语义，扩展到新层时同样禁止谎报。

## 10. 成功标准（一期）

1. 新目录克隆后，`/env-foundation` → `/env-terminal` 在干净或半残 Windows 上可跑通。
2. `/env-doctor` 在三层已就绪时全绿；拔掉任一依赖能正确标黄/红。
3. 重复执行两遍不产生重复 profile 块、不重复安装。
4. 现有 `/yazi-detect` `/yazi-install` `/yazi-config` 路径与行为不回归。
5. `validate-release.ps1`（需随改名更新）通过。

## 11. 未决 / 实现时现查

- 新仓库是否保留 `yazi-windows-rescue` 旧名 redirect（GitHub 会自动跳转，通常够用）。
- Windows Terminal 字体设置能否可靠用脚本写 `settings.json`（一期可能保留 GUI 手动一步 + 脚本备选）。
- AI 编码工具的安装源与版本策略（二期开工前再查权威文档，不沿用本文）。

## 12. 文档纪律

实现若改协议、目录、状态词或一期范围，先改本文件再改代码。README 面向用户；本文件面向维护者与 agent。
