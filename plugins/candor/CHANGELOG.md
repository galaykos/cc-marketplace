# Changelog

All notable changes to the `candor` plugin.

## 0.10.0 — 2026-10-25

- **The terse badge re-reads the level file only after a main-loop `Bash` call, at turn start and at session start.** It re-read on every tool call, a subagent's included, though only `/candor:level` and `level.sh` (both through Bash) write the file. Gate: `tests/badge.test.ts`, "reads the level file again after a main-loop Bash call only".
- **The shared mod kit exports `hostOf` and runs the git-root lookup once per hook call.** `hooks/cc-kit.ts` (byte-identical in every mod plugin) now exports the host adapter that seven feature files pasted, and remembers `stateRoot` per host object, so a hook that asked three times runs `git rev-parse` once. It also carries `countOutcome`, a counts-only `$.store` tally.

## 0.9.0 — 2026-10-15

### Changed
- **Clause 4 holds for a running behavioral gate until the deadline the gate writes, and its block names the Bash timeout.** task-runner 0.48.0's gate ends itself by `BEHAVIORAL_GATE_TOTAL` (6600 s unless raised) and writes line 3 of `running.pid`: its start, plus the total, plus 60 s. While that deadline is ahead the clause holds, whatever the file's age; once it passes the file is stale. A file with no deadline, from a task-runner before 0.48.0, keeps 0.8.0's 240 minutes. No fixed window fits both producers: this version's first cut held for 120 minutes, because from CLI 2.1.285 the host stops a background Bash call by 2 h (from 2.1.288 only in `-p`, SDK, CI and cloud sessions), but a raised total where the host sets no limit, and task-runner 0.47.0's seven suites at 1800 s (210 minutes), outlived it, and the stop then asked for a second gate under the first one's load. A host stop does not leave a live-looking file: measured on 2.1.300 through TaskStop, the host sends TERM, then KILL about 1.4 s later, to the whole tree, the gate's trap removed `running.pid`, and a file the KILL beats names a dead PID the liveness check already ignores. The no-gate-pass block now says to start the gate with a Bash timeout of 7200000, since the 30-minute default stops it first. Pinned by `gate-pins.test.sh` "bg PID age: a 238-minute running.pid with no deadline …" (red against this version's first cut), "bg PID deadline: a 300-minute running.pid whose deadline is 10 minutes ahead …" and "… a fresh running.pid whose deadline passed a minute ago is ignored …" (red against the first cut and 0.8.0), and `gate.test.sh` "no gate pass: the block names the 7200000 ms Bash timeout" (red against 0.8.0). Residuals: on macOS a recycled PID at the same HEAD holds until the deadline (about 111 minutes by default, longer with a raised total), or for 240 minutes with none; a gate that outlives its deadline, which only a host with no `timeout`, `gtimeout` or `perl` allows, draws one block at its HEAD.
- **`/candor:level` asks the host for the `cc_terse` option.** `level.sh --sources` runs `claude plugin configure candor@<marketplace> --json` (CLI 2.1.285+) when it runs from an installed copy, and reads the option from its `inputs`. Measured on 2.1.300 in a scratch HOME: it resolves user settings, `managed-settings.json` and `managed-settings.d` drop-ins with managed winning, follows a symlinked settings file, and ignores project and local settings as the host does; it sees a `--settings` file only when passed to its own invocation, so never the session's. About 0.45 s a call, so the badge, `measure.sh` and `/candor:check` stay on the settings files. A CLI without the subcommand (2.1.284 exits 1, `unknown command 'configure'`), no `claude` on PATH, no `jq`, or a `--plugin-dir` copy falls back to the files (`level-sources.test.sh`, three cases red against 0.8.0). Residual: MDM and server-managed policy through `configure` are unmeasured — neither exists in a scratch HOME.

## 0.8.0 — 2026-10-15

### Added
- **Clause 4 requires the run-close whole-range review.** A run registered by task-runner 0.47.0's `register-run.sh` carries `start_sha`. At a stop with a gate pass for HEAD, the clause now blocks unless `rv/range-<sha>.json` names HEAD (a prefix of at least 7 hex characters), written by task-runner's observer when a `/code-review:review` call carries `RV-RANGE: <HEAD12>`, or a `rv-skip-range-<sha>` / `rv-exempt-range-<sha>` record does; a skip then meets the disclosure check like any other. Per-card reviews cannot see what changed across cards, and in two reviewed sessions the whole-branch pass found defects they had missed. A range skip is not counted as a card's review. A commit after a range review owes a review of only the commits since the newest recorded one, and the block names that range — re-reviewing the whole run per fix commit would cost a full pass each time. Residuals: a sentinel without `start_sha` (written by hand, or by an older task-runner) owes none; the record proves the call carried the marker, not which range it reviewed.
- **Clause 4 requires ui-ux-reviewer on a UI card.** For each `rv/diff-<card>.patch` newer than the registration whose `diff --git` lines name a `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.sass`, `.less` or `.blade.php` file, the card needs a `rv-agent-<card>@…ui-ux-reviewer.json` record, a skip or an exemption. In one run 8 of 10 UI cards were reviewed without it and the reviewer count still passed. A test or story file (`*.test.*`, `*.spec.*`, `*.stories.*`, under `__tests__/` or `tests/`) is not a UI file: task-runner's reviewer routing gives a test-only card code-reviewer alone. Residuals: a card whose orchestrator wrote no diff file is not seen; a test directory named otherwise (`test/`, `e2e/`) still counts as UI.

### Changed
- **The closing stop of a finished run is checked.** With no `active-run.json`, clause 4 reads `closed-run.json` (task-runner 0.47.0 renames the sentinel at close instead of deleting it), runs the same checks, and deletes the file once they all hold. A `closed-run.json` whose `gate-pass.json` names a HEAD other than the current one is deleted silently: the run closed at that earlier commit, and its closing stop never reached the clause (Esc, session end, the clause off), so read as a live run it would block the first stop after any later commit on that branch. Residuals: a commit made between the gate pass and the closing stop retires the run unchecked too; a `closed-run.json` with no `gate-pass.json` still blocks. Before, a run that followed `run.md` deleted its sentinel before the closing report, so the reviewer, control and disclosure checks never read a compliant close. The two messages that said to delete or clear `active-run.json` now name the file actually present, and the no-pass message names the whole-range review and says to run the behavioral gate in the background: a foreground Bash call is killed at 2 minutes by default and 10 at most, well under the gate's 1800 s suite cap, and leaves no verdict (`gate.test.sh` "no gate pass: the block says to run the behavioral gate in the background", red against this version's first cut).
- **Clause 4 waits for a behavioral gate still running in the background.** In a reviewed session the no-gate-pass block fired while `behavioral-gate.sh` was running in background Bash, asking for the run already in progress. task-runner now writes `.claude/task-runner/bg/running.pid` (the PID, then the HEAD it tests); while that PID is live, the sha is the current HEAD and the file is under 240 minutes old, the gate counts it as one background worker: the same printed line, no block, this HEAD's one block kept for the next stop. A dead PID or another HEAD is ignored. 240, not the in-flight records' 180: seven built-in runners at the gate's 1800 s cap run 210 minutes. With `/proc` (Linux), live means the recorded PID's command line names `behavioral-gate.sh`, or else a live `behavioral-gate.sh` runs from under the repo root: a gate in sandboxed Bash (`bwrap --unshare-pid`) records the sandbox's own PID, which the first cut tested with `kill -0` as another process (probed: PID 2, the host's kthreadd, so the block stood). Residuals: without `/proc` (macOS) a recycled PID at the same HEAD holds the block until the file is 240 minutes old; on Linux any process naming `behavioral-gate.sh` from under the root holds it while the file is current; an added `--runner` or a raised `BEHAVIORAL_GATE_TIMEOUT` can outrun the cap, and the stop then blocks once at that HEAD. The file is task-runner's, not the host's `background_tasks` list, whose `shell` entries carry the command line on CLI 2.1.300's schema but have not been probed for this. Standing: gate — `gate.test.sh` "in flight: a behavioral gate whose PID is live at HEAD holds…" (red against the first 0.8.0 cut), "…recorded for another HEAD is ignored" and "a dead behavioral-gate PID at HEAD is ignored"; "sandbox: a dead recorded PID while a behavioral-gate.sh runs from under the root holds the block" and "sandbox: a recorded PID naming another live process, the only gate outside the root, is ignored" (both red against the cut before this one); `gate-pins.test.sh` "bg PID age: a 238-minute…" (red against this version's first cut, which capped at 180) and "…242-minute… is ignored".
- **Read-only subagents no longer get the five moves.** Reviewers, scouts and `Explore` were told to prove a change in the browser. `preamble.sh` now skips the text for this marketplace's agents whose `tools:` holds neither `Write` nor `Edit`, by qualified name (the reviewers, `toolchain-experts:*-expert`, `craft-layer:creative-director`, `taskmaster:spec-adversary` and `:context-scout`, `approaches:opinion-lens` and `:consultant`, `ultra-deep-research:researcher` and `:verifier`, `hindsight:transcript-miner`), and the built-in `Explore`, `Plan` and `claude-code-guide`; the in-flight record clause 4 reads is still written. The first cut matched the bare name, so another source's writable `verifier` or `acme:security-reviewer` lost the text too. The whole text is skipped rather than moves 4–5 sent: no skipped type can write, and a second text would be a second thing to keep in step. Six of the 19 marketplace types (the five `*-expert` and `devops-reviewer`) and the built-ins `Explore` and `Plan` do hold Bash; the `*-expert` agents keep the skip because each runs its analyzers and states it never edits. Residual: another source's read-only agent still gets it. Standing: gate — `preamble-hook.test.sh` 22 derives the set from every `agents/*.md` and fails on one the list misses, 23 on a writable one it skips (no `tools:` key, or a YAML-list `tools:` naming `Write` or `Edit`, counts as writable: 28–30); 22, 24 and 25 are red against 0.7.1, 27 (another source's agent sharing a skipped bare name) against this version's first cut, 26 pins the record.
- **`/candor:check` resolves citations the way the gate does.** `candor-scan.sh` still had the pre-0.7.1 lookup, so a dependency basename, an absolute `vendor/` path and a `shop.localhost:8080` host counted as unresolved, and the report said the file existed "nowhere" over a tree it had pruned. Both now source one lookup, `hooks/cite.sh` (extraction, then `cite_miss <file:line> <root> <cwd>`), so the report counts what clause 1 would block; the scan resolves from the transcript cwd's state root and names what it searched. A first cut copied the gate's functions under a text-comparison test that could not see the URL strip or the `...` filter. A gate that cannot source the file stands clause 1 down with one stderr line, never failing the stop; the scan prints `-` for the axis. Standing: gate — `candor-scan.test.sh` "gate and report agree: …" (a `vendor/` citation, a dependency basename, `localhost:8000` and an invented basename, each run through both), "gate.sh and candor-scan.sh carry no citation lookup of their own" (red against the first cut); "a dependency basename, an absolute vendor/ path and dev hosts are not counted" and the "never anywhere" case are red against 0.7.1; `gate.test.sh` "without hooks/cite.sh the citation clause stands down and says so".
- **avert reads no commit message or PR body.** In a reviewed session it asked about a `gh pr create` body that disclosed a precaution a worker had coded earlier, and the user waited 6 minutes: a commit message or PR body records a hedge already made. A Bash call's `git commit` or `gh pr create`/`edit` at a command position, up to the next `;`, `&`, `|` or line end, and any heredoc body opened there, is no longer scanned; the text around it still is, and heredoc bodies opened elsewhere are kept in order. A `<<WORD` inside a quoted message opens no heredoc, nor does a `<<<` here-string, so neither hides a body written later in the command. Residuals: a separator inside the quoted message, or a multi-line quoted message with no heredoc, leaves the rest scanned (it asks); a message written by Write and passed with `-F` or `--body-file` is read as a file; `gh pr comment` and `git tag -m` bodies are read. Standing: gate — `avert-hook.test.sh` 16–18, red against 0.7.1; 19–23 are the neighbours that still ask (a file written after the commit, a heredoc opened before its body, `git commit` named inside another command's text, and a `<<EOF` quoted in the message or a `<<<` here-string before a heredoc that writes a file; 22 and 23 were silent on this version's first cut).
- **Move (2) yields to the user's own test plan.** It now ends "If the user said they will test it themselves, name what is untested and stop." In a reviewed session the model built throwaway containers three times to prove a config change the user had said they would test in production. The text is 957 chars (965 bytes), +79, still under the 1,000-byte bound. Standing: agent-graded — `preamble-hook.test.sh` 31–32 pin the text on both events; no eval case measures the behaviour.
- **The preamble reads the user's ask, not the harness's.** It adopts the shared prompt-shape block: a harness frame (a subagent hand-back, a task notification, a `/loop` tick) neither injects the moves nor spends the session's one injection, and a making verb only inside a `<pasted_content>` span does not count. Residual: a session opened with a ship-only prompt ("create the PR") still gets the moves, once. Standing: gate — `preamble-hook.test.sh` 33–38; 33–36 are red against 0.7.1.
- Pinned by `gate.test.sh` cases "range: …", "ui: …" and "closed run: …"; 12 of the 19 new cases are red against 0.7.1. "ui: a card whose only UI-extension file is a test owes no ui-ux-reviewer" and "closed run: left behind with a gate pass for an earlier HEAD, …" are red against this version's first cut.

### Fixed
- **Clause 4 knows its run's branch when a tag shares the name.** It read the branch with `git rev-parse --abbrev-ref HEAD`, which prints `heads/<branch>` once a tag of that name exists, so a tag made during a run stood the clause down ("registered on branch x, now on heads/x"). It reads `git symbolic-ref -q HEAD` now; a detached HEAD (exit 1) is still not the run's branch, and any other failure (exit 128 from dubious ownership or a broken git environment) leaves the branch unknown and the clause enforced, where an earlier cut read it as `HEAD` and stood down. task-runner's `register-run.sh` writes the name it compares against, and must spell it the same way. Standing: gate — `gate.test.sh` "branch: a tag named like the run's branch does not move the run to another branch" (red against the first 0.8.0 cut) and "branch: a detached HEAD is not the run's branch, as before"; "branch: symbolic-ref failing with exit 128 …" is red against that earlier cut.

## 0.7.1 — 2026-10-14

### Fixed
- **The citation clause no longer calls a real dependency file invented, or a dev host a file.** In five reviewed sessions it blocked citations that were correct: a basename that exists only under `node_modules/` or `vendor/` (the search skips both, then said the name "exists anywhere"), an absolute path into `vendor/` (the extractor dropped its leading `/`, so it resolved nowhere), and `shop.localhost:8080`-style hosts read as `file:line`. In one session 14 of 17 subagent blocks were false positives. Now the leading `/` is kept, `.localhost`, `.test`, `.local`, `.internal`, `.example`, `.invalid` and `.lan` before `:<port>` are hosts, and a basename the main search misses is looked up under the root's `node_modules` and `vendor` (6 levels deep, stops at the first hit) and treated as real but undecidable. The block names what it searched instead of saying "anywhere". Residuals: a file only under `dist/`, `build/` or `.venv/`, or past either depth limit, still reads as invented; a citation into a file whose extension is one of those host names (`.env.local:3`, `.env.example:12`) is no longer checked; a fabricated line number in a basename that also exists in a dependency passes. `gate.test.sh` cases "a basename only under node_modules…", "an absolute path into vendor/…" and "a .localhost / .test host:port…" pin it and fail against 0.7.0; "an invented basename still blocks beside a vendor/ tree" and "an absolute vendor/ path past EOF still blocks" pin the true positives.
- **A blocked subagent is told to re-send its COMPLETE report.** Only a subagent's last message reaches the caller, and a subagent that answered a citation block with just the correction lost the rest of its report. The SubagentStop block now says so. Case "subagent: the block asks for the COMPLETE report…" pins it.

## 0.7.0 — 2026-10-08

- **The terse badge shows with no setup.** On Claude Code 2.1.291 or later, a hooks module (`hooks/badge.ts`, the plugin's first) appends the active level, e.g. `[TERSE:ULTRA]`, dim at the end of the hint line under the prompt, and nothing while terse is off. Before this the badge appeared only for people who wired `scripts/statusline.sh` into their own `statusLine` setting, which a plugin cannot do for them. It follows `statusline.sh`'s rule (`CC_TERSE`, then the level file, then `cc_terse`; a value outside the vocabulary or a symlinked level file shows none) and re-reads at session start, at each turn start and after every tool call. Text another plugin adds to the same line stays, the badge after it. It draws on the hint line, not as a `$.ui.status` line, because the host prefixes every status line with `⚠ <plugin>:`, which reads as a warning. Terminal only: the desktop app does not draw the line's tail yet.
- New option `cc_terse_badge` (default on), overridden by the environment variable `CC_TERSE_BADGE`; off leaves the hint line untouched.
- `statusline.sh` and `statusline.ps1` are unchanged and still work for an older CLI or a status line of your own.
- `tests/badge.test.ts` (13 cases, `claude plugin test plugins/candor`) covers the level order, the tail composition, both switches, the CLI floor and a plugin reload. Tested live once on 2.1.294 in a terminal: the badge showed from `CC_TERSE` and from `cc_terse` saved through `--settings` (a source `statusline.sh` cannot read), and showed nothing under `CC_TERSE_BADGE=off` or with no level set. Not tested live: a level read from the level file, a switch mid-session, and another plugin's tail on the same line.

## 0.6.3 — 2026-10-05

- **The preamble's move (1) now ends with one sentence about comments:** `Add no code comment unless it states what the code cannot; a CLAUDE.md house style wins.` It goes out with the five moves, on the first work prompt of each session and on every subagent start. So the comment rule reaches the model before its first edit in every subagent (whose prompt carries no comment rule of its own) and in a main session whose host prompt lacks one, including on an install without `code-review`, whose hooks judge a comment only as it is written. Still five moves. The message is now 878 chars (886 bytes), within the test's 1,000-byte bound. **Effect unmeasured:** the measurement behind the five moves predates this sentence, and no eval case covers it.
- `scripts/__tests__/preamble-hook.test.sh` gains three cases: the exact sentence at the end of move (1) on `UserPromptSubmit` (19) and on `SubagentStart` (20), and `CC_PREAMBLE=off` silencing `SubagentStart` (21), which no case covered before. The size claims (~800 and ~640 chars) in the README (and in the hook header until this release moved it to the marketplace repository's `rationale/`) now state the measured 878.
- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/activate.sh`, `avert.sh`, `gate.sh`, `mode.sh` and `preamble.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. After this cut each hook parsed to the same code as before (bash's own parser, comments ignored); `gate.sh`, `preamble.sh` and `avert.sh` were then refactored (next entry).
- **The rest of the hook, script, test and eval-scaffold comments are cut to a contract line per file, plus off-switch and `Misses:` lines where it reads one or had a residual; behaviour unchanged.** The derivations, measurements and history moved to the marketplace repository's `rationale/derivations/plugin-candor.md`, which an install does not contain. `gate.sh` now runs its clauses as named functions (`clause_naked_completion`, `clause_unevidenced_reversal`, `clause_fabricated_citation`, `clause_lockfile_drift`, beside `run_clause`) with `read_transcript` and `report_verdict`, and names its six bare numbers (`INFLIGHT_TTL_MIN=180`, `DISCLOSURE_TAIL_LINES=200`, `TRANSCRIPT_TAIL_LINES=4000`, `MAX_CITATIONS_CHECKED=25`, `BARE_PUSHBACK_MAX_BYTES=400`, `CLAIM_WINDOW_LINES=30`); `preamble.sh` and `avert.sh` name their marker age `MARKER_TTL_MIN=1440`. Those three hooks therefore differ in code, so instead of a parse comparison: new pin tests (13 in `gate-pins.test.sh`, 2 each in `preamble-pins.test.sh` and `avert-pins.test.sh`) passed on the old and the new code, and a run of the old against the new hook found 0 divergences in 245 input pairs for `gate.sh`, 43 for `preamble.sh` and 34 for `avert.sh` (output, exit status and every file left behind compared). The other 16 changed files parse to the same code as before. Not tested: bash 5, and hooks firing in parallel.
- **Docs corrected.** The README's hook table and `lane.tsv` now list `Task` among `avert.sh`'s PreToolUse tools, which its matcher has included since 0.4.5. The README's eval paragraph said one case per move; it now counts them: one for the whole preamble, two for move (1) (one of them for a "nothing less" half the move no longer carries), one each for moves (4) and (5), none for (2) or (3).
- `scripts/__tests__/gate-pins.test.sh` finds `gate.sh` from its own plugin root, as the other pins tests do; it looked four directories up for the repository, so it failed from an installed copy.

## 0.6.2 — 2026-10-01

- No behaviour change. The SubagentStop gate's header now states a measurement instead of an unknown: on 2.1.286 (one run) a hook's `additionalContext` lands in a subagent's transcript as attachment entries, never as a user entry — from SubagentStart and PostToolUse, before and after the hand-back — so the scoped hand-back read cannot take it for a turn boundary. The residual is narrowed to a host or hook event that writes it as a user entry.

## 0.6.1 — 2026-10-01

- **`/candor:level`, `/candor:check`, `scripts/measure.sh` and the statusline badge now see a level set only through the `cc_terse` /config option.** A new `scripts/level.sh` resolves the level the way the hooks do — `CC_TERSE`, then the level file, then the option, an invalid value counting as off — and prints the layer that won. `/candor:level status` names every layer; `/candor:level off` names the source still holding a level instead of saying normal length resumes, and trusts the hook's own "keeps it active" line over `level.sh`.
- The option is read from managed settings, then user settings: measured on 2.1.286, the host exports it to candor's hooks and not to the Bash tool the commands run in. Not read by the badge or the commands, though the hooks apply it: a `cc_terse` saved through a `--settings` file, a managed drop-in or policy, a symlinked settings file (`--sources` names it as not read), and any settings file when `jq` is missing. `statusline.ps1` mirrors the rule and has not been run (agent-graded).
- **A resumed subagent is judged on its own closing text.** The SubagentStop gate read the last `SubagentHandback` in the transcript tail, so a subagent resumed with SendMessage that ended without a new hand-back was judged again on the earlier one. It now reads only hand-backs after the tail's last user-text entry (measured on 2.1.286, one run). Residuals, in the hook header: hook-injected context written as a user entry after a hand-back hides that hand-back, and a resume message the transcript has not recorded yet leaves the earlier hand-back judged.

## 0.6.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_avert`, `cc_candor_gate`, `cc_evidence_gate`, `cc_lockfile_gate`, `cc_preamble`, `cc_terse`, `task_runner_stop_gate`, under `/config` (or `/plugin configure candor`), each with today's default. The environment variable (`CC_AVERT`, `CC_CANDOR_GATE`, `CC_EVIDENCE_GATE`, `CC_LOCKFILE_GATE`, `CC_PREAMBLE`, `CC_TERSE`, `TASK_RUNNER_STOP_GATE`) still overrides its option. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.
- **Hook state moved out of your repo.** When the host sets `CLAUDE_PLUGIN_DATA`, the gate's one-block and which-clause markers live under `${CLAUDE_PLUGIN_DATA}/<project-key>/candor/` instead of `.claude/candor/`. An existing in-repo dir is left in place and stays ignored (it carries its own `.gitignore`); delete it by hand if you like. Without the variable, nothing moves.
- `cc_terse` sits below the level file: `CC_TERSE` in the environment, then a level set with `/candor:level`, then the option. `/candor:level off` deletes the level file, so a saved `cc_terse` level shows through, and the hook says so.

## 0.5.2 — 2026-09-29

- **The SubagentStop citation check now reads the report a subagent actually hands back.** A probe on Claude Code 2.1.284 (`rationale/candor-subagent-probe-2026-09-29.md`) found the report in the last `SubagentHandback` tool_use of the agent's own transcript, as `input.message`, already written when the hook fires. `last_assistant_message` held only the closing text written after it, so the gate checked that text and never the report. This is branch B of the change: `hooks/gate.sh` reads that tool_use first, and only on `SubagentStop`. If it is missing or empty, the gate falls back to `last_assistant_message` and then to the transcript's last assistant text, the order it used before. A subagent on an older CLI, or one that never hands back, is still checked. Refusal text is unchanged.

## 0.5.1 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. Wording that named the retired bundles in this plugin's hook text and README now describes the plugin standing alone; no behaviour changed.

## 0.5.0 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

Why for all three: `rationale/2026-09-25-session-plugin-usage-review.md`, findings 2, 4, 5.

### Changed
- **The completion gate no longer blocks while workers are in flight.** Clause 4's "no
  behavioral-gate pass for HEAD" branch prints one line and stands down while this session
  has a background worker running. It writes no per-HEAD nudge, so the stop after the last
  hand-back still gets its one block. Measured: one orchestrated run took 47 of these
  blocks, nearly all while workers were in flight, and each was answered with "No card can
  start yet…". The gate reads the host's `background_tasks` list when the Stop payload
  carries it; a live probe on CLI 2.1.282 showed a running background agent listed as
  `type: "subagent"`. Without that list it reads in-flight records: `hooks/preamble.sh`
  writes one on every `SubagentStart`, even under `CC_PREAMBLE=off`, and `hooks/gate.sh`
  deletes it on `SubagentStop`. If the gate blocks a subagent, the subagent keeps running,
  so the gate restores its record. A record older than 180 minutes is swept and not
  counted; that is what bounds an agent killed without a `SubagentStop`. Records live under
  `$TMPDIR`, keyed on the hashed `session_id`. The same probe showed that `SubagentStart`,
  `SubagentStop` and the parent's `Stop` share one `session_id`. The other clause-4 reasons
  still block with workers in flight.
- **`no-behavioral-coverage` can close a run, but only honestly.** Before this, the verdict
  always blocked, and in one run with ~40 React files and no JS runner the only exit was
  deleting `active-run.json`. It now passes when
  `.claude/task-runner/reductions/coverage-bg-<HEAD12>.json` exists and is newer than the
  run's registration. That file is exactly what task-runner's `scripts/reduction-record.sh
  --kind coverage --id bg-<HEAD12>` writes. The existing disclosure check then requires
  `bg-<HEAD12>` in the closing report. The block message for this verdict now names that
  command. `empty-suite`, `unverifiable-suite` and every other red verdict still block.

### Fixed
- **State and run records resolve at the project root, not the payload `cwd`.** The payload
  `cwd` follows the model's `cd`. The gate's own state dir already resolved the git
  toplevel, but clause 4 read `active-run.json`, `gate-pass.json`, `nc/`, `rv/`, `bg/`,
  `rt/` and `reductions/` from the raw `cwd`, so a stop taken from a subdirectory found no
  run and enforced nothing. Clause 5 read `$cwd/package.json` against repo-relative
  `git status` paths and passed silently. Clause 1 walked only the subdirectory, so a
  correct repo-relative citation could block as invented. All of them now use the shared
  `cc_state_root` block (`templates/blocks/state-root.md`). Clause 1 still tries the shell
  `cwd` first, then the root.

## 0.4.11 — 2026-09-24

### Changed
- **The completion gate's end-of-run branch names the exact command and a pace rule.** It
  said "run behavioral-gate.sh on the produced code (isolated)" under a "continue NOW with a
  tool call" that read as applying to both branches. On 2026-09-24, at the end of a 44-card
  run, an agent hand-built that "isolated" checkout as a rushed chain of commands. The
  worktree call was denied as a whole and the agent read the denial as "only the cp failed".
  The next `cd /tmp/… && …; cp .env.example .env && php artisan key:generate` then ran in the
  live repo and replaced the developer's `.env` and `APP_KEY`. Now the urgency applies only to
  the cards branch. The gate branch says it has no deadline and names task-runner's
  `scripts/behavioral-gate.sh --isolate --changed "…"` (task-runner 0.40.0). It forbids
  hand-built checkouts and writing any `.env` for the gate. It also adds one line for every
  branch: one shell step per call, read each result, and a denied or failed call ran
  NOTHING. The first line of the message is unchanged, so matchers on it still work.

## 0.4.10 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** the per-turn terse reminder (`hooks/mode.sh`) and `/candor:level` now put "blocker or decision" second in the report skeleton, matching terse-output's skill since 0.4.9 — both copies had kept the old fifth-slot order; `/candor:check` and `/candor:level` drop dated incident prose. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.4.9 — 2026-09-23

### Changed
- **`terse-output`'s work-done skeleton puts "Blocker or decision" second, right after
  the verdict.** It sat fifth of six. The Opus 5.5 playbook (claude.dev, 2026-09-22)
  says the first thing to read when a long run ends is what the model is waiting on
  you for; a slot near the bottom of a 12-line budget is the wrong place for it. The
  hooks read the contract block live from the skill, so the injected card moves with
  it. Order only; every slot's content is unchanged.

## 0.4.8 — 2026-09-22

### Fixed
- **`hooks/gate.sh` validates the payload `cwd` with `[ -d ]` before creating its state
  dir.** It checked only `-n`, so a stop taken with a deleted project directory as `cwd`
  recreated that directory three levels deep to hold `.claude/candor/` — reproduced
  against the committed hook. A cwd that is not a directory now degrades to the process
  cwd, which by construction exists, and the state dir is anchored at
  `git rev-parse --show-toplevel` when there is one. Residual: a cwd that IS a directory
  but not this project's still gets a `.claude/candor/` — the check proves existence,
  never identity.

### Changed
- **Every blocking reason now names its own off switch**, the way the lockfile clause
  already did for `CC_LOCKFILE_GATE`. Citation and reversal name `CC_CANDOR_GATE`, the
  evidence clause names `CC_EVIDENCE_GATE`, and all eight completion-gate reasons name
  `TASK_RUNNER_STOP_GATE` (one line at the single print site, not eight copies). A Stop
  gate reaches the reader only through its stderr, so a variable documented anywhere else
  is a variable the person being blocked cannot find.
- `hooks/avert.sh`'s ask reason names `CC_AVERT=off` and `CC_AVERT=notify`. It reads both
  and could deny; it named neither in anything it printed.

## 0.4.7 — 2026-09-19

### Removed
- Move 1's "and nothing less" half (added in 0.4.4). The corrected with/without eval on
  `substitution-surfaced-before-build` (3 runs per arm, Opus, all completed) had the
  preamble reaching every with-arm run and every run in both arms still inventing
  creatures without surfacing it: 0/3 vs 0/3 by the case's criteria. A rule that measures
  zero is decoration (`rationale/measured-zero-shapes.md`); the before-half with teeth is
  `hooks/avert.sh` (0.4.5), which fires on a hedge the model writes down. The eval case
  stays as the fixture for any future attempt. Move 1 is the 0.4.1 text again.

## 0.4.6 — 2026-09-19

### Fixed
- All five eval cases: `execution.timeout_seconds: 900` (the runner's default is 300 s, and
  on 2.1.276 five of six Opus runs of `substitution-surfaced-before-build` timed out, three
  before their first tool call), and every llm grader now sets `focus: trace` — the
  runner's default `last_message` shows the judges only the final reply, so a run that
  named Agumon in its transcript and its file was voted FAIL 3/3 against criteria that
  say "judge the files written and every assistant message". Measured 2026-09-19,
  `rationale/fable-distillation-2026-09-18.md` §4. Running any of these needs the operator
  grant `--allow-tools Write Edit` (Bash too where the case's scaffold needs it); the
  case's `allowed_tools` alone grants nothing.

## 0.4.5 — 2026-09-18

### Added
- `hooks/avert.sh`, PreToolUse on Agent, Write, Edit, MultiEdit and Bash: when the text
  about to reach a worker or disk declares doing less than what was named for a reason
  the user did not give — a legal/IP reason, a declared substitute (original, invented,
  generic, placeholder, stand-in, look-alike, inspired-by) in place of the real thing, or
  precaution language ("to be safe", "as a precaution", "to avoid any legal …") — and no
  human turn in the session transcript contains that term, the call becomes a permission
  question (`ask`), once per term per session. `CC_AVERT=notify` makes it a notification
  instead (the user asked for "a notification or a confirmation", not a trademark filter). Tool results are not human turns, so a worker's
  report cannot launder a hedge into "the user said it". Trigger: the 0.4.4 avert left its
  reason in the dispatch it wrote — "NOT copies of trademarked characters" — while no prompt
  of the user's mentioned trademarks; the user asked whether that intent could be caught.
  It can, inside this vocabulary: a hedge that never names its reason still passes, and
  that half stays with move 1 and drift-review. Eleven-case harness. `CC_AVERT=off`.
  Standing: gate on the call; a guard, not a proof.

## 0.4.4 — 2026-09-18

### Changed
- `hooks/preamble.sh` move 1 gains its other half: "and nothing less". Averting part of
  what the user named — a risk judged for them, a hedge, a safer substitute — is a question
  before the first edit, not a cut confessed after. The move is the avert, not its subject.
  Trigger: the same day, the orchestrating session — asked for a Digimon-themed page with
  2D sprites — decided a trademark hedge on the user's behalf, briefed its sprite worker
  to draw invented mascots, in a project whose library already showed real Digimon, and
  named the swap only at the end. The user's words: "the action you did which is avert". Harness cap raised from
  800 to 1,000 chars. One eval case, `substitution-surfaced-before-build`, with the
  with/without control arm; not run.

## 0.4.3 — 2026-09-18

### Added
- `hooks/preamble.sh` also runs on `SubagentStart`, once per `agent_id`, unconditionally —
  a spawn is work by construction, so the prompt-shape trigger is skipped. Measured the
  same day: three Agent-tool workers built a Laravel/React app under 0.4.2 and the preamble
  reached 0 of 3 (`UserPromptSubmit` never fires inside a subagent), while a plugin
  `SubagentStart` entry probed with `--plugin-dir` on CLI 2.1.276 did reach a
  `general-purpose` subagent, which quoted the injected text and named its source
  (`rationale/fable-distillation-2026-09-18.md`). No matcher: Explore and Plan spawns pay
  the ~640 chars too. Five new harness cases (14-18). Standing unchanged: `recorded`.

## 0.4.2 — 2026-09-18

### Added
- Three eval cases for the preamble, one per move the 2026-09-17 simulation showed a
  differential on, each with a scaffold so the action under test is real and cheap:
  `limitation-checked-before-stated` (move 4: the prompt asserts node is unavailable; the check
  must happen before the claim is repeated), `unasked-additions-need-a-trigger` (move 1: one
  flag asked for; any addition carries a named trigger or is absent),
  `configuration-named-in-report` (move 5: a stub becomes a Postmark send; the report names the
  token variable and sender and says the live path is untested). Three runs each; the control
  arm is `--ablation with-without`. They load on the eval gate; nothing runs them in CI and
  none has been run.

## 0.4.1 — 2026-09-17

### Changed
- `hooks/preamble.sh` move 1 names the admissible triggers again (the user asked, a stated
  criterion, an observed defect) and says an addition admitted afterwards is not one. The
  2026-08 arm-C wording carried that list and produced "cut, and why" lists with features left
  out; the 0.4.0 text ("name the trigger for anything more") produced, in a one-run simulation,
  an unasked minimax opponent plus a scope note confessing it
  (`rationale/fable-distillation-2026-09-17.md` §8). Wording change only; standing unchanged.

## 0.4.0 — 2026-09-17

### Added
- `hooks/preamble.sh` (UserPromptSubmit): once per session, on the first imperative
  work-shaped prompt, injects five working moves before the first edit — smallest change,
  prove it through the surface the user will use, a stale or load-contaminated green is not
  evidence, check a limitation before stating it, name the untested/cut/to-configure in the
  final message. Advisory (`recorded`); the Stop gate remains the only clause with teeth.
  `CC_PREAMBLE=off` silences it. Derivation and the measurements it rests on:
  `rationale/fable-distillation-2026-09-17.md`.
- `evals/first-edit-discipline/case.yaml`: the with/without fixture for that hook — a bare
  build prompt on which the recorded control arm (Opus 5, 2026-08) shipped no
  verified/unverified boundary in 3 of 3 runs. Not run in CI.
- `scripts/__tests__/preamble-hook.test.sh`: 13 cases over the trigger, the one-shot
  marker, the off switch and fail-open.

## 0.3.8 — 2026-09-16

### Changed
- `/candor:level` and `/candor:check` carry `disable-model-invocation: true` (trend
  audit D1, `rationale/marketplace-trend-audit-2026-09-16.md`). The level switch is
  the user's act — `hooks/mode.sh` keys on the literal `/candor:level` in the typed
  prompt and still does — and the check is a report the user asks for; neither is loaded
  by name from a skill or hook (`activate.sh`'s fallback line tells the USER to run it).
  Both descriptions leave the model's listing (measured on a skill, 2.1.237; on a command
  it rests on the host doc's "work the same way"); the typed commands run as before.

## 0.3.7

### Fixed
- **Clause 4's negative-control count accepted a record from a PREVIOUS run.** Its three
  sibling counts (`rv/`, `rt/`, `reductions/`) all bound `find` with `-newer
  active-run.json`; the `nc-pass-*`/`nc-skip-*` count did not, and `nc/` is never
  cleared while card ids repeat across runs — so two stale records covered two done
  cards that had no control at all. Measured against the shipped 0.3.6 hook: stale
  records, two done cards, every other gate green → **exit 0** (allowed); with the bound
  → **exit 2** with the missing-controls message, and fresh records still allow. The
  count is also deduplicated by card id now, like `rv/` (`nc-pass-01` plus `nc-skip-01`
  is one card, not two). The header's clause-4 limitation states the bound and its
  residual: a legitimate record written before the run registered itself is invisible,
  which blocks rather than passes.

## 0.3.6

### Fixed
- **The per-prompt cost of the terse mode was understated by a quarter.** `mode.sh`'s
  header and the README both said "~120 tokens per prompt (measured: 476 chars)". Driven
  against a real `UserPromptSubmit` payload on 2026-09-15 the injected line is **596-597
  chars at `lite`/`full`/`ultra` (~150 tok) and 693 at a `wenyan-*` level (~173 tok)** —
  it grew when the findings-cap waiver and the wenyan clause were added to the emitted
  string and nobody re-measured. The one number a user weighs against `/candor:level off`
  was the stale one. Both now carry the measured figures and the method.
- **The README's author-time check list carried a wrong case count and an incomplete
  scope.** `evidence-gate-hook-tests.sh` was labelled "30 cases" and prints 35;
  `gate.test.sh` was labelled "clauses 1-2" and also pins clause 5 and clause
  independence. The counts are gone rather than corrected — each harness prints its own,
  so a second copy here is only a thing to drift.
- **`CHANGELOG.md` carried two `## 0.3.3` sections.** Clause 5 (a blocking clause) landed
  under the version number the previous release had already used, so a consumer reading
  0.3.3 could not tell which of two feature sets they had. Merged under one heading that
  says so.
- **The statusline badge reads the level file only.** A level set purely through
  `CC_TERSE` is active and unbadged; the README implied the badge tracks the active level.
  Stated, not changed: the badge is opt-in, unwired by default, and its Windows twin
  would have to move with it.

## 0.3.5

### Fixed
- **The description announced five clauses and then listed four.** Clause 5 (lockfile
  drift) was missing from its own enumeration — 0.3.4 changed the count word and not the
  list, so the always-on text a user reads at install described a gate with one fewer
  rule than it has. The clause is named now, and `task-runner run` lost the redundant
  "registered" so the whole description stays under the 700-char clarity guideline.
  Found by a second branch review.

## 0.3.4

### Fixed
- **Clause 5 never stood down, so a blocked turn could not be unblocked.** It was
  missing the `$skip` term every other clause carries, and the loop guard keys on the
  final assistant text — so the continuation re-blocked, and a third turn with different
  text blocked again. The escape the clause's own message offers ("say plainly that the
  lockfile is deliberately unchanged and why") was unreachable. Found by a branch review
  before merge; 0.3.3 shipped for a few hours with it.
- **Clause 5 armed on ANY line change in a non-JSON manifest**, so a `version` bump in
  `pyproject.toml`, a `[tool.ruff]` edit, or a comment added to a `Gemfile` blocked a
  Stop — the exact false fire its own header promised could not happen. Each of the four
  now tests dependency-shaped lines and excludes metadata keys by name. Nine cases
  measured across pyproject/Gemfile/Cargo/go.mod, in both directions.

### Changed
- The README, the plugin description and the hook table say **five** clauses, and the
  clause table documents clause 5 and `CC_LOCKFILE_GATE`. 0.3.3 added a blocking clause
  and left every count at four.

## 0.3.3

Two releases shipped under this one version number — the clause-5 change below landed
after the three fixes without a bump, so the entries are merged here rather than split
across two `0.3.3` headings that a consumer could not order or tell apart.

### Added
- **Clause 5: lockfile drift.** A Stop is blocked when a dependency manifest's
  dependency map changed in the working tree and the lockfile that governs it did not —
  npm/pnpm/yarn/bun, Composer, Bundler, Poetry/uv/pdm, Cargo, Go. The install step was
  skipped, so the tree being left has a manifest and a lockfile that disagree; the next
  clone resolves different versions and CI blames whoever ran it.
  `stack-scan:package-hygiene` has stated the rule in prose all along, and the model
  agrees and does it anyway, because adding a dependency line looks complete. For JSON
  manifests it compares PARSED dependency maps rather than diff lines: package.json is
  frequently one line, so a line diff makes every `version` bump look like a dependency
  change — the harness caught exactly that, and a hand test had missed it because the
  loop guard was still holding the previous verdict. Disarmed for subagents.
  `CC_LOCKFILE_GATE=off` disables it.

### Fixed
- **Clause 3 arms on an MCP file write.** Its evidence scan counted only
  `Edit|Write|MultiEdit|NotebookEdit`, so a session that edited exclusively through an
  IDE's MCP server never armed the clause that blocks a done-claim after a mutation with
  nothing executed. It now also counts `apply_patch` and `create_new_file`.
- **The terse findings skeleton no longer collides with clause 1.** `path:line — problem`
  was mandatory; clause 1 blocks a citation into a file the turn just deleted or
  shortened, so a finding about a removed file failed the turn. The line number is now
  droppable in exactly that case.
- **The no-emoji rule yields to a mandated protocol banner.** taskmaster prints a
  byte-identical status line that `validate.sh` gates for parity; a terse level shortens
  prose, it does not rewrite another plugin's contract.

## 0.3.2

### Fixed
- **Clause 1 blocked `~/` citations.** `~` was outside the extraction class, so
  `~/.claude/settings.json:12` was read as the absolute path `/.claude/settings.json`,
  resolved to nothing, and blocked — on the exact file a settings question is
  answered from. `~/` now expands to `$HOME` before resolution; a `~/` path that
  does not exist, or a line past its end, still blocks. Three harness cases.
- **Clause 3 taxed docs-only turns.** "Fixed the typo in README.md" after one Edit
  to a `.md` file blocked, and the only way through was to run any command at all
  (`git diff` satisfied it) — a turn spent on ceremony, never on a check, because no
  command's failure proves prose wrong. Mutations of `.md`/`.mdx`/`.markdown`/`.txt`/
  `.rst`/`.adoc`/`.asciidoc` files no longer arm the clause. Everything else still
  does: an edit with no `file_path`, no extension, or a code/config extension
  (`.json`, `.yaml`, `.sh`, …). Same reasoning clause 4 already applies as its
  `no-executable-surface` verdict. Residual, stated: a prose edit that claims
  "verified" passes on the claim alone — there was nothing to execute either way.
  Five harness cases in `scripts/smoke/evidence-gate-hook-tests.sh`.

### Changed
- **Gate state moved into `.claude/candor/`** (`last`, `blocked`, per-agent
  suffixes unchanged) and the directory carries a self-ignoring `.gitignore` the
  first time it is created. The bare files `.claude/candor-last` and
  `.claude/candor-blocked` showed up as untracked in every user's `git status` —
  observed in a live repo, and named as "other plugins' scratch" by overseer's own
  acceptance protocol — one `git add -A` away from being committed. A stale bare
  file from 0.3.1 is inert; delete it by hand.

## 0.3.1

### Fixed
- **A bounded clause 4 silenced clauses 1-3.** In 0.3.0 the gate reported one
  verdict per stop and clause 4 ran first, so once a registered task-runner run had
  been blocked at a HEAD (per-HEAD nudge written) — or whenever
  `TASK_RUNNER_STOP_GATE=warn` — every later stop at that HEAD exited 0 before the
  citation, reversal and evidence clauses ran. On master those were three
  independent Stop hooks, each evaluated every stop; the merge lost that for the
  whole of every card. Clause 4 still blocks first and alone; when it is bounded or
  warn-mode it prints and falls through. Six regression cases in
  `scripts/__tests__/gate.test.sh` (clause independence), four of which fail on
  0.3.0. Found by a post-merge review; no harness case had combined a live run with
  a clause 1-3 shape at a second stop.

## 0.3.0

### Added
- **The marketplace's one Stop gate.** `hooks/gate.sh` gains clause 3 (a completion
  claim after edits with nothing executed since — code-architecture's
  `evidence-gate.sh` until now) and clause 4 (a registered task-runner run stopping
  without its recorded gate pass, card counts, per-card control and reviewer records,
  red-team panel or reduction disclosure — task-runner's `completion-gate.sh` until
  now). Both clauses keep their env overrides (`CC_EVIDENCE_GATE`,
  `TASK_RUNNER_STOP_GATE`), their messages and their harnesses
  (`scripts/smoke/{evidence,completion}-gate-hook-tests.sh` now drive this script).
  The three-script namespaced-disarm protocol is gone: one script records WHICH
  clause blocked (`.claude/candor-blocked` now carries the clause name) and skips
  only that clause on its own continuation; clause 4 keeps its per-HEAD nudge.
  (2026-09-14 consolidation plan, §4.2.)
- **The terse reply mode**, merged in from the terse plugin: `hooks/activate.sh` <!-- removed-ok -->
  (SessionStart), `hooks/mode.sh` (UserPromptSubmit), the `terse-output` skill,
  `/candor:level`, `scripts/measure.sh` behind `/candor:check --brevity` (also
  automatic while a level is active), the statusline badge and the MCP catalog
  shrinker. The level file (`~/.claude/terse-mode`) and `CC_TERSE` keep their names,
  so a level set under the old plugin stays set. Dropped with the merge: the
  terse-crew, terse-commit and terse-compress skills, the three crew agents and <!-- removed-ok -->
  `/terse:commit` / `/terse:compress` (the host's `/commit` covers the first). <!-- removed-ok -->

### Changed
- `lane.tsv`: `candor:gate` no longer yields to code-architecture's evidence gate —
  there is nothing left to yield to; rows for the mode hook, `/candor:level` and
  `terse-output`.
- `/candor:check` argument list grows the brevity flags; the candour scan is
  unchanged.

## 0.2.0

### Added
- `hooks/gate.sh` also fires on `SubagentStop`: a subagent's final report goes
  through the fabricated-citation clause before the main thread quotes it. The
  payload's `last_assistant_message` is judged directly; `agent_transcript_path`
  is the fallback. Clause 2 (reversal) disarms for subagents — no user turn there.
  Loop-guard and claim markers are suffixed per agent id (hashed). Seven harness
  cases drive the measured SubagentStop payload shape.
- A span ledger was considered and dropped: the host already writes one transcript
  per subagent under `<session>/subagents/`, which is the cost denominator
  `scripts/turn-cost.sh` lacks — a reader problem, not a new writer.

## 0.1.3

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.1.2

### Changed
- **Every hook entry now declares a `timeout`.** `gate.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.1.1

### Fixed
- One measurement, two numbers: `CHANGELOG.md` said ~3.8k assistant messages
  across 47 transcripts, `hooks/gate.sh:148` said ~3.3k across the same 47 with
  the same two-step resolver. Aligned on the figure in the code comment nearest
  the script that produced it. Recorded as a judgment, not a re-measurement — the
  original run is not reproducible from here.

## 0.1.0 — 2026-08-18

Initial release.

### Added

- `hooks/gate.sh` — a blocking `Stop` hook with two falsifiable clauses.
  Clause 1 fails a turn whose final message cites a `path/file.ext:NNN` that does
  not resolve under `cwd` or points past the file's last line. Clause 2 fails a
  turn that retracts a position ("you're right", "my mistake", "I stand
  corrected") after challenge-shaped pushback that carried no correction of its
  own, when no tool ran between the challenge and the retraction.
  Modes: `CC_CANDOR_GATE=block` (default) `| warn | off`. Fails open on missing
  `jq`, an unreadable transcript, or empty text. One block per distinct final
  message.
- Citation resolver ladder, forced by measurement rather than theory: cwd-relative,
  then a full-suffix match, then the basename. Only a basename that exists
  **nowhere** counts as fabrication. Over 47 real transcripts (~3.3k assistant
  messages) a two-step version flagged mostly ABBREVIATED paths —
  `craft-layer/asset-sourcing/SKILL.md` for a file that really lives at
  `plugins/craft-layer/skills/asset-sourcing/SKILL.md` — which is the
  false-positive class that gets a gate switched off. The accepted residual: a
  real filename cited under the wrong directory now passes silently. Elided paths
  (`plugins/x/.../SKILL.md:74`) are skipped as prose, not resolved.
- `scripts/candor-scan.sh` + `/candor:check` — report-only measurement of a
  session transcript across six axes: the two gated ones plus flattery openers,
  apologies, defensive phrasing and emotional intensifiers. Always exits 0.
  Citations resolve against the transcript's own recorded `cwd`, printed in the
  report — pointing the scan at a session that ran elsewhere previously reported
  78 real paths as missing in a single transcript. The `defensive` axis dropped
  the bare `you asked for` pattern for the same reason: 4 hits on a 719-message
  transcript, all of them neutral back-references. The citation axis is
  backward-looking by nature (it resolves a whole session's history against
  today's tree); the gate is not, and both say so.
- `skills/straight-talk/SKILL.md` — the six orderings the gate cannot check:
  evidence before claim, disagreement before concession, reversal-as-finding,
  "I don't know" plus the settling command, scope honesty, correction without
  performance. Carries the standing table for which of them have teeth.
- `lane.tsv` — territory declaration; the Stop gate yields to
  `code-architecture:evidence-gate` on completion-claim territory, which it does
  not duplicate.
- Three author-time harnesses, 64 cases. `install.test.sh` is the one that would
  catch a plugin working only in-tree: it copies the plugin to a temp directory,
  resolves the hook by expanding `${CLAUDE_PLUGIN_ROOT}` from `hooks/hooks.json`,
  fails if that path lands back inside this repository, and drives it against a
  consumer project that is not a git repository, with full-shape transcript
  entries.
