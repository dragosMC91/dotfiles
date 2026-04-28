#!/bin/bash
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILEPATH=~/Downloads/screenshots/screenshot_${TIMESTAMP}.png
cat > "$FILEPATH"

# in case the screenshot step is quit mid way
[ ! -s "$FILEPATH" ] && rm "$FILEPATH" && exit 0

osascript -e '
tell application "Preview"
    open POSIX file "'"$FILEPATH"'"
    activate
end tell

delay 0.5

tell application "System Events"
    tell process "Preview"
        keystroke "a" using {shift down, command down}
    end tell
end tell

delay 1
repeat
    tell application "System Events"
        if not (exists window 1 of process "Preview") then
            exit repeat
        end if
    end tell
    delay 0.5
end repeat
tell application "Preview" to quit

# Copy the screenshot to the clipboard
delay 0.5
set the clipboard to (read POSIX file "'"$FILEPATH"'" as «class PNGf»)
'
