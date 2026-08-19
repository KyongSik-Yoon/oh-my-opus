#!/bin/sh
# oh-my-opus end-of-turn recap: Stop hook on the MAIN session only (subagent
# turns use SubagentStop, which this plugin does not register). When the ending
# assistant message runs long in an Opus 5 session, force exactly one more turn
# asking for a short recap. Fails quiet everywhere: a missing flag, disabled
# recap, missing jq, unknown model, or short message prints nothing and exits 0.
# The extra turn can never loop — it blocks only when stop_hook_active is falsy.
FLAG="${HOME}/.claude/oh-my-opus"
[ -f "$FLAG" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

# Resolve the recap threshold. recap=on|missing -> 1200 chars; off -> disabled;
# an integer 1-99999 -> that char threshold; anything else -> disabled (quiet).
rc=$(sed -n 's/^recap=//p' "$FLAG" 2>/dev/null | tail -1)
[ -n "$rc" ] || rc=on
case "$rc" in
  on) threshold=1200 ;;
  off) exit 0 ;;
  [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9]) threshold=$rc ;;
  *) exit 0 ;;
esac

input=$(cat)

# Loop guard first: when this Stop hook runs as a result of our own block,
# stop_hook_active is true. Exit before any other work so a single extra turn
# is all we can ever force. This must precede the model lookup.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

# Stop fires for the main session only, but a subagent-carried agent_id here
# would still mean "not the main agent" — do nothing.
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
[ -z "$agent_id" ] || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 0
# `.` is a POSIX special builtin: a failed source aborts the shell before any
# fallback runs, so pre-check readability. If the lib is gone, omo_is_opus5 is
# undefined and the model check below fails closed (do nothing) — the safe
# direction here is to never spend an extra call on a session we cannot identify.
[ -r "$DIR/lib-model.sh" ] && . "$DIR/lib-model.sh"

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
omo_is_opus5_session "$tp" 2>/dev/null || exit 0

# Measure the ending message. jq's `length` on a string counts codepoints, not
# bytes — correct for non-ASCII text. last_assistant_message is ONLY measured
# here; it is never interpolated into the output below.
len=$(printf '%s' "$input" | jq -r '.last_assistant_message // "" | length' 2>/dev/null)
case "$len" in
  '' | *[!0-9]* ) exit 0 ;;
esac
# Record every evaluation, fired or not, so the threshold can be tuned against
# real usage instead of guesswork. Length and threshold only — the message text
# is never written anywhere. Kept outside the state dir so the 7-day prune of
# per-session files cannot delete the history.
fired=0
[ "$len" -gt "$threshold" ] && fired=1
printf '%s\t%s\t%s\t%s\t%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$sid" "$len" "$threshold" "$fired" \
  >> "${HOME}/.claude/oh-my-opus.log" 2>/dev/null || true

[ "$fired" = 1 ] || exit 0

# Force one more turn. Built with jq -n so the output is valid JSON by
# construction. The reason text is fixed and carries no input.
jq -n '{
  decision: "block",
  reason: "Your last message ran long. Reply with a recap and nothing else: the essential point, anything the user must decide, and — only if you changed something — what changed. No preamble, no restating detail from above, most important line last. If your last message ended with a question or asked the user to choose, keep that question as the final line."
}'
exit 0
