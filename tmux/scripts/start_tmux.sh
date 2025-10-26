#!/bin/bash
# Set the target directory
TARGET_DIR="$HOME/Documents/AutoGen-Experiments"
# Create a new tmux session in detached mode
tmux new-session -d -s autogen -c "$TARGET_DIR"
# Rename the first window which is automatically created
tmux rename-window -t autogen:1 'LiteLLM'
tmux send-keys -t autogen:1 'source .venv/bin/activate' C-m
tmux new-window -t autogen:2 -n 'chat' -c "$TARGET_DIR"
tmux send-keys -t autogen:2 'source .venv/bin/activate' C-m
tmux new-window -t autogen:3 -n 'chat' -c "$TARGET_DIR"
tmux send-keys -t autogen:3 'source .venv/bin/activate' C-m

