---
description: Get an independent stronger-model second opinion at a key moment — composes a facts-only brief (no leaning) and dispatches the blind stronger-model consultant; prints its Take, Risks, and one Alternative. Advice only.
argument-hint: [topic — what to get a fresh take on]
---

Consult the fresh-eyes consultant per this plugin's `consult` skill
(`skills/consult/SKILL.md` — the binding contract; read it first). Do not
write implementation code as part of this command.

1. **Classify the moment.** `stuck-debug` — the session has repeated failed
   fix attempts on one problem; `irreversible` — a destructive or one-way
   action is imminent (drop, force-push, history rewrite, bulk delete, contract
   freeze). If `$ARGUMENTS` is empty, take the topic from the most recent
   problem in the conversation; if `$ARGUMENTS` names one, use it verbatim.

2. **Compose the brief** with exactly the skill's four fields:
   - Moment type.
   - Problem statement — observable state only: the failing output
     (`stuck-debug`) or the target and what depends on it (`irreversible`).
   - History / plan — attempts and their actual results, or the exact action
     about to run and why now.
   - Relevant repo-relative paths.

   **Blind rule:** the brief must not contain your preferred answer, current
   hypothesis, leading framing, or ranked options. Attempts are facts and go
   in; the conclusions you drew from them stay out.

3. **Dispatch** the `consultant` agent from this plugin with the brief as its
   prompt, passing `model:` = the session model or opus, whichever is HIGHER on
   `haiku<sonnet<opus<fable` — an active upward override, never merely the absence
   of a downward one. One consultant, one dispatch — no panel, no retry for a
   better answer, and never a tier below the session model.

4. **Relay verbatim.** Print the consultant's `Take`, `Risks`, and
   `Alternative` sections exactly as returned — no paraphrase, no merging into
   your own narrative — followed by the closing line: "advice only — your
   call."

5. **Degraded path.** If the dispatch errors or the return is empty or missing
   the three sections, print the one-line notice "no advice returned" and
   continue the session normally. Never retry in a loop, never fabricate a
   take, never treat the failed consult as a reason to stop the user's action.
