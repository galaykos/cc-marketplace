# Plugin usage in four real sessions: what fired, what misfired, what never ran — 2026-09-25

**Standing: `recorded`.** Nothing reads this file back. Every finding names the source
line it was checked against; every count names how it was taken.

## Sample and its bounds — read before quoting a number

- The four sessions registered in `~/.claude/sessions/` on 2026-09-25 (the fifth entry
  is the session that wrote this). Transcripts under `~/.claude/projects/`, CLI
  2.1.280–2.1.282, dates 2026-09-01 → 2026-09-25. Two were still live when read.
- Projects are named by shape, not by name — three are work repositories:

  | label | shape | main-thread records | subagents |
  |---|---|---|---|
  | **P1** | Laravel/Inertia/React social-publishing app, two phases through taskmaster → task-runner | 34 MB | 316 files (158 spawns) |
  | **P2** | multi-tenant platform rebuild, ~40 task-list items driven by "proceed next recommended" | 12 MB | 1 |
  | **P3** | UI/UX review and implementation on a dashboard app | 3 MB | 3 |
  | **P4** | hosting control-plane: architecture chat → overseer → taskmaster → task-runner | 6 MB | 17 |

- Method: a script reduced each main thread to prompts, Skill/Agent calls, hook
  injections, Stop-hook blocks and tool errors (digests kept in the gitignored
  `taskmaster-docs/session-review-2026-09-25/`). Subagent transcripts were **counted**
  (tool calls, SKILL.md reads), not read.
- "Bash write" is a regex over Bash commands (`cat >`, `cat <<`, `tee`, `sed -i`,
  `> file.ext`, Python `open(...,'w')`). It over-counts a little (redirects of command
  output). For P2 the targets were extracted and checked: 369 `cat >` targets, **291
  `.php` and 41 `.ts/.tsx`** source files.
- No control arm. "Should have fired" is judged against the artifact's own trigger
  text, not proven to have helped.

## Findings, most severe first

### 1. Files written through Bash are invisible to every Edit/Write hook — **confirmed**

| session | main: Bash writes | main: Edit/Write | subagents: Bash | subagents: Edit/Write |
|---|---|---|---|---|
| P2 | 233 | 5 | — | — |
| P1 | 154 | 14 | 270 | 494 |
| P4 | 48 | 0 | 10 | 29 |

Every one of these sessions carries a host `auto_mode` record with `bashFirst: true`
(P2 without bypass mode too), and the host's system prompt tells the model it may make
file changes with heredocs. The main thread follows it. These hooks match only
host write tools and read `.tool_input.file_path`, so they never see those writes:

- `secret-scanning/hooks/scan.sh` (PreToolUse deny) — `case "$tool" in Write|Edit|MultiEdit|NotebookEdit`.
  Its own header already names "a Bash heredoc around the guard" as the bypass.
- `skill-router/hooks/route.sh` (per-edit routing, and the "Signals from recent edits" digest it feeds).
- `code-review` conventions / density / comment scan, `task-runner/hooks/scope.sh`.

Effect in P2: across ~40 items that built auth guards, impersonation, invite tokens,
API tokens and an outbound HTTP client, skill-router routed **one** edit (a migration,
through one of the 5 Edit calls). The digest fired 45 times in P1, where subagents use
Edit, and **zero** times in P2.

### 2. Hook state is written under the payload `cwd`, which follows the model's `cd` — **confirmed**

`code-review/hooks/verbosity.sh:67` justifies `$cwd/.claude/comment-discipline` by
saying "the payload's cwd is whatever the session STARTED in". It is not. P4's payload
`cwd` was `app/Enums`, then `app/Models`, then the repo root, once each after a `cd`.
The warning is documented as "Shown once per session", and P4 got it **three times**.

Stray state directories on disk: P4 `app/Enums/.claude`, `app/Models/.claude`; P3 at
least nine (`resources/js/`, `resources/js/pages/`, `app/Http/Lists/`, `crawler-sidecar/`,
five under `taskmaster-docs/`); P1 two. **In P1 one is tracked in git**:
`specification/.claude/comment-discipline/verbosity-<sid>`. It predates the
self-ignoring `.gitignore` these dirs now carry. 22 hook files build state paths from
`$cwd/.claude`. Two use `$CLAUDE_PROJECT_DIR`; `candor/hooks/gate.sh:150` resolves
`--show-toplevel`. The same drift silently disarms `scope.sh`: it looks for scope files
under the drifted cwd and finds none.

### 3. ask-ledger reads subagent hand-backs as the user's ask — **confirmed, still in 0.2.1**

`ask-ledger/hooks/ledger.sh:54-56` skips prompts starting with `<task-notification>`,
`<system-reminder>`, `[SYSTEM NOTIFICATION` or `Stop hook feedback:`. A SendMessage
hand-back arrives as `Another Claude session sent a message:\n<agent-message from="…">
[Subagent hand-back] …` and is not skipped. Ledger entries it created: agent IDs
(`ac61f13cc0e92d08a`), their fragments (`430c`), `SubagentHandback`, `NOT`,
`PopoverContent`, `7th PATCH`. The Stop gate then blocked 6 turns (P1 4, P4 2), and at least 32 accounting lines
like `ac61f13cc0e92d08a: as named` went into user-facing messages. The digests
truncate messages, so the real count is higher.

### 4. candor's completion gate blocks while the orchestrator is correctly waiting — **confirmed**

P1: **47** `completion-gate` Stop blocks, P4: 2. Almost every one landed while
background workers were in flight. The model answered each with "No card can start
yet…", a turn that bought nothing. The gate re-arms on every commit
(`gate.sh:371`, "ONE BLOCK PER HEAD"), and an orchestrator commits after each card. candor
already registers `SubagentStart`/`SubagentStop` hooks, so it could know about
in-flight workers, but the run clause does not consult them.

The 2026-09-24 `.env` overwrite happened at the end of this P1 run. The model's own
account names the pressure: "a hook kept pressing me to close it". The rewording in
candor 0.4.11 (commit `8ab63818`) addresses the command sequence, not the block count.

### 5. A run whose stack has no JS test runner cannot close — **confirmed**

`behavioral-gate.sh` returns `no-behavioral-coverage` for P1's ~40 changed React files
(the project has no JS runner). `gate.sh:264` accepts only `covered` and
`no-executable-surface`. `reduction-record.sh` supports `--kind coverage`, but the gate
never reads it for this verdict. The user's only exit was deleting `active-run.json`,
done by the model on request, after which every Stop stopped blocking.

### 6. Reviewer agents dispatched ad hoc run without their skills — **confirmed**

P3 spawned three `ui-ux:ui-ux-reviewer` agents. Between them: 101 / 95 / 97
Read-Grep-Glob calls and **zero** SKILL.md reads. The agent's body says "When a
dispatch injects a skill's Read path, Read it first". Only task-runner's dispatcher
injects that path; the custom `bestpractices-skill:` frontmatter does nothing on its
own. Claude Code's subagent frontmatter has a real `skills:` field that injects the
full skill content at startup (docs, `code.claude.com/docs/en/sub-agents`, read
2026-09-25). No agent in this marketplace uses it. Contrast: under task-runner, P1's
subagents read SKILL.md files 156+ times.

### 7. Inline long runs get no independent review — **observed**

P2 shipped ~40 items over 22 days: tenancy, a second auth guard, impersonation with an
audit trail, invite and API tokens (hashed), signed URLs, rate limiting, encrypted
destination credentials, an outbound HTTP client. It dispatched **0** reviewer agents
and loaded **1** skill (`devops:compose-init`), although every SessionStart listed eight
or nine repo-relevant skills. The model verified every item well: Pest, PHPStan L7, CI on each
merge.

In the same weeks, P1's pipeline reviewers found defects that tests and static analysis
had passed:

- API keys reached logs unredacted (card 09 security review);
- a stale-sweep race overwrote a failure with "succeeded" (card 27/30 review);
- an image refusal detector fired on ordinary words like "blocked" (card 16/20 review);
- a rolled-back team deletion had already deleted its files.

P2 lacked the prompt, not the tools. Its prompts ("proceed next recommended", "E2.3")
carry no keywords for a UserPromptSubmit router, and finding 1 removed the per-edit
nudges.

### 8. Smaller items

- **Stale scope files (task-runner).** At P1 09-23T15:11, the phase-2a run's
  `scope-*.json` flagged the new phase-2b *spec* edit as scope creep. `scope.sh` reads
  scope files whether or not a run is active; its header already names stale scope
  files as a limitation.
- **Guessing instead of checking.** P1 09-24T07:14: the model called two OpenAI model
  IDs "doubtful" from memory. The user: "why you guess? do a request and see". A free
  `GET /v1/models/{id}` settled it. candor's preamble move 4 was injected that session
  and says exactly this. A prose rule fired and did not bind.
- **Reversals on a one-line challenge (P4).** "Environments" and then outbound-agent vs
  SSH, 09-20 and 09-21. `candor:straight-talk` was not loaded. Both reversals gave a
  merit reason, and the second matches how comparable panels work. No change proposed.
- **Worker stalls.** P4 needed 13 SendMessage nudges. In P1, one worker was silent for
  40 min and another for 90. task-runner's reclaim path worked both times. This is
  host-side, recorded only.

### What worked (evidence the pipeline earns its cost)

- `spec-redteam` found 8 (P4), 43 (P1 2a) and 27 (P1 2b) holes, including blockers,
  before any cards existed.
- `coverage-check` found real gaps.
- Per-card negative controls caught vacuous verifies (P1 cards 21, 23, 27).
- `git-workflow`'s no-AI-trailer deny, the `.env` read denials and secret-scanning's
  zero-width warning all fired correctly.
- When the router offered a skill it did not need, the model declined in one line, as
  designed (P1 09-23T15:22).

## Should more things auto-trigger?

Mostly no. The biggest gap is **existing triggers that cannot see**, not missing ones.

| candidate | verdict | reason |
|---|---|---|
| Edit/Write hooks also see Bash writes (PostToolUse `Bash`: parse redirect/heredoc targets, or diff `git status --porcelain` against the last call) | **do first** | restores the existing per-edit auto-triggers; in P2 233 of 238 main-thread writes bypassed them (finding 1) |
| secret-scanning PreToolUse on `Bash`, scanning heredoc bodies bound for a file | **do** | the one *deny* guard on the default write path is bypassed (finding 1) |
| Advisory Stop nudge: inline session (no active run), diff since the last reviewer dispatch ≥ N files or touches an auth/policy/token/middleware/migration path → one line suggesting `/code-review:review`; once per HEAD, never blocking | **do, advisory** | P2's 0-review gap (finding 7). Blocking would repeat finding 4. |
| `skills:` preload on reviewer agents | **measure first** | fixes finding 6 with no dispatcher, but every spawn pays for the full skill bodies; run it through `context-budget.sh` and a with/without arm |
| More prompt-keyword skill injection in the main thread | no | the router already does this; P1 received its digest 45 times, so more adds noise |
| Auto-trigger `candor:straight-talk` on a challenge | no | the observed reversals were on the merits |
| Auto-spawn reviewers | no | cost and surprise; the advisory nudge carries the signal |

## Fix list (not auto-triggers)

1. **ask-ledger**: skip prompts starting with `Another Claude session sent a message:`
   or containing `<agent-message`, plus a fixture. Size S.
2. **Hook state root**: one shared resolver, `$CLAUDE_PROJECT_DIR` → `git -C "$cwd"
   rev-parse --show-toplevel` → `$cwd`, adopted by all 22 files at once (the header in
   `verbosity.sh` explains why a partial move splits one-shots). Add a `pc_*` check
   against a raw `"$cwd/.claude`. Size M.
3. **candor run clause**: do not block while SubagentStart − SubagentStop > 0 for this
   context, and accept a recorded `--kind coverage` reduction for
   `no-behavioral-coverage`. Size M.
4. **scope.sh**: ignore scope files when `active-run.json` is absent or newer than
   them. Size S.
5. **Owner action, outside this repo**: remove the tracked
   `specification/.claude/comment-discipline/verbosity-*` from P1, and delete the
   stray `.claude/` dirs listed in finding 2.

## UI/UX output: what the AI built, how it was checked, how it was shown

Measured on the same four sessions (full working notes, with transcript timestamps and
file:line citations, stay in the gitignored working area; the load-bearing facts are
restated here so the shipped CHANGELOGs have a tracked source).

- **P1 shipped its UI unverified in a browser.** 34 UI worker subagents made 0 browser
  calls. Eight UI defects surfaced after implementation:
  - found by code-reading reviewers: focus not returned when two dialogs close; an
    approval row that never stacks at 375 px ("worked out, not measured"); a stale row
    opening the framework's error modal; a typeless `<button>` inside a form that also
    submitted it; duplicate error text; a provider offered when it was not configured;
  - found by the one 2-minute browser check, which review cycles had missed: two nav
    items highlighted at once; Generate enabled with no provider configured.
- **A loaded rubric was necessary, not sufficient.** The workers had read `a11y-audit`,
  which states the rules behind the focus and button defects, and shipped both.
- **Deferrals were never closed.** Reviewers deferred a11y items to `/ui-ux:audit`, which
  never ran. No `ui-ux-reviewer` was dispatched on any UI card, and no skip was recorded.
- **Access, not tooling, blocked the browser.** Playwright was available throughout. The
  model (correctly) would not type the user's password, and five surfaces needed data or
  API keys that did not exist, so they were logged "not observed".
- **UI card Verify lines were existence-only.** They were type-check plus lint plus grep,
  and `verify-teeth-lint` passed them.
- **P4 had the same tools and walked.** The walk ran in the main thread, it
  self-registered a user, it served built assets, and overseer's `accept` refused to
  close without evidence. It caught a 375 px overflow and a dialog animating under
  reduced motion that seven reviews had missed.
- **Ad-hoc reviewers ran with no rubric.** P3's three `ui-ux-reviewer` agents made
  97-101 tool calls each and read 0 skills. The agents' `bestpractices-skill:` field only
  works when task-runner's dispatcher injects Read paths.
- **Results reached the user as prose.** P1 took 9 screenshots and mentioned none. P3
  and P4 pointed at a folder, not at screens. design-kit's `snapshot.sh review` already
  builds a before/after page, but cannot pass a login.

## Resolution (branch `review/session-plugin-usage-2026-09-25`)

| finding | change | plugin (version) |
|---|---|---|
| 1 Bash writes invisible | shared `cc_bash_write_targets` block (`templates/blocks/`); Bash added to the router, scope-lock, conventions one-shot, secret write guard and unicode scan | skill-router 0.20.0, task-runner 0.41.0, code-review 0.23.0, secret-scanning 0.9.0 |
| 2 state under a drifting cwd | shared `cc_state_root` block in every state-writing hook, the phase-sentinel writer and the reminder template; gates `pc_state_root` + `pc_shared_blocks` | candor, task-runner, skill-router, code-review, api-design, approaches, brain, debugging, design-kit, taskmaster, ui-ux, git-workflow, code-architecture |
| 3 ask-ledger reads hand-backs | skip the `agent-message` / `[Subagent hand-back]` frames | ask-ledger 0.2.2 |
| 4 completion gate blocks waiting orchestrator | trust the Stop payload's `background_tasks`; SubagentStart/Stop records as fallback | candor 0.5.0 |
| 5 no JS runner → run cannot close | accept `no-behavioral-coverage` only with a `coverage-bg-<HEAD12>` reduction record, disclosed in the report | candor 0.5.0, task-runner 0.41.0 |
| 6 ad-hoc reviewers skill-less | `skills: [ui-ux:a11y-audit]` preload (live-probed on CLI 2.1.282) | ui-ux 0.26.3, web-dev 0.9.3 |
| 7 inline runs never reviewed | advisory review-debt nudge on UserPromptSubmit | code-review 0.23.0 |
| 8 stale scope files | scope-lock ignores scope files with no live run or older than it | task-runner 0.41.0 |
| UI: no browser walk | orchestrator walk when a UI card group closes: 1280/375, overflow probe, keyboard/Escape focus return, console, reduced motion; a Screens table in the closing report; `reduction-record.sh --evidence` | task-runner 0.41.0 |
| UI: no walk access | grill settles "Walk access" and a `Narrow (375):` field per screen; the first UI card builds access and seeders; UI cards carry a `<walk>` line; `verify-teeth-lint` WARNs `ui-static-only` | taskmaster 0.45.2 |
| unicode one-shot spent by a clean touch | marker claimed only when a warning prints | secret-scanning 0.9.0 |

**Standing of what shipped.** The two block gates, the harnesses and the prose-corpus cap
are `gate`. The review-debt nudge, the UI walk, the walk-access row and the `<walk>` line
are `recorded` or advisory: no script proves a walk ran or looked at the right state, and
no control arm shows that any of this changes an outcome. The unicode, candor and a11y
preload changes were each probed once against a live host. Nothing else was.
