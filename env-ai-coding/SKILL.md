---
name: env-ai-coding
description: Install Windows L3 AI coding CLIs for windows-env-rescue — detect-first, auto-install only Claude Code and Pi (pi.dev). Other agents (Codex, Kimi) are observe-only. Use when the user wants AI 编码工具 / Claude Code / Pi agent CLI on a new machine. Does not log in or configure API keys.
license: MIT
compatibility: Windows 10/11. Needs network for missing tools. PowerShell 5.1+ (7 preferred).
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L3
---

# env-ai-coding（AI 编码 CLI）

L3：**先探测，已装则跳过**；缺失时**只自动安装**：

| 工具 | 安装 |
| --- | --- |
| Claude Code | `irm https://claude.ai/install.ps1 \| iex` |
| Pi | `irm https://pi.dev/install.ps1 \| iex`（失败可 npm `@earendil-works/pi-coding-agent`） |

Codex / Kimi 等：**只报告 present/absent，不安装**。

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-ai-coding.ps1
# 只装其一：
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-ai-coding.ps1 -SkipPi
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-ai-coding.ps1 -SkipClaude
```

状态词：`INSTALL-AI-CODING: OK` / `PARTIAL` / `FAIL: <reason>`。

## Agent 流程

1. 说明：只装 Claude Code 与 Pi；已装不动；**不代登录**。
2. 运行脚本。
3. OK → 提示新开终端，`claude` / `pi` 自行认证。
4. FAIL：网络（`claude.ai`/`pi.dev`）→ 代理后重跑；verify 失败 → 对照官方文档，勿谎报成功。
5. 不要在这层装 GUI 应用或改 git 配置。

## Manifest

`_shared/manifests/ai-coding.toml`（`[[tool]]` 可装，`[[observe]]` 只看）。

## 与 bootstrap

`/env-bootstrap` 顺序：foundation → terminal → devtools → **ai-coding** → doctor。
