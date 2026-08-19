# oh-my-opus

Bound an Opus 5 session at its edges without steering how it works.

## Premise

oh-my-opus is the deliberate inverse of [baton](https://github.com/KyongSik-Yoon/baton). baton runs the session as a hook-enforced pure orchestrator: it blocks the main agent's edits and forces delegation. This plugin does the opposite. It constrains **the boundary, never the interior.**

- A **boundary** is a budget or a check at an edge: the per-turn subagent cap, an optional end-of-turn recap, and a fresh-context review you may ask for. These are the only things this plugin enforces.
- The **interior** is how a turn actually runs: mandated process, forced delegation, step-by-step instructions. baton ships these on purpose. oh-my-opus refuses to — Opus 5 decides how to work.

The harness overlay is the one deliberate exception to that rule, and it is worth naming as one. It is a per-turn injection, which is an interior control. It exists only to offset interior controls a project already imposes, and it is off unless the project opts in.

If baton is a harness, oh-my-opus is a guardrail on the edge of the road. They are siblings that take opposite approaches; pick the one that matches how much you want to steer.

## What ships

Four workers, all **available by choice and never required**:

- `scout` — Haiku, read-only recon. Cheap file discovery and evidence gathering instead of the expensive built-in Explore.
- `coder` — Sonnet 5, implements a handed stage against clear acceptance criteria.
- `reviewer` — Opus 4.8, read-only adversarial review of a final diff. Pinned one generation back on purpose: the value is a fresh context that did not produce the change, on a model that did not write it and will not defer to it — not a stronger model.
- `advisor` — Fable 5, one independent judgment on a question. Where the reviewer is a prior Opus with a fresh context, the advisor is a *different model family* with a fresh context, so the two miss different things.

The advisor has **no trigger**. Nothing in this plugin decides when to consult it, on purpose: a mandatory escalation gate is an interior control, and a second voice arriving after a direction is already chosen is a good way to manufacture the churn this plugin exists to avoid. The cheap moment for a second opinion is *before* you commit — a design you are about to build on, a decision you have already reversed once, evidence that will not reconcile. The session judges that moment itself, as it does with the other three.

Three mechanisms:

- **Subagent cap** — a per-turn limit on how many subagents the main agent may spawn. `auto` is 10 under an Opus 5 session and unlimited otherwise; `0` is unlimited; `1`-`99` is a hard cap. The counter resets on every user prompt.
- **Recap** — an optional short recap when a turn ends long, at the cost of one extra model call on those turns. It fires only in an Opus 5 session and only when the ending message exceeds the threshold. `on` (the default) uses 1200 characters; `off` disables it; an integer `1`-`99999` sets a custom threshold. The threshold counts characters, not bytes.
- **Harness overlay** — tells a frontier session (Opus 5 or Fable 5) to read a project's `CLAUDE.md`, skills, and workflow rules as context rather than a checklist. See [The overlay](#the-overlay). Opt-in per project; off everywhere else.

## Install

```
/plugin marketplace add KyongSik-Yoon/oh-my-opus
/plugin install oh-my-opus@oh-my-opus
```

Then `/oh-my-opus on`. Installing alone does nothing: the plugin is **inert until you turn it on** — no flag file means no cap, no recap, no overlay, nothing written. It only ever acts under Opus 5.

## Usage

Run `/oh-my-opus`:

- `on [maxagents=auto|0-99] [recap=on|off|<chars>] [overlay=on|off]` — turn on (defaults `maxagents=auto`, `recap=on`, `overlay=on`).
- `off` — turn off; the plugin goes inert.
- `maxagents auto|0-99` — change the cap, keep the rest.
- `recap on|off|<chars>` — change the recap setting, keep the rest.
- `overlay on|off` — the global kill switch for the overlay; per-project opt-in is separate, below.
- `status` — report all three values, and whether this project carries the overlay marker.

## The overlay

Most project harnesses were written for models that needed the scaffolding: do these steps in this order, delegate this stage, run this review ritual, answer in this shape. That scaffolding made weaker models reliable. On a current frontier model it mostly gets in the way, and you cannot always force a session onto a particular model, so deleting the scaffolding is not an option either.

That last point is also why the overlay is the one mechanism here that is not Opus-5-only. Its argument is about capability, not about a model id, so it applies to a Fable 5 session too — and a session you did not get to choose is exactly the one that most needs it. The other two mechanisms stay Opus-5-only: `auto` caps only an Opus 5 session, and the recap fires only there, because Fable's turns are already short enough (see below) that the extra call would buy nothing.

The overlay resolves that by changing how the rules are read rather than whether they exist:

- **Method becomes advisory** — step order, mandatory delegation or subagent use, review rituals, format and length conventions. The session follows its own judgment where that serves the task better.
- **Substance still binds** — paths you must not touch, commands you must run before finishing, acceptance criteria, security and compliance rules, and anything you said in the conversation.
- **Tool permissions and hook decisions are never advisory.** This plugin does not read, alter, or override them. If something is blocked, it stays blocked.
- **Departures are visible.** When the session deliberately sets a rule aside it says so in one line, so you can see what it did rather than discovering it later.

### Turning it on for a project

```sh
touch .claude/oh-my-opus
```

That marker is the opt-in, and any parent directory of the session cwd counts — except `$HOME` itself, whose `.claude/oh-my-opus` is the global flag file and is never read as a project marker. Three gates must all pass before a single word is injected: the session model is Opus 5 or Fable 5, the global flag does not say `overlay=off`, and the marker exists. Without the marker nothing happens — which is the point. A plugin that silently rewrote how every repository's rules are read, including repositories whose rules are not yours to reinterpret, would be a worse thing than the problem it solves.

Commit the marker if the team agrees the project's method rules are legacy scaffolding. Leave it untracked if that is your call alone.

State lives in `~/.claude/oh-my-opus` (the flag file) and `~/.claude/oh-my-opus-state/` (per-turn subagent slot directories, pruned after 7 days). Nothing about the session itself is cached, so turning the plugin on mid-session works immediately.

### How it knows the session is Opus 5

Not from the `SessionStart` payload. That payload carries a `model` field only sometimes: a headless `claude -p` run has none, and an interactive session started without an explicit `--model` was observed to have none either, which left the plugin silently inert in exactly the sessions it was meant for.

Instead every hook reads the model out of the transcript. Every hook payload carries `transcript_path`, and every assistant entry in that JSONL records the model that produced it. That works however the session was launched, follows a mid-session `/model` switch, and costs about 17 ms on a 2 MB transcript because the tail is scanned first. Two details matter: sidechain entries are skipped, since a Sonnet subagent's turn would otherwise mask an Opus 5 session; and before the first assistant reply the model is simply unknown, so everything fails open.

## Where the numbers come from

Both defaults were measured against 55 real transcripts (114 user turns) rather than chosen by feel.

**Recap threshold, 1200 characters.** The final message of a turn, by session model:

| model | turns | median | p90 | over 1200 |
| --- | --- | --- | --- | --- |
| `claude-opus-5` | 34 | 700 | 1601 | 23.5% |
| `claude-fable-5` | 61 | 187 | 1245 | 11.5% |

Opus 5's median turn is 3.7x longer than Fable's, which is the verbosity complaint in numbers. It is also why the recap stays Opus-5-only while the overlay does not: a Fable session clears 1200 on 11.5% of turns and its p90 sits at 1245, right on the threshold — the long tail the recap exists to catch barely exists there. 1200 sits near the Opus 5 p76, so the recap fires on roughly the top quartile of turns — where scanning actually breaks down — and costs an extra call about one turn in four. Note what it does and does not do: the recap is appended, not substituted, so it buys scannability, not fewer tokens.

**Subagent cap, 10.** Across the same 114 turns the maximum spawned in a single turn was **3**, and 62% of turns spawned none. A cap of 5 would not have bound either. This cap is insurance against a fan-out that has not yet been observed here, not a fix for a measured problem — treat 10 as a ceiling that should never fire, and lower it only if you see a runaway.

**Tuning it yourself.** Every time the recap hook evaluates a turn it appends one line to `~/.claude/oh-my-opus.log`:

```
2026-08-18T22:54:10Z	<session id>	1500	1200	1
```

Timestamp, session id, message length, threshold in force, and whether it fired. **The message text is never written** — only its length. Turns that were skipped before measurement (a non-Opus-5 session, or the second half of a recap pair) are not logged, so the file is exactly the population the threshold applies to.

After a week of real use, that file answers whether 1200 is right for you:

```sh
awk -F'\t' '{n++; s+=$5; if($3>m) m=$3; a[n]=$3}
  END{asort(a); printf "turns %d  fired %d (%.0f%%)  median %d  p90 %d  max %d\n",
      n, s, 100*s/n, a[int(n*0.5)], a[int(n*0.9)], m}' ~/.claude/oh-my-opus.log
```

If it almost never fires, your own output style or system prompt is already doing the work and you can set `recap=off` — the hook is not earning its extra call. If it fires on most turns, lower the threshold or fix the upstream instruction instead of paying for a recap every turn. The recap is a backstop for a standing instruction that decays; its firing rate is the measurement of that decay.

## Why this exists

Heavy orchestration harnesses can fight a capable model as much as they help it. oh-my-opus is the experiment in the other direction: give the session cheap tools and a hard budget at the edges, then get out of its way. It is a sibling of https://github.com/KyongSik-Yoon/baton, which takes the opposite approach on purpose.

## License

MIT — see [LICENSE](./LICENSE).
