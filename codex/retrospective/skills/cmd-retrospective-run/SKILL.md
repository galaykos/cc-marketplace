---
name: cmd-retrospective-run
description: "Use when the user asks to run a five-minute retrospective on the work just completed — surprises, friction, learnings — and route each into its sink (CLAUDE.md, skill suggestion, process tweak)."
---

_This skill wraps the `/retrospective:run` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Run the retrospective protocol from the retrospective skill on $ARGUMENTS
(default scope: the most recent completed task run, feature, or milestone in
this session; if the session holds no completed work, say so and stop).

1. Collect evidence from the actual session: what contradicted assumptions,
   which steps looped or stalled, what was re-derived that should have been
   known.
2. Produce the three-sink table (CLAUDE.md candidates / skill or automation
   suggestions / process tweaks) per the skill.
3. Propose — never silently write. Offer each banked artifact as a
   selectable choice: "Apply CLAUDE.md lines" (multi-select per line),
   "Scaffold the suggested skill now" (proceeds as
   the `cmd-claude-authoring-new-skill` skill would) / "Skip". Typed commands only when
   headless.
4. Keep it under a page. A retro longer than the work it reviews is theater.
