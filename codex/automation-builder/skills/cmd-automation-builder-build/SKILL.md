---
name: cmd-automation-builder-build
description: "Use when the user asks to plan and build a browser automation from a goal — pick the tool, sequence the flow, then scaffold via the engineer agent."
---

_This skill wraps the `/automation-builder:build` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Plan and build a browser automation for $ARGUMENTS (an automation goal — if
empty, ask what should be automated and against which target).

1. Invoke the `automation-planning` skill from this plugin for $ARGUMENTS: state
   the goal, target, and auth needs, then walk the tool decision tree.
2. Pick the tool (Playwright / Puppeteer / AdsPower / Kameleo / Camoufox) and
   present the sequenced plan — flow modelled as discrete steps with explicit
   wait conditions, error/retry and idempotency, extraction and storage,
   session persistence, concurrency/proxy strategy, and cleanup. Name the
   matching `/…:check` command for the chosen tool's specifics.
3. Ask via AskUserQuestion: "Build it now with the browser-automation-engineer
   (Recommended)" / "Stop — plan only". Headless: plan only.
4. On build, dispatch the `browser-automation-engineer` agent with the full
   plan (tool, language, sequenced steps, target, auth, and cleanup
   requirements). The agent verifies the API against current docs, scaffolds
   the automation, and runs or syntax-checks it — reporting the command run and
   its output.
