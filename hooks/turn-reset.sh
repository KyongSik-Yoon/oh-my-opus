#!/bin/sh
# baton-opus5 turn reset: UserPromptSubmit hook. Does exactly one thing — clears
# the per-turn subagent slot dir so the cap counts from zero each user prompt.
# Injects NO context and prints nothing (there is no posture injection in this
# plugin). Fails open and always exits 0: a missing flag, missing jq, or bad
# session id must never block a prompt.
FLAG="${HOME}/.claude/baton-opus5"
[ -f "$FLAG" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

sid=$(cat | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

# sid is sanitized to ^[A-Za-z0-9_-]+$ above, so this rm -rf can never target
# anything outside baton-opus5-state.
STATE="${HOME}/.claude/baton-opus5-state"
rm -rf "${STATE}/${sid}.agents" 2>/dev/null
exit 0
