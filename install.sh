#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Function to safely create symlink
create_symlink() {
    local source="$1"
    local target="$2"
    
    if [ ! -e "$source" ]; then
        echo "Warning: Source file does not exist: $source"
        echo "Continuing with with operation would remove the content of $target"
        echo "Skipping symlink creation for $target"
        return 1
    fi
    
    ln -sf "$source" "$target"
    echo "Created symlink: $target -> $source"
}

# Create symlinks
create_symlink "$SCRIPT_DIR/shell/.p10k.zsh" ~/.p10k.zsh
create_symlink "$SCRIPT_DIR/tmux/.tmux.conf" ~/.tmux.conf
create_symlink "$SCRIPT_DIR/tmux/scripts/process_path.sh" ~/process_path.sh
create_symlink "$SCRIPT_DIR/tmux/scripts/start_tmux.sh" ~/start_tmux.sh
create_symlink "$SCRIPT_DIR/terminal/ghostty/config" ~/Library/Application\ Support/com.mitchellh.ghostty/config