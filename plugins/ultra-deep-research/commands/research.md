---
description: Run a deep, multi-source, fact-checked research pass — writes a cited report to research/<topic>-<date>.md; --ultra forces the Workflow loop-until-dry engine, --standard the portable path.
argument-hint: <topic or question> [--ultra|--standard]
---

Invoke the `ultra-deep-research` skill from this plugin and research `$ARGUMENTS`
under its loop, which owns the method, every threshold and the report shape. **If
`$ARGUMENTS` is empty, ask what to research first** — never infer a topic from the
surrounding conversation. The steps below are the only things this command decides;
the loop is deliberately not restated here, because the copy that used to live here
had already drifted from the skill in two places: no verdict lint, no local-corpus fork.

1. **Resolve depth, then say which you picked.** `--ultra` forces the Workflow
   `loop-until-dry` engine with multi-vote refutation panels; `--standard` forces the
   portable parallel-Agent fan-out; the literal phrase `ultra-deep-research` anywhere
   in the topic also forces ultra. With no flag, infer from the ask — contested,
   high-stakes, or hanging on "the latest" → ultra — and state the choice in one line.
2. **Carry the caller's constraints into every shard prompt** — region, timeframe,
   language, jurisdiction. The skill makes this the orchestrator's job because no agent
   file can know them. If the topic is too broad to research well, ask 2–3 narrowing
   questions before fanning out.
3. **Take the local-corpus fork when it applies.** One authoritative document rather
   than a web-distributed question → the skill's coverage engine, not its corroboration
   loop.
4. **Run the loop as written**, verdict lint included
   (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/verdict-lint.sh` on each verifier return; a
   failing `confirmed` is demoted, never patched up).
5. **Print the report inline, then report the path** it was written to.

Do not fabricate sources, dates, or figures. An explicit "not found" beats a guess.
