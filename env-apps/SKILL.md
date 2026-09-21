---
name: env-apps
description: Install only necessary Windows GUI apps for windows-env-rescue via Scoop extras — currently VS Code and cc-switch. Detect-first. Other software (browsers, ChatGPT, chat apps) is intentionally left to the user. Use when the user wants the curated necessary GUI set, not a full app catalog.
license: MIT
compatibility: Windows 10/11. Requires scoop + extras bucket.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L4
---

# env-apps（必要应用）

**原则**：本套件核心是**环境配置**。GUI 软件默认由用户自装；L4 **只装必要项**。

| 包 | 说明 |
| --- | --- |
| `vscode` | 编辑器（`code`） |
| `cc-switch` | AI CLI 供应商切换 |

**明确不装**：ChatGPT、浏览器、通讯软件等——需要时用户自行 `scoop install` / 官网 / 商店。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-apps.ps1
# -SkipVscode / -SkipCcSwitch
```

状态词：`INSTALL-APPS: OK` / `PARTIAL` / `FAIL: <reason>`。

## Agent 流程

1. 说明「只装必要 GUI」原则。
2. 运行脚本；已装跳过。
3. 用户要装其他应用 → 指导其自行安装，**不要**扩 manifest 除非用户明确要求改钦定清单。

## Manifest

`_shared/manifests/apps.toml`（默认仅两项；加包等于改产品钦定清单）。
