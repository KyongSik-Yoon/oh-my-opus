#!/bin/sh
# oh-my-opus agent cap: PreToolUse hook on Task|Agent. While the flag file
# exists, cap how many subagents the MAIN agent may spawn in a single turn. Only
# the main agent is capped (subagent spawns carry agent_id). The counter is reset
# per turn by turn-reset.sh on UserPromptSubmit. Fails OPEN everywhere: a missing
# flag, missing state, or bad session id never blocks a spawn.
FLAG="${HOME}/.claude/oh-my-opus"
[ -f "$FLAG" ] || exit 0

input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# Only the main agent is capped; a subagent spawn carries a non-empty agent_id.
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
[ -z "$agent_id" ] || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
case "$sid" in
  '' | *[!A-Za-z0-9_-]* ) exit 0 ;;
esac

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 0
# `.` is a POSIX special builtin: a failed source aborts the shell before any
# fallback runs, so pre-check readability. If the lib is gone, omo_effective_cap
# is undefined below and the [ -n "$cap" ] guard fails OPEN (allow) — safe.
[ -r "$DIR/lib-model.sh" ] && . "$DIR/lib-model.sh"

cap=$(omo_effective_cap "$sid" 2>/dev/null)
[ -n "$cap" ] || exit 0

STATE="${HOME}/.claude/oh-my-opus-state"
slotdir="${STATE}/${sid}.agents"

# Atomic per-turn slot claim. mkdir is atomic on POSIX: for any given slot dir
# exactly one concurrent caller wins the create, so racing spawns in one
# assistant message cannot overshoot the cap. Try slots 1..cap; the first mkdir
# that succeeds claims that slot and allows the spawn. If every slot already
# exists, the cap is full for this turn -> deny. A denied spawn claims nothing,
# so the count cannot drift. cap is at most 99, so the loop is bounded and cheap.
# If the parent slot dir itself cannot be created, fail OPEN (allow), never deny.
mkdir -p "$slotdir" 2>/dev/null || exit 0

i=1
while [ "$i" -le "$cap" ]; do
  if mkdir "${slotdir}/${i}" 2>/dev/null; then
    exit 0  # claimed slot $i
  fi
  i=$((i + 1))
done

# Every slot is taken. Do NOT claim anything when denying.
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"oh-my-opus: this turn already spawned %s subagents (maxagents cap). Finish with what you already have, or stop and report to the user — they can raise it with /oh-my-opus maxagents <n>."}}\n' "$cap"
exit 0
