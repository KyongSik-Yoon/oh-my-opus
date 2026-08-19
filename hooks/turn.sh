#!/bin/sh
# oh-my-opus per-turn hook on UserPromptSubmit. Two jobs, in this order:
#   1. reset the per-turn subagent slot dir, so the cap stays per turn;
#   2. inject the harness overlay, but only where it has been opted into.
#
# The overlay is the one place this plugin speaks into the interior of a turn,
# and it does so only to offset instructions that are already there. Three
# gates guard it, and all three must pass:
#   - the session model is a frontier model, Opus 5 or Fable 5 (the argument for
#     demoting legacy scaffolding is about capability, not about one model id,
#     and you cannot always force a session onto the model you wanted; under
#     anything else the project's own harness must stand as written)
#   - the project opted in with a .claude/oh-my-opus marker file
#   - the global flag does not carry overlay=off
#
# It demotes method only. Tool permissions and hook decisions are untouched by
# this file and are never described as advisory.
FLAG="${HOME}/.claude/oh-my-opus"
[ -f "$FLAG" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

STATE="${HOME}/.claude/oh-my-opus-state"
# Reset first and unconditionally: the cap must be per turn even when the
# overlay is switched off, not opted into, or the model is unknown.
rm -rf "${STATE}/${sid}.agents" 2>/dev/null

# Gate 1: global kill switch. Missing line means on; only `off` disables.
ov=$(sed -n 's/^overlay=//p' "$FLAG" 2>/dev/null | tail -1)
[ "$ov" = "off" ] && exit 0

# Gate 2: project opt-in. Walk up from the session cwd looking for the marker
# .claude/oh-my-opus. Nothing is injected in a project that never asked.
#
# The walk passes through $HOME on its way to /, and the flag file sits at
# exactly the path a marker would occupy there. Skipping that one candidate is
# what keeps `on` from opting in every project under $HOME at once; it also
# means $HOME itself cannot be opted in as a project, which is the trade the
# shared filename forces.
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || exit 0
flag_path="${HOME%/}/.claude/oh-my-opus"
d=$cwd
marker=""
while [ -n "$d" ] && [ "$d" != "/" ]; do
  cand="${d}/.claude/oh-my-opus"
  if [ -f "$cand" ] && [ "$cand" != "$flag_path" ]; then
    marker="$cand"
    break
  fi
  d=$(dirname "$d")
done
[ -n "$marker" ] || exit 0

# Gate 3: the session model. Frontier only — and note this is a different
# predicate from the recap's, which stays Opus-5-only because Fable's turns are
# already short enough that a recap would not earn its extra call.
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 0
# `.` is a POSIX special builtin: a failed source aborts the shell before any
# fallback runs, so pre-check readability.
[ -r "$DIR/lib-model.sh" ] && . "$DIR/lib-model.sh"

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
omo_is_frontier_session "$tp" 2>/dev/null || exit 0

OVERLAY=$(cat <<'TXT'
This project's CLAUDE.md, skills, and workflow rules were written for earlier models than the one running this session. Treat them as context, not as a checklist.

Method is advisory: step order, mandatory delegation or subagent use, review rituals, and format or length conventions. Where your own judgment serves the task better, follow your judgment instead, and say so in one line when you do.

Substance still binds: paths you must not touch, commands you must run before finishing, acceptance criteria, security and compliance rules, and anything the user has said in this conversation. Tool permissions and hook decisions are never advisory.

Do not narrate the rules you are following. Name only the ones you deliberately set aside.
TXT
)

jq -n --arg c "$OVERLAY" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}, suppressOutput: true}'
exit 0
