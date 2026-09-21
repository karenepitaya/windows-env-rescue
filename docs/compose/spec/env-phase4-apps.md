---
feature: env-phase4-apps
status: delivered
updated: 2026-09-12
branch: feat/env-phase4
commits: d1bac3d..4c31d15
---

# Env Phase 4 — L4 Apps

## Report

**What was built** — L4 `env-apps`：`apps.toml`（vscode / cc-switch / chatgpt，scoop extras）+ `install-apps.ps1`（探测优先、确保 extras、GUI verify 有限时如实输出）+ doctor L4 + bootstrap 扩到 apps。

**Verification** — parse 0 错误；本机：`code` 已在 PATH（OK）；`cc-switch` scoop/bin 存在 → `OK (verify limited)`；`chatgpt` 清单存在但 **~786MB** 下载超时未完成 → doctor **L4 RED missing: chatgpt**（诚实，非谎报）。scoop 桶更新会拉长首次安装。

**Journey log**

1. 三件套均在 scoop extras：`vscode`、`cc-switch`、`chatgpt`。
2. ChatGPT scoop 可能是大体积 MSIX/在线安装器；严格「非商店」需用户确认开始菜单产物。
3. GUI 无 `--version` 时用 scoop list/bin 存在性，状态可为 OK + verify limited 或 PARTIAL。

## [S1] Problem

L0–L3 装好终端/开发/AI CLI 后，新机仍缺日常 GUI。用户钦定 L4 清单：**VS Code**、**cc-switch**、**ChatGPT（非微软商店路径）**；安装策略 **scoop 优先**，已装跳过。

## [S2] Design

### 决策

| 轴 | 决定 |
| --- | --- |
| 层 | L4 `env-apps` |
| 清单 | `vscode`、`cc-switch`、`chatgpt`（均为 scoop **extras**） |
| 策略 | 探测 → 缺则 `scoop install`；确保 `extras` bucket |
| 商店 | ChatGPT 若 scoop 清单仍是 Store 转发安装器 → **如实 PARTIAL/警告**，不谎报「已脱离商店」 |
| 认证/账号 | 脚本不登录 |

### Manifest

`_shared/manifests/apps.toml`：

```toml
schema = 1
name = "apps"

[[tool]]
id = "vscode"
scoop = "vscode"
bucket = "extras"
binary = "code"
required = true
verify = "code --version"

[[tool]]
id = "cc-switch"
scoop = "cc-switch"
bucket = "extras"
binary = "cc-switch"
required = true
verify = "cc-switch --version"  # 若无 --version，引擎允许 Get-Command 兜底并 PARTIAL 注明

[[tool]]
id = "chatgpt"
scoop = "chatgpt"
bucket = "extras"
binary = "ChatGPT"
required = true
verify = ""  # GUI：以 scoop list / 安装目录存在为准
```

### 脚本 `install-apps.ps1`

1. 要求 scoop；缺 extras → `scoop bucket add extras`。
2. 已装且 verify 通过 → skip。
3. 安装失败 → required FAIL；GUI verify 不可用时：scoop 显示已安装则 **OK 但注明 “verify limited”**，否则 FAIL。
4. 对 chatgpt：安装后提示「部分 extras 清单可能仍调用商店/在线安装器，以实际 Start Menu 是否出现为准」。
5. 状态词 `INSTALL-APPS: OK/PARTIAL/FAIL`。

### Skill `env-apps`

- 裸跑命令；说明清单与 scoop 优先；不代登录。
- doctor L4：required 三件缺失 → RED；scoop 已装但 binary 名不确定 → YELLOW 并写 detail。

### bootstrap

顺序：… → ai-coding → **apps** → doctor。

## [S3] Out of Scope

- 浏览器、通讯软件、PowerToys 等未钦定应用
- winget 主路径
- 扩展同步 / VS Code 设置迁移（属 L5）

## Tasks

- [x] T1: apps.toml + env-apps/SKILL.md — acceptance: 清单三件与 scoop extras 契约正确 (covers: S2)
- [x] T2: install-apps.ps1 — acceptance: 幂等；extras 确保；状态词；chatgpt 商店风险如实输出 (covers: S2; depends: T1)
- [x] T3: doctor L4 + bootstrap — acceptance: 含 L4 行；bootstrap 顺序含 apps (covers: S2; depends: T2)
- [x] T4: validate/README/DESIGN — acceptance: 文档与校验覆盖 L4 (covers: S2; depends: T1)
- [x] T5: 端到端 — acceptance: 本机探测/安装结果写入 Report (covers: S2; depends: T3)
