#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Insert Code Fence
# @raycast.mode silent
# @raycast.packageName Typing
# @raycast.icon ⌨️
# @raycast.description Types shift+enter, ``` , shift+enter into the focused text field
#
# Bind it to a hotkey in Raycast. Shift+Enter (not Enter) so chat inputs don't send the message.
# Waits (up to ~1s) until the hotkey's modifiers are released, otherwise a still-held
# ⌘/⌥/⌃ would combine with the typed keys (e.g. ⌘` switches windows); if they are still
# held after that, it types nothing.
# Needs Automation (Raycast → System Events) and Accessibility permissions for Raycast.

osascript -l JavaScript <<'JXA'
ObjC.import("AppKit");
function run() {
  const MODS = 0x1E0000; // shift | control | option | command
  const held = () => Number($.NSEvent.modifierFlags) & MODS;
  for (let i = 0; i < 50 && held(); i++) delay(0.02);
  if (held()) return; // fail closed: typing with ⌘/⌥/⌃ held would fire shortcuts instead

  const se = Application("System Events");
  se.keyCode(36, { using: "shift down" }); // shift+enter
  delay(0.03);
  se.keystroke("```");
  delay(0.03);
  se.keyCode(36, { using: "shift down" }); // shift+enter
}
JXA
