# Tooling & Prerequisites

Everything you need to install **before** running `./install.sh` or using the scripts in this repo.
Target: **macOS on Apple Silicon (arm64)**. Homebrew lives at `/opt/homebrew` on this arch — a few scripts assume that path.
`install.sh` also runs on **Linux**, where it offers only the cross-platform items — see [Linux](#linux).

## 1. Homebrew

The base package manager for everything below.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# add brew to your shell (Apple Silicon path)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 2. Shell environment (`shell/.zshrc`, `shell/.p10k.zsh`)

The `.zshrc` sources oh-my-zsh, powerlevel10k, and version managers. Install these or shell startup will error:

```sh
# oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# powerlevel10k (sourced from ~/powerlevel10k, not the omz custom dir)
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

# zsh-autosuggestions plugin
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# version managers referenced in .zshrc
brew install pyenv pyenv-virtualenv goenv nvm
mkdir -p ~/.nvm   # nvm needs its working dir

# JDK 11 (the .zshrc defaults to java11 on startup)
brew install openjdk@11
```

> The `.zshrc` also references the Android SDK and AWS profiles — optional, only needed if you use those. Remove those lines if not relevant.

### Managing Python — use `uv`

`uv` is the one tool for Python: it installs interpreters, creates venvs, and resolves/locks dependencies. Default to it for everything on a new machine.

```sh
brew install uv

uv python install 3.12   # install an interpreter
uv python list           # see what's installed
uv python pin 3.12       # pin the version for the current project
uv venv                  # create a .venv using the pinned/latest Python
uv sync                  # install locked deps into the venv
```

> **No global `python` after install?** That's expected — `uv python install` only downloads an interpreter into uv's own store; it does **not** put a `python`/`python3` on your `PATH` (a bare `python3` still resolves to macOS's system 3.9.x). Use it one of two ways:
> - **Per project (preferred):** `uv venv && source .venv/bin/activate` (or `uv run python …`) → `python` points at your pinned version.
> - **Global shim:** `uv python install 3.12 --default` installs `python`/`python3` into `~/.local/bin`.
>
> If uv warns that `~/.local/bin` isn't on your `PATH` (where the `--default` shims land), add it:
> ```sh
> export PATH="$HOME/.local/bin:$PATH"   # add to ~/.zshrc to persist
> ```
> This repo's `shell/.zshrc` already sets it. `install.sh` does not link `.zshrc`, so copy or source it yourself for the warning to go away.

## 3. Terminal — Ghostty (`terminal/ghostty/config`)

```sh
brew install --cask ghostty
```

The config uses the built-in **Dracula** theme; no extra theme install needed.

## 4. tmux (`tmux/.tmux.conf`, `tmux/scripts/*`)

```sh
brew install tmux lazygit
```

- `lazygit` — bound to `prefix + g` in `.tmux.conf`.
- `tmux/scripts/process_path.sh` (the copy-mode `o` binding) additionally needs:
  - **python3** — `brew install python3` (path normalization; falls back gracefully if missing).
  - An **editor CLI** — defaults to `cursor`; override with `EDITOR_CMD` (`code`, `subl`, …). See §5.
  - **Helium** browser — URLs are opened with `open -a "Helium"`. Install it, or edit the script to use your browser (e.g. `Safari`, `Google Chrome`).
  - **`E2E_PATH`** — export it to the maple frontend checkout (e.g. `export E2E_PATH="$HOME/Documents/maple/frontend"`) so `e2e-pw/...` paths in test output resolve from any pane. The repo's `shell/.zshrc` does not set it.
  - URLs, images, documents and media are opened with macOS `open`, so only code files open on Linux.

## 5. Editor CLI — Cursor / VS Code

Both `process_path.sh` and the Automator quick action shell out to `cursor -g`.

```sh
brew install --cask cursor      # or: brew install --cask visual-studio-code
```

Then install the shell command: in Cursor/VS Code run **Cmd+Shift+P → "Install 'cursor'/'code' command in PATH"**.
To use VS Code instead of Cursor, set `export EDITOR_CMD="code"`.

## 6. Node.js — for `scripts/sanitize_and_open.js`

The sanitize script runs under Node. Install via nvm (already installed in §2):

```sh
nvm install 20.10.0 && nvm use 20.10.0
```

> `scripts/sanitize_and_open.md` hardcodes a node path (`~/.nvm/versions/node/v20.10.0/bin/node`) in the Automator action. Run `which node` and update that path to match your installed version.

## 7. Screenshot-annotate workflow (`scripts/screenshot-annotate.sh`)

Uses only built-in macOS tooling (Preview, `osascript`), plus two apps to trigger it:

```sh
brew install --cask raycast
```

- **Shortcuts** (built-in) — create the "AnnotateScreenshot" shortcut per `scripts/screenshot-annotate.md`.
- **Raycast** — bind the shortcut to a hotkey.
- Grant **Accessibility** + **Screen Recording** permissions to the Shortcuts app (System Settings → Privacy & Security).

## 8. Screen recording (native, no script)

Unlike screenshots, there is no scriptable region-select video capture: `screencapture`
records only the full screen for video (`-i` is rejected with "video not valid with -i").
The built-in recorder is the right tool and already covers everything a script would.

- Trigger with **Cmd+Shift+5** (or rebind it in System Settings → Keyboard → Keyboard
  Shortcuts → Screenshots).
- Click **Record Selected Portion**, drag the region, **Record**, stop from the menu bar.
- In the toolbar's **Options** menu (set once): **Save to** → `~/Downloads/recordings`,
  enable **Show Mouse Clicks**, keep **Remember Last Selection**.
- The floating thumbnail after recording opens the clip for quick trim / share.

### Auto-reveal in Finder after saving

An Automator **Folder Action** on `~/Downloads/recordings` opens Finder to the new clip as
soon as it is saved. Folder Actions run inside the GUI login session, so `open` reliably
surfaces Finder — a launchd `WatchPaths` agent does **not** work here (it fires outside the
GUI session / on another Space, so the reveal never becomes visible; this was tried and
abandoned).

Set it up (all in Automator, no terminal):

1. Open **Automator** → **File → New** → **Folder Action** → Choose.
2. Top of the workflow: *"Folder Action receives files and folders added to"* → dropdown →
   **Other…** → select `~/Downloads/recordings`.
3. Search the actions list for **Run Shell Script**, drag it into the workflow.
4. Set **Shell:** `/bin/zsh`, **Pass input:** `as arguments`, and use this body:
   ```bash
   open -R "$1"      # reveal + select the new recording in Finder
   open -a Finder    # force Finder to the front, even from a fullscreen Space
   ```
5. **⌘S**, name it e.g. "Reveal Recording".

On first trigger macOS asks to allow controlling Finder — approve it. After that, every
recording saved into the folder pops Finder to the front with the clip selected.

> Folder Actions live in `~/Library/Workflows/Applications/Folder Actions/`, outside this
> repo, so this one is a manual setup step rather than something `install.sh` provisions.

## 9. tokenmaxx loop (`scripts/tokenmaxx-loop.sh`, `plist/*`)

Drives a Claude Code session inside tmux on a timer via `launchd`.

```sh
# Claude Code CLI
brew install --cask claude-code    # or: npm install -g @anthropic-ai/claude-code
```

Requires **tmux** (§4) and an authenticated `claude` login. Managed with `launchctl` — see `plist/tokenmaxx.md`.

## 10. Automator quick action (`scripts/sanitize_and_open.*`)

**Automator** is built into macOS — no install. Follow `scripts/sanitize_and_open.md` to create the Quick Action and assign a keyboard shortcut. Needs Node (§6) and an editor CLI (§5).

---

## Quick install (Homebrew bundle)

```sh
brew install tmux lazygit pyenv pyenv-virtualenv goenv nvm openjdk@11 python3
brew install --cask ghostty cursor raycast claude-code
# then oh-my-zsh, powerlevel10k, zsh plugins (see §2), and nvm node (see §6)
```

## Run the installer

Once the above is in place, symlink/copy configs into place:

```sh
./install.sh        # pick items in a checkbox menu
./install.sh --all  # install every item offered on this OS, no menu
```

The menu starts with every item ticked: ↑/↓ (or `j`/`k`) move, space toggles, `a` toggles all,
enter installs, `q` quits without installing. When stdin or stdout is not a terminal (piped, CI),
the menu is skipped and everything is installed.

| Item | Installs | OS |
|------|----------|----|
| tmux config | symlinks `~/.tmux.conf` | macOS, Linux |
| process_path.sh | symlinks `~/process_path.sh` (the `.tmux.conf` copy-mode `o` binding calls it) | macOS, Linux |
| start_tmux.sh | symlinks `~/start_tmux.sh` | macOS, Linux |
| wf-cli | symlinks `~/bin/wf-cli` (the `wf-ci` link and `.zshrc` line from `scripts/wf-cli.md` stay manual) | macOS, Linux |
| Ghostty | symlinks the config into `~/Library/Application Support/com.mitchellh.ghostty/` | macOS |
| sanitize_and_open | copies `sanitize_and_open.js` to `/usr/local/bin` (uses `sudo` if not writable) | macOS |
| tokenmaxx | copies `~/bin/tokenmaxx-loop.sh`; on macOS also installs and loads the LaunchAgent | macOS, Linux |

Existing files are backed up to `<target>.bak.<timestamp>` before being replaced. Missing parent
directories (e.g. `~/bin`) are created. The shell configs (`.zshrc`, `.p10k.zsh`) are not installed.

## Linux

`install.sh` itself needs only `git` (to clone), `bash` and the standard coreutils, plus:

- `cmp` (`diffutils`) — without it the tokenmaxx copy is backed up and re-copied on every run.
- `tput` (`ncurses`) — optional; only hides the cursor while the menu is open.

The installed items need:

- **tmux config** — `tmux` (and `lazygit` for `prefix + g`).
- **process_path.sh** — `python3`, an editor CLI (§5) and `E2E_PATH` (§4). Only code files open.
- **wf-cli** — `uv`, `git`, `gh` and `zsh` (see `scripts/wf-cli.md`). The `env -S` shebang needs coreutils 8.30+.
- **tokenmaxx** — `tmux` and an authenticated `claude`. There is no LaunchAgent on Linux, so nothing starts the loop.

Mouse DPI (Logitech G502 X via Piper, incl. the `ratbagd` commands) — see `linux/g502x-piper.md`.
