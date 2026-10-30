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

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

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
        # When copied with sudo the target is root-owned; ensure it stays
        # world-readable so tools running as the user (e.g. Automator Quick
        # Actions) can read it. Otherwise node fails with EACCES.
        $SUDO chmod 755 "$target"
        printf "${GREEN}Copied:${RESET} %s -> %s\n" "$source" "$target"
    else
        printf "${YELLOW}Warning:${RESET} failed to copy to %s\n" "$target"
        return 1
    fi
}

# --- Launch agents (macOS only: launchd) ---
# Render each plist for the current user (source uses a __HOME__ placeholder so it
# is not tied to any one username), then install and (re)load it.
install_launch_agent() {
    local label="$1"
    local rendered_plist plist_target
    rendered_plist="$(mktemp)"
    sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/plist/${label}.plist" > "$rendered_plist"
    plist_target=~/Library/LaunchAgents/${label}.plist
    if safe_copy "$rendered_plist" "$plist_target"; then
        launchctl unload "$plist_target" 2>/dev/null
        if launchctl load "$plist_target" 2>/dev/null; then
            printf "${GREEN}Loaded launch agent:${RESET} %s\n" "$label"
        else
            printf "${YELLOW}Warning:${RESET} could not load launch agent (load it manually with: launchctl load %s)\n" "$plist_target"
        fi
    fi
    rm -f "$rendered_plist"
}

# --- Installable items ---
# powerlevel10k config is mostly a placeholder, with my preset configs, so fully overriding it is not the best idea.
# create_symlink "$SCRIPT_DIR/shell/.p10k.zsh" ~/.p10k.zsh
install_tmux_conf() {
    create_symlink "$SCRIPT_DIR/tmux/.tmux.conf" ~/.tmux.conf
}

install_process_path() {
    create_symlink "$SCRIPT_DIR/tmux/scripts/process_path.sh" ~/process_path.sh
}

install_start_tmux() {
    create_symlink "$SCRIPT_DIR/tmux/scripts/start_tmux.sh" ~/start_tmux.sh
}

install_wf_cli() {
    create_symlink "$SCRIPT_DIR/scripts/wf-cli/wf-cli" ~/bin/wf-cli
}

install_ghostty() {
    create_symlink "$SCRIPT_DIR/terminal/ghostty/config" ~/Library/Application\ Support/com.mitchellh.ghostty/config
}

# Copied, not symlinked: symlinks don't work when macOS Automator executes scripts.
# /usr/local/bin may not exist on a fresh Apple Silicon Mac, and may need sudo.
install_sanitize_and_open() {
    if [ ! -d /usr/local/bin ]; then
        sudo mkdir -p /usr/local/bin
    fi
    if [ -w /usr/local/bin ]; then
        safe_copy "$SCRIPT_DIR/scripts/sanitize_and_open.js" /usr/local/bin/sanitize_and_open.js
    else
        safe_copy "$SCRIPT_DIR/scripts/sanitize_and_open.js" /usr/local/bin/sanitize_and_open.js sudo
    fi
}

install_tokenmaxx() {
    safe_copy "$SCRIPT_DIR/scripts/tokenmaxx-loop.sh" ~/bin/tokenmaxx-loop.sh
    if is_macos; then
        mkdir -p ~/Library/Logs
        install_launch_agent com.dragos.tokenmaxx
    fi
}

# Items offered on this OS: install function + menu label (parallel arrays).
ITEM_FUNCS=()
ITEM_LABELS=()
add_item() { ITEM_FUNCS+=("$1"); ITEM_LABELS+=("$2"); }

add_item install_tmux_conf "tmux config (~/.tmux.conf)"
add_item install_process_path "process_path.sh (tmux copy-mode o)"
add_item install_start_tmux "start_tmux.sh"
add_item install_wf_cli "wf-cli (~/bin)"
if is_macos; then
    add_item install_ghostty "Ghostty config"
    add_item install_sanitize_and_open "sanitize_and_open.js (Automator, /usr/local/bin)"
    add_item install_tokenmaxx "tokenmaxx loop + launch agent"
else
    add_item install_tokenmaxx "tokenmaxx loop script (no launch agent on Linux)"
fi

# Interactive checkbox menu; fills SELECTED[i]=1 for each chosen item.
# Keys: up/down or k/j move, space toggles, a toggles all, enter installs, q quits.
SELECTED=()
select_items() {
    local count=${#ITEM_LABELS[@]} cursor=0 key i mark pointer all
    for ((i = 0; i < count; i++)); do SELECTED[i]=1; done

    printf "Select what to install (↑/↓ move, space toggle, a all/none, enter install, q quit):\n"
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null' EXIT

    while true; do
        for ((i = 0; i < count; i++)); do
            mark=" "; [ "${SELECTED[i]}" = 1 ] && mark="x"
            pointer="  "; [ "$i" -eq "$cursor" ] && pointer="${ORANGE}> ${RESET}"
            printf "\033[K%s[%s] %s\n" "$pointer" "$mark" "${ITEM_LABELS[i]}"
        done

        IFS= read -rsn1 key
        # Arrow keys arrive as ESC [ A / ESC [ B.
        [ "$key" = $'\033' ] && IFS= read -rsn2 key
        case "$key" in
            '[A'|k) cursor=$(( (cursor - 1 + count) % count )) ;;
            '[B'|j) cursor=$(( (cursor + 1) % count )) ;;
            ' ') SELECTED[cursor]=$(( 1 - SELECTED[cursor] )) ;;
            a)
                all=0
                for ((i = 0; i < count; i++)); do [ "${SELECTED[i]}" = 1 ] || all=1; done
                for ((i = 0; i < count; i++)); do SELECTED[i]=$all; done
                ;;
            '') break ;;
            q) tput cnorm 2>/dev/null; printf "Aborted, nothing installed.\n"; exit 0 ;;
        esac
        # Move back up to redraw the list in place.
        printf "\033[%dA" "$count"
    done
    tput cnorm 2>/dev/null
}

# Non-interactive runs (piped, CI) or --all install everything offered on this OS.
if [ "${1:-}" = "--all" ] || [ ! -t 0 ] || [ ! -t 1 ]; then
    for ((i = 0; i < ${#ITEM_FUNCS[@]}; i++)); do SELECTED[i]=1; done
else
    select_items
fi

for ((i = 0; i < ${#ITEM_FUNCS[@]}; i++)); do
    if [ "${SELECTED[i]}" = 1 ]; then
        "${ITEM_FUNCS[i]}"
    fi
done
