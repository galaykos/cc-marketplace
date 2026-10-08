# skill-router mods: skill-listing and compaction probe (2026-10-08)

Purpose: settle the open questions of `taskmaster-docs/specs/2026-10-08-mods-round-3-survey.md`
rows #1 and #2 before skill-router 0.25.0 ships them. Row #1 is a stack-scoped skill listing
through `prompt.attachment`; row #2 is compaction steering through `session.compact`.

**Standing: `recorded`** — a one-time measurement; nothing re-runs it.

## Method

- CLI 2.1.294, driven in a pseudo-terminal with python `pexpect` and the `pyte` VT emulator.
- A scratch `CLAUDE_CONFIG_DIR` and a placeholder API key.
- `ANTHROPIC_BASE_URL` pointed at a local stand-in for the API. It logs every request body as
  JSONL and answers each request with a fixed reply, streamed when asked; one variant answers
  with a `tool_use` block. **No real model was called.**
- Plugins were loaded with `--plugin-dir`: skill-router, laravel and web-dev, so the stack skills
  are in the listing.

## Results

| Question | Result |
|---|---|
| Listing format | A heading line `The following skills are available for use with the Skill tool:`, a blank line, then one `- name: description` entry per skill. A description may wrap onto later lines. It was sent once per session, inside a `system`-role message of the request. |
| Does the rewritten listing reach the API? | Yes. Every logged request lacked the dropped entries and carried the replacement line: `Listed by name only, as this repository shows no evidence of their stack (skill-router); the Skill tool still loads each: laravel:inertia-best-practices, laravel:laravel-best-practices, web-dev:nextjs-best-practices, web-dev:react-native-best-practices, web-dev:vite-best-practices.` |
| Does a hidden skill still load by name? | Yes. A `Skill` `tool_use` naming the hidden `laravel:laravel-best-practices` returned `Launching skill: laravel:laravel-best-practices` and the skill body. Hiding changes what is listed, never what loads. |
| Does a `session.compact` instruction rewrite reach the summarizer? | Yes. `/compact` with a phase sentinel and an active run on disk sent a summarization request carrying: `Pipeline state is open on disk (skill-router read it). In the summary keep, word for word … State found: arc phase build owned by task-runner:run, declared by another session (.claude/cc-phase.json); task-runner run ship-x on branch main, cards at taskmaster-docs/tasks/ship-x/00-INDEX.md (.claude/task-runner/active-run.json).` |
| Without state? | The summarization request carried none of it. |
| Appending a message to the summary output? | Accepted, but it drew in the transcript as a `❯` row, as though the user had typed it. It also repeats what `compact-capsule.sh` restates afterwards, so it was not shipped. |

## Not measured

- An automatic compaction. Only a manual `/compact` was driven.
- Whether a shorter listing makes the right skill fire more often. The one measurement of
  listing overflow (`rationale/2026-09-15-listing-eviction-probe.md`) is why the listing feature
  ships off.
- Real-model behaviour on the steered summary: whether the summary actually keeps what it is
  asked to keep.
