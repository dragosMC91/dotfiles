#!/bin/bash

set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Colors (only when writing to a terminal)
if [ -t 1 ]; then
    ORANGE=$'\033[38;5;208m'
    YELLOW=$'\033[33m'
    GREEN=$'\033[32m'
    RESET=$'\033[0m'
else
    ORANGE=""; YELLOW=""; GREEN=""; RESET=""
fi

timestamp() { date +%Y%m%d%H%M%S; }

# Symlink a config into place, backing up anything real that is already there.
create_symlink() {
    local source="$1"
    local target="$2"

    if [ ! -e "$source" ]; then
        printf "${YELLOW}Warning:${RESET} source does not exist: %s\n" "$source"
        printf "${YELLOW}Skipping symlink for %s${RESET}\n" "$target"
        return 1
    fi

    # Make sure the parent directory exists (e.g. Ghostty's config dir).
    mkdir -p "$(dirname "$target")"

    # Already the correct symlink — nothing to do.
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        printf "${GREEN}Already linked:${RESET} %s -> %s\n" "$target" "$source"
        return 0
    fi

    # Something is already there (real file, dir, or a different/broken symlink):
    # back it up before we clobber it.
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup="${target}.bak.$(timestamp)"
        if mv "$target" "$backup"; then
            printf "${ORANGE}⚠ Overriding existing %s${RESET}\n" "$target"
            printf "${ORANGE}  Backup saved to: %s${RESET}\n" "$backup"
        else
            printf "${YELLOW}Warning:${RESET} failed to back up %s; leaving it untouched\n" "$target"
            return 1
        fi
    fi

    ln -sf "$source" "$target"
    printf "${GREEN}Created symlink:${RESET} %s -> %s\n" "$target" "$source"
}

# Copy a file into place, backing up an existing (differing) target first.
# Usage: safe_copy <source> <target> [sudo]
safe_copy() {
    local source="$1"
    local target="$2"
    local use_sudo="${3:-}"

    local SUDO=""
    [ "$use_sudo" = "sudo" ] && SUDO="sudo"

    if [ ! -e "$source" ]; then
        printf "${YELLOW}Warning:${RESET} source does not exist: %s\n" "$source"
        printf "${YELLOW}Skipping copy for %s${RESET}\n" "$target"
        return 1
    fi

    $SUDO mkdir -p "$(dirname "$target")"

    # Identical already — nothing to do.
    if [ -e "$target" ] && cmp -s "$source" "$target"; then
        printf "${GREEN}Already up to date:${RESET} %s\n" "$target"
        return 0
    fi

    # Existing but different — back it up before touching it.
    if [ -e "$target" ]; then
        local backup="${target}.bak.$(timestamp)"
        if $SUDO cp -p "$target" "$backup"; then
            printf "${ORANGE}⚠ Overriding existing %s${RESET}\n" "$target"
            printf "${ORANGE}  Backup saved to: %s${RESET}\n" "$backup"
        else
            printf "${YELLOW}Warning:${RESET} failed to back up %s; leaving it untouched\n" "$target"
            return 1
        fi
    fi

    if $SUDO cp "$source" "$target"; then
        printf "${GREEN}Copied:${RESET} %s -> %s\n" "$source" "$target"
    else
        printf "${YELLOW}Warning:${RESET} failed to copy to %s\n" "$target"
        return 1
    fi
}

# --- Symlinked configs ---
# powerlevel10k config is mostly a placeholder, with my preset configs, so fully overriding it is not the best idea.
# create_symlink "$SCRIPT_DIR/shell/.p10k.zsh" ~/.p10k.zsh
create_symlink "$SCRIPT_DIR/tmux/.tmux.conf" ~/.tmux.conf
create_symlink "$SCRIPT_DIR/tmux/scripts/process_path.sh" ~/process_path.sh
create_symlink "$SCRIPT_DIR/tmux/scripts/start_tmux.sh" ~/start_tmux.sh
create_symlink "$SCRIPT_DIR/terminal/ghostty/config" ~/Library/Application\ Support/com.mitchellh.ghostty/config

# --- Copied files (symlinks don't work when macOS Automator executes scripts) ---
# /usr/local/bin may not exist on a fresh Apple Silicon Mac, and may need sudo.
if [ ! -d /usr/local/bin ]; then
    sudo mkdir -p /usr/local/bin
fi
if [ -w /usr/local/bin ]; then
    safe_copy "$SCRIPT_DIR/scripts/sanitize_and_open.js" /usr/local/bin/sanitize_and_open.js
else
    safe_copy "$SCRIPT_DIR/scripts/sanitize_and_open.js" /usr/local/bin/sanitize_and_open.js sudo
fi

safe_copy "$SCRIPT_DIR/scripts/tokenmaxx-loop.sh" ~/bin/tokenmaxx-loop.sh

# --- Launch agent ---
# Render the plist for the current user (source uses a __HOME__ placeholder so it
# is not tied to any one username), then install and (re)load it.
mkdir -p ~/Library/Logs
rendered_plist="$(mktemp)"
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/plist/com.dragos.tokenmaxx.plist" > "$rendered_plist"
plist_target=~/Library/LaunchAgents/com.dragos.tokenmaxx.plist
if safe_copy "$rendered_plist" "$plist_target"; then
    launchctl unload "$plist_target" 2>/dev/null
    if launchctl load "$plist_target" 2>/dev/null; then
        printf "${GREEN}Loaded launch agent:${RESET} com.dragos.tokenmaxx\n"
    else
        printf "${YELLOW}Warning:${RESET} could not load launch agent (load it manually with: launchctl load %s)\n" "$plist_target"
    fi
fi
rm -f "$rendered_plist"
