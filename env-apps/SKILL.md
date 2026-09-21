---
name: env-apps
description: Install curated Windows GUI apps for windows-env-rescue via Scoop extras — VS Code, cc-switch, ChatGPT (non-Store path when the manifest allows). Detect-first, skip if present. Use when the user wants 装应用 / VS Code / cc-switch / ChatGPT desktop via scoop. Does not sign in to apps.
license: MIT
compatibility: Windows 10/11. Requires scoop + extras bucket.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L4
---

# env-apps（应用层）

L4 钦定清单（scoop **extras**）：

| 包 | 二进制/说明 |
| --- | --- |
| `vscode` | `code` |
| `cc-switch` | AI CLI 供应商切换 |
| `chatgpt` | GUI；**下载可达数百 MB**，可能超时；部分清单可能仍调用商店/在线安装 |

已装则跳过；不代登录。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-apps.ps1
# 可选：-SkipVscode / -SkipCcSwitch / -SkipChatgpt
```

状态词：`INSTALL-APPS: OK` / `PARTIAL` / `FAIL: <reason>`。

## Agent 流程

1. 说明 scoop 优先与三件清单。
2. 运行脚本；PARTIAL 常见原因：chatgpt verify 受限 / 商店转发提示。
3. 提示用户检查开始菜单；需要严格非商店时，可改用 winget/官网并告知本 skill 默认走 scoop。
4. 不在本层装浏览器/通讯软件（未钦定）。

## Manifest

`_shared/manifests/apps.toml`
