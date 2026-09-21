---
feature: env-phase2-devtools
status: delivered
updated: 2026-09-12
branch: feat/env-phase2
commits: b035b27..b762670
---

# Env Phase 2 — L2 Devtools

## Report

**What was built** — L2 `env-devtools`：`devtools.toml`（git/nvm/uv required，make/cmake optional）+ `install-devtools.ps1`（引导式 git 身份、nvm LTS、uv Python 3.12、corepack pnpm、`-SkipOptional`）+ doctor L2 行 + bootstrap 扩展为 foundation→terminal→devtools→doctor（任一层 FAIL 跳过更高安装层）。

**Verification** — 本机：脚本 parse 0 错误；`install-devtools -SkipOptional` → `INSTALL-DEVTOOLS: PARTIAL` exit 2（optional 跳过，git 身份/node/pnpm/uv 就绪）；doctor L0/L1 GREEN、L2 YELLOW（make/cmake）、L6 GREEN，exit 0。未跑完整 scoop 装 make（桶更新超时，环境因素）。

**Journey log**

1. `scoop install make` 会触发整桶刷新并可能超时 → `-SkipOptional` + PARTIAL 是诚实路径。
2. Review C1/C2：git 身份写入必须 re-read 验证；final verify 必须跑命令而非仅 `Get-Command`。
3. PATH 用 Machine+User 全量重建会丢掉本进程注入的 scoop shims，刷新后要重新拼接。

## [S1] Problem

一期把新机装到「终端就绪」（L0+L1），仍无法进行日常 Python / Web 开发：没有 git 身份、Node 版本管理、Python 工具链或 pnpm。需要 L2 `env-devtools`：在 foundation 之上装好开发底座，并接入 doctor / bootstrap。

## [S2] Design

### 决策

| 轴 | 决定 |
| --- | --- |
| 层 | L2 `env-devtools`（本 feature 只做这一层） |
| Node | **nvm-windows**（scoop `nvm`），**不用** fnm；**不** scoop 装 nodejs 以免与 nvm 双源 |
| Node 版本 | `nvm install lts` + `nvm use lts` |
| Python | scoop **`uv`**，运行时用 `uv python install`（钦定默认 3.12，可覆盖） |
| 包管理 | Node：`corepack enable` + 准备 **pnpm**；不用全局 yarn |
| 构建 | scoop **make**、**cmake**（optional） |
| git | manifest **required**（覆盖 foundation 里 optional） |
| git 身份 | **引导式**：缺 name/email 时 skill 询问并传入脚本；裸跑未传参 → 输出指引 + `PARTIAL` |
| 状态 | 仍纯探测；状态词 `INSTALL-DEVTOOLS: OK/PARTIAL/FAIL` |
| 编排 | `bootstrap.ps1` 顺序扩展为 **foundation → terminal → devtools → doctor** |

### Manifest

`_shared/manifests/devtools.toml`：

- required：`git`、`nvm`、`uv`
- optional：`make`、`cmake`
- `[post]`：`nvm_channel = "lts"`、`uv_python = "3.12"`、`pnpm = true`、`corepack = true`

Node/pnpm 不作为 scoop `[[tool]]` 条目；由脚本 post 步骤处理（依赖 nvm 成功）。

### 脚本 `install-devtools.ps1`

1. 要求 scoop 已存在（否则 FAIL，指向 `/env-foundation`）。
2. 网络：需下载时复用四端点探测；失败 FAIL + 代理指引。
3. 按 manifest 装缺失包；required 失败 → 不进入会半残的 post 配置中「假装成功」；optional 失败 → PARTIAL。
4. **刷新 nvm 环境**：读取用户级 `NVM_HOME` / `NVM_SYMLINK` 并注入当前进程 PATH（scoop 装完 nvm 后本会话常看不见 `nvm`）。
5. 若 `nvm` 仍不可执行 → FAIL（常见原因：未刷新环境 / scoop nvm 安装失败）。
6. Post：
   - `nvm list` 无 LTS/已装版本 → `nvm install lts`；`nvm use lts`。
   - PATH 优先 `NVM_SYMLINK`（node 应通过符号链接可达）。
   - `corepack enable`；若 `pnpm` 仍无 → `corepack prepare pnpm@latest --activate`（失败则 PARTIAL）。
   - `uv python install <uv_python>`（已存在则跳过；失败 PARTIAL，不阻塞 node）。
7. Git 身份：
   - `git config --global user.name` / `user.email` 任一为空：
     - 若 `-GitName`/`-GitEmail` 均提供 → 写入并验证。
     - 否则打印需要配置的字段与示例命令，层状态至少 PARTIAL。
8. 最终 verify：`git --version`、`nvm version`、`node --version`、`uv --version`；required 不过 → FAIL。

参数：

```powershell
-GitName <string> -GitEmail <string>   # 可选
-UvPython <string>                     # 默认取 manifest
-SkipPnpm                              # 可选跳过 pnpm
-SkipOptional                          # 跳过 make/cmake 等 optional（避免 scoop 桶刷新卡住）
```

### Skill `env-devtors` → `env-devtools/SKILL.md`

1. 先确认 L0（doctor 或 scoop/pwsh）。
2. 检测 git 身份；缺失则 `AskUserQuestion` 收集 name/email。
3. 调用脚本，带或不带 `-GitName/-GitEmail`。
4. 提示 **新窗口** 才能稳定看到 nvm/node（环境变量）。
5. 失败解读：nvm 未找到 → 刷新环境/重跑 foundation 网络；corepack/pnpm 网络失败 → PARTIAL 可后补。

### doctor / bootstrap 扩展

- `doctor.ps1` 增加 **L2 devtools** 行：required（git/nvm/uv）+ 隐含探测 `node`（nvm 通道）与 git 身份；身份缺失标 YELLOW（工具可用时）或计入 RED 仅当 git/nvm/uv 缺失。
- `bootstrap.ps1`：在 terminal 之后、doctor 之前调用 `install-devtools.ps1`；terminal FAIL 仍可尝试 devtools（与 foundation FAIL 跳过安装的策略对齐：仅 foundation FAIL 跳过后续安装层；terminal FAIL **仍装 devtools**——开发底座不依赖 starship）。若需更严，实现时以「任一层 FAIL 则跳过更上层安装」为准：**foundation FAIL → 跳过 terminal+devtools；terminal FAIL → 跳过 devtools**（更安全，避免脏环境半套件）。

采用更严策略：**任一安装层 FAIL → 不跑更高层安装，只跑 doctor 汇总**。

### 文档 / 校验

- README skill 表增加 `/env-devtools`。
- `validate-release.ps1` required 增加 env-devtools skill、devtools.toml、install-devtools.ps1。
- DESIGN.md：L2 从「二期」改为已实现摘要。

## [S3] Out of Scope

- env-ai-coding / env-apps / env-dotfiles
- yarn、fnm、scoop 直接装 nodejs 作为主路径
- 非 LTS Node 定制矩阵
- VS Code 扩展、Docker、WSL
- git 身份的跨机同步/读密钥

## Tasks

- [x] T1: `devtools.toml` + `env-devtools/SKILL.md` — acceptance: manifest 字段符合 [S2]；skill 含裸跑命令与 git 身份引导 (covers: S2)
- [x] T2: `install-devtools.ps1` — acceptance: 可解析执行；已就绪机器幂等；缺 git 身份且未传参时 PARTIAL + 指引；nvm PATH 刷新逻辑存在 (covers: S2; depends: T1)
- [x] T3: doctor L2 + bootstrap 串联 — acceptance: doctor 含 L2 行；bootstrap 顺序 foundation→terminal→devtools→doctor，FAIL 跳过更高安装层 (covers: S2; depends: T2)
- [x] T4: validate-release + README + DESIGN — acceptance: 校验含新文件；文档描述 L2 (covers: S2; depends: T1)
- [x] T5: 端到端验证 — acceptance: 本机 doctor L2 状态正确；install-devtools 幂等或如实 PARTIAL/FAIL；结果写入 Report (covers: S2; depends: T3)
