---
name: env-dotfiles
description: Export or import local Windows dotfiles for windows-env-rescue — PowerShell profile, gitconfig, Windows Terminal, VS Code user settings, yazi config, plus scoop export inventory. Package lives under the user profile by default. Does not reinstall apps or sync secrets to the cloud. Use for 换机/重置后恢复配置.
license: MIT
compatibility: Windows 10/11. PowerShell 5.1+.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L5
---

# env-dotfiles（本机配置包）

**原则**：套件核心是环境（L0–L4）；L5 负责**可搬运的本机配置**。  
默认包目录：`%USERPROFILE%\windows-env-rescue-dotfiles\<timestamp>\`

## 导出内容

| id | 内容 |
| --- | --- |
| profile | `$PROFILE` |
| gitconfig | `~/.gitconfig` |
| wt | Windows Terminal `settings.json` |
| vscode-settings / vscode-keybindings | VS Code 用户配置 |
| yazi | `%APPDATA%\yazi\config\` |
| scoop-export | `scoop export` 清单 |
| inventory.md / manifest.json | 命中清单与哈希 |

**默认不拷贝**：`.claude/`、`.pi/`、token 等敏感树（只写入 inventory 观察项）。

## 裸跑

```powershell
# 导出
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\export-dotfiles.ps1
# 导入（-Force 覆盖前仍会备份；-Ids 可过滤）
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\import-dotfiles.ps1 -FromDir "$env:USERPROFILE\windows-env-rescue-dotfiles\<ts>"
```

状态词：`EXPORT-DOTFILES:` / `IMPORT-DOTFILES:` + OK/PARTIAL/FAIL。

## Agent 流程

1. **换机/重置**：先 `/env-bootstrap`（或分层装环境）→ 再 `/env-dotfiles` 导入。
2. **备份**：先 export 再动系统。
3. import **不**代替 scoop 重装；应用清单在包内 `scoop-export.json` 参考。
4. 敏感信息：提醒用户自行检查包内容再外传。

## 与 bootstrap

bootstrap **不**自动 export/import，避免在错误机器上覆盖配置。
