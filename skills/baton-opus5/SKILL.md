---
name: baton-opus5
argument-hint: "[on [maxagents=auto|0-99] [recap=on|off|<chars>] | off | maxagents auto|0-99 | recap on|off|<chars> | status]"
description: Bound an Opus 5 session at its edges without steering how it works — a per-turn subagent cap, an optional end-of-turn recap, cheap workers it may call by choice, and a fresh-context reviewer for high-consequence changes. Invoke only when the user runs /baton-opus5 or asks about the mode; never implicitly.
---

Opus 5 decides how to work. This plugin does not tell it. The rule is: **constrain the boundary, never the interior.** A boundary is a budget or a check at an edge — the subagent cap and the optional recap. The interior is how the turn actually runs: mandated process, forced delegation, per-turn posture injection, step-by-step instructions. This plugin ships boundaries and refuses to ship interior controls.

## What ships

Three workers, all available and never required: `scout` (Haiku, read-only recon), `coder` (Sonnet 5, implements a handed stage), `reviewer` (Opus 5, fresh-context adversarial review of a final diff). The session calls them if and when it judges they help.

Two mechanisms: a per-turn **cap** on how many subagents the main agent may spawn, and an optional end-of-turn **recap** (asks for a short recap when a turn ends long; costs one extra model call on those turns).

## Commands

Handle the argument first, confirm in one line, then stop.

- `on [maxagents=<v>] [recap=<v>]` — write the flag file, defaults `maxagents=auto`, `recap=on`:
  `printf 'maxagents=<m>\nrecap=<r>\n' > ~/.claude/baton-opus5`
- `off` — `rm -f ~/.claude/baton-opus5` (plugin goes inert).
- `maxagents auto|0-99` — rewrite only that line, keep the current `recap`.
- `recap on|off|<chars>` — rewrite only that line, keep the current `maxagents`.
- `status` — report both current values.

## Cap semantics

`auto` means a cap of 10 under an Opus 5 session and unlimited otherwise. `0` is unlimited. `1`-`99` is a hard cap regardless of model. The per-turn counter resets on every user prompt. The session model is recorded at `SessionStart`, because later hook payloads do not carry a model field — that is why the cap knows whether the session is Opus 5.

## Recap semantics

`recap=on` (the default) fires the recap when the ending message exceeds **1200 characters**; `off` disables it; an integer `1`-`99999` sets a custom threshold. The threshold counts characters (codepoints), not bytes. The recap fires only in an Opus 5 session and only when the ending message exceeds the threshold, costing one extra model call on those turns.

Missing flag file means the plugin is inert: no cap, no recap, nothing written.
