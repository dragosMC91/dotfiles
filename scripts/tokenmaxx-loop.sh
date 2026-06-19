#!/bin/bash
# tokenmaxx-loop.sh
# Runs the tokenmaxx cycle on a random 30min-1h cadence, measured in WALL-CLOCK time.
# Because the deadline is real-clock based and we poll every 15s, the cycle fires
# right after the mac wakes if the interval elapsed while it was asleep.
# Managed by ~/Library/LaunchAgents/com.dragos.tokenmaxx.plist

# script assumes a tmux session called "claude" is running with a window called "tokenmaxx"
# if not, you can start it with `tmux new-session -d -s claude -c "$TARGET_DIR"`
# and then rename the window to "tokenmaxx" with `tmux rename-window -t claude:1 'tokenmaxx'`
# make sure to update the dump directory to your own before running the script
TARGET="claude:tokenmaxx"
DUMP_DIR="~/.claude/projects/-Users-dragoscampean-claude-dump/"

run_cycle() {
  # just for manual debugging purposes
  tmux send-keys -t "$TARGET" C-c C-c C-c
  tmux send-keys -t "$TARGET" C-u 'date' Enter

  # 1. start claude (C-u clears the prompt line first)
  tmux send-keys -t "$TARGET" C-u "claude --model claude-sonnet-4-6 --effort low \"$(date +%s)\"" Enter


  # 2. ~1 minute later, interrupt twice
  sleep 60
  tmux send-keys -t "$TARGET" C-c C-c

  # 3. soon after, clean up the dump
  sleep 5
  tmux send-keys -t "$TARGET" C-u "rm -rf $DUMP_DIR" Enter
}

next=0  # 0 => run immediately on first start
while true; do
  now=$(date +%s)
  if [ "$now" -ge "$next" ]; then
    run_cycle
    # schedule the next run a random 30min (1800s) to 1h (3600s) from now
    next=$(( $(date +%s) + 1800 + RANDOM % 1801 ))
  fi
  sleep 15
done
