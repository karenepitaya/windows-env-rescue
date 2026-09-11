---
name: env-bootstrap
description: One-shot Windows new-machine bootstrap for windows-env-rescue — runs foundation, then terminal, then doctor. Use when the user wants 新机装机 / bootstrap / 一条龙配置到终端就绪. FAIL stops later installs; PARTIAL continues. Prefer this over manually chaining skills when the goal is a fresh daily-driver terminal.
license: MIT
compatibility: Windows 10/11. Prefers PowerShell 7+ after foundation installs it.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: orchestrator
---

# env-bootstrap（总入口）

按序执行：

1. `install-foundation.ps1`（L0）
2. `install-terminal-tools.ps1`（L1）
3. `doctor.ps1`（汇总验收）

一期完成线：**终端就绪**（L0+L1 无 RED）。

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\bootstrap.ps1
```

状态词：`BOOTSTRAP: OK` / `PARTIAL` / `FAIL`。退出码：0 / 2 / 1。

## Agent 流程

1. 两句话说明范围：装 scoop/pwsh7 → 现代终端工具 + profile → doctor 验收。不做 git 身份、语言运行时、GUI 应用（二期）。
2. 直接跑 bootstrap 脚本，不要手写串联。
3. 失败时：
   - network → 代理后重跑 bootstrap 或单跑 foundation。
   - terminal required（starship）→ 修网络/scoop 后重跑。
4. 成功后提示：新窗口生效；可选 `/yazi-install` 装文件管理器。
5. 单层重跑仍然合法：`/env-foundation`、`/env-terminal`、`/env-doctor`。

## 退出语义（引擎）

| 情况 | bootstrap 状态 |
| --- | --- |
| 两层 OK 且 doctor 非 RED | OK |
| 出现 PARTIAL（无 FAIL） | PARTIAL |
| 任一层 FAIL 或 doctor RED | FAIL |
