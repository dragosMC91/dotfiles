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

# prompts are built as random template + random topic; keep them short-answer and
# tool-free so the pings stay cheap (%s in a template is replaced by the topic)
TEMPLATES=(
  "Share one surprising fact about %s."
  "Explain %s in a single sentence."
  "Write a haiku about %s."
  "What is a common misconception about %s? One sentence."
  "Give a one-line tip for someone curious about %s."
  "Describe %s to a five year old in one sentence."
  "Name three words you associate with %s."
  "Write a one-sentence story involving %s."
  "Rate %s from 1 to 10. Reply with the number only."
  "Give %s a one-word nickname."
  "In five words or fewer, why does %s matter?"
  "Which color best matches %s? One word."
  "Name one emoji that fits %s. Reply with the emoji only."
)
TOPICS=(
  "octopuses" "sourdough bread" "Roman aqueducts" "TCP handshakes" "Jupiter's moons"
  "bonsai trees" "the Fibonacci sequence" "jazz improvisation" "coral reefs" "chess openings"
  "volcanoes" "honeybees" "the printing press" "black holes" "espresso"
  "the Danube" "origami" "lighthouses" "glaciers" "mechanical watches"
  "the Carpathians" "hash tables" "tardigrades" "medieval castles" "solar eclipses"
  "vinyl records" "migrating birds" "the Rubik's cube" "fermentation" "northern lights"
  "sea otters" "the Silk Road" "bicycles" "thunderstorms" "the Eiffel Tower"
  "mushrooms" "Morse code" "penguins" "the Moon landing" "compound interest"
)

# prints a shell-escaped random prompt, safe to type into the tmux pane
random_prompt() {
  local template="${TEMPLATES[RANDOM % ${#TEMPLATES[@]}]}"
  local topic="${TOPICS[RANDOM % ${#TOPICS[@]}]}"
  printf '%q' "$(printf "$template" "$topic")"
}

run_cycle() {
  # just for manual debugging purposes
  tmux send-keys -t "$TARGET" C-c C-c C-c
  tmux send-keys -t "$TARGET" C-u 'date' Enter

  # 1. start claude (C-u clears the prompt line first)
  tmux send-keys -t "$TARGET" C-u "claude --model claude-haiku-5-5 --effort low $(random_prompt)" Enter


  # 2. ~1 minute later, interrupt twice
  sleep 60
  tmux send-keys -t "$TARGET" C-c C-c

  # 3. soon after, clean up the dump
  sleep 5
  tmux send-keys -t "$TARGET" C-u "rm -rf $DUMP_DIR" Enter

  # 4. ping codex non-interactively; exits on its own, --ephemeral leaves no session files
  tmux send-keys -t "$TARGET" C-u "codex exec --ephemeral --skip-git-repo-check -s read-only -m gpt-6-luna -c model_reasoning_effort=low $(random_prompt)" Enter
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
