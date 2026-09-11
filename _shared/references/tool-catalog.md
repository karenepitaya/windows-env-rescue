# Tool catalog

All packages install via Scoop. Binary name is what you actually type and what
`Get-Command` should be checked against. "Bucket" tells you which Scoop bucket
holds the manifest; everything here is in `main` unless noted. If `scoop install X`
ever fails with "couldn't find manifest", run `scoop search X` to find the bucket,
then `scoop bucket add <bucket>` (confirm with the user first) and retry.

## Core set (install these unless the user opts out)

| Tool     | scoop pkg  | binary | replaces / does            | bound to |
|----------|------------|--------|----------------------------|----------|
| eza      | `eza`      | `eza`  | modern `ls`, icons, git    | `ls ll la lt` |
| bat      | `bat`      | `bat`  | `cat` with syntax highlight| `cat` |
| fd       | `fd`       | `fd`   | fast, friendly `find`      | own name (`fd`) |
| ripgrep  | `ripgrep`  | `rg`   | fast `grep`                | own name (`rg`) |
| fzf      | `fzf`      | `fzf`  | fuzzy finder               | Ctrl+R, Ctrl+T |
| zoxide   | `zoxide`   | `zoxide`| smarter `cd`              | `cd`, `z`, `zi` |

## Optional set (offer; install only if the user wants them)

| Tool     | scoop pkg  | binary | does                       | bound to |
|----------|------------|--------|----------------------------|----------|
| lsd      | `lsd`      | `lsd`  | alt to eza (used only if eza absent) | `ls ll la lt` |
| git-delta| `delta`    | `delta`| pretty git diffs           | git config |
| dust     | `dust`     | `dust` | visual `du`                | own name |
| duf      | `duf`      | `duf`  | friendlier `df`            | own name |
| procs    | `procs`    | `procs`| modern `ps`                | own name |
| bottom   | `bottom`   | `btm`  | `top`/`htop` replacement   | own name (`btm`) |
| jq       | `jq`       | `jq`   | JSON processor             | own name |
| yq       | `yq`       | `yq`   | YAML/JSON processor        | own name |
| starship | `starship` | `starship` | cross-shell prompt     | auto-init if present |

## Design rationale — read before changing the alias map

- **Why only `ls`/`cat` are shadowed.** `fd`, `rg`, `dust`, `duf`, `procs`, `btm`
  take *different flags* from the `find`/`grep`/`du`/`df`/`ps`/`top` they replace.
  Aliasing the old name onto them silently breaks muscle memory and any script that
  passes classic flags. Worse, in PowerShell `ls`, `cat`, `ps` are built-in aliases
  for cmdlets — `ps` → `Get-Process` especially. So we keep the new tools under
  their own names and only override `ls` and `cat`, where the replacement is a clean
  drop-in. If the user explicitly wants more shadowing, do it, but warn them.

- **Why a single marked block.** Everything lives between
  `# >>> windows-env-rescue >>>` and `# <<< windows-env-rescue <<<` in `$PROFILE`. Re-running
  the skill replaces that region in place (idempotent); uninstalling is "delete the
  block". Never scatter edits across the profile.

- **Why runtime guards.** Each feature in the block is wrapped in
  `if (Get-Command X)`, so the same block is safe on a machine missing some tools and
  degrades gracefully if a tool is later uninstalled.

- **fzf key bindings are native, no extra module.** The Ctrl+R / Ctrl+T handlers use
  PSReadLine's own API calling the `fzf` binary directly. This keeps "everything via
  Scoop" true — no `Install-Module PSFzf` from the PowerShell Gallery required.

- **Nerd Font assumed.** eza/lsd icons need a Nerd Font in the terminal. The suite
  installs Maple Mono NF CN, so `--icons` is safe. If icons render as boxes, the
  terminal font isn't a Nerd Font — note it in the guide rather than dropping `--icons`.

- **Why zoxide uses `--cmd cd`.** By default `zoxide init powershell` only creates
  `z`/`zi` aliases. That means plain `cd` bypasses zoxide entirely — directories
  visited via `cd` never get recorded, so the database stays empty and `z` can't
  find anything. Using `--cmd cd` makes `cd` go through zoxide (which calls
  `zoxide add` on every directory change). We then add `z`/`zi` as extra aliases
  pointing to the same functions, so all three work. A `zoxide add` for the
  startup directory runs once at profile load to cover the case where the shell
  opens in a directory the user never explicitly `cd`'d into.

- **Why starship MUST init before zoxide.** `starship init powershell` replaces
  `function prompt` entirely (not appending — replacing). `zoxide init powershell`
  works by wrapping the existing prompt with a hook that calls `zoxide add` on
  every directory change. If zoxide inits first, its hook-wrapped prompt gets
  replaced by starship and the hook is lost — directories are never recorded.
  Starship-first means zoxide wraps starship's prompt, and the execution chain is:
  `zoxide hook → starship prompt → original prompt`. This is the only correct order.

- **Windows Terminal keybindings (optional).** The skill can apply a curated set of
  vim-style pane-management keybindings to Windows Terminal's `settings.json`. This
  is a separate step from the profile block — it edits the WT config file directly.
  See `_shared/config/wt-keybindings.json` for the keybinding list.
