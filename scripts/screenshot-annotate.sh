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

tell application "System Events"
    tell process "Preview"
        -- wait until the image window is actually up before touching menus
        repeat 40 times
            if (exists window 1) then exit repeat
            delay 0.1
        end repeat
        -- "Show Markup Toolbar" toggles to "Hide Markup Toolbar" once open,
        -- so only click while it still reads "Show" -> idempotent, no toggle-off race
        tell menu bar 1
            if (exists menu item "Show Markup Toolbar" of menu 1 of menu bar item "View") then
                click menu item "Show Markup Toolbar" of menu 1 of menu bar item "View"
            end if
        end tell
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
'

# Copy to the clipboard as BOTH a file reference (like Finder's "Copy", furl)
# AND the PNG bitmap. The file reference pastes as a path in terminals that
# can't receive image bitmaps (e.g. Claude Code in Ghostty, which lacks the
# OSC 5522 image-transport protocol); the bitmap keeps inline-image paste
# working in native apps like Slack.
osascript - "$FILEPATH" <<'APPLESCRIPT'
use framework "Foundation"
use framework "AppKit"
use scripting additions

on run argv
    set thePath to item 1 of argv
    set theURL to current application's |NSURL|'s fileURLWithPath:thePath
    set pngData to current application's NSData's dataWithContentsOfFile:thePath
    set pb to current application's NSPasteboard's generalPasteboard()
    pb's clearContents()
    pb's writeObjects:{theURL}
    pb's addTypes:{"public.png"} owner:(missing value)
    pb's setData:pngData forType:"public.png"
end run
APPLESCRIPT
