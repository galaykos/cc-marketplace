# Dispatch prompts — the brief, the worker, the reviewer, the browser tester

The orchestrator's prompt is the only thing a delegate ever sees. When `orchestration`
is installed, `cat` its `delegation-contracts/references/discipline-preamble.md` into the
prompt — never retype it; a retyped preamble shed one clause per dispatch in the first
simulation. Write each prompt to `milestones/<id>/dispatch/<n>.md` and run
`program.sh dispatch check <file>` before spawning: it refuses a prompt whose preamble
clauses are missing or reworded, or that lacks `TOUCH ONLY`, `VERIFY`, or a `…/SKILL.md`
path that exists. The minimal rules below apply either way:
absolute paths everywhere; the scope lock stated as touch/do-not-touch; the verify
commands inside the prompt; the return shape and length cap stated; "your final message
is data for the orchestrator, not prose for a human".

## Resolving a skill path (do it yourself; the delegate cannot)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/skill-path.sh <plugin> <skill>            # installed plugin skill
${CLAUDE_PLUGIN_ROOT}/scripts/skill-path.sh project <skill> --project <root>   # <root>/.claude/skills/<skill>
```

It resolves through the CLI's `installPath` when the plugin is enabled in this session and
falls back to the newest cache directory that HAS the file, printing which route it used.
A skill name that resolves only to an old version has been renamed or retired — read the
plugin's current skill list before pinning it (a `database-design` skill existed only up <!-- removed-ok -->
to database 0.4.2; simulation 2 pinned it without noticing).

Inject as: `Read <abs-path> before writing; it is the authoritative best-practice source
for this stack.` A miss is skipped silently, never invented.

## State files and siblings — two lines every prompt carries

`STATE FILES: brief <abs>, findings <abs>, decisions <abs>` — a delegate told to "apply the
recorded decisions" without a path reports "decisions.md does not exist" (it did, elsewhere).
`dispatch check` warns when one of those names appears without an absolute path.
`SIBLINGS: <who else is editing this tree, which files are theirs>` — or "none". A worker
that sees unexplained changes in `git status` stops to report them; tell it first.

## Brief (`milestones/<id>/brief.md`) — what taskmaster or the cards are built from

```
# <id> — <title>
Program: <goal>  ·  Branch: <branch>  ·  Depends on: <ids or none>
## Goal
One paragraph: what a user can do when this is done, and why it is next.
## Acceptance (each line is something a browser can show)
- [ ] <user action> → <visible result>
- [ ] <invalid input> → <named error, input preserved>
- [ ] Works at 375, 768 and 1280 px wide; no horizontal scroll; primary action reachable
- [ ] Console clean; suite green (`<verify command>`)
## Binding decisions (from charter.md)
Library: … · Motion: … · States: … · Dependencies: none without a decisions.md entry
## Scope
Touch: <dirs/files>. Do not touch: <dirs/files>.
## Skills to read (absolute paths)
- <path> — why
## Project rules
<the lines from CLAUDE.md/AGENTS.md that bind: deps, structure, docs, verification>
## Verify
<exact commands: suite, types, lint, build>
```

Hand it over as `/taskmaster:task ultra-goal <the brief text>` (hands-off) or
`/taskmaster:task <brief>` (interactive); taskmaster's grill treats the acceptance lines
as CLEAR rows and asks only about what the brief left open.

## Worker (no taskmaster/task-runner installed, or a card dispatched directly)

```
You are implementing ONE card in <abs project root>. Cwd resets between commands: use
absolute paths or `git -C`.
CARD: <title>. DONE WHEN: <criteria copied from the brief>.
STATE FILES: brief <abs>, findings <abs>, decisions <abs>.   SIBLINGS: <none | who, files>.
TOUCH ONLY: <files, listed — never "the files in the brief">. DO NOT TOUCH: <files>.
Adding a dependency is out of scope. Never leave a dev server running: stop what you
start and delete the hot file before returning.
READ FIRST: <skill abs paths, one per line, with why — at least one, always>.
DESIGN (page or component builds only; binding, from charter.md § Product decisions):
  layout per width (375 / 768 / 1280) · states (empty, loading, error, success — the copy)
  · every interactive element and its keyboard path · focus after each action · data-test
  hooks · which primitives to ADD to the owned library when one is missing (say it here,
  or the worker will build a local one) · motion: what moves, ≤ N ms, motion-safe only.
CONVENTIONS: <project rules>. Match sibling files for structure and naming.
VERIFY: run <commands>; paste the last 15 lines of each. For a guard you add, paste a
control run with the guard removed showing the new test fail.
RETURN (max 25 lines): completion table; files touched; behaviour no test exercises;
parked items. No narrative. Your final message is data for the orchestrator.
```

## Direction (a read-only creative or technical direction, BEFORE a build)

```
You are the <creative director | architect> for <surface> in <abs root>. You WRITE NO
FILES; you return a document the orchestrator saves as milestones/<id>/direction.md.
READ FIRST: <skill abs paths — craft-layer creative-direction, section-decisions,
motion-tiers, … or the stack's design skills>; the project's tokens/files: <abs paths>.
RAW BRIEF (the user's words win): "<…>". Ambition: <…>. Dependencies allowed: <list>.
SIZE THE ENGINE FIRST: any perf budget you write must sit above the floor of the
libraries you mandate (motion core + features ≈ 42 KB gz; say the number, then budget).
PRODUCT VOCABULARY: <the nouns and counts the other milestones ship — stages, roles,
object names>; never describe a capability that is not in a done or queued milestone.
RETURN (max 120 lines, this structure): <sections>. No narrative outside it.
```
Gate it with `program.sh dispatch check <file> --kind reader`. The overseer amends the
returned direction in `decisions.md` before the build worker sees it — and checks it
against the other milestones' contracts (simulation 2's direction sold four renameable
stages; the product shipped five fixed ones).

## Reviewer (read-only)

```
Review the diff `git -C <root> diff <base>...<branch>` against <skill abs paths>.
One line per finding: `path:line — severity — problem — fix`. Severity-sorted.
Skip style nits unless they change meaning. Max 30 lines. End with `CLEAN` when none.
```

## Browser tester (the acceptance walk, when delegated)

```
App URL: <url>. Credentials: <how to log in>. Tools: <Playwright MCP | Chrome MCP>.
For each acceptance line in <brief path>: perform it, screenshot to
<abs evidence dir>/<slug>-<width>.png, note console errors and network failures.
Widths: 375, 768, 1280. Report one line per acceptance line per width:
`<line> — <width> — PASS|FAIL — <evidence file> — <note>`. Max 40 lines.
```

The overseer records the returned lines with `program.sh evidence add`; a FAIL is a
finding for the fix loop, not a reason to soften the acceptance line.
