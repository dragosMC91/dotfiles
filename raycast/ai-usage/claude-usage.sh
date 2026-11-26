#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Claude
# @raycast.mode inline
# @raycast.refreshTime 5m
# @raycast.packageName AI Usage
# @raycast.icon images/claude-logo.png
#
# Inline row:  $cost-today · 5h [bar] used% ↻time-left · 7d [bar] used% ↻time-left · Fable [bar] used%
#  (the last part is each per-model weekly limit the account has; its ↻ is shown only
#   when it resets at a different time than the 7d window)
#
# Each refresh:
#  - ~20 ms check whether any Claude Code log changed since the last run.
#  - Cost: only when logs changed / new day / last attempt failed -> `ccusage claude daily`
#    for TODAY only (local logs + public LiteLLM price list).
#  - Limits: Anthropic usage endpoint, only when logs changed or the cached value is older
#    than FETCH_EVERY; after a failure it backs off for RETRY_AFTER_FAIL.
#    The Claude Code token is read READ-ONLY from the Keychain, piped (never written to a
#    file, argv or env), never refreshed, never cached.
#  - Cache: ~/Library/Caches/ai-usage (0700 dir, 0600 files), derived numbers only.

# ---- settings -----------------------------------------------------------------
USAGE_URL="https://api.anthropic.com/api/oauth/usage"   # undocumented endpoint, may change
BETA_HEADER="oauth-2025-04-20"                           # required by that endpoint today
USER_AGENT="claude-code/2.1.319"
FETCH_EVERY=900          # refetch limits at least this often (s) when idle
RETRY_AFTER_FAIL=900     # back-off after a failed fetch (s)
NAME=claude
LOGS="$HOME/.claude/projects"
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
      else "\(. / 86400 | floor)d\(. % 86400 / 3600 | floor)h" end;
  def ts: try (if type == "number" then .
    else capture("^(?<b>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}:?[0-9]{2})?$") as $m
      | ($m.b + "Z" | fromdateiso8601)
        - (($m.z // "Z") | if . == "Z" then 0
           else (.[0:1]) as $s | ((.[1:3] | tonumber) * 3600 + (.[-2:] | tonumber) * 60) | if $s == "-" then -. else . end end)
    end) catch null;'

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

# ---- cost (today only) --------------------------------------------------------
cost=""
if [ -n "$CC" ]; then
  if [ -n "$changed" ] || [ -f "$C/$NAME.cost.retry" ] || [ "$(cat "$C/$NAME.day" 2>/dev/null)" != "$today" ]; then
    tmp=$(mktemp "$C/$NAME.tmp.XXXXXX")
    if run_ccusage claude daily -j -s "$today" >"$tmp" 2>/dev/null && jq -e .totals "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$C/$NAME.daily.json"; echo "$today" >"$C/$NAME.day"; rm -f "$C/$NAME.cost.retry"
    else
      touch "$C/$NAME.cost.retry"
    fi
  fi
  if [ "$(cat "$C/$NAME.day" 2>/dev/null)" = "$today" ]; then
    # "≥": some model used today has no price data, so the total is a lower bound.
    cost=$(jq -r "$JQ_FMT"'
      (((.totals.unpricedModels // []) | length) > 0
       or ([.daily[]?.modelBreakdowns[]? | select((.cost // 0) == 0
            and ((.inputTokens // 0) + (.outputTokens // 0) + (.cacheReadTokens // 0) + (.cacheCreationTokens // 0)) > 0)]
           | length) > 0) as $partial
      | (if $partial then "≥" else "" end) + (.totals.totalCost | money)' "$C/$NAME.daily.json" 2>/dev/null)
    [ -n "$cost" ] && [ -f "$C/$NAME.cost.retry" ] && cost="$cost (stale)"
    [ -n "$cost" ] && cost="$cost · "
  fi
fi

# ---- rate limits ---------------------------------------------------------------
if [ -z "${AI_USAGE_NO_FETCH:-}" ] \
   && { [ -n "$changed" ] || [ "$(age "$C/$NAME.limits.json")" -ge "$FETCH_EVERY" ]; } \
   && { [ -n "$manual" ] || [ ! -f "$C/$NAME.limits.err" ] || [ "$(age "$C/$NAME.limits.err")" -ge "$RETRY_AFTER_FAIL" ]; }; then
  err="" tok="" exp=0
  { IFS= read -r tok; IFS= read -r exp; } < <(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
      | jq -r '.claudeAiOauth // {} | (.accessToken // ""), (.expiresAt // 0 | floor)' 2>/dev/null)
  case "$exp" in ''|*[!0-9]*) exp=0 ;; esac
  if [ -z "$tok" ]; then
    err="not logged in"
  elif [ "$exp" -gt 0 ] && [ $(( exp / 1000 )) -le "$now" ]; then
    err="login expired, open Claude Code"
  else
    tmp=$(mktemp "$C/$NAME.tmp.XXXXXX")
    code=$(printf 'Authorization: Bearer %s\n' "$tok" | curl -sS --max-time 10 -o "$tmp" -w '%{http_code}' -H @- \
             -H "anthropic-beta: $BETA_HEADER" -H "Accept: application/json" -A "$USER_AGENT" "$USAGE_URL" 2>/dev/null)
    if [ "$code" = 200 ] && jq -e '.five_hour // .seven_day' "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$C/$NAME.limits.json"; rm -f "$C/$NAME.limits.err"
    else
      err="HTTP ${code:-error}"
    fi
  fi
  unset tok
  [ -n "$err" ] && printf '%s\n' "$err" >"$C/$NAME.limits.err"
fi

mv -f "$C/$NAME.stamp.next" "$C/$NAME.stamp"

lim=$(jq -r --argjson now "$now" "${BAR_ARGS[@]}" "$JQ_FMT$JQ_BAR"'
  # $ref: reset time already shown by another window; a reset within 60 s of it is not repeated.
  def w($l; $ref): if . == null then empty else
      ((.resets_at // null) | ts) as $r
      | if $r != null and $r <= $now then "\($l) reset"
        else (.utilization // 0) as $u | "\($l) " + ($u | bar) + "\($u | round)%"
          + (if $r != null and ($ref == null or (($r - $ref) | fabs) > 60) then " ↻" + ($r - $now | left) else "" end) end end;
  def w($l): w($l; null);
  # Per-model weekly limits (e.g. Fable) live in .limits[] as kind "weekly_scoped".
  def scoped($ref): (try .limits[] catch empty)
    | select(type == "object" and .kind == "weekly_scoped")
    | ((try .scope.model.display_name catch null) | if type == "string" and length > 0 then .[0:12] else empty end) as $name
    | {utilization: .percent, resets_at: .resets_at} | w($name; $ref);
  ((.seven_day.resets_at // null) | ts) as $wr
  | [(.five_hour | w("5h")), (.seven_day | w("7d")), scoped($wr)] | join(" · ")' "$C/$NAME.limits.json" 2>/dev/null)

note=""
lage=$(age "$C/$NAME.limits.json")
[ -n "$lim" ] && [ "$lage" -ge 1200 ] && note=" · stale $(( lage / 60 ))m"
[ -f "$C/$NAME.limits.err" ] && note="$note · ⚠ $(head -c 60 "$C/$NAME.limits.err")"
say "${cost}${lim:-limits unavailable}${note}"
