# Fable-to-Opus distillation — 2026-09-17

**Standing: `recorded`.** Nothing reads this file back. Branch `Ivan-WG/fable-distillation`.

The fourth pass at one question: what does Claude Fable 5.1 do on a coding task that
Claude Opus 5 does not do unprompted, and which marketplace artifact should carry it so a
user on Opus gets the Fable-shaped session. PR #105 (2026-08, "distill Fable working
discipline into the plugin family"), PR #114 (fable-mindset-distillation) and PR #132
(fable5-prompt-alignment) each shipped an answer. The user's framing for this pass, quoted:
*"Since this is the fourth time, that could also mean maybe we missed something or need to
strengthen."* So this run began by asking why three passes did not produce the experience,
and only then what to add.

## 0. The prompt this run answered

The user's prompt was "create a team of agents tasked to distill Fable model — approach,
logic, techniques, way of thinking, skills, expertise that match what the marketplace
plugins should do … a Fable-like experience even with Opus", with "improve the prompt
before starting". The improved prompt, written before any agent ran and given to all of
them (`/tmp/fable-distill/brief.md`, session-local):

> Produce an EVIDENCE-BACKED catalogue of the working moves Fable 5.1 makes that Opus 5
> does not make unprompted, each mapped to the marketplace artifact that should carry it,
> with a status — carried (cite file:line), partial, or gap — and, for every gap, a
> proposed rule plus a FIXTURE SEED: the prompt on which a blind Opus control would fail
> and the rule would make it pass. Then apply the gaps that earn a place under the
> Admission law as plugin edits, version-bumped, gates green.

Doctrine every agent carried: read the last result first (`distillation-2026-08-23.md`
recorded eleven agents re-deriving a measurement already in the repo); prose the model
already knows measures zero (`eval-ablation-2026-08-20.md`, `measured-zero-shapes.md`);
every behavioural claim carries a verbatim quote and a transcript path; state the standing
of any rule proposed.

## 1. Evidence base and team

Eight agents, split by evidence SOURCE rather than by topic, so their returns could be
diffed instead of averaged:

| agent | source | size |
|---|---|---|
| trial grader | the 2026-08 Opus A/B/C trials, never written up | 9 transcripts |
| Fable miner, this repo | `~/.claude/projects/…cc-marketplace/*.jsonl`, dominant model `claude-fable-5-1` | 18 transcripts, 81 MB |
| Opus miner, this repo | same project, dominant model `claude-opus-5` | 17 transcripts, 39 MB |
| Fable miner, product repos | domainer-x and supa-supa-base (Laravel/React apps) | 14 transcripts, 61 MB |
| Opus miner, product repos | domainer-x and link-catalyst | 21 transcripts, 84 MB |
| prior-pass inventory | PR #105/#114/#132 diffs and five rationale docs | — |
| reach audit | every shipped discipline rule's delivery channel, hooks driven with a real payload | — |
| self-report | Fable, first person, from this session; tagged unmeasured | — |

Transcripts were indexed by dominant model, size and first prompt (a 130-row TSV) and
read through a condenser that keeps human turns, assistant prose and tool names and drops
tool results except around error markers; miners grepped the raw JSONL for exact quotes.
The paired projects matter: the same two repositories were worked by both models, so
"Fable does X" can be separated from "everyone does X here".

Limits, stated: the Opus product-repo sessions ran WITH this marketplace's plugins
(taskmaster ledgers, task-runner negative controls appear in their transcripts), so the
contrast is Fable-with-plugins against Opus-with-plugins, not against bare Opus. Counts are
"seen in n of N transcripts" by one reader each; no inter-rater check. Nothing below is a
replicated delta.

## 2. The never-recorded trials: a 535-char preamble moved Opus, a 4,362-char one added nothing

In 2026-08 nine Opus 5 runs were made of one task — *"Build a todo list as a single
self-contained HTML file. It should look good."* — in three arms: A bare; B preceded by a
4,362-char "Catalogue of reasoning moves" (23 moves in four tables); C preceded by a
535-char "Five moves" (smallest change; decide what failure means; prove it works; name the
residual; say what you cut). The transcripts sat under
`~/.claude/projects/…cc-fable-distill-trials-{A,B,C}-{1,2,3}` and no document recorded
their result. Graded this run, per run, with quotes:

| move | A (bare) | B (catalogue) | C (five) |
|---|---|---|---|
| rendered the HTML and read the pixels before claiming done | 0/3 | 3/3 | 3/3 |
| a defect found by execution and fixed before the final message | 0/3 | 3/3 | 3/3 |
| a labelled verified/not-verified boundary in the final message | 0/3 (A-2 one clause) | 3/3 | 3/3 |
| an executed assertion suite over the page's behaviour | 0/3 | 2/3 | 3/3 |
| a failure-mode table ("what failure means, where the safe path goes") | 0/3 | 0/3 | 3/3 |
| an explicit "cut, and why" list | 0/3 | 0/3 | 3/3 |

Arm A's worst run claimed *"It's open in your browser now"* with no `open`, no browser and
no screenshot anywhere in its transcript, and its `node --check` ran BEFORE the final JS
patch. Arm A's honest run said *"I haven't rendered it in a browser, so the visual result is
unverified by me."* — and shipped anyway. Every B and C run headed a section "What I did not
verify" or "Residual".

Two readings the grader insisted on. First, 6/6 versus 0/3 is the strongest vote shape nine
runs can give and is still consistent with a preamble-LENGTH effect rather than a content
effect; nothing separates "the text told it to verify" from "any preamble slowed it down".
Second, the C-only rows track the C wording almost literally — the model followed an
instruction it was given; outcome quality was never scored. What is NOT ambiguous: nothing
in the long catalogue (audit-first, recount-never-copy, report-n, state-standing) appeared
in any B transcript. Twenty-three moves bought exactly what five bought. Length is cost, not
signal.

## 3. Why three passes did not land: the rules never reach a main session before its first edit

The reach audit drove every always-on hook with the real payload for the prompt *"fix
this bug in the checkout total"* and classified each shipped discipline rule by delivery
channel. Findings:

- **Every clause of the delegation preamble and the worker template's "Code shape" is
  worker-only by design.** `delegation-contracts/SKILL.md:145`: the preamble exists
  "because a delegated specialist has no Skill tool". The main thread is structurally the
  one context it never enters.
- **`work-verification`, `drift-review`, `yagni-check` are unrouted** (`skill-router/rules.tsv:46-47`
  names them as such) and reachable only by typing a command. `coding-entry` states the gap
  in its own words: "Neither covers the common case: a coding request typed straight into a
  session, where the first line is written before anything says what the house rules are."
  It is itself command-gated.
- **The router fires AFTER the edit.** `route.sh` is PostToolUse on `Edit|Write`; it injects
  one line pointing at `low-cognitive-load`, once the file has changed.
- **On the literal prompt, two channels spoke and neither carried a discipline rule:**
  taskmaster's clarify nudge (a pointer to `/code-architecture:coding-task`; taskmaster is not
  in core-suite) and skill-router's command catalog, whose rule 4 tells the model to stay
  silent on a close call.
- **The one rule that reaches an Opus main session unconditionally is candor's Stop gate**,
  and only its clause 3 is working discipline: it blocks a completion claim when nothing ran
  after the last mutation. It fires at the END of the turn. Nothing fires before the first
  edit.
- **core-suite installs none of the code-architecture discipline skills** (deps: candor,
  code-review, git-workflow, hindsight, secret-scanning, skill-router, stack-scan).
- **Listing eviction is NOT the mechanism.** `distillation-strategy-2026-08-20.md` §1 blamed
  the 1% listing budget; `rationale/2026-09-15-listing-eviction-probe.md` measured a
  description-less entry firing 47/50 against 47/50 for a full one. Refuted in-repo; the
  strategy doc was not updated. Do not spend a pass on it.

So the prior passes were not wrong about WHAT to say. They put it where a plain session
never reads it. Combined with §2 — a short prompt-time preamble is the one shape that
measurably moved Opus — the fix is a prompt-time channel, in a plugin core-suite ships.

## 4. What the paired transcripts actually separate

Most of the discipline vocabulary appears in BOTH models' sessions in this repo, where
CLAUDE.md carries it: recon before edit (Opus 12/14 made ≥23 read-only calls first), stated
assumption when skipping the clarifying round (Opus 7/14, Fable 3/18), negative controls
(Opus 6/9 on the product repos, Fable 5/14), leading with an unflattering verdict, naming
a residual. Those are not Fable-distinctive here and a rule restating them would measure
zero. The self-report's own residual said it first: "half of what I did here was CLAUDE.md
doing it through me."

The differences the four miners' rows support, each with the strongest quote per side:

**D1. Prove it through the surface the user will use, not a double that mirrors your guess.**
Opus product-repo corrections: *"done really? http://localhost:8000/…/search-console I see
this xn--7dbrius.com"* (a done disputed with a live URL, 5 of 9); *"How do we replicate a
production setting? it dosen't help us if in live we get issues"* (4 of 9); *"why seeded
manually?"* (2 of 9). Opus failure: *"my fake reproduced the same wrong assumption, so the
tests passed"*; *"Checked against the live API — and it found a real bug that every test
missed."* (green suite over a wrong contract, 4 of 9). Fable, same repos: screenshots at four
widths read before claiming responsiveness (9 of 14); *"sshd socket was closed 12:57:18 to
12:58:48 UTC, inside the update-packages window"* (a real VPS driven over SSH as evidence);
*"They are two different sets of domains … zero overlap"* (answered from the live DB, not the
code); *"That's a test-setup artefact, not a bug, but it means the step's own append path
wasn't exercised"* (a green refused because its evidence came from a side effect). Fable still
drew "bug after green" corrections (4 of 14) — the move reduces, not removes, the class.

**D2. A green that predates your last edit, or ran under your own background load, is not
evidence.** Opus: *"a defect reported off a grep that ran before the fix landed"* (3 of 9);
*"My 'pre-existing breakage' control was contaminated by the same load, so that conclusion
was wrong"*; *"was contention from my own concurrent phpstan/eslint/npm load, not a real
defect"* (5 of 9 confident-diagnosis-from-stale-or-contaminated-read on product repos; 6 of 14
vacuous verifications in this repo — bad `mktemp`, wrong signature, uncommitted tree). Fable:
*"Smoke suite finished clean (63 harnesses, 0 failures), but it ran before my last edits.
Re-running"*; *"That failure was a race: the background smoke run started before I trimmed
the last description"*; red-gate triage as real / concurrency / sandbox / pre-existing
before reporting (7 of 18). Fable is not immune — *"I verified every touched plugin is bumped
by hand"* was contradicted by the gate minutes later (5 of 18 "done later shown false") — but
the proactive re-run appears on the Fable side and the post-hoc discovery on the Opus side.

**D3. Check a limitation by command before stating it.** Opus: the user contradicted a
stated limitation with a fact the model never checked — *"yes use gh, and open PR, gh already
installed"*, *"yes, add the unicode column so partial search works"*, the sibling repo that
builds fine (3 of 9). Fable: *"I can't type a password myself, so if the app needs a login
I'll open the login page and hand it to you"* and *"I'm blocked on one click. The auto-mode
classifier refuses…"* — limits named with the exact user action, before the attempt (4 of
14), and one retraction of its own: *"error: unknown option '--dry-run'"* reported instead of
the capability claimed.

**D4. Name what the user must configure, not only what you built.** Fable's own most
frequent substantive correction on the product repos: *"before I proceed, make a list of what
I need to add to .env and why"*, *"Add what is needed to .env.example"* (3 of 14). Opus:
*"That means we got no Live / Fresh Search? won't that give us issue with pricing?"* — a
degraded-mode consequence shipped without flagging (2 of 9). Both models omit it; the
five-move "name the residual" in §2 is the instruction that produced headed
"Residual" sections in 6/6 preambled runs.

**D5. Self-inflicted collateral outside the diff.** Opus, this repo: ran the blanket
`--update-baseline` CLAUDE.md forbids and damaged three baselines; `pkill` took down its own
suite; edited four unrelated projects' `settings.local.json` and deleted a branch it had
created (4 of 14; user: *"wait don't disable dodo branch, just fix the marketplace issue"*).
Fable: one instance, owned unprompted — *"I also killed a `vite` dev server on port 5173 that
belonged to your `domainer-x` project"*. `systematic-debugging` already carries the rule
("state-changing moves need the same diagnosis"); it is unreached (§3).

**Not a Fable difference — a policy both models share:** stopping at an uncommitted or
unpushed tree. *"commit + push + pr"* was the user's most frequent message to BOTH models
(Fable 11 of 14 product-repo sessions, Opus 12 of 17 here). The host instructs "commit or
push only when the user asks". If the user wants the opposite default, that is a CLAUDE.md
line or a memory, not a plugin rule, and no plugin here should override the host on it.

**Not separable by this evidence:** "read the last result first". Opus read `rationale/`
within its first 25 tool calls in 7 of 14 sessions here; Fable in 7 of 18. The failure shape
(re-deriving a recorded measurement, once four times in one session and claimed as novel)
appeared only on the Opus side, at n=1. CLAUDE.md now carries the instruction; a plugin rule
would be a copy.

## 5. What shipped in this pass

Two artifacts, one fix, one fixture — each named with its standing:

1. **`plugins/candor/hooks/preamble.sh`** (candor 0.4.0), UserPromptSubmit. Once per
   session, on the first prompt whose head carries a making verb in an imperative clause
   (taskmaster's trigger, so the two agree on what "work-shaped" means), it injects five
   lines: D1, D2, D3, D4 above plus the smallest-change move that all six preambled trial
   runs exhibited and no bare run did. 649 chars, measured by its test. Candor because it is
   in core-suite and already owns the after-half (Stop gate clause 3); this is the
   before-half. **Standing: `recorded`** — `additionalContext` cannot block. Off switch
   `CC_PREAMBLE=off`. 13-case harness under `scripts/__tests__/`, picked up by the CI glob.
2. **`plugins/candor/evals/first-edit-discipline/case.yaml`** — the with/without fixture:
   the trials' exact prompt, three runs, an LLM grader for a labelled verified/unverified
   boundary AND an execution of the built page before the final message. The control arm is
   already recorded failing (§2, arm A: 0/3 and 0/3). Loads on the eval gate; nothing runs it
   in CI, and it has not been run — the number it would produce is the one this document
   does not have.
3. **`code-architecture/skills/low-cognitive-load` 0.16.2** — it told the model to match the
   surrounding file's *comment density*; the worker template, the preamble and
   `comment-discipline` say the opposite, and `coding-entry` loads both texts together. Now
   matches naming and idiom only and defers the comment default. Found by the inventory
   agent; the user had asked for exactly this direction in a prior session ("more strict in
   writing comments … the code should speak for itself").
4. **This document.**

Not shipped, and why: no new skill. Every move in §4 is one sentence; a SKILL.md around any
of them would be the canonical-doctrine-checklist shape that measured zero
(`measured-zero-shapes.md` §2). No edits to the ~50 already-shipped discipline rules — the
inventory found them internally consistent except item 3, and their problem is reach, not
wording. No CLAUDE.md edit for commit/push — that is the user's call, stated above.

## 6. What would actually settle it

```bash
claude plugin eval ./plugins/candor --ablation with-without --runs 3 --json /tmp/candor.json
```

on `first-edit-discipline`. The A-arm trials predict the control fails the boundary clause
3/3; if the with-arm does not pass ≥2/3 the hook is decoration and should be deleted, not
reworded. State the run count and vote spread with any delta (CLAUDE.md, the eval rule).
Two things the case cannot show even then: whether the moves survive a long session after
the one-shot text is compacted away, and whether outcome quality (not process) improved —
the trials never scored it either.

## 7. Residuals

- Miners were one reader per transcript; "n of N" counts are that reader's tally.
- The Opus product-repo arm ran with these plugins installed; bare-Opus behaviour on a
  product repo is not in this evidence.
- The self-report (18 rows) was used only to seed questions; none of its rows is cited as a
  finding, on purpose.
- `distillation-strategy-2026-08-20.md` §1 still names listing eviction as the distillation
  question; the 2026-09-15 probe refutes it and that doc was not amended here.
