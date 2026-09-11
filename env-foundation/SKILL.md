---
name: env-foundation
description: Install or repair the Windows foundation layer for windows-env-rescue — Scoop, PowerShell 7, execution policy, UTF-8, and a GitHub network gate. Use when the user needs a new machine bootstrap base, scoop/pwsh missing, or says 装 scoop / 装 PowerShell 7 / foundation 层. Engine script is runnable without Claude. For full bootstrap use /env-bootstrap; for health check use /env-doctor.
license: MIT
compatibility: Windows 10/11. Engine may start on PowerShell 5.1 to install pwsh; target is 7+.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L0
---

# env-foundation（地基层）

L0：scoop、pwsh7、执行策略、UTF-8、网络闸门。默认**静默执行引擎脚本**，只在失败时解读。

## Language

交互默认简体中文。命令/路径/包名保持原文。

## 裸跑（无 Claude）

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-foundation.ps1
```

结束后必有一行 `INSTALL-FOUNDATION: OK` / `PARTIAL` / `FAIL: <reason>`。退出码：0/2/1。

## Agent 流程

1. 一句话说明：这一步装地基（scoop + PowerShell 7），已满足的项会跳过。
2. 直接运行上面的脚本（有 shell 时不要让用户复制粘贴）。
3. 读最后一行状态词：
   - **OK** → 报告成功，可建议 `/env-terminal` 或 `/env-bootstrap`。
   - **PARTIAL** → 如实列出警告（常见：可选包 git 未装上），不阻塞后续。
   - **FAIL: network…** → 给代理指引：`scoop config proxy 127.0.0.1:7890`（换成用户端口），网络通后重跑本 skill。
   - **FAIL: scoop…** → 说明官方安装未完成，检查执行策略/网络后重跑。
4. 不要在本 skill 写终端美化配置（那是 `/env-terminal`）。

## Manifest

钦定清单：`_shared/manifests/foundation.toml`。改包前先改 manifest，不要在对话里临时 `scoop install` 作为“标准环境”的一部分。

## 安全

- 只动用户级 scoop / CurrentUser 执行策略，不请求管理员。
- 无删除/卸载路径。
