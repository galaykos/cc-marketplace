# Program state — files, statuses, resume

Everything lives under `<project>/.claude/overseer/`. The directory carries its own
`.gitignore` holding `*`: state follows the working copy across branch switches (untracked
files survive `git switch`) and never lands in a commit. A teammate who clones gets no
program — that is the stated limitation; the charter and briefs are re-creatable, the
evidence is machine-local by nature.

```
.claude/overseer/
  .gitignore              # "*"
  program.json            # the machine-read state (schema below) — written ONLY by program.sh
  charter.md              # raw goal, upgraded statement, users, must-haves, non-goals, product decisions, suggestions
  discovery.md            # project inventory (stack, features, components, tests, tooling, CI)
  capabilities.tsv        # capability-scan.sh output at start time
  decisions.md            # every decision taken on the user's behalf; ASSUMED rows answer unasked questions
  milestones/<id>/
    brief.md              # the milestone brief handed to the pipeline (dispatch-prompts.md § Brief)
    dispatch/<n>.md       # every prompt dispatched directly, as sent, after `program.sh dispatch check`
                          # (a follow-up message to a live worker too: <n>-followup.md, --kind followup)
    findings.md           # reviewer findings and what was done with each; points at decisions.md rows
    evidence/             # screenshots, console dumps, test output the accept step recorded
  archive/<slug>-<at>/    # a closed program: its program.json (evidence paths rewritten to the
                          # archive), milestones/ and a copy of the md files
```

## program.json

```json
{
  "version": 1,
  "goal": "Build a CRM that manages clients",
  "slug": "crm-clients",
  "base_branch": "master",
  "hands_off": false,
  "hands_off_reason": "",
  "model": "opus",
  "created_at": "2026-09-11T10:00:00Z",
  "milestones": [
    {
      "id": "m1",
      "title": "Walking skeleton: clients list page",
      "branch": "overseer/m1-clients-list",
      "kind": "crud",
      "size": "M",
      "depends": [],
      "history": [ { "status": "queued", "at": "…" }, { "status": "building", "at": "…" } ],
      "status": "queued",
      "reason": "",
      "evidence": [ { "kind": "tests", "note": "pest 42 · pint · phpstan · tsc · build", "file": "/abs/…/tests.txt", "at": "…" } ]
    }
  ]
}
```

`history` is appended by every `milestone set` and by `accept`; `status` derives wall time
from the first `briefed`/`building` stamp to `done`, and `program.sh log` merges it with
evidence stamps, dispatch file times, `decisions.md` and `suggestions.md` into one timeline
(the guidance log of a run is that export plus hand-written learnings, never typed stamps).
`suggestions.md` (`program.sh suggestion add --text … --from mN`) is the deferred ledger
close prints and archives.

`kind` (default `feature`) selects the row of `kinds.tsv` whose skill groups `accept`
requires some gated dispatch to have pinned by an existing path (**gate**). `size`
(`S|M|L|XL`, default `M`) routes the pipeline: M and up are briefed to taskmaster, only S
may go to one direct worker (`dispatch check --milestone` WARNs otherwise); it is a roadmap
guess, so `milestone set --size <X> --reason` may correct it (history keeps the row) and
`accept` prints "sized X · actual …" beside it. `rigour` (`lean|standard|adversarial`,
unset until the brief is scored — `dispatch-prompts.md` § Rigour) says what scrutiny the
milestone buys; `dispatch check --milestone` WARNs while unset or contradicted by the card
index (**WARN**). `milestones/<id>/dispatch/.gated` is written by `dispatch check` (checksum,
kind, file per exit 0); `accept` reads only files listed there and unchanged since. `model` (`opus|auto`, set by `init
--model`, default `opus`) is the tier every dispatch's `MODEL:` line must respect
(**gate**); a program written before the field exists reads as `opus`. `foreign_session_reason` at the
program level is set only by `init --foreign-session`; while it is non-empty every
`dispatch check --milestone` WARNs that the pipeline commands are unreachable.

Statuses, in order: `queued` → `briefed` → `building` → `accepting` → `done`, plus `parked`
from any state with a `reason`. `program.sh milestone set` refuses any other word and
refuses `done` (**gate**; only `accept` sets it). `done` and `parked` are both CLOSED for
`next`, the hook and `close`; a parked milestone whose dependants are queued makes them
unreachable, which the hook says out loud ("none runnable").

Evidence kinds (fixed vocabulary, **gate**): required — `tests`, `browser-happy`,
`browser-error`, `viewport:mobile`, `viewport:tablet`, `viewport:desktop`, `console-clean`,
`keyboard`, `motion`; optional — `a11y`, `review`, `perf`, `dark-mode`, `progress`. Every
required kind needs `--file`, a non-empty regular file, stored as an absolute path and
re-checked by `accept`; every required row must be newer than the last gated worker or
follow-up dispatch (**gate** — a walk before the last fix cycle walked older code; record
the kinds again, the newest row counts). Nine kinds on one file draws a WARN. See
`acceptance.md` for what each must contain.

`hands_off` is set by `init --hands-off --reason "<why>"`; `accept` refuses a hands-off
program until `decisions.md` carries at least one ASSUMED row (**gate**).

## Resume — reconcile before continuing

`/overseer:resume` trusts the file for intent and git for facts:

1. `program.sh status` — the board. `0/0 done` and `next: none` means the roadmap step never
   ran: go back to `/overseer:start`, which re-inits a program with no milestones.
2. For the target milestone, check `git branch --list <branch>`: missing and status past
   `queued` → the branch was deleted; set `parked` with reason "branch missing" and ask.
3. `git branch --merged <base>` containing the branch and status not `done` → the user
   merged by hand; run acceptance anyway (merged is not proven) — never skip to `done`.
4. Status `building` and a `taskmaster-docs/tasks/*/00-INDEX.md` that names the milestone
   and postdates its registration → continue that run via `/task-runner:run <index>`;
   otherwise re-execute from the brief.
5. Status `accepting` → acceptance re-runs from scratch. Evidence from a previous session
   is discarded by `program.sh evidence clear --id <id>` first: a screenshot of yesterday's
   build proves nothing about today's HEAD.

The SessionStart hook (`hooks/announce.sh`) prints one line when any milestone is neither
`done` nor `parked`; it resolves the project from the git toplevel of the session cwd (a
subdirectory still announces), reads the same file and writes nothing.
