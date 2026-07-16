# Tooling & Prerequisites

Everything you need to install **before** running `./install.sh` or using the scripts in this repo.
Target: **macOS on Apple Silicon (arm64)**. Homebrew lives at `/opt/homebrew` on this arch — a few scripts assume that path.

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
> This repo's `.zshrc` already sets it, so once `install.sh` is done the warning goes away.

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

## 8. tokenmaxx loop (`scripts/tokenmaxx-loop.sh`, `plist/*`)

Drives a Claude Code session inside tmux on a timer via `launchd`.

```sh
# Claude Code CLI
brew install --cask claude-code    # or: npm install -g @anthropic-ai/claude-code
```

Requires **tmux** (§4) and an authenticated `claude` login. Managed with `launchctl` — see `plist/tokenmaxx.md`.

## 9. Automator quick action (`scripts/sanitize_and_open.*`)

**Automator** is built into macOS — no install. Follow `scripts/sanitize_and_open.md` to create the Quick Action and assign a keyboard shortcut. Needs Node (§6) and an editor CLI (§5).

---

## Quick install (Homebrew bundle)

```sh
brew install tmux lazygit pyenv pyenv-virtualenv goenv nvm openjdk@11 python3
brew install --cask ghostty cursor raycast claude-code
# then oh-my-zsh, powerlevel10k, zsh plugins (see §2), and nvm node (see §6)
```

## Run the installer

Once the above is in place, symlink/copy all configs into place:

```sh
./install.sh
```

`install.sh` creates symlinks for the shell, tmux, and Ghostty configs, and copies the
sanitize script, tokenmaxx loop, and LaunchAgent plist to their runtime locations.
It also expects `~/bin` to exist (`mkdir -p ~/bin`) for the tokenmaxx copy target.
