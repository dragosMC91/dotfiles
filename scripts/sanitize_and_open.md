## Quick action for selecting a file path in any app and opening it

This is a specific use case, for copying file names from the ci job runs, sanitizing them, and opening them in an IDE.
When debugging hundreds of failing test, selecting the exact file path in the browser, copying it to clipboard, moving to IDE, pasting etc is slow, it can be done with a single key combination.

This flow can be extrapolated to other actions.

### ARchitecture
Browser (select text) --> macOS Quick Action (keyboard shortcut)
  --> Shell script
    --> node ~/scripts/sanitize.js "$selectedText"
    --> cursor "$sanitizedOutput"

### Steps for setting this up
1. Add necessary sanitization script logic (custom to your use-case).
There is a bare bone example under [`./scripts/sanitize_and_open.js`](scripts/sanitize_and_open.js).

This script can be tested independently, so ideally add unit tests for it.

2. Create the Quick Action in MacOS Automator

- Open Automator.app
- Choose **Quick Action**
- Configure the top bar:
    - **Workflow receives current**: text
    - **in**: any application
- Add a **Run Shell Script** action:
    - **Shell**: /bin/zsh
    - **Pass input**: as arguments
    - Script content:

```sh
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
sanitized=$(/path/to/.nvm/versions/node/v20.10.0/bin/node /usr/local/bin/sanitize_and_open.js "$1" 2>> /tmp/automator-debug.log)
echo "Sanitized: $sanitized" >> /tmp/automator-debug.log 2>&1
cursor "$sanitized" >> /tmp/automator-debug.log 2>&1
```

Notice the `sanitize_and_open.js` script is under `/usr/local/bin/` so make sure to make a copy there (symlink won't work on mac).
This is needed because otherwise Automator doesn't have permissions to access the script. Alternative is to give the app full access to the whole disk.

The export PATH line ensures cursor is found (Automator runs with a minimal PATH).
- Save the Quick Action with a name like Open in Cursor

3. Assign a Keyboard Shortcut

- Open System Settings > Keyboard > Keyboard Shortcuts > Services
- Under Text, find your `Open in Cursor` service
- Double click it to "Add Shortcut" and assign a key combo (e.g., Cmd+Shift+O -- pick something that doesn't conflict with browser shortcuts).

4. Test it
- Open browser and select a filename (or whatever your use case might be)
- Press the newly defined keyboard shortcut
- Profit

### Troubleshooting
- If the shortcut doesn't fire, check System Settings > Privacy & Security > Accessibility -- your browser needs to be listed there
- Check /tmp/automator-debug.log for errors
- If node is not found, run which node in your terminal and use the full path in the shell script