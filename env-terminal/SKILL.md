---
name: env-terminal
description: Install modern CLI tools and the managed PowerShell profile block for windows-env-rescue (starship, eza, bat, fzf, zoxide, …) via Scoop and the terminal manifest. Use when the user wants 终端增强 / modern CLI / profile block after foundation is ready, or to refresh the windows-env-rescue profile markers. Replaces the old terminal-boost skill. Engine runs without Claude.
license: MIT
compatibility: Windows 10/11. Requires scoop; prefers PowerShell 7+.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L1
---

# env-terminal（终端层）

L1：按 `_shared/manifests/terminal.toml` 安装缺失 CLI，并幂等写入 `$PROFILE` 标记块（`# >>> windows-env-rescue >>>` … `# <<< windows-env-rescue <<<`）。会自动迁移旧的 `terminal-boost` 标记块。

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-terminal-tools.ps1
```

状态词：`INSTALL-TERMINAL-TOOLS: OK` / `PARTIAL` / `FAIL: <reason>`。

## Agent 流程

1. 先确认 scoop 在 PATH（否则指向 `/env-foundation`）。
2. 运行脚本；已安装工具会跳过，只装缺失项。
3. 状态解读：
   - **OK** → 提示新窗口或 `. $PROFILE` 生效；图标需 Nerd Font（Maple Mono NF CN）。
   - **PARTIAL** → 可选包失败，列出名字；可修网络后重跑。
   - **FAIL** → 按 reason 处理（常见：scoop 缺失、必需包 starship 失败）。
4. 可选：Windows Terminal 字体仍建议 GUI 设为 Maple Mono NF CN（脚本不强制改 WT 配置以免损坏用户 settings）。

## Profile 规则

- 只允许替换标记块；块外内容永不改写。
- 写前自动备份 `$PROFILE.bak-<timestamp>`。
- 卸载 = 删除整段标记块。

## 与 yazi

块内含可选的 yazi `y` 跳转函数（检测到 yazi 才启用）。yazi 安装仍走 `/yazi-install`。

## Manifest

工具集合以 `terminal.toml` 为准（starship 为 required，其余 optional）。
