#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ln -sf $SCRIPT_DIR/tmux/.tmux.conf ~/.tmux.conf
ln -sf $SCRIPT_DIR/tmux/scripts/process_path.sh ~/process_path.sh
ln -sf $SCRIPT_DIR/tmux/scripts/start_tmux.sh ~/start_tmux.sh
ln -sf $SCRIPT_DIR/terminal/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config