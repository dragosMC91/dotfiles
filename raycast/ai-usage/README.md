# AI usage in Raycast

Two Raycast Script Commands that show live Claude Code and Codex usage as subtitles at the
top of Raycast's root search (when favorited):

```
Claude   $33.41 · 5h ❚❚❚❚❚ 9% ↻2h25 · 7d ❚❚❚❚❚ 25% ↻2d23h · Fable ❚❚❚❚❚ 68%
Codex   ≥$1.92 · 5h ❚❚❚❚❚ 29% ↻10m · 7d ❚❚❚❚❚ 48% ↻1d19h
```

Each bar is coloured: the filled part green, yellow from 70% and red from 90%, the rest grey.

`$` = today's estimated API-equivalent cost (`≥` = some model used today has no price data, so the
total is a lower bound) · `5h` / `7d` = % of the rate-limit window used · `↻` = time until it resets ·
`Fable` = % used of the weekly limit for that model family (Claude only; one entry per per-model
weekly limit the account has, with its own `↻` only if it resets at a different time than `7d`).

## Requirements

- macOS on Apple Silicon, Raycast.
- `jq`, which ships with macOS 15+ at `/usr/bin/jq`.
- [`ccusage`](https://github.com/ccusage/ccusage) v20+, for the cost figure only. Either install it
  globally under nvm (`npm i -g ccusage`) or with `brew install ccusage`. Without it, the
  limits still work and the cost is simply omitted. For an npm install the scripts skip the
  Node wrapper and call the native binary shipped inside the package
  (`node_modules/@ccusage/ccusage-darwin-arm64/bin/ccusage`), so Node isn't needed at runtime.
- Claude Code logged in (`claude` → `/login`). Codex CLI used at least once in the last 8 days.

## Install

1. Raycast → Settings → Extensions → **+** → **Add Script Directory** → choose this folder.
2. Search **Claude** and **Codex** in Raycast → ⌘K → **Add to Favorites**.

Uninstall: remove the script directory in Raycast, then `rm -rf ~/Library/Caches/ai-usage`.

### Tinycast

Tinycast imports Raycast *extensions*, not Script Commands with live subtitles, so `tinycast/` is a
tiny extension wrapping the same two scripts: `package.json`, `claude.js`, `codex.js` (plain CommonJS,
no build step) and `assets/` (icons). Each is a `no-view` command with `interval: 5m` that runs the
matching `.sh` and sets its subtitle via `updateCommandMetadata`.

1. Tinycast → Extensions → **Add from folder** → choose `tinycast/`.
2. Favorite **Claude** and **Codex**. Enter on a row = manual refresh, same as in Raycast.

Tinycast *copies* the folder on import, so the `.js` files locate the scripts through the extension
preference **Scripts folder** (default `~/Documents/dotfiles/raycast/ai-usage`). Script changes apply
immediately; changes to `tinycast/` itself need a re-import. Use one launcher at a time: both share
the cache, and two schedulers would make the manual-refresh heuristic fire more often.

## What they do (every 5 minutes, in the background)

| | Claude (`claude-usage.sh`) | Codex (`codex-usage.sh`) |
|---|---|---|
| Change check | `find -newer` over `~/.claude/projects/**/*.jsonl` (~30 ms) | same over `~/.codex/sessions` |
| Cost | only if logs changed / new day: `ccusage claude daily --since today` | only if logs changed / new day: `ccusage codex daily --since today` |
| Limits | Anthropic `api/oauth/usage`, only if logs changed or last fetch > 15 min | newest `rate_limits` event Codex wrote to its local logs (no network) |
| Credentials | Claude Code Keychain token, **read-only**; never refreshed or written; passed to curl via stdin | none |
| Network | `api.anthropic.com` + LiteLLM price list (via ccusage, only on change) | LiteLLM price list (via ccusage, only on change) |

**Manual refresh:** press **Enter** on a row. Raycast re-runs the script; a run that comes 30 s – 4 min
after the previous one is treated as manual and skips all throttles (recomputes cost, rescans logs,
fetches Claude limits even during error back-off). Presses within 30 s of each other use the cheap path.

Cache: `~/Library/Caches/ai-usage` (dir `0700`, files `0600`), derived numbers only, never tokens.
One run at a time per script (lock dir); an overlapping run just repeats the last output.

Measured on an M5 Pro: ~0.02–0.06 s CPU / 2 MB when nothing changed; ~0.2 s / 50–70 MB when it
recomputes; the very first Codex run scans 8 days of logs (~0.8 s, once).

## What the row can say

| Output | Meaning |
|---|---|
| `5h reset` / `Fable reset` | the window's reset time has passed; real numbers return on the next fetch / Codex turn |
| `$12.30 (stale)` | today's cost couldn't be recomputed (ccusage failed); retried every refresh |
| `· stale 25m` | Claude limits are older than 20 min (fetch failing or backing off) |
| `· ⚠ HTTP 401` / `⚠ login expired…` / `⚠ not logged in` | last Claude fetch failed; retried after 15 min |
| `· as of 2d ago` | newest Codex limit event is older than a day (Codex not used since) |
| `needs jq` / `unsafe cache dir` | missing dependency / cache path is a symlink or not yours |

## Settings

At the top of each script: `FETCH_EVERY`, `RETRY_AFTER_FAIL` (Claude), `FIRST_SCAN_DAYS` (Codex), and
the display settings `BAR_CELLS` (bar width, `0` = no bars), `WARN_AT` / `CRIT_AT` (yellow / red
thresholds) and `COLOR` (`0` = no ANSI colours; bars then use `▮▯`). The row has room for about
5 cells per bar before Raycast truncates it.
The Claude limits endpoint (`USAGE_URL`, `BETA_HEADER`, `USER_AGENT`) is undocumented and may
change; if the row shows `⚠ HTTP 4xx` after a Claude Code update, check those values.

Environment overrides: `AI_USAGE_CCUSAGE` (path to ccusage; otherwise found via PATH, the newest
nvm Node, or volta), `AI_USAGE_CACHE` (cache dir), `AI_USAGE_NO_FETCH=1` (never call the API;
for testing), `AI_USAGE_COLOR=0` (plain-text bars; the Tinycast wrappers set this because a
subtitle set through the extension API shows escape codes literally).

## Icons

`images/*-logo.png` were extracted from the locally installed Claude and ChatGPT apps.
Raycast caches icons by path, so if you replace an icon, give it a new filename and update the
`@raycast.icon` line.
