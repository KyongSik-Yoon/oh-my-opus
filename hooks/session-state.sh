#!/bin/sh
# baton-opus5 session state: one script for both SessionStart and SessionEnd
# (branch on hook_event_name from stdin). The model id is only present in the
# SessionStart payload, so it is captured here to a per-session file that later
# hooks (agent-cap) read. Unlike baton, this exits doing nothing when the flag
# file is absent: an inert plugin must write nothing. Always exits 0 and prints
# nothing; a missing jq, missing field, or unwritable dir must never block a
# session.
FLAG="${HOME}/.claude/baton-opus5"
[ -f "$FLAG" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

STATE="${HOME}/.claude/baton-opus5-state"
mkdir -p "$STATE" 2>/dev/null || exit 0

case "$event" in
  SessionStart)
    model=$(printf '%s' "$input" | jq -r '.model // empty' 2>/dev/null)
    if [ -n "$model" ]; then
      printf '%s\n' "$model" > "${STATE}/${sid}.model" 2>/dev/null || exit 0
    fi
    # Prune stale per-session state so the dir cannot grow without bound: stale
    # .model files, and stale .agents slot dirs (directories, so -type f no
    # longer reaches them). -mindepth 1 -maxdepth 1 with -type d confines the
    # recursive delete to immediate children of $STATE — it can never remove
    # $STATE itself or anything above it.
    find "$STATE" -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true
    find "$STATE" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    ;;
  SessionEnd)
    # sid is sanitized to ^[A-Za-z0-9_-]+$ by the case above, so this rm -rf can
    # never target anything outside baton-opus5-state.
    rm -f "${STATE}/${sid}.model" 2>/dev/null
    rm -rf "${STATE}/${sid}.agents" 2>/dev/null
    ;;
esac
exit 0
