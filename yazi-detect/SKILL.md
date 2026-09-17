---
name: yazi-detect
description: Read-only diagnosis of a yazi file manager installation on Windows. Use when the user wants to CHECK what is wrong with yazi without changing anything - e.g. "帮我看看 yazi 哪里有问题", "检测一下我的 yazi", "yazi diagnosis", "why is yazi broken", or before deciding whether to reinstall. Reports install method, config state, preview wiring (YAZI_FILE_ONE), Nerd Font status, PowerShell version, and real HTTPS network reachability to the GitHub endpoints scoop needs. Changes and deletes NOTHING. To actually fix problems, the user should then run /yazi-install; to configure a working install, /yazi-config.
license: MIT
compatibility: Windows 10/11. Runs on any PowerShell (5.1 or 7+).
metadata:
  author: karenepitaya
  suite: windows-env-rescue
---

# Yazi Detect（只读诊断）

Standalone read-only diagnosis. This is the first half of /yazi-install, exposed on its own so anyone can ask "看看哪儿坏了" without committing to a fix.

## Language

**Conduct the entire interaction in Simplified Chinese (简体中文) by default.** Explanations plain and jargon-glossed. Commands, paths, and package names stay verbatim. Only switch language if the user clearly writes in another language first and keeps doing so.

## Rules

1. **This entry is READ-ONLY.** Never install, uninstall, delete, or modify anything here — not even if the user asks mid-diagnosis. If they want a fix, point them to `/yazi-install`（安装/修复）or `/yazi-config`（配置/美化）.
2. **PowerShell, not bash.** If a command fails, suspect bash syntax first: see `../_shared/references/powershell-vs-bash.md`.
3. Garbled text (`锘`, `鈻`, `□`) in script output is a display-encoding issue, not a failure — the scripts re-apply UTF-8 themselves. Boxes *inside yazi's UI* are a Nerd Font issue, which the report covers separately.
4. **Incomplete report ⇒ incomplete conclusions.** The script is fault-isolated; a section that prints `[CHECK FAILED]` is UNCHECKED, not OK. Mark those items 「未检测」 in the summary and never substitute guesses for them（e.g. 不要说"字体应该没事"——要么检测到了，要么如实标未检测）. If the failed section matters to the user's question, suggest re-running in pwsh 7 for a complete report.

## Procedure

1. Tell the user (one sentence): "这一步只查看你的系统，什么都不会改、不会删。" Then run the diagnosis:

```powershell
powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}\..\_shared\scripts\diagnose.ps1"
```

**Execution mode:** if you have shell access (Claude Code), run it yourself directly — do not ask the user to copy-paste-run-paste-back; that ceremony is only the fallback for environments where you cannot execute commands. Read-only diagnosis needs no permission ritual beyond the one-sentence notice above.

2. Interpret the report with `../_shared/references/troubleshooting.md` ("Reading the diagnosis report" section) and summarize in plain Chinese, covering: yazi 是否安装、装在哪、怎么装的（scoop/winget/cargo/手动）；配置是否有 TOML 错误；预览（YAZI_FILE_ONE）是否接好；Nerd Font 是否安装并被终端选用；PowerShell 版本；网络（四个 GitHub 端点）是否可达。

3. End with a clear recommendation, one of:
   - 一切正常 → 「不需要修。想美化和增强的话可以跑 `/yazi-config`。」
   - 有问题 → 列出问题，然后「跑 `/yazi-install` 可以把这些一次性修好。」
   - 报告有 `[CHECK FAILED]` 的节 → 在总结里把对应项标「未检测」，并建议在 pwsh 7 里重跑取得完整报告；只对已检测项下结论。
   - 只有网络问题 → 先给代理指引（`scoop config proxy 127.0.0.1:7890`，换成用户自己的端口），网络通了再装。

Do not start fixing anything in this entry, even if invited — hand off to the right slash command instead.
