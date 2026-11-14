# Overseer necessity review — 2026-11-13

Branch `review/overseer-necessity`. Report only: no plugin file was changed. The question: do we
need `overseer`? The bar is `README.md`'s opening paragraph: a rule the model gets wrong from
memory, or a mechanism prose cannot replace.

## Verdict

**Keep it. Its value is unmeasured, so measure it on the live program before adding more.**

Overseer is the only artifact, in this marketplace or in the host, that does either of two things:

1. It carries one build across sessions and branches as a roadmap: `program.json`, the
   five-line `resume`, the SessionStart line and the status line.
2. A script refuses `done` until evidence files exist, are newer than the last fix, and were
   `Read` in the session (`program.sh accept`, `hooks/track-read.sh`).

Nearest neighbours, and why each falls short:

- `task-runner --tracks` runs milestones inside ONE card index in ONE run.
- `taskmaster` scopes one spec.
- ui-ux's `hooks/ui-check.sh` sends a turn back once when a UI edit was not followed by a
  browser call. It is a nudge, not an evidence set.
- The host's `/goal` keeps a loop turning. It holds no roadmap and no acceptance gate.

Overseer is also in use: the maintainer is running a program now (§ Evidence).

"Keep" is not "proven". Two things are missing:

- The fixes shipped after the 11-05 retro (0.8.0 to 0.11.0) have not been measured on a real
  program.
- The eval suite has one measurement, from 0.4.0.

## Evidence

| Source | What it shows | Standing |
| --- | --- | --- |
| `~/.claude/hindsight/*/skills.jsonl`, skill names only | 10 `overseer:overseer` invocations in 5 projects, 2026-10-26 … 11-13; 8 in one Unity project (claude-cowork), most recently today | verified (counted this session; no other project's files opened) |
| `~/.claude/plugins/installed_plugins.json` | 15 `local`-scope installs, 12 at 0.11.1 | verified |
| `.claude/worktrees/overseer-dx-plan/.claude/overseer/archive/` | one program on this repository, 19 milestones, all `done`, 2026-10-26 … 10-29 | verified |
| `rationale/session-retro-2026-11-05.md` § 1 | five programs, hours per milestone; six causes, the largest being the same tree verified 6–7 times | relayed |
| `CHANGELOG.md` 0.8.0 – 0.11.0 | answers to the retro: `Verify: range`, four-signal rigour, the fix cap, the size check. 0.11.0 says "not yet run on a real ask" | verified (read) |
| `CHANGELOG.md` 0.4.0 | the only eval measurement: 2026-09-13, one run per arm, 2 of today's 4 cases, haiku judge. In one case the with-plugin arm answered without loading the skill | verified (read) |
| `bash scripts/__tests__/program.test.sh` | 384 passed, 0 failed | verified (ran) |
| `bash scripts/__tests__/status-core.test.sh` | node 20.20.2 (the local default): 0 passed, 1 failed (`ERR_UNKNOWN_FILE_EXTENSION ".ts"`). node 24.22.1 (CI's): 14 passed | verified (ran) |

## What an installer pays

| Cost | Value | Standing |
| --- | --- | --- |
| always-on listing | 88 tokens (`scripts/context-budget-baseline.json`) | verified |
| `track-read.sh` on every `Read` in every session | 6 ms per call with no program open (20 runs) | verified (timed) |
| status-line mod | one `git rev-parse` per main-loop Bash/Write/Edit/MultiEdit | relayed (README) |
| size | 352 KB, 4,815 lines; `program.sh` is 821 lines and its harness 870; 60 commits since 2026-09-11 | verified |
| coupling | files in other plugins that name it, among them candor `hooks/gate.sh` (reads `Verify: range`), taskmaster `index-markers.md`, task-runner `range-verify`/`ui-walk.md`, code-architecture `/work` (program lane), stack-scan catalog. Count: `grep -rln overseer plugins/ \| grep -v plugins/overseer/` | verified |

The runtime cost to an installer who never opens a program is small. The real cost is the
maintenance load and the hours a program takes (retro § 1).

## Findings

1. `plugins/overseer/scripts/program.sh:816` — `close` copies `decisions.md` and `suggestions.md`
   into the archive and leaves both in place, so the next `init` inherits them. Consequences:
   - A new `--hands-off` program passes the "at least one ASSUMED row" gate (`:526`) on the
     previous program's row.
   - `resume` shows the old program's last decision and counts its suggestions.
   - Reproduced in `/tmp`: init (hands-off), ASSUMED row, close, init (hands-off). The gate
     regex then matches 1 inherited row. The harness never opens a second program.
2. `plugins/overseer/scripts/__tests__/status-core.test.sh:7` — the harness checks that `node`
   exists, not that it can strip types (node ≥ 22.18). The `CLAUDE.md` "run the lot" loop
   therefore reports FAIL on this machine's default node. CI uses node 24 and passes.
3. `plugins/overseer/scripts/capability-scan.sh:17` — the phase map never lists `devops`. Once
   `capabilities.tsv` exists, `plugin_installed devops` (`program.sh:146`) therefore returns
   false. The `infra` kind's only group then reads "not installed": accept never refuses it,
   and the WARN tells the model to record a fallback for a plugin that is installed.
   Reproduced in `/tmp` with devops 0.9.3 in the cache. `ui-libraries` is also missing from
   the map; the groups it sits in always have a `ui-ux` alternative, so nothing slips there.
4. `plugins/overseer/scripts/program.sh:124` — `init` refuses a session started in a
   subdirectory of the repository. The transcript directory encodes the start cwd and
   `$root` is the git toplevel, so the error says "opened in another directory". Reproduced
   with a fake `HOME`. Not checked: whether such a session really cannot reach the project's
   plugins.
5. `plugins/overseer/evals/*/case.yaml` — all four cases grade prose judgment. None exercises
   a gate, and none has been measured at 0.8.0 or later. Under `CLAUDE.md` "Evals" they cannot
   show the plugin helping. The live program is the cheaper measurement: `accept` prints
   `Process cost since …` and `sized X · actual …` for every milestone (since 0.7.4).

## Options

| Option | What changes | Cost | Risk |
| --- | --- | --- | --- |
| **A. Keep, fix, measure** | fix findings 1–3; freeze features; compare the live program's next accepted milestones (the `Process cost` and `actual` lines) with retro § 1's hours | S | the measurement may show 0.8–0.11 did not fix the slowness, which reopens B |
| B. Fold into task-runner | program state, resume and the accept gate move into task-runner, which already owns milestones (`--tracks`), receipts and `ui-walk.md`; overseer is removed | L: two plugins, a sweep of every coupled file, a migration for open programs | breaks the program running now; task-runner grows by ~800 script lines |
| C. Retire | `/work`'s program lane falls back to spec; the accept gate is gone | M: sweep plus `removed-plugins.tsv` | loses the only script-enforced browser-evidence gate; the live program loses its state machine |

## Not done

- Not read: `plugins/overseer/hooks/cc-kit.ts` (shared, byte-identical, gated by `pc_mod_kit`);
  the body of `scripts/__tests__/program.test.sh` (run, not read); `tests/status-line.test.ts`
  (neither read nor run; `scripts/mod-tests.sh` was not run); `CHANGELOG.md` lines 62–224 and
  246–419 (lines 1–62 and 225–245 were read, the rest grepped for eval and measured).
- No eval was run, and no other project's files or transcripts were opened. The claude-cowork
  program's cost lines were therefore not read.
- The repo gates (`validate.sh` and the others) were not run: this branch adds one file under
  `rationale/`.
