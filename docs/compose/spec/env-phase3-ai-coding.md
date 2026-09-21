---
feature: env-phase3-ai-coding
status: in-progress
updated: 2026-09-12
branch: feat/env-phase3
commits: # filled at delivery
---

# Env Phase 3 — L3 AI Coding Tools

## Report

**What was built** — L3 `env-ai-coding`：manifest + `install-ai-coding.ps1`（探测优先；仅安装 Claude Code 与 Pi；codex/kimi 只观察）+ doctor L3 + bootstrap 扩到 ai-coding。

**Verification** — 本机：parse 0 错误；`install-ai-coding` → OK exit 0（claude 2.1.261、pi 0.84.1 已装幂等）；doctor L3 GREEN，observe codex+/kimi+；L2 仍 YELLOW（optional make/cmake）。

**Journey log**

1. 官方安装源：Claude `claude.ai/install.ps1`，Pi `pi.dev/install.ps1`（npm 备选 `@earendil-works/pi-coding-agent`）。
2. `[[observe]]` 不得进入自动安装清单；解析 observe 时跳过 manifest 首段，避免误把 tool 的 binary 当成 observe。

## [S1] Problem

L2 装好 git/node/python 后，新机仍缺日常使用的 agent CLI。用户钦定：**先探测，未安装才装**；**只自动安装 Claude Code 与 Pi**（其余如 Codex/Kimi 若已存在则只报告，不装不删）。

## [S2] Design

### 决策

| 轴 | 决定 |
| --- | --- |
| 层 | L3 `env-ai-coding` |
| 可安装 | **Claude Code**、**Pi**（`pi`） |
| 只探测 | Codex / Kimi Code 等（存在则 GREEN 信息，不安装） |
| 策略 | 已装 → 跳过；未装 → 官方安装器 |
| 认证 | **不在安装脚本内登录**；装完提示用户自行 `claude` / `pi` 认证 |
| 依赖 | 需网络；建议 L0/L2 就绪（node 可选：Pi 也可用官方 ps1） |

### 安装契约（2026-09 文档核实）

| 工具 | 探测 | Windows 安装 | 验收 |
| --- | --- | --- | --- |
| Claude Code | `claude` on PATH 或 `%USERPROFILE%\.local\bin\claude.exe` | `irm https://claude.ai/install.ps1 \| iex`（官方 native） | `claude --version` |
| Pi | `pi` on PATH | `irm https://pi.dev/install.ps1 \| iex`；备选 `npm install -g --ignore-scripts @earendil-works/pi-coding-agent` | `pi --version` 或 `pi -h` |

不把 scoop/winget 作为主路径（与官方文档一致）。网络探测复用四端点 + 可选扩展 `claude.ai`/`pi.dev`。

### Manifest

`_shared/manifests/ai-coding.toml`：

```toml
schema = 1
name = "ai-coding"

[[tool]]
id = "claude-code"
binary = "claude"
required = true
install = "native-ps1"
url = "https://claude.ai/install.ps1"
verify = "claude --version"

[[tool]]
id = "pi"
binary = "pi"
required = true
install = "native-ps1"
url = "https://pi.dev/install.ps1"
verify = "pi --version"

[[observe]]
id = "codex"
binary = "codex"

[[observe]]
id = "kimi"
binary = "kimi"
```

`scoop` 字段不适用；引擎按 `install`/`url` 执行。

### 脚本 `install-ai-coding.ps1`

1. 刷新 PATH（含 `%USERPROFILE%\.local\bin`）。
2. 对每个 `[[tool]]`：已探测且 verify 通过 → `OK` 跳过。
3. 缺失且 required → 网络门（失败 FAIL + 代理提示）→ 执行官方 ps1 → 重新刷新 PATH → `verify`。
4. verify 失败 → FAIL（不谎报 OK）。
5. `[[observe]]`：仅打印 present/absent，不影响层状态（除非文档要求）。
6. 状态词 `INSTALL-AI-CODING: OK/PARTIAL/FAIL`。
7. 参数 `-SkipClaude` / `-SkipPi` 可选（默认都不 skip）。

### Skill `env-ai-coding`

- 中文引导；裸跑命令；装完提示新开终端并自行登录。
- 不在 skill 里代跑登录/API key。

### doctor / bootstrap

- doctor 增加 **L3 ai-coding**：required（claude+pi）缺失 → RED；observe 仅写入 detail。
- bootstrap：foundation → terminal → devtools → **ai-coding** → doctor；任一安装层 FAIL 跳过更高层。

### 文档

- README skill 表、manifest 列表、维护者树。
- validate-release required 增加 skill/script/manifest。
- DESIGN：L3 标为已实现。

## [S3] Out of Scope

- Codex / Kimi 自动安装
- OAuth / API key / 订阅登录
- Desktop GUI 安装
- L4/L5

## Tasks

- [x] T1: `ai-coding.toml` + `env-ai-coding/SKILL.md` — acceptance: 契约字段符合 [S2]；skill 含裸跑与认证说明 (covers: S2)
- [x] T2: `install-ai-coding.ps1` — acceptance: 已装幂等跳过；未装走官方 URL；最终 verify 真实命令；状态词契约 (covers: S2; depends: T1)
- [x] T3: doctor L3 + bootstrap 串联 — acceptance: doctor 含 L3；bootstrap 顺序含 ai-coding 且 FAIL 跳过更高层 (covers: S2; depends: T2)
- [x] T4: validate/README/DESIGN — acceptance: 校验与文档覆盖 L3 (covers: S2; depends: T1)
- [x] T5: 端到端验证 — acceptance: 本机探测结果写入 Report；安装路径在已装机器上证明幂等 (covers: S2; depends: T3)
