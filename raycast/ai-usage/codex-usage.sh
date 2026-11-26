#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Codex
# @raycast.mode inline
# @raycast.refreshTime 5m
# @raycast.packageName AI Usage
# @raycast.icon images/codex-logo.png
#
# Inline row:  $cost-today · 5h [bar] used% ↻time-left · 7d [bar] used% ↻time-left
#
# Each refresh:
#  - ~10 ms check whether any Codex session log changed since the last run.
#  - Limits: newest rate-limit event Codex itself wrote to ~/.codex/sessions, scanning only
#    the logs that changed. No network, no credentials.
#  - Cost: only when logs changed / new day / last attempt failed -> `ccusage codex daily`
#    for TODAY only (local logs + public LiteLLM price list).
#  - Cache: ~/Library/Caches/ai-usage (0700 dir, 0600 files), derived numbers only.

# ---- settings -----------------------------------------------------------------
NAME=codex
LOGS="$HOME/.codex/sessions"
FIRST_SCAN_DAYS=8        # how far back to look for limits on the very first run
BAR_CELLS=5              # usage-bar width in cells; 0 = no bars
WARN_AT=70               # bar is green below this %, yellow from here ...
CRIT_AT=90               # ... and red from here
COLOR=1                  # 0 = no ANSI colours (also: AI_USAGE_COLOR=0); bars then use ▮▯

# ---- common setup (same in both scripts) --------------------------------------
umask 077
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
command -v jq >/dev/null || { echo "needs jq (macOS 15+ ships /usr/bin/jq)"; exit 0; }
C="${AI_USAGE_CACHE:-$HOME/Library/Caches/ai-usage}"
mkdir -p "$C" 2>/dev/null
if [ -L "$C" ] || [ ! -d "$C" ] || [ ! -O "$C" ]; then echo "unsafe cache dir: $C"; exit 0; fi
chmod 700 "$C"
now=$(date +%s); today=$(date +%Y%m%d)
age() { echo $(( now - $(stat -f %m "$1" 2>/dev/null || echo 0) )); }

# One run at a time; an overlapping run repeats the last line.
if ! mkdir "$C/$NAME.lock" 2>/dev/null; then
  if [ "$(age "$C/$NAME.lock")" -lt 120 ]; then cat "$C/$NAME.last" 2>/dev/null || echo "…"; exit 0; fi
  rm -rf "$C/$NAME.lock"; mkdir "$C/$NAME.lock" 2>/dev/null || exit 0
fi
trap 'rm -rf "$C/$NAME.lock"; rm -f "$C/$NAME".tmp.*' EXIT
say() { printf '%s\n' "$1" >"$C/$NAME.last"; printf '%s\n' "$1"; }

# Manual refresh = press Enter on the row (Raycast re-runs the script). A run arriving well
# before the 5-min schedule (30 s – 4 min after the previous one) is treated as manual and
# skips the throttles below. The 30 s floor keeps repeated presses from hammering anything.
manual=""
since=$(age "$C/$NAME.ran"); [ "$since" -ge 30 ] && [ "$since" -lt 240 ] && manual=1
touch "$C/$NAME.ran"

# ccusage: $AI_USAGE_CCUSAGE, PATH (brew), newest nvm node, volta.
CC="${AI_USAGE_CCUSAGE:-}"
[ -x "$CC" ] || CC=$(command -v ccusage 2>/dev/null)
if [ -z "$CC" ]; then
  for d in $(ls -d "$HOME"/.nvm/versions/node/v*/bin 2>/dev/null | sort -V -r) "$HOME/.volta/bin"; do
    [ -x "$d/ccusage" ] && { CC="$d/ccusage"; break; }
  done
fi
# An npm install's `ccusage` is a Node wrapper around a native binary shipped in the package.
# Call that binary directly: same results, ~half the CPU, and no Node needed at runtime.
if [ -n "$CC" ]; then
  arch=$(uname -m); [ "$arch" = x86_64 ] && arch=x64
  pkg=$(dirname "$(dirname "$(readlink -f "$CC" 2>/dev/null || echo "$CC")")")
  native="$pkg/node_modules/@ccusage/ccusage-darwin-$arch/bin/ccusage"
  if [ -x "$native" ]; then CC="$native"; else PATH="$(dirname "$CC"):$PATH"; fi   # wrapper needs its node
fi
run_ccusage() { if command -v perl >/dev/null; then perl -e 'alarm shift; exec @ARGV' 45 "$CC" "$@"; else "$CC" "$@"; fi; }

JQ_FMT='
  def money: ((. // 0) * 100 | round | if . <= 0 then 0 else . end) as $n
    | "$\($n / 100 | floor).\($n % 100 | tostring | if length < 2 then "0" + . else . end)";
  def left: (if . < 0 then 0 else floor end)
    | if . < 3600 then "\(. / 60 | floor)m"
      elif . < 86400 then "\(. / 3600 | floor)h\(. % 3600 / 60 | floor | tostring | if length < 2 then "0" + . else . end)"
      else "\(. / 86400 | floor)d\(. % 86400 / 3600 | floor)h" end;'

# Usage bar drawn before each percentage. Raycast renders ANSI colours in inline rows, so
# filled cells are green / yellow / red and empty ones grey. Without colour the two are told
# apart by glyph. A bar is never empty above 0% and never full below 100%.
COLOR="${AI_USAGE_COLOR:-$COLOR}"
case "$BAR_CELLS" in ''|*[!0-9]*) BAR_CELLS=0 ;; esac
case "$WARN_AT" in ''|*[!0-9]*) WARN_AT=70 ;; esac
case "$CRIT_AT" in ''|*[!0-9]*) CRIT_AT=90 ;; esac
JQ_BAR='
  def bar: if $cells <= 0 then "" else
      (if . < 0 then 0 elif . > 100 then 100 else . end) as $p
      | ($p * $cells / 100 | round
         | if $p > 0 and . == 0 then 1 elif $p < 99.5 and . >= $cells then $cells - 1 else . end) as $n
      | def rep($g; $k): [range(0; $k) | $g] | join("");
        if $color == "1" then
          "\u001b[" + (if $p >= $crit then "31" elif $p >= $warn then "33" else "32" end) + "m" + rep("❚"; $n)
          + "\u001b[38;5;242m" + rep("❚"; $cells - $n) + "\u001b[0m "
        else rep("▮"; $n) + rep("▯"; $cells - $n) + " " end end;'
BAR_ARGS=(--argjson cells "$BAR_CELLS" --argjson warn "$WARN_AT" --argjson crit "$CRIT_AT" --arg color "$COLOR")

# Stamp taken BEFORE scanning, promoted at the end: writes during the run aren't missed.
touch "$C/$NAME.stamp.next"
changed="$manual"          # a manual refresh recomputes everything
if [ ! -f "$C/$NAME.stamp" ] || [ -n "$(find "$LOGS" -name '*.jsonl' -newer "$C/$NAME.stamp" -print -quit 2>/dev/null)" ]; then
  changed=1
fi

# ---- limits: newest valid event across changed logs + the cached one -----------
if [ -n "$changed" ] || [ ! -s "$C/$NAME.limits.json" ]; then
  if [ -f "$C/$NAME.stamp" ] && [ -s "$C/$NAME.limits.json" ]; then
    set -- -newer "$C/$NAME.stamp"
  else
    set -- -mtime "-$FIRST_SCAN_DAYS"
  fi
  tmp=$(mktemp "$C/$NAME.tmp.XXXXXX")
  { cat "$C/$NAME.limits.json" 2>/dev/null
    find "$LOGS" -name '*.jsonl' "$@" -print0 2>/dev/null | xargs -0 grep -h '"rate_limits"' 2>/dev/null \
      | jq -c 'select(.timestamp != null
                      and (.payload.rate_limits | type == "object" and .primary != null
                           and ((.limit_id // "codex") == "codex")))
               | {t: .timestamp, rl: .payload.rate_limits}' 2>/dev/null
  } | jq -cs 'if length > 0 then max_by(.t) else empty end' >"$tmp" 2>/dev/null
  [ -s "$tmp" ] && mv -f "$tmp" "$C/$NAME.limits.json"
fi

# ---- cost (today only) --------------------------------------------------------
cost=""
if [ -n "$CC" ]; then
  if [ -n "$changed" ] || [ -f "$C/$NAME.cost.retry" ] || [ "$(cat "$C/$NAME.day" 2>/dev/null)" != "$today" ]; then
    tmp=$(mktemp "$C/$NAME.tmp.XXXXXX")
    if run_ccusage codex daily -j -s "$today" >"$tmp" 2>/dev/null && jq -e .totals "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$C/$NAME.daily.json"; echo "$today" >"$C/$NAME.day"; rm -f "$C/$NAME.cost.retry"
    else
      touch "$C/$NAME.cost.retry"
    fi
  fi
  if [ "$(cat "$C/$NAME.day" 2>/dev/null)" = "$today" ]; then
    # "≥": a model used today has no price data (isFallback only means approximate price).
    cost=$(jq -r "$JQ_FMT"'
      (((.totals.unpricedModels // []) | length) > 0
       or ([.daily[]?.models // {} | to_entries[] | select(.value.missingPricing == true)] | length) > 0) as $partial
      | (if $partial then "≥" else "" end) + (.totals.costUSD | money)' "$C/$NAME.daily.json" 2>/dev/null)
    [ -n "$cost" ] && [ -f "$C/$NAME.cost.retry" ] && cost="$cost (stale)"
    [ -n "$cost" ] && cost="$cost · "
  fi
fi

mv -f "$C/$NAME.stamp.next" "$C/$NAME.stamp"

lim=$(jq -r --argjson now "$now" "${BAR_ARGS[@]}" "$JQ_FMT$JQ_BAR"'
  def wl: (.window_minutes // 0) | if . >= 1440 then "\(. / 1440 | floor)d" elif . > 0 then "\(. / 60 | floor)h" else "?" end;
  def w: if . == null then empty else
      (.resets_at // null) as $r
      | if $r != null and $r <= $now then "\(wl) reset"
        else (.used_percent // 0) as $u | "\(wl) " + ($u | bar) + "\($u | round)%" + (if $r != null then " ↻" + ($r - $now | left) else "" end) end end;
  (.t | sub("\\.[0-9]+"; "") | try fromdateiso8601 catch $now) as $seen
  | ([(.rl.primary | w), (.rl.secondary | w)] | join(" · "))
    + (if $now - $seen > 86400 then " · as of \(($now - $seen) / 86400 | floor)d ago" else "" end)' \
  "$C/$NAME.limits.json" 2>/dev/null)

say "${cost}${lim:-no Codex limit data yet}"
