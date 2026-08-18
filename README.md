# baton-opus5

Bound an Opus 5 session at its edges without steering how it works.

## Premise

baton-opus5 is the deliberate inverse of [baton](https://github.com/KyongSik-Yoon/baton). baton runs the session as a hook-enforced pure orchestrator: it blocks the main agent's edits and forces delegation. This plugin does the opposite. It constrains **the boundary, never the interior.**

- A **boundary** is a budget or a check at an edge: the per-turn subagent cap, an optional end-of-turn recap, and a fresh-context review you may ask for. These are the only things this plugin enforces.
- The **interior** is how a turn actually runs: mandated process, forced delegation, per-turn posture injection, step-by-step instructions. baton ships these on purpose. baton-opus5 refuses to — Opus 5 decides how to work.

If baton is a harness, baton-opus5 is a guardrail on the edge of the road. They are siblings that take opposite approaches; pick the one that matches how much you want to steer.

## What ships

Three workers, all **available by choice and never required**:

- `scout` — Haiku, read-only recon. Cheap file discovery and evidence gathering instead of the expensive built-in Explore.
- `coder` — Sonnet 5, implements a handed stage against clear acceptance criteria.
- `reviewer` — Opus 5, read-only adversarial review of a final diff. Pinned to the session's own model on purpose: the value is a fresh context that did not produce the change, not a stronger model.

Two mechanisms:

- **Subagent cap** — a per-turn limit on how many subagents the main agent may spawn. `auto` is 10 under an Opus 5 session and unlimited otherwise; `0` is unlimited; `1`-`99` is a hard cap. The counter resets on every user prompt.
- **Recap** — an optional short recap when a turn ends long, at the cost of one extra model call on those turns. It fires only in an Opus 5 session and only when the ending message exceeds the threshold. `on` (the default) uses 1200 characters; `off` disables it; an integer `1`-`99999` sets a custom threshold. The threshold counts characters, not bytes.

## Install

Add this directory as a marketplace plugin in Claude Code, then enable `baton-opus5`. The plugin is **inert until you turn it on** — no flag file means no cap, no recap, nothing written.

## Usage

Run `/baton-opus5`:

- `on [maxagents=auto|0-99] [recap=on|off|<chars>]` — turn on (defaults `maxagents=auto`, `recap=on`).
- `off` — turn off; the plugin goes inert.
- `maxagents auto|0-99` — change the cap, keep the recap setting.
- `recap on|off|<chars>` — change the recap setting, keep the cap.
- `status` — report both current values.

State lives in `~/.claude/baton-opus5` (flag file) and `~/.claude/baton-opus5-state/` (per-session model capture and per-turn slot dirs, pruned after 7 days). `session-state.sh` only records the model at `SessionStart`, so turning the plugin on mid-session leaves both the cap and the recap inactive until the next session start.

## Why this exists

Heavy orchestration harnesses can fight a capable model as much as they help it. baton-opus5 is the experiment in the other direction: give the session cheap tools and a hard budget at the edges, then get out of its way. It is a sibling of https://github.com/KyongSik-Yoon/baton, which takes the opposite approach on purpose.

## License

MIT — see [LICENSE](./LICENSE).
