#!/bin/bash
# Rex version of tmux/scripts/start_tmux.sh: the same session, tabs,
# working directory and setup commands. A generic example, edit it for
# your own sessions.
#
# A session whose label already exists in Rex is skipped, so running this
# twice doesn't duplicate anything.

set -euo pipefail

REX="$(command -v rex || true)"
REX="${REX:-$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex}"

rex() { "$REX" "$@"; }

session_exists() {
  rex ls --json | jq -e --arg l "$1" '.sessions[] | select(.label == $l)' >/dev/null
}

# Type each command into a block and press Enter, like tmux send-keys ... C-m.
run_in() {
  local block="$1"; shift
  local cmd
  for cmd in "$@"; do rex send -b "$block" "$cmd"$'\r'; done
}

# new_session LABEL FIRST_TAB DIR -> prints the first tab's block ID
new_session() {
  rex new "$1" --window "$2" -c "$3" --json | jq -r '.initial_windows[0].block_ids[0]'
}

# new_tab SESSION LABEL DIR -> prints the tab's block ID
new_tab() {
  rex window new -s "$1" "$2" -c "$3" --focus=false --json | jq -r '.block_ids[0]'
}

DIR="$HOME/Documents/AutoGen-Experiments"
if session_exists autogen; then
  echo "autogen: already exists, skipping"
else
  b=$(new_session autogen LiteLLM "$DIR")
  run_in "$b" 'source .venv/bin/activate'
  for tab in chat chat; do
    b=$(new_tab autogen "$tab" "$DIR")
    run_in "$b" 'source .venv/bin/activate'
  done
  echo "autogen: created"
fi
