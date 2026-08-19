---
name: oh-my-opus
argument-hint: "[on [maxagents=auto|0-99] [recap=on|off|<chars>] [overlay=on|off] | off | maxagents auto|0-99 | recap on|off|<chars> | overlay on|off | status]"
description: Bound an Opus 5 session at its edges without steering how it works — a per-turn subagent cap, an end-of-turn recap, cheap workers it may call by choice, a fresh-context reviewer, and an opt-in overlay that demotes a project's legacy method instructions to advice. Invoke only when the user runs /oh-my-opus or asks about the mode; never implicitly.
---

Opus 5 decides how to work. This plugin does not tell it. The rule is: **constrain the boundary, never the interior.** A boundary is a budget or a check at an edge — the subagent cap and the recap. The interior is how a turn actually runs: mandated process, forced delegation, step-by-step ritual.

The overlay is the one deliberate exception, and it is an exception on purpose. It is a per-turn injection, which is an interior control — but it exists only to offset interior controls a project already imposes, and it stays silent unless that project opts in. It is also the one mechanism that is not Opus-5-only; it applies to a Fable 5 session too.

## What ships

Four workers, all available and never required: `scout` (Haiku, read-only recon), `coder` (Sonnet 5, implements a handed stage), `reviewer` (Opus 4.8, fresh-context adversarial review of a final diff), `advisor` (Fable 5, one independent judgment on a question). The session calls them if and when it judges they help.

The advisor is a different model family with a fresh context where the reviewer is a prior Opus generation with a fresh context — neither one wrote the change, and they miss different things. It has no trigger and this plugin never mandates one — a second opinion is cheap before a direction is committed to and expensive after, and the session is the thing that knows which it is looking at.

Three mechanisms: a per-turn **cap** on subagent spawns, an end-of-turn **recap** when a turn runs long, and the harness **overlay**.

## Commands

Handle the argument first, confirm in one line, then stop.

- `on [maxagents=<v>] [recap=<v>] [overlay=<v>]` — write the flag file, defaults `maxagents=auto`, `recap=on`, `overlay=on`:
  `printf 'maxagents=<m>\nrecap=<r>\noverlay=<o>\n' > ~/.claude/oh-my-opus`
- `off` — `rm -f ~/.claude/oh-my-opus` (plugin goes inert).
- `maxagents auto|0-99` / `recap on|off|<chars>` / `overlay on|off` — rewrite only that line, keep the others.
- `status` — report all three values, and whether the current project carries the overlay marker.

## Cap semantics

`auto` means a cap of 10 under an Opus 5 session and unlimited otherwise. `0` is unlimited. `1`-`99` is a hard cap regardless of model. The per-turn counter resets on every user prompt. How the cap knows the session is Opus 5: every hook payload carries `transcript_path`, and every assistant entry in that transcript records the model that produced it, so the hooks read the model there. Subagent (sidechain) entries are skipped, or a Sonnet worker could mask the session. Before the first assistant reply the model is unknown and the cap fails open.

## Recap semantics

`recap=on` (the default) fires when the ending message exceeds **1200 characters**; `off` disables it; an integer `1`-`99999` sets a custom threshold. It counts characters (codepoints), not bytes, and costs one extra model call on the turns it fires. It fires in an Opus 5 session only — unlike the overlay, it does not extend to Fable 5, whose turns are already short enough that the extra call would not earn itself.

## Overlay semantics

Project harnesses were mostly written for models that needed the scaffolding. The overlay tells a frontier session to read a project's `CLAUDE.md`, skills, and workflow rules as context rather than a checklist: **method** becomes advisory (step order, mandatory delegation, review rituals, format conventions) while **substance** still binds (paths not to touch, commands to run before finishing, acceptance criteria, security and compliance). Tool permissions and hook decisions are never advisory and this plugin does not touch them. When the session sets a rule aside deliberately it says so in one line, so the departure stays visible.

Three gates all have to pass, so it is quiet by default: the session model is **Opus 5 or Fable 5**, the flag does not say `overlay=off`, and **the project opted in** by creating a marker file `.claude/oh-my-opus` in the repo (any parent directory of the session cwd counts, except `$HOME` itself — the file there is the global flag, not a marker, so opting in the plugin never opts in every project under `$HOME`). Without that marker nothing is injected — which is what keeps the plugin from silently rewriting the rules of a repository that never asked.

Missing flag file means the plugin is inert: no cap, no recap, no overlay, nothing written.
