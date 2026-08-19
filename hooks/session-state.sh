#!/bin/sh
# oh-my-opus per-session cleanup, on SessionStart and SessionEnd. All this
# keeps now is the per-turn subagent slot directory: the session model is read
# from the transcript at the moment a hook needs it (see lib-model.sh), so
# nothing has to be captured at SessionStart any more. That also means turning
# the plugin on mid-session works immediately, with no stale state to go wrong.
# Always exits 0 and prints nothing.
FLAG="${HOME}/.claude/oh-my-opus"
[ -f "$FLAG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

STATE="${HOME}/.claude/oh-my-opus-state"
mkdir -p "$STATE" 2>/dev/null || exit 0

case "$event" in
  SessionStart)
    # Prune slot dirs abandoned by sessions that never reached SessionEnd.
    # -mindepth/-maxdepth 1 confines the recursive delete to immediate children
    # of $STATE — it can never remove $STATE itself or anything above it.
    find "$STATE" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    find "$STATE" -mindepth 1 -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true
    ;;
  SessionEnd)
    # sid is sanitized to ^[A-Za-z0-9_-]+$ above, so this rm -rf can never
    # target anything outside the state directory.
    rm -rf "${STATE}/${sid}.agents" 2>/dev/null
    ;;
esac
exit 0
