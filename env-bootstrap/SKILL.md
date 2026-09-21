---
name: env-bootstrap
description: One-shot Windows new-machine bootstrap for windows-env-rescue — runs foundation, terminal, devtools, then doctor. Use when the user wants 新机装机 / bootstrap / 一条龙. FAIL stops later install layers; PARTIAL continues.
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
3. `install-devtools.ps1`（L2）
4. `doctor.ps1`（汇总验收）

完成线：L0–L2 无 RED（git 身份等可为 YELLOW）。

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\bootstrap.ps1
```

状态词：`BOOTSTRAP: OK` / `PARTIAL` / `FAIL`。退出码：0 / 2 / 1。

## Agent 流程

1. 说明范围：scoop/pwsh7 → 终端工具 + profile → git/nvm/uv/pnpm → doctor。
2. 直接跑 bootstrap 脚本。
3. 若 bootstrap 未收集 git 身份，跑完后可单独 `/env-devtools` 补引导。
4. 失败时：
   - network → 代理后重跑。
   - 任一层 FAIL → 修好该层后重跑 bootstrap 或单跑对应 `/env-*`。
4. 成功后提示：新窗口生效；可选 `/yazi-install` 装文件管理器。
5. 单层重跑仍然合法：`/env-foundation`、`/env-terminal`、`/env-doctor`。

## 退出语义（引擎）

| 情况 | bootstrap 状态 |
| --- | --- |
| 两层 OK 且 doctor 非 RED | OK |
| 出现 PARTIAL（无 FAIL） | PARTIAL |
| 任一层 FAIL 或 doctor RED | FAIL |
