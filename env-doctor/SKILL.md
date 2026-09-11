---
name: env-doctor
description: Read-only layered health check for windows-env-rescue on Windows. Reports L0 foundation, L1 terminal, and optional L6 yazi as GREEN/YELLOW/RED/UNKNOWN. Use when the user asks 体检 / doctor / 哪层有问题 / is my env ready — never changes the system. Point failures at /env-foundation or /env-terminal.
license: MIT
compatibility: Windows 10/11. Any PowerShell; complete probes prefer pwsh 7+.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: cross-cutting
---

# env-doctor（分层体检）

只读。按层输出一行状态，最后 `DOCTOR: GREEN|YELLOW|RED`。

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\doctor.ps1
```

退出码：无 RED 为 0，有 RED 为 1。

## 输出契约

```text
L0 foundation  GREEN   scoop+pwsh OK
L1 terminal    YELLOW  missing optional: dust; profile block present
L6 yazi        YELLOW  not installed (optional; use /yazi-install)
```

- **GREEN**：该层 required（及 optional）验收通过。
- **YELLOW**：仅 optional 缺失，或 yazi 未装。
- **RED**：required 缺失（如 scoop/pwsh/starship）。
- **UNKNOWN**：探测失败——**禁止**说成正常。

## Agent 流程

1. 说明只读。
2. 运行脚本，用表格/列表向用户转述各行。
3. RED → 指到对应 skill（foundation/terminal/yazi-install）。
4. 全绿 → 可建议日常用 `y`/`yazi` 或继续个性化。
5. 不要在 doctor 里安装任何东西。

## 与 /yazi-detect

`/yazi-detect` 仍是 yazi 专用深度诊断；本 skill 是套件分层总览，可共存。
