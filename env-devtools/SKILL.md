---
name: env-devtools
description: Install Windows L2 devtools for windows-env-rescue — git (required), nvm-windows + Node LTS, uv + Python, pnpm via corepack, optional make/cmake. Use when the user wants 开发环境 / node / python / uv / nvm / pnpm after foundation is ready. Guides git user.name/email when missing. Engine: _shared/scripts/install-devtools.ps1.
license: MIT
compatibility: Windows 10/11. Requires scoop (run /env-foundation first). Prefers PowerShell 7+.
metadata:
  author: karenepitaya
  suite: windows-env-rescue
  layer: L2
---

# env-devtools（开发底座）

L2：在 scoop/pwsh 就绪后安装 **Python + Web（Node）** 开发底座。

钦定路径：

- **git**（required）
- **nvm-windows**（scoop `nvm`）→ `nvm install lts` + `nvm use lts`（**不用** fnm / scoop nodejs）
- **uv** + `uv python install`（默认 3.12）
- **pnpm**（corepack）
- **make / cmake**（optional）

## Language

交互默认简体中文。

## 裸跑

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-devtools.ps1
# 已知 git 身份时：
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-devtools.ps1 -GitName "Your Name" -GitEmail "you@example.com"
# 跳过 make/cmake 等 optional（避免 scoop 整桶刷新长时间卡住）：
pwsh -NoProfile -ExecutionPolicy Bypass -File _shared\scripts\install-devtools.ps1 -SkipOptional
```

状态词：`INSTALL-DEVTOOLS: OK` / `PARTIAL` / `FAIL: <reason>`。

## Agent 流程

1. 确认 scoop 在 PATH（否则 `/env-foundation`）。
2. 检测 git 身份：
   ```powershell
   git config --global user.name
   git config --global user.email
   ```
3. 若身份缺失，用选择题收集 name 与 email，再带参数跑脚本。
4. 运行 `install-devtools.ps1`。
5. 结果解读：
   - **OK** → 提示**新开终端**（nvm/node 环境变量）；`node -v` / `uv --version` 应可用。
   - **PARTIAL** → 常见：git 身份未配、pnpm/corepack 网络失败、make/cmake 缺失、uv python 失败。可补参重跑。
   - **FAIL** → scoop 缺失 / 网络 / nvm·node 未进 PATH。网络代理：`scoop config proxy 127.0.0.1:7890`。
6. 不要在这层装 GUI 应用或 AI CLI（二期另层）。

## Manifest

`_shared/manifests/devtools.toml`。Node 版本通道与 uv Python 版本以 `[post]` 为准。

## 与 bootstrap

`/env-bootstrap` 顺序：foundation → terminal → **devtools** → doctor。任一安装层 FAIL 会跳过更高层安装并跑 doctor。
