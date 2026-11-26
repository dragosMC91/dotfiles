#!/bin/bash
# Keeps the Mac awake with the lid closed, then turns sleep back on.
# pmset needs root, and one sudo has to cover both calls: sudo forgets the
# password after 5 minutes, long before the timer ends.
#
#   awake [minutes]      defaults to 30
#
# Install: sudo runs this as root, so the copy that runs must not be editable
# by my user, or any program running as me could add lines that run as root.
# The `awake` alias in ~/.zshrc points at a root owned copy. Reinstall it
# after every edit of this file:
#   sudo install -o root -g wheel -m 755 awake.sh /usr/local/bin/awake
#
# Debug: the power log shows when the Mac really slept and woke.
#   pmset -g log | grep -E "Entering Sleep|Wake from|Display is turned" | tail
# A working run ends with "Display is turned off", then "Software Sleep".

minutes="${1:-30}"
floor=20 # stop at this battery %, macOS skips its own low-battery sleep while this runs

restore() {
  pmset -a disablesleep 0
  # Turning the flag off doesn't recheck the lid, so put a closed Mac to sleep here
  if ioreg -r -k AppleClamshellState -d 1 | grep -q '"AppleClamshellState" = Yes'; then
    sleep 2
    pmset sleepnow
  fi
}
trap restore EXIT
trap 'exit' INT TERM HUP

pmset -a disablesleep 1
for ((i = 0; i < minutes; i++)); do
  battery=$(pmset -g batt | grep -Eo '[0-9]+%' | tr -d %)
  if ((battery <= floor)); then
    echo "Battery at ${battery}%, stopping."
    break
  fi
  sleep 60
done
