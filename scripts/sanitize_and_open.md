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
export CI_PREFIX="/home/runner/_work/repo/repo/"
export E2E_PATH="/Users/myuser/Documents/maple/"
sanitized=$(/Users/myuser/.nvm/versions/node/v20.10.0/bin/node /usr/local/bin/sanitize_and_open.js "$1" 2>> /tmp/automator-debug.log)
echo "Sanitized: $sanitized" >> /tmp/automator-debug.log 2>&1
cursor -g "$sanitized" >> /tmp/automator-debug.log 2>&1 &
# processes remain open and eat up resources
pkill -9 -f 'automator.runner'
```

Notice the `sanitize_and_open.js` script is under `/usr/local/bin/` so make sure to make a copy there (symlink won't work on mac).
This is needed because otherwise Automator doesn't have permissions to access the script. Alternative is to give the app full access to the whole disk.
`install.sh` copies it there and `chmod 755`s it so the copy stays readable by your user (Automator runs as you, not root).

The export PATH line ensures cursor is found (Automator runs with a minimal PATH).

`CI_PREFIX` is the CI checkout path to replace (e.g. `/home/runner/_work/repo/repo/` on GitHub Actions runners) and `E2E_PATH` is the local prefix it maps onto (customize to your checkout). Both are plain strings, not patterns. They **must** be exported inside this script — Automator runs a non-interactive, non-login shell that never sources `~/.zshrc`, so an export there won't reach it. Put it in `~/.zshenv` instead if you want it available to every zsh invocation.
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
- Check /tmp/automator-debug.log for errors
- `EACCES: permission denied` reading `/usr/local/bin/sanitize_and_open.js`: the copy there is root-owned and not readable by your user (Automator runs as you, not root). Fix with `sudo chmod 755 /usr/local/bin/sanitize_and_open.js`. `install.sh` now does this automatically on copy.
- If node is not found, run which node in your terminal and use the full path in the shell script
- If the shortcut doesn't fire at all: confirm it's assigned under System Settings > Keyboard > Keyboard Shortcuts > Services and doesn't conflict with an app shortcut. (The browser does *not* need to be in Privacy & Security > Accessibility for this -- a text Service receives the selection without it.)