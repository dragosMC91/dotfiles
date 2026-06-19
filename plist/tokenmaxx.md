# tokenmaxx

Runs the tokenmaxx script.

- **Loop script:** `~/bin/tokenmaxx-loop.sh`
- **LaunchAgent:** `~/Library/LaunchAgents/com.dragos.tokenmaxx.plist`
- **Logs:** `~/Library/Logs/tokenmaxx.log`, `~/Library/Logs/tokenmaxx.err.log`

## Manage

```bash
# start (load once; auto-loads on every login after this)
launchctl load -w ~/Library/LaunchAgents/com.dragos.tokenmaxx.plist

# stop
launchctl unload ~/Library/LaunchAgents/com.dragos.tokenmaxx.plist

# status
launchctl list | grep tokenmaxx

# after editing the plist or script: unload then load
launchctl unload ~/Library/LaunchAgents/com.dragos.tokenmaxx.plist
launchctl load -w ~/Library/LaunchAgents/com.dragos.tokenmaxx.plist
```

Load is needed only once — `launchd` auto-loads it on every login.