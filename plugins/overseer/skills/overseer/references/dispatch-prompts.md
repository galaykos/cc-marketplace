# Dispatch prompts — the brief, the worker, the reviewer, the browser tester

The orchestrator's prompt is the only thing a delegate ever sees. When `orchestration`
is installed, `cat` its `delegation-contracts/references/discipline-preamble.md` into the
prompt — never retype it; a retyped preamble shed one clause per dispatch in the first
simulation. Write each prompt to `milestones/<id>/dispatch/<n>.md` and run
`program.sh dispatch check <file>` before spawning: it refuses a prompt in which any line of
any preamble clause is missing or reworded (whitespace folded, so a reflow passes), or that
lacks `TOUCH ONLY`, `VERIFY`, or a `…/SKILL.md` path that exists. Exit 0 records the file's
checksum and kind in `dispatch/.gated`; `accept` counts only gated, unchanged files, so a
prompt sent without the check — or edited after it — is not part of the record. The minimal rules below apply either way:
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

## The model per seat — one line every prompt carries, bound by the program tier

`MODEL: <value>` names the model the Agent call passes for this seat; `dispatch check`
refuses a prompt without it, with a value above the program's tier (`init --model`,
default `opus`), or with `inherit` on a worker under any tier. Simulation 3 ran two thirds of its subagent turns on the session model
because no dispatch said one and every `inherit` agent followed the session.

| Seat | tier `opus` (default) | tier `auto` (`/overseer:start … --model auto`) |
| --- | --- | --- |
| card worker (task-executor, web-developer, engineers) | `opus` | `opus` — a card with a locked file set and a DONE WHEN list does not need more |
| direction, adversary, reviewer, critic | `opus` | `inherit` (the session model) — the judgment seats are where capability shows |
| scout, explorer | `sonnet` or `opus` | same — native is enough for a read |

Below the tier is always allowed (`sonnet`, `haiku`). The tier binds only prompts the
overseer writes: taskmaster's own red-team and coverage seats resolve `auto` against the
session model under `goal`, so the one way to hold every seat at opus is to start the
session with `claude --model opus`.

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
Primitives to ADD to the owned library first: <list or none> — decided here, never by a worker
## Scope
Touch: <dirs/files>. Do not touch: <dirs/files>.
## Skills to read (absolute paths)
- <path> — why
## Project rules
<the lines from CLAUDE.md/AGENTS.md that bind: deps, structure, docs, verification>
## Verify
<exact commands: suite, types, lint, build>
```

Add a `## Rigour` block (next section) before handing over. Hand it over as
`/taskmaster:task <brief>` (interactive; grill treats the acceptance lines as CLEAR rows and
asks only about what the brief left open), `/taskmaster:task ultra <brief>` when the profile
is adversarial, or `/taskmaster:task goal <brief>` (hands-off — `goal` is autonomy plus the
boost, whatever the profile; the residual is a `decisions.md` row). Every milestone sized M
or larger goes to taskmaster; only an S milestone may skip to the worker template below, and
the skip is a `decisions.md` row (`dispatch check --milestone` WARNs when it is missing). When
the card index has two-plus parallel groups, hand execution to `/task-runner:run --tracks`.

## Rigour — what scrutiny a milestone buys, decided from the brief, not from its size

The size letter says how much work a milestone is; it says nothing about how wrong the
work can be. Simulation 4 priced the boost by size and got both directions wrong: "reserve
it for L/XL" could never fire (an M milestone was five cards and 119 minutes) and "WARN on
a boosted S/M" always did. What taskmaster's `ultra`/`goal` marker actually buys on top of a
standard run — the per-card reviewers and the negative control are task-runner's baseline
either way, and the spec red-team already runs past three criteria or an ASSUMED row — is
the code red-team over the shipped diff (three refuters, a completeness critic with browser
probes, up to three rounds), coverage loop-until-dry and tier escalation. In simulation 4
that phase was 40 of 119 minutes and found the negative-total-interest bug, a 2.78:1 stale
label and a comma-decimal keypad lockout; its third round found one test-strength issue and
changed no source.

Score six signals from the brief, one line each in the block; the profile is the sum,
overrides first (**agent-graded** — no script reads a brief for novelty):

| # | signal | where it shows |
| --- | --- | --- |
| 1 | irreversible or data surface: kind `auth`/`api`/`data-model`/`form`, or Scope touches auth, session, payment, PII, migration, money arithmetic | kind, § Scope |
| 2 | a numeric or parsing contract in the acceptance lines (computed value, format, range, parser) | § Acceptance |
| 3 | novel shape — no sibling in the tree implements it | `discovery.md` |
| 4 | shared blast radius — `Primitives to ADD` non-empty, tokens/layout/middleware a later milestone consumes, two-plus dependants | brief, roadmap |
| 5 | reviewer history — the previous milestone's `findings.md` has a major from a second reviewer or the red-team (first milestone: 1) | `milestones/*/findings.md` |
| 6 | four-plus cards or ten-plus files expected | brief, roadmap |

- **signal 1 → never lean**, whatever the sum (`dispatch check` WARNs on a lean surface kind).
- **sum ≤ 1 and no logic change → `lean`**: `/taskmaster:task <brief>`; baseline reviewers
  and negative control (free); no red-team of either kind. A copy change, a footer year.
- **sum 2–3 → `standard`**: `/taskmaster:task <brief>` (the spec red-team fires on its own
  gate); after the run, ONE code red-team round you drive yourself — the correctness lens
  always, the security lens only with a surface, the test-teeth lens when a card's negative
  control needed an explicit mutant — as reviewer dispatches (`--kind reviewer`), then the
  fix loop. Simulation 4's m2 (marketing page: a11y and direction already forced by its
  kind) is the worked case.
- **sum ≥ 4 → `adversarial`**: `/taskmaster:task ultra <brief>` (hands-off: `goal`): the
  full code red-team; stop after the critic round unless its fixes touched source no test
  covers. Simulation 4's m1 (money maths, new primitives, first milestone) scores 5 and
  buys what it bought, minus the six-minute third round; its m3 (an application form:
  name, email, phone) is signal 1 → adversarial, which `--kind feature` would never have
  reached — register it `--kind form`.

Record the profile: `program.sh milestone set --id <id> --rigour <profile> --reason
"<the signals>"` (or `--rigour` at `milestone add` when the roadmap already shows it);
`status` prints it; `dispatch check --milestone` WARNs while it is unset, when a surface
kind is lean, and when the card index disagrees with it — a `Goal:`/`Ultra:` marker on a
lean/standard milestone (interactive: brief without the token; hands-off: the residual
row) or no marker on an adversarial one (**WARN**; the score itself is recorded). Budget
left is not an input: the plugin has no cost channel, and a rule on a number nothing can
read is a fifth unenforceable claim. What the rule never cuts: the reviewers task-runner
routes per card and the negative control — in simulation 4 every card major came from
the second or third reviewer, and they cost nothing extra.

```
## Rigour: <lean | standard | adversarial>
1 surface: <yes/no — why> · 2 numeric/parsing: … · 3 novel: … · 4 blast radius: … · 5 history: … · 6 volume: …
```

## Worker (no taskmaster/task-runner installed, or a card dispatched directly)

```
You are implementing ONE card in <abs project root>. Cwd resets between commands: use
absolute paths or `git -C`.
CARD: <title>. DONE WHEN: <criteria copied from the brief>.
AGENT: <agent type this prompt is sent to, e.g. task-runner:task-executor — close counts it>.
MODEL: <opus | sonnet | haiku — the seat table; the Agent call passes the same value>.
STATE FILES: brief <abs>, findings <abs>, decisions <abs>.   SIBLINGS: <none | who, files>.
OWNER: you own exactly TOUCH ONLY; a sibling owns <files> — do not read-modify-write theirs.
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
control run with the guard removed showing the new test fail. For a token, variant or
shared-primitive change: list every consumer you checked (grep the class or token).
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
MODEL: <opus under the default tier; inherit only when the program was started --model auto>.
RETURN (max 120 lines, this structure): <sections>. No narrative outside it.
```
Gate it with `program.sh dispatch check <file> --kind reader`. The overseer amends the
returned direction in `decisions.md` before the build worker sees it — and checks it
against the other milestones' contracts (simulation 2's direction sold four renameable
stages; the product shipped five fixed ones).

## Reviewer (read-only)

```
Review the diff `git -C <root> diff <base>...<branch>` against <skill abs paths>.
You are read-only: you write no file and run no command that changes the tree.
MODEL: <opus | inherit — the seat table>.
One line per finding: `path:line — severity — problem — fix`. Severity-sorted.
Skip style nits unless they change meaning. Max 30 lines. RETURN `CLEAN` when none.
```

Save it as `dispatch/<n>-review-<name>.md` and gate it with `--kind reviewer` before
sending — a reviewer is a dispatch, and the record of a fix cycle is incomplete without
the prompt that produced its findings (`accept` WARNs when a milestone has none). On the
taskmaster path task-runner writes the richer per-card form (`RV-CARD:`, one line per
criterion, the compressed return); this template is the direct-worker path's.

## Follow-up to a worker that is still alive

A second message to a running worker IS a dispatch: the second simulation sent two ("fix
cycle 3 — same preamble and rules as your card…") and neither reached `dispatch/` or the
gate, so the record has a fix cycle no prompt explains. Write it to `dispatch/<n>-followup.md`
and gate it with `--kind followup`: no preamble text (the worker holds it), but the message
must say the preamble still binds, keep or extend TOUCH ONLY, repeat VERIFY and RETURN, and
name the dispatch file it continues by absolute path.

```
Fix cycle <n> — same preamble and rules as your card <abs>/dispatch/<k>.md; same TOUCH ONLY
set plus <files>; same VERIFY; same RETURN shape. Items: 1. … 2. …
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
