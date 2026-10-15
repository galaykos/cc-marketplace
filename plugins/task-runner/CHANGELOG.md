# Changelog

All notable changes to the task-runner plugin.

## 0.47.0 — 2026-10-14

- **Every route that starts a run registers it, through one script.** Registration (`active-run.json`, the record dirs, the `build` phase sentinel) was prose in `/task-runner:run` step 1 only. A handoff that invoked the task-execution skill directly ran unregistered: the review observer recorded none of 22 reviews, candor's completion clause never armed, and the run closed over a red behavioral-gate verdict. `scripts/register-run.sh` now does it, and `/task-runner:run` (step 1, and on the `--tracks` path once the run branch exists), the task-execution skill's new step 1 and `/task-runner:plan`'s "Run now" call it. On the `--tracks` path this version's earlier cut registered before the run branch existed, so the sentinel named `main`, and on the run branch the spawn cap asked at #20 and candor's clause 4 stood down; `run.md` now has the branch established first, and registered again if a route registered earlier. Pinned by `register-run.test.sh` "run.md --tracks establishes the run branch before registering" (red against that cut); keeping the order is agent-graded. It also records `start_sha`, HEAD at registration, beside the merge-base `base`. A second call for the same index on the same branch resumes the run instead of discarding its done cards' records; `--fresh` starts over. An inline run (no `--index`) always registers anew: its slug is only a name, `run` when none is given, so a new inline run on the branch resumed an abandoned one and counted that run's card records. Residual: an inline run registered twice loses its done cards' records, and the closing gate asks for them again. Pinned by `register-run.test.sh` "a second inline call …", red against this version's first cut. Standing: the three call sites are a gate (`register-run.test.sh` pins them, red against 0.46.3); whether the model runs the line it reads is agent-graded. Residual: a sentinel written by hand carries no `start_sha`, so no range review is owed.
- **Reviewers get a diff file.** The reviewer agents hold Read, Grep and Glob. Dispatches said "review the diff" and delivered none, so reviewers re-read whole files, judged against memory and skipped the history pass. `scripts/review-diff.sh --card <id> --base <ref> <files>` writes `.claude/task-runner/rv/diff-<id>.patch`: the working tree against the card's base, its untracked files, and the blame and commit subjects of the lines each hunk changes. Paths are root-relative, as a card lists them, from any directory, and paths with no diff against the base exit 4 with nothing written: the first cut read them from the shell's directory, so from a subdirectory it wrote an empty patch and exited 0. Pinned by `review-diff.test.sh` "from a subdirectory, root-relative paths …" and "paths with no diff …", red against that cut. reviewer-routing's new § Diff delivery has every `RV-CARD` dispatch name it with "cite line numbers from the working file", and never tells a reviewer to run git. Standing: the script is gated by `review-diff.test.sh`; naming the path in a dispatch is agent-graded.
- **One whole-range review at run close, required.** Per-card reviews cannot see what changed across cards, and in two reviewed sessions the whole-branch pass found defects they had missed. `run.md` step 4 and the skill's completion protocol run `/code-review:review <start_sha>..HEAD` with `RV-RANGE: <HEAD12>` before the gates; per-card passes never substitute, and a skip is a `review-skip.sh --card range-<HEAD12>` record named under `Skipped:`. `rv-observe.sh` now also watches Skill calls and records the marker as `rv/range-<sha>.json`, which candor 0.8.0's clause 4 requires at the closing HEAD.
- **A run closes by renaming its sentinel to `closed-run.json`.** Step 4 deleted `active-run.json` before the closing report, so the stop after it found no run, and clause 4's reviewer, control and disclosure checks never read a compliant close. The rename keeps the file for that stop, and candor retires it when the records hold. `rv-observe.sh` and `rv-consent.sh` treat `closed-run.json` as the run, so a review the closing block asks for is still recorded and a skip still asks; every other hook reads only `active-run.json`, and the next registration deletes a leftover. Pinned by `rv-hooks.test.sh` "… inside a closing run" (red against 0.46.3) and candor's "closed run: …" cases.
- **The reviewer type per card is recorded.** `rv-observe.sh` writes `rv-agent-<card>@<type>.json` beside the count, so candor can require `ui-ux-reviewer` on a UI card: in one run 8 of 10 UI cards were reviewed without it. Pinned by `rv-hooks.test.sh` (the type, RV-RANGE and matcher cases are red against 0.46.3).
- **reviewer-routing and task-execution, prose (agent-graded).** The security gate dispatches `security:security-engineer` under a review-only contract (probes under `$TMPDIR`, no repo writes, findings in the reviewer format) instead of priming code-reviewer to "also do security": a read-only reviewer could not have run the probes that found an SSRF and an XSS bypass. A markdown-only or test-only card diff gets one `code-reviewer` at `effort: high`. A fix-round finding that names a mechanism greps the run's diff for siblings. Inline execution Reads every `<skill>` SKILL.md the card names before its first edit.
- **`behavioral-gate.sh --runner-for <lang> '<cmd>::<regex>'` replaces that language's built-in runner.** `--runner` only adds one, so a PHP suite reachable only through `docker exec` passed 119/119 as a `--runner` while the host phpunit beside it timed out, and the gate read `unverifiable-suite` on a green suite. The replacement runs exactly where the built-in would have (a language nothing touched runs neither). The caller's empty regex is checked first and the gate owns not-started and timeout, as for `--runner`; then that language's own parse decides, so the replacement must show the evidence the built-in would have: in this version's first cut a `docker exec` into a stopped container exited 1 with no count and read covered. Through a wrapper the exit code may be the wrapper's, so a pytest replacement must also print its `N passed`/`N failed` summary; a js replacement is parsed as a `package.json` test script. Each parse also takes the count line of the language's sibling runners, which a replacement is often for: unittest's and bun's `Ran N tests`, minitest's `N runs,`, nextest's `N tests run:`, gotestsum's `DONE N tests`, and a line that opens with `N passed`/`N pass` (Playwright, bun); in an earlier cut each of those green suites read `unverifiable-suite`. A go result line is now `ok <pkg>`, `FAIL <pkg>`, `--- PASS|FAIL|SKIP:` or a bare `PASS`/`FAIL`: any line opening `---` or `ok` counted, so a wrapper's `--- :go:` banner above a docker error read covered. An inherited `RF_custom<N>` no longer reaches a `--runner` entry; it was called as `parse_custom<N>` and the gate died with exit 127 and no verdict. `RF_<lang>` from the environment is ignored: an inherited one replaced a runner unasked. `run.md`'s container example gives the suite its own `timeout 1700`, because the gate's cap kills the `docker exec` client and the suite kept running in the container (measured), and says `/app` must mount the repo root. Pinned by `behavioral-gate.test.sh` "--runner-for php replaces the failing host runner" and three usage/scope cases, red against 0.46.3; "--runner on the same fixture only adds one" pins the difference; "--runner-for php exiting 1 with no test count", "--runner-for py exiting 1 with no pytest summary" and "RF_php inherited from the environment is ignored" are red against the first cut; the six "--runner-for <lang> printing <runner>'s …" cases, "--runner-for go, a '--- :go:' banner over a docker error" and "RF_custom1 from the environment leaves --runner alone" are red against the cut the 2026-10-15 range review read.
- **Every runner's output is read without terminal codes, and jest's count after a prefix.** 0.46.3 stripped colour from PHP output only. Jest under `FORCE_COLOR` or `docker exec -t`, and vitest with `CI` set, colour output written to a file, so a code sat between `Tests` and the count; and jest's count had to open the line, so a workspace prefix (`web:test: Tests: 5 passed, 5 total`) missed it. Either way the empty check's bare `0 total` then matched the `Snapshots:   0 total` jest prints on every run: a green jest suite read `empty-suite`, a green vitest one `unverifiable-suite`. Every suite's output, the caller's empty regex included, now has CSI escape codes removed first; entrypoint probes still compare raw output. Jest's count follows a `Tests:` label anywhere on the line with only counts between, so `Test Suites: 1 passed` still never counts, and its empty signal is `Tests: 0 total`. Pinned by `behavioral-gate.test.sh` "jest under FORCE_COLOR …", "jest behind a workspace prefix …" and "vitest with CI set …", red against the cut the range review read.
- **The suite timeout is 1800 s and `--help` documents it.** At 60 s a large green Pest suite and a container suite both read TIMED OUT, so the closing gate could not be earned. The cap exists to turn a hang into a verdict; too high costs only the wait on a real hang. `BEHAVIORAL_GATE_TIMEOUT` still moves it; entrypoint `--help` and differential probes keep 60 s. `run.md`, the task-execution and behavioral-gate skills and the tracks final gate run it in the background, because the Bash tool ends a foreground call by 10 minutes, with no verdict; a longer Bash timeout cannot reach 1800 s (agent-graded). Pinned by "--help documents BEHAVIORAL_GATE_TIMEOUT" and "a suite runs under the 1800 s default cap" (red against 0.46.3) and "BEHAVIORAL_GATE_TIMEOUT=1 over a 5 s suite".
- **A running gate says so: `.claude/task-runner/bg/running.pid`.** `run.md` now runs the gate in the background, and candor's clause 4 blocked a stop while it was still running because no verdict existed yet. While it runs, the gate writes its PID and the HEAD it judges into the bg dir its record goes to, and its exit trap removes the file only while the file still names it, so a second gate's file survives the first one's exit. It writes only where that bg dir already exists (run registration creates it); creating it would arm the verdict record outside a run. Residual: a SIGKILL leaves the file naming a dead PID, or a reused one beside the right HEAD. candor reads the file. Pinned by `behavioral-gate.test.sh` "a running gate holds bg/running.pid …" (red against 0.46.3) and "a running.pid another gate rewrote is not removed …" (red against a cleanup that does not check the PID).
- **`--isolate` builds its worktree inside the repo, under the gitignored `.claude/task-runner/iso/`, not `$TMPDIR`.** A suite that only runs in a container sees the repo's bind mount and nothing in `/tmp`. `BG_TREE_REL` (exported) names the tree from the repo root for `docker exec -w`; `vendor`/`node_modules` are linked relatively, since an absolute host path dangles inside the container; a tree older than a day, left by a gate killed before its trap ran, is swept by the next run. The tree's `.env` is a copy of the first committed `.env.example`, `.env.dist` or `.env.sample`: Symfony's Dotenv reads `.env.dist` only while `.env` is absent, and an earlier cut hid it behind the empty `.env` below. With none of them, the tree root gets an empty `.env` when the live repo has one: the tree sits inside the live repo, so a loader that walks up parent directories (python-dotenv's `find_dotenv`) read the live credentials in this version's first cut. The live `.env` is still never read. Composer's autoloader resolves its paths through the `vendor` link, so the app's PHP classes load from the live tree, uncommitted edits included; the uncommitted-changes WARN now says so instead of calling those changes untested. Residual: while the tree exists, a scanner run in the live tree (a watch-mode test runner, an IDE indexer, a test run whose discovery enters dot-directories) can see it; a crash leftover waits a day, and a non-empty directory a container created in the tree as root defeats the cleanup and the sweep, silently; a container that mounts only a subdirectory of the repo cannot reach the tree; other config found by walking up parent directories still resolves to the live repo. Pinned by "--isolate tree lives under .claude/task-runner/iso/…" and "--isolate sweeps a day-old leftover worktree" (red against 0.46.3) and "--isolate with no .env.example: a parent-directory .env lookup stops in the tree…" (red against the first cut) and "--isolate with a committed .env.dist …" (red against the cut the range review read).
- **`spawn-cap.sh` notifies instead of asking inside a registered run, from the run's plan.** The ask at dispatch #20 left an authorized run idle for 67 minutes, then 25 at #40, while its other agents finished; neither approval changed the plan. With `active-run.json` at the state root, naming the checked-out branch or none, as candor's clause 4 reads it, the first threshold is max(cap, 3 per card in `index_path`), doubling after, and the notice goes to the user (`systemMessage`) and the model (`additionalContext`) naming the slug, card count and index. Outside a run it asks as before, and so it does beside a sentinel registered on another branch, which this version's first cut read as the run. Residual: a run that dispatches past its plan is told, not stopped; a tag made after registration with the branch's name makes `git rev-parse --abbrev-ref` print `heads/<branch>`, so the run reads as another branch's, here and in candor's clause 4 alike (`symbolic-ref --short` prints the same). Pinned by `spawn-cap.test.sh` "a 10-card run moves the first threshold to 30…" and four more, five red against 0.46.3, "a run registered on another branch still asks at 20", red against the first cut, and "a sentinel naming no branch is the current run", red against the cut the range review read.
- **The review-skip consent ask fires on a redirect into a shell-built record name.** The redirect detector matched the name against an id class, so `> rv-skip-bg-${H:0:12}.json` was never asked about, and widening the class to `$ { } :` still missed `$(git rev-parse …)`, `"$H"` and a backtick; the name now runs to `.json` short of a pipe or command separator, and so does the path before it: a read after an earlier redirect, `2>/dev/null; ls …/rv-skip-*.json`, was asked about in an earlier cut. Pinned by `rv-hooks.test.sh` "rv-consent asks on a redirect into rv-skip-bg-${H:0:12}.json" (red against 0.46.3) and three "… a record named by:" cases (red against the class); reading a record, or copying one out with `cat … > /tmp/x`, stays silent, and so do the two "… a read after another redirect" cases, red against that cut. Residual: the ask shows such a card cut at the first character outside the display's id class (`bg-$`), or as `(unnamed)`.
- **The scope lock sees interpreter writes.** In four sessions of the 2026-10-13 retro, 40–85% of code writes went through interpreter heredocs (`python3 - <<'EOF' … open(p, 'w')`), and `scope.sh` named only what a redirect, `tee` or `sed -i` writes. It now carries the shared `bash-write-effects` block: after a command naming python, node, php, ruby, perl, deno, bun, `cp`, `mv`, `install` or `patch`, each file git reports changed or untracked since this hook's previous call in the run (at most 8) is judged against the scope as an Edit of it is, still never a block. Its warning is worded apart from an Edit's, because nothing tells who wrote such a file: it changed since the previous tool call, may not be this command's, check `git diff -- <file>`, and never revert a change you did not make (a range review found two workers in one tree where A was told to revert the file B's python wrote). A failed command fires `PostToolUseFailure`, so `scope.sh` is registered on it for Bash and answers in that event's envelope. The marker is dated on every Edit, Write and Bash call of a registered run, so a file an Edit changed is not read again by the next Bash call; outside a run nothing is written; a marker older than `active-run.json`, or dated by another session (it holds the session's cksum), reads nothing, so a user's edit between two sessions of one run is not the next session's write; nothing under `.claude/` is read, so a sibling plugin's fresh marker is not one either. Residual: the first Bash call of a run or of a session, writers it does not name (`make`, `git apply`), gitignored outputs, `mv`/`cp -p` destinations, a submodule's files, no git, a `$HOME` root or `status.showUntrackedFiles=no` (nothing read); any other change in the window (an IDE save, a parallel worker in the same tree, an unignored cache) warns, in that wording, as the command's write, and the worker that made it then reads nothing. Latency, 20 runs on a clone of a 2,786-file repo, median (max): a non-matching call in a run 12.5 (14.1) → 13.1 (15.2) ms, 12.7 (13.1) → 16.8 (18.0) ms with `CLAUDE_PLUGIN_DATA` set; `python3 -c 'print(1)'` 12.8 (13.8) → 16.5 (17.6) ms; a python heredoc writing three files 12.4 (12.9) → 24.2 (25.2) ms; outside a run 7.5 (8.5) → 7.8 (8.3) ms. After the range review's round (session cksum, one `find` over git's list, the `.claude/` and config tests), on a synthetic repo of that size: in a run 11.6 (12.2) → 13.2 (13.9) ms, with `CLAUDE_PLUGIN_DATA` 14.7 (15.2) → 16.4 (17.5) ms, outside a run 6.9 → 6.8 ms. Pinned by `scope-hook.test.sh` case 18, five of nine red against 0.46.3; the Edit-between case also fails a hook that marks only Bash calls, and the earlier-run case one that ignores the registration's date. The round's cases — the effects wording on its three paths, two workers in one tree, another session's marker, the `PostToolUseFailure` registration and envelope, a sibling's marker under `.claude/` — are 10 assertions red against 0.47.0's first cut.
- **Test resource limits in the worker preamble and parallel-planning (agent-graded).** One session seeded a row past a production-sized cap, a query ran away to 36 GB, and the machine crashed twice while six workers ran suites in parallel; a `memory_limit` set on the host did not apply inside the container shim. Preamble clause 5 now gives every test command a wall-clock timeout and a memory cap where the process runs, and runs full suites one at a time under `flock "$(git rev-parse --git-common-dir)/verify.lock"`, a path every worktree shares and that exists outside a run; the first cut's `.claude/task-runner/verify.lock` was per worktree, and outside a run `flock` exited 66 and the suite never ran. Without `flock` (stock macOS) the worker runs the suite unlocked and says so. parallel-planning caps the agent count at 2 when a group's cards run tests: a limit on concurrent agents, beside the one-at-a-time limit on full suites. Residual: no script reads either.
- **Cut to pay for that prose, no rule removed:** behavioral-gate's Safety section (its timeout, live-tree and probe lines restate "Where it runs" and steps 2 and 4, and its "skipped-with-reason" contradicted the script's fail-closed `unverifiable-suite`), two Anti-patterns bullets restating the script-is-authoritative line and "Where it runs", and the three-gate backstop sentence restating item 3.
- **Cut to stay under the skills-prose cap, no rule removed:** routing.md's pointer to a "§ markers" section that does not exist, its restated first-reachable sentence, the cost-lever design note in the cheap-tier aside, and the verify-side note; reviewer-routing's item 8 (a pointer to the section below it) and the tracks MVP aside; task-execution's restatements of the role-tier floor and of routing.md steps 1-6, and the Ralph and live-view rationale; crew.md's restated dispatch rule, which was also stale on security; algorithm.md's red-final-gate restatement of the track-orchestration skill's reason that a clean merge can still break.

## 0.46.3 — 2026-10-14

- **`behavioral-gate.sh` finds the tests of a large repo.** Each "is there an own-test" probe piped `find … -print` into `grep -q .`; grep quits on the first line, and once the path list outgrew the 64 KB pipe buffer find died of SIGPIPE (exit 141), which `pipefail` made the probe's answer. Every repo large enough to matter read `no-behavioral-coverage`, so the closing gate could not be earned there. The find probes now stop at the first match (`-print -quit`) and the Rust content probe is `grep -rqm1`. Residual: an unreadable directory find reaches before the first match still reads as no tests. Pinned by `behavioral-gate.test.sh` "php repo whose test-path list passes 64 KB", red against 0.46.2.
- **A coloured Pest summary is counted.** With `colors="true"` in `phpunit.xml`, Pest colours output written to a file too (measured, Pest 5.3.2), so `Tests:` was followed by an escape code, not the count, and a green suite read `unverifiable-suite`. The PHP runner's output now has its SGR colour codes stripped before the count is read; other runners' output is matched as it comes. Pinned by "pest coloured 'Tests: 1 passed'" (red against 0.46.2); "pest coloured 'No tests found.'" keeps the empty verdict.
- **The review-skip consent ask shows the reason and the card as written.** A `--reason` over 200 characters read "no reason given in the command", because the pattern wanted its closing quote inside the 200-character interval; it now shows the first 200 characters and `…`. A card id built in the shell, `bg-${H:0:12}`, was shown as `bg-`; the id class now takes `$`, `{`, `}` and `:`. Residual: an unterminated quote shows the rest of the command as the reason. Pinned by `rv-hooks.test.sh` (the 250-character and shell-built-id cases are red against 0.46.2).
- **The scope lock no longer warns on every edit of a run whose scope file has the wrong shape.** Orchestrators wrote `{card, allowed}`; `scope.sh` checked only that the file was JSON, read the missing `allow` as an empty list, and called every edit scope creep. A scope file with no `allow` array now leaves the call unenforced, like a malformed one, and stderr names the expected `{"allow":["path","dir/"],"task":"<id>"}`. `routing.md` step 3 now states that shape and has the dispatch name the armed file, and `task-executor` no longer writes, rewrites or deletes a file the dispatch names as armed. A Write/Edit to an absolute path outside the project root (a `/tmp` probe, the user's memory directory) is no longer told to "revert this edit". Residual: updating the run's own card index under the root still warns unless a card lists it. Pinned by `scope-hook.test.sh` 13b and 13c, red against 0.46.2.

## 0.46.2 — 2026-10-11

- **The phase sentinel is written by the installed taskmaster, not a guess.** The writer path `${CLAUDE_PLUGIN_ROOT}/../taskmaster/scripts/phase-sentinel.sh` resolves only from a source checkout: an installed plugin sits at `<marketplace>/<plugin>/<version>/`, so `task-runner/<version>/../taskmaster` does not exist. The fallback `find ~/.claude/plugins/cache -name phase-sentinel.sh` then listed every cached taskmaster version unordered (three on the machine that measured it), and the model ran whichever it picked. `/task-runner:run` now takes the newest: `find … -path '*/taskmaster/*/scripts/phase-sentinel.sh' | sort -V | tail -1`. Residual: newest is not necessarily the enabled version after a downgrade; no harness drives the command text.

## 0.46.1 — 2026-10-09

- **The board writes its saved state only when it changed.** Every tool call, main loop and subagents, refreshed the board and wrote its state even when nothing moved, which outside a run meant the same inactive board on every call. A refresh now compares first. Subagent calls still refresh the board, so a delegated card marked done moves the line mid-turn. One new test.

## 0.46.0 — 2026-10-08

- **A card status outside the vocabulary is shown, not read as pending.**
  - **The incident:** a run wrote `committed <sha> — …` in 14 status cells. The status line read `card 0/25` while 14 cards had landed, and the session-start notice counted all 25 as open.
  - **What changed:**
    - The status line now adds `14 unrecognised`.
    - `/task-board` marks such a card `[?]` and counts it in its summary.
    - `announce.sh` names how many cards have a status outside `pending, in_progress, done, parked, blocked`, and still counts them open.
    - An empty cell is still pending.
- **task-execution states the rule the run broke:** the status cell starts with the word, as in `done (<sha>) — note`, never `committed <sha>`.
- **Standing: gate.**
  - `scripts/__tests__/board-core.test.sh` covers the unrecognised parse and the status-line part.
  - `scripts/__tests__/announce-hook.test.sh` covers the notice's count, and that a vocabulary-only index names none.
  - Each case is red against the previous code.

## 0.45.0 — 2026-10-08

- **The task board can be pinned: `/config` option `cc_task_board_pin` (environment variable `CC_TASK_BOARD_PIN`), off by default.** With it on, while a run is active on this branch, a board you close by hand closes and is opened again 100 ms later; `/task-board` still closes it for good. A hook that refuses a person's close does not keep a pane open on CLI 2.1.294, so the pin reopens instead. Below 144 terminal columns the reopened board waits undrawn until the terminal is widened or you run `/task-board`. With the pin off, a board you close stays closed for that run, as before.
- **`/task-board` shows a board that waits undrawn instead of closing it.** It used to close any listed pane; it now closes only a placed one, and opens (so places) one the engine listed but could not draw.
- Standing: the reopen is **recorded**. The test kit cannot raise a person's close, so it was measured only with a probe plugin on CLI 2.1.294 (marketplace repository, `rationale/2026-10-08-mods-ui-survey-and-pane-probe.md` §3), not with this plugin. `tests/board.test.ts` gates the switch's default and override, that `/task-board` closes a pinned board, and that it shows an undrawn one. Untested: a person's close through the mouse, the desktop surface.

## 0.44.0 — 2026-10-06

- **The model-floor rule as a pure function, `hooks/floors-core.ts`, called by the spawn-floor mod below.** `parseRegistry` reads the floors from delegation-contracts' `references/role-floors.md` (the first fenced block whose every non-blank line is `<plugin>:<agent> <tier>`; one malformed line leaves no floors). `rank` places a model on haiku < sonnet < opus < fable by case-insensitive substring, so an alias and a full id rank alike. `decideModel` returns the model a floored agent's spawn should carry: the floor when the given or inherited model is below it, the parent's model when no model was given and the parent is at or above the floor, and nothing (leave the spawn as is) when an explicit model is at or above the floor or either model is off the ladder. Where that mod does not load, floors are still enforced only on agent frontmatter, and a dispatch with no `model` runs at the agent's pin even under a stronger session. `scripts/__tests__/floors-core.test.sh` runs each branch under node.
- **Subagent model floors at spawn time, a hooks module (`hooks/mods.ts`, the feature in `hooks/floors.ts`) beside the classic hooks.** On CLI 2.1.291 or later, every spawn of an agent listed in `role-floors.md` runs at no less than its floor, and a dispatch that names no model (or `inherit`) runs at the session's model when that is a higher tier, so the main thread's own dispatches are floored too, not only skill-mediated ones. A session at the floor's own tier leaves such a dispatch as it was, so a no-model dispatch keeps the agent's pin and an `inherit` one keeps the session's model. It only raises: forks, agents outside the registry, an explicit model at or above the floor, and a model of unknown family are left as given, and no spawn is refused. One toast names the agent, the model asked for and the model it runs on whenever the tier changes from what would have run: the explicit model, the session's for `inherit`, or the agent's pin when no model is named. A no-model dispatch raised to the floor runs at that pin, so it is silent. `/config` option `cc_spawn_floor` (environment variable `CC_SPAWN_FLOOR`) turns it off; an unreadable `role-floors.md`, or one with no parseable registry rows, is logged once and every spawn passes through. Below CLI 2.1.291 spawns are left as given; on CLI 2.1.287 the same module's `tool.call` hook has the effect the run-suggestion entry below names. `tests/floors.test.ts` runs each branch under `claude plugin test`. Not covered: the floor is set as the alias the registry names (`opus`), so which version it resolves to is the host's choice; and a raise to the session's model passes the parent's model string through verbatim, so a form such as `…[1m]` or `opusplan` reaches the spawn as given — the 2.1.291 types promise only an alias or a full id there, and no test confirms the host accepts the rest.
- **After a card index is written, the prompt box offers `/task-runner:run <index>`, a second feature of the hooks module (`hooks/suggest.ts`).** On CLI 2.1.291 or later, when the main conversation writes `taskmaster-docs/tasks/<slug>/00-INDEX.md` at the root of the current repository (else of the project) and no run is registered on the current branch, the idle prompt box suggests `/task-runner:run <that path>` at the first turn end with no live phase sentinel; Tab accepts it. A live sentinel is a `.claude/cc-phase.json` under two hours old that this session holds or that names no session. `/taskmaster:task` holds one while it writes the index, so the offer comes once "Stop here" has cleared it. It is not made while a run is registered on this branch, nor for a finished index: every card row's status cell starting with done, parked or skipped (read as the SessionStart announcement reads it), or `.claude/task-runner/gate-pass.json` naming it. So the index "Run now" hands to a run is not offered after that run completes, and may be offered if the run stops with a card still open; an index with no card rows that can be read counts as open. Once shown it is not offered again for that index in the session; if the host did not show it, it is offered at the next turn end. Nothing is offered for a denied or failed Write, an index anywhere else (another checkout, a test fixture), an index written while a run on this branch is active, or with `CC_SUGGEST=off` in the environment, which silences this marketplace's next-step suggestions (taskmaster, task-runner, code-review, git-workflow) and has no `/config` option; Claude Code's own suggestion is not suppressed; a run registered on another branch does not count. `tests/suggest.test.ts` covers these under `claude plugin test`; that a subagent's Write is ignored rests on the shared kit's own tests in the marketplace repository, not on these. The module adds a `tool.call` hook on `Write`, and on CLI 2.1.287 with mods on it registers even though the version check inside it passes every call through, so that CLI's own bug (a plugin `tool.call` hook breaks Bash and file search in worktree subagents, fixed in 2.1.288) applies even with `CC_SUGGEST=off`: upgrade the CLI or turn mods off. Not covered: whether the host's prompt box shows a suggestion, which only a live session shows; the tests answer `prompt.suggest` themselves.
- **A status line of the run's phase and card progress, a third feature of the hooks module (`hooks/board.ts`).** On CLI 2.1.291 or later, while a run is registered on the current branch, one line is pinned under the prompt: `task-runner  <phase>  card <N>/<total>  <p> parked  <ultra|goal>`. N counts done cards plus the one in progress, empty parts are dropped, the phase is the live phase sentinel's or else `build`, and a plain run or an index with no card table shows only `task-runner  <phase>`. It refreshes at session start and after every tool call, main loop and subagents; the index is parsed again only when its modification time moves (an index that cannot be statted, read or parsed is read again at every refresh), and only the newest of overlapping refreshes writes or paints, so an older one finishing last cannot revive an ended run's line. The line clears while no run is registered on this branch. The parsed index is kept under the `board` state key that `types/index.d.ts` declares. `/config` option `cc_task_board` (environment variable `CC_TASK_BOARD`) turns off the line and the pane below. The module now registers a `tool.call` hook on every tool, not only on `Write`, so on CLI 2.1.287 with mods on, that CLI's own bug (a plugin `tool.call` hook breaks Bash and file search in worktree subagents, fixed in 2.1.288) applies even with `CC_TASK_BOARD`, `CC_SUGGEST` and `CC_SPAWN_FLOOR` all off: upgrade the CLI or turn mods off. `tests/board.test.ts` covers these under `claude plugin test`. Not covered: the line as drawn (the test kit records its text), and the state key itself, which a 2.1.291 test cannot read, so its `runActive` and `phase` fields are asserted only through the pane's rendered text.
- **A task-board pane, toggled by `/task-board` (`hooks/board-view.tsx`).** It draws `Task board  <slug>  <marker>`, then `<phase>  <done>/<total> done  <p> parked`, then a button row, then one row per card: id, title cut to the pane width, parallel group and a marker (`[x]` done, `[>]` in progress, `[ ]` pending, `[-]` parked, `[!]` blocked), followed by `<NN` for the first unmet dependency and `+N` for the rest (`<11+5`), a parked dependency counting as unmet; a header row precedes each milestone's cards. With no run it shows the newest card index under `taskmaster-docs/tasks/`, labelled `not running`, or `no card index found`; a plain run and an unparseable index get a one-line note and no buttons. It opens itself once per run in a session (latched on the run's root, slug and branch) when the terminal can place it, and is withdrawn where it cannot; a pane closed by hand stays closed for that run. Two plain buttons only fill the prompt box, replacing its text: `r: Run next` with `/task-runner:run <index>`, and `t: Red-team` with `/taskmaster:redteam <spec>`, hidden without taskmaster's red-team command or a spec path in the index. The same `CC_TASK_BOARD` / `cc_task_board` switch keeps it closed, and a session started with it off has no `/task-board`. `tests/board.test.ts` covers these under `claude plugin test`; the pane was verified live in a terminal on CLI 2.1.292 through pexpect, and no other surface (desktop, web) has been. Not covered: the board's error path (a hook that errors passes through); `…` and `—` are ambiguous-width, so a terminal that draws them double-width misaligns that row; with the pane open and no run, every tool call lists `taskmaster-docs/tasks` to find the newest index.
- **task-execution's "No status theater" exempts a live view.** A view that checks the index at every refresh, re-parsing it whenever its modification time moves, and keeps only that parse, as the status line and pane do, is not a run board: it cannot drift from the index past the next refresh that sees the index change. Standing: recorded. delegation-contracts' `role-floors.md` residual now says the spawn-floor mod closes the main-thread gap where it loads (CLI 2.1.291 or later, mods on, neither `CC_SPAWN_FLOOR` nor `cc_spawn_floor` off, no `allowManagedModsOnly` policy) and that it stays open elsewhere.

## 0.43.0 — 2026-10-05

- **Every dispatch states its done-when:** delegation-contracts' prompt contract gains a bullet — a bar the agent can check and cannot meet early ("every caller of parse() listed with path and line", not "find the callers"), because a vague bar is where a worker stops short. Standing: recorded; `scripts/dispatch-lint.sh` does not check for it.
- The rule adapts one from mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock), rewritten here rather than copied. Its effect is unmeasured: no run compared dispatches with and without it.
- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/scope.sh`, `drift.sh`, `announce.sh`, `rv-consent.sh`, `rv-observe.sh`, `spawn-cap.sh` and `ultra-assess.sh` keep each function's contract and limits in a few lines, and `ultra-assess.sh`'s own comments keep its tier, off-switch and one line per step; the derivations and history moved to the marketplace repository's `rationale/`. Each hook parses to the same code as before, compared by bash's own parser with comments ignored.
- **`/task-runner:run` deletes a stale `gate-pass.json` and `bg/bg-<HEAD>.json` when it registers a run.** Candor's completion gate trusts both when they name HEAD, whatever their age. On a new run registered at the commit an earlier run passed on, a stale card-run pass blocked the stop for the old run's records; a stale plain-run `{"head"}` pass (or one with no `nc/` or `rv/` dir) let the stop through; an old run's `covered` verdict passed the new run. The registration step no longer claims a re-registration re-arms every check by itself and names these two exceptions. Standing: recorded; no hook or test checks that registration deletes them.

## 0.42.2 — 2026-10-01

- **The scope-lock hook reads a write after a lone `&`:** the shared `cc_bash_write_targets` block now ends a command at a lone `&`, so a write after one is read (`echo x & sed -i s/a/b/ f.json` used to return nothing) and words after one are no longer taken for `sed`/`perl`/`tee` operands; `cmd |& tee f` is read; a `-`-led file after `sed … --` or `perl -i` is returned. So a file the second command writes is checked against the card's declared files.
- Still not read: a `>& file` redirect, a bare `-x` operand with no `/` or `.` in it, and operands after a `&` inside `$(( ))` or `${ }` (that `&` ends the command). Over-read, harmless: a `-`-led argument to a perl script that contains `/` or `.`.

## 0.42.1 — 2026-10-01

- **The scope-lock hook reads `sed -i` edits correctly:** the shared `cc_bash_write_targets` block now returns every file a `sed -i` / `perl -i` command edits instead of its last word, never a trailing redirect (`sed -i … tsconfig.json 2>/dev/null` used to yield `2>/dev/null`), and recognises GNU `--in-place[=SUF]` and BSD `-I`. So every file such a command edits is checked against the card's declared files.
- Still not read: a globbed operand (`tests/*.js`), a `\` line continuation, sed or perl reached through another word (`gsed`, `/usr/bin/sed`, `xargs`, `find -exec`), and a dot-named file right after a bare `-i` when another file follows (read as BSD's backup suffix).

## 0.42.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_boost`, `cc_drift`, `cc_remind`, `cc_spawn_cap`, `orchestration_boost`, under `/config` (or `/plugin configure task-runner`), each with today's default. The environment variable (`CC_BOOST`, `CC_DRIFT`, `CC_REMIND`, `CC_SPAWN_CAP`, `ORCHESTRATION_BOOST`) still overrides its option, and `CC_REMIND` / `CC_BOOST` set in the shell still mute every plugin at once. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.

## 0.41.2 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. `delegation-contracts/references/fleet-and-apply.md` no longer routes through a bundle; no rule changed.

## 0.41.1 — 2026-09-26

- `task-execution/references/ui-walk.md`: the walk now checks that a composite widget is one tab stop
  with arrows inside, that every drag also completes through its non-drag route (a mouse-only board
  is a finding, SC 2.5.7), and that a live region announces a summary, never each tick or row.
  Standing: agent-graded (the walk is run by the orchestrator, not a script).
- Dated measurement prose moved out of `reviewer-routing.md` and `tree-wide-gates.md` to
  `rationale/2026-09-26-task-runner-prose-derivations.md` to stay under the per-plugin prose cap; no
  rule changed.

## 0.41.0 — 2026-09-25

- `code-redteam` dedups each round against every finding SEEN, refuted ones included, matching verification-panels' loop-until-dry rule and the harness's own `--dedup <seen-file>`; its prose said "confirmed findings", the shape verification-panels names as the non-converging anti-pattern. `crew.md`'s pointer names reviewer-routing's batch rule 5 (it cited a heading that does not exist).

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

Source for every change here: the review of four real sessions in
`rationale/2026-09-25-session-plugin-usage-review.md`, which is in the marketplace repo.

### Added
- **The scope-lock hook now sees Bash writes.** `hooks.json` adds `Bash` to the `scope.sh`
  matcher. For a Bash call the hook parses the command with the shared
  `cc_bash_write_targets` block, which finds `>`/`>>`, heredocs, `tee` and `sed -i`/`perl -i`.
  It resolves relative targets against the call's cwd and keeps only existing regular files
  under the project root, up to 8 per call. Each out-of-scope path gets the same warning an
  Edit gets. A Bash call with no targets stays silent. Files under `.claude/task-runner/`
  are the run's own state and are never checked, on either path.
  **Why:** finding 1. With the host's `bashFirst` auto mode, 233 of 238 main-thread writes
  in one session were `cat > file`, and those never reached the tripwire.
- **The honest exit for `no-behavioral-coverage` is now documented.** This covers a changed
  language that has no test runner in the project at all, such as React files in a repo
  with no JS runner. `skills/behavioral-gate/SKILL.md`, `run.md` step 4 and the
  `reduction-record.sh` usage all give the same steps. Record
  `reduction-record.sh --kind coverage --id bg-<HEAD12> --reason "…"`, write the gate pass,
  then name `bg-<HEAD12>` in the closing report. candor's completion gate accepts that
  verdict only when that record exists; that side of the change ships in candor.
  **Why:** finding 5. A run with ~40 changed React files and no JS runner could only close
  by deleting `active-run.json`.
- **A UI walk when a group of UI cards closes.** The new
  `skills/task-execution/references/ui-walk.md` sets out a browser walk that the
  ORCHESTRATOR runs when a milestone (or a run) whose diff touches UI closes. It never runs
  in a worker. The walk serves the built assets and signs in through the walk access the
  spec settled; it never types the user's credentials, and if no access exists it asks or
  records the gap. It walks each changed surface at 1280 and 375 with an overflow probe
  (`scrollWidth > clientWidth` plus a scan for wide elements), tabs through the new
  controls (Escape must return focus to the trigger), reads the console, and emulates
  reduced motion where motion changed. Shots go to
  `.claude/task-runner/walk/<group>/{desktop,mobile}/<route>.png`, the layout design-kit's
  `snapshot.sh review` pairs. Surfaces the walk could not see are listed as not observed,
  never left out. The group's closing message and the completion report carry one Screens
  table (screen · width · before · after · not observed). The reference cites overseer's
  `acceptance.md` for the fuller checklist and states the minimum inline.
  `task-execution/SKILL.md` gains a short section, and `run.md` step 4 a line.
  **Why:** the same four sessions' UI output, reviewed the same day. In one session, 34 UI
  worker subagents made 0 browser calls. Eight UI defects surfaced after the build: six through
  code-reading reviewers, two through the one 2-minute browser check. Another session used
  the same tools and walked in the main thread. Its walk caught a 375 px overflow and a
  reduced-motion bug that six card reviews and a whole-diff review had missed.
- **`reduction-record.sh --evidence <path>`.** Records what was observed in place of the
  reduced step, such as the walk dir behind a `bg-<HEAD12>` no-runner coverage record.
  The path must exist and sit inside the repo root; otherwise it is a usage error (exit 3)
  and no record is written. It is stored repo-relative. The new
  `scripts/__tests__/reduction-record.test.sh` is the first harness for this script. It
  covers a plain record, `--evidence`, missing and outside-the-repo evidence, the bad-kind
  usage error, and a call from a subdirectory landing at the repo root.
- **Accessibility deferrals close in the run.** `reviewer-routing.md` no longer sends a
  reviewer's "→ /ui-ux:audit" or "a11y minor, to the backlog" to the follow-up backlog. At
  group close they go to ONE `ui-ux:a11y-engineer` dispatch (or to the card's worker when
  ui-ux is absent), or `review-skip.sh --reason` records them. A UI card reviewed without
  `ui-ux-reviewer` needs a skip or exemption record, because the observer counts any
  reviewer and cannot see which one is missing.
  **Why:** in that first session the deferred focus-loss items became a backlog entry
  that was never fixed. `ui-ux-reviewer` was never spawned across 27 UI worker spawns, and nothing
  recorded why.

### Changed
- **Skill prose trimmed under the 160,000 B corpus cap (167,709 → 157,982 B), no rule changed.** `ui-walk.md` cites overseer's `acceptance.md` instead of restating it; restated rules across task-execution, track-orchestration, verification-panels, code-redteam and tree-wide-gates became one line plus a pointer; dated derivations moved to `rationale/2026-09-25-task-runner-prose-derivations.md`.
- The UI walk's surface list is the union of the group's cards' `<walk>` lines plus any changed surface without one, and it signs in through the spec's Walk access row. `reviewer-routing.md` no longer primes `ui-ux:a11y-audit` for `frontend-reviewer`/`ui-ux-reviewer`, which preload it (ui-ux ≥0.26.3, web-dev ≥0.9.3); a `frontend`/`ui-ux` card falling back to `code-reviewer`, or an older install, still gets it.

### Fixed
- **Hook state follows the project root, not the shell's cwd.** `scope.sh`, `drift.sh`,
  `announce.sh`, `rv-observe.sh` and `rv-consent.sh` carry the shared `cc_state_root` block.
  They read `active-run.json`, the scope files, `cc-phase.json` and the index, and write
  their records, at the git toplevel. `behavioral-gate.sh` (without `--record-dir`) and
  `sweep-residual.sh` anchor their state the same way.
  **Why:** finding 2. The payload `cwd` follows the model's `cd`. After a `cd app/Models`,
  the scope lock found no scope files, the observer recorded no reviewer dispatch, and
  `sweep-residual.sh --dir src` left a `src/.claude/` behind.
- **Stale scope files no longer flag the next task.** `scope.sh` ignores every scope file
  while no `active-run.json` exists. It also ignores any scope file older than
  `active-run.json`, so a new registration retires the last run's files.
  **Why:** finding 8. A finished phase's `scope-*.json` flagged the next phase's spec edit
  as scope creep.
- **`drift.sh` yields to a registered run, not to a bare `scope.json`.** Now that `scope.sh`
  ignores leftover scope files, yielding to one would mute both hooks. `lane.tsv` updated.

### Residual
- Bash writes the parser cannot name are still invisible: `python open()`, `cp`/`mv`
  destinations, a path held in a variable, and any target past the eighth. mtimes compare
  at whole seconds under macOS's bash 3.2, so a stale scope file written in the same second
  as the registration still counts as live.
- The UI walk is `recorded`. No hook sees whether it ran, which reviewer ran, or what a
  shot shows. `--evidence` proves only that the path exists. A one-user walk cannot reach
  a second actor's state (a stale-row 403), so that state needs a named test. A browser
  tool that cannot save a PNG leaves `seen, not saved` in the table.

## 0.40.0 — 2026-09-24

### Added
- **`behavioral-gate.sh --isolate` builds its own disposable checkout.** It adds a detached
  `git worktree` of HEAD under `mktemp -d` and checks that the directory exists and that git
  inside it names a different toplevel from the live repo. If either check fails it
  refuses with exit 3 and runs nothing; it never falls back to the live tree. It links
  `vendor`/`node_modules`, copies `.env` from the tree's own `.env.example` by absolute
  path, exports a throwaway `APP_KEY` for Laravel (no `key:generate`), writes the verdict
  record to the live repo's `bg/` dir, and removes the worktree on exit. It never reads or
  writes the live `.env`. `run.md` step 4, the behavioral-gate, task-execution and
  track-orchestration texts all name `--isolate`.
  **Why:** on 2026-09-24 a run followed the old instruction, "invoke from a disposable
  checkout", and built the checkout by hand. The permission layer rejected the Bash call
  holding `git worktree add`, and the model did not see that the worktree was never made.
  In the next call, `cd /tmp/<dir>; cp .env.example .env && php artisan key:generate` ran
  in the live repo after the `cd` failed, and a developer's `.env` and `APP_KEY` were
  overwritten.
- **Refuses in a registered run's live tree.** Without `--isolate`, the gate exits 3 when
  `.claude/task-runner/active-run.json` is at the toplevel. `--in-place` is the explicit
  escape for a caller that is already in a disposable copy.

### Residual
- `vendor/` and `node_modules/` are symlinks to the live directories, so a suite that
  writes into them writes to the live tree. The worktree is HEAD, so uncommitted changes to
  tracked files are not tested; the gate warns about this but does not refuse.

## 0.39.1 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** reviewers list every blocker and major finding (only minor ones past the tenth may collapse); routing.md quotes task-executor's comment-density rule correctly; discipline-preamble and negative-control paths are plugin-root-relative; the ≥0.11.0 Goal-marker pin and "as today" phrasing are gone; role-floors, fleet-and-apply, behavioral-gate, ultra-assess and dispatch-tier drop dated history. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.39.0 — 2026-09-23

### Changed
- **Card readers accept taskmaster's role-tagged card shape.** The routing reference
  reads the worker tag from `<agent>` and the skills to prime from `<skill name="…"/>`
  elements; delegation-contracts' skill-priming rule and task-execution's ordering rule
  name the same elements. A legacy bold-label card (`**Agent:**`, `Skills to apply`,
  `Depends on`) is still read — the acceptance is for in-flight card sets, not a second
  template. Why the shape changed, and the measurement showing it changes nothing on the
  READING side: taskmaster's `skills/task-cards/references/card-shape.md`.

## 0.38.0 — 2026-09-22

### Added
- **`scripts/behavioral-gate.sh` resolves a runner for PHP, Rust, Ruby and Java/Kotlin**,
  and takes `--runner '<cmd>::<empty-output-regex>'` (repeatable) for anything else.
  Before this the classifier knew `py`/`js`/`go`: every other language fell to
  `HAS_OPAQUE=1` → `no-behavioral-coverage` → exit 2, with no flag to escape, and candor's
  Stop gate then refused every close — a gate that could not be passed rather than a rule
  that could be followed. Driven against REAL toolchains on 2026-09-22 (PHPUnit 13.3.1,
  cargo 1.98.1, rspec 3.13.6, Gradle 9.7.1): four green-suite fixtures went EXIT=2 → EXIT=0,
  and four fixtures whose runner executes zero tests still exit 2. Empty-detection per
  runner is in `skills/behavioral-gate/references/runners.md`; 16 harness cases pin it.
  Two things the Java row states rather than hides: `--rerun-tasks` is required because
  the gate runs from a copied checkout carrying `build/`, where a plain `gradle test`
  reports `:test UP-TO-DATE` and executes nothing (→ `unverifiable-suite`, never a pass);
  and a green `gradle test` prints no counts at all, so that one path falls back to
  "test sources exist and the task did not fail" — weaker than every other row.
  `--runner`'s residual is the caller's: a regex that never matches turns an empty suite
  green and nothing in the script can tell. The gate still owns the two failures a
  declaration cannot paper over — a command that never started (126/127/signal) and one
  that hung (124).

### Changed
- **`hooks/scope.sh` enforces the union of every `scope*.json`**, not just the fixed
  `scope.json`. `task-execution/references/routing.md` writes one `scope-<cardId>.json`
  per delegated or tracked card, so the path the plugin sells was scope-locked by prose
  only: with per-card files present and no `scope.json`, the hook was silent on every
  edit. Union rather than per-file because the payload carries a path and not a card id.
  Residuals now in the header: a worker in another WORKTREE never reaches this hook at
  all, a stale card file widens the union rather than narrowing it, and one malformed
  member disarms the whole call (a partial union would warn about a path the file it
  could not parse had allowed). Nine harness cases.
- `commands/run.md` names `--runner` in the completion-gate invocation and the seven
  languages the gate resolves on its own.

### Fixed
- **`hooks/ultra-assess.sh` starts `#!/bin/bash`, not `#!/usr/bin/env bash`.** The absolute
  interpreter is what makes the fail-open claim in the hook's own header true under a
  stripped PATH, where `/usr/bin/env bash` exits 127 and the host reads the miss as an
  allow. Rendered from `templates/boost-hook.sh.tmpl`, not edited here; `pc_hook_shebang`
  reads the claim back and fails the build now that every shipped hook agrees with it.
- **`hooks/drift.sh` validates the payload `cwd` with `[ -d ]` before `mkdir -p`.** It
  did not, and recreated a project directory the user had just deleted, four levels deep
  — reproduced against the committed hook. The state dir is now anchored at
  `git rev-parse --show-toplevel` when there is one (pattern:
  `overseer/hooks/track-read.sh`). Residual: a cwd that IS a directory but not this
  project's still gets state — the check proves existence, never identity.

## 0.37.0 — 2026-09-22

### Added
- `hooks/announce.sh` (SessionStart, matcher `startup|resume|clear`): one line when the
  project has a registered run — slug, branch, how many index cards are still open, and
  the declared arc phase. `active-run.json` outlives the session that wrote it while the
  model's knowledge of it does not, so a cold session met candor's Stop block at the end
  of its first turn with no idea what the run was, and the cheapest-looking escape was
  deleting a live run's sentinel. Standing: advisory — SessionStart context informs a
  turn and cannot block one; the teeth remain the Stop gate. Pure read, silent with no
  run registered (so the always-on and activated context budgets read 0), and compaction
  is left to skill-router's capsule. Pinned by `scripts/__tests__/announce-hook.test.sh`.

### Fixed
- `commands/run.md` step 1 pre-created `rv/`, `rt/`, `bg/` and `reductions/` but not
  `nc/`, and `negative-control.sh` only creates it lazily on the first control that
  actually runs — so a run that skipped its first control left candor's gate on its
  "no `nc/` dir → legacy allow" path and the per-card negative-control count never armed.
- `skills/code-redteam/SKILL.md` named `plugins/task-runner/scripts/code-redteam-diff.sh`,
  a repo-relative path that does not exist on an installer's disk; now
  `${CLAUDE_PLUGIN_ROOT}/scripts/`.
- `commands/plan.md` read `$ARGUMENTS` with no `argument-hint` frontmatter.

## 0.36.6 — 2026-09-22

### Fixed
- `agents/task-executor.md` told every worker to write the fixed `scope.json`, which
  parallel workers clobber and which `routing.md` reserves for the inline tripwire; it
  now writes `scope-<task-id>.json` and says the hook does not read it.
- `track-orchestration/SKILL.md` cited `references/reviewer-routing.md`, a file that
  lives under `task-execution/references/`; path corrected.

## 0.36.5 — 2026-09-18

### Changed
- `delegation-contracts/references/discipline-preamble.md` clause 2: an exit code is evidence
  only if captured — the Bash tool may run zsh, where `${PIPESTATUS[0]}` is empty (two of three
  workers wrote it on 2026-09-18 and reported statuses they never saw). Clause 4: blaming an
  out-of-set file for a failed check requires the output line naming it. The `SKILL.md`
  evidence section says which report the orchestrator always doubts
  (`rationale/fable-distillation-2026-09-18.md`).

## 0.36.4

### Fixed
- `lane.tsv`'s `spawn-cap` trigger said "an Agent dispatch". `hooks/spawn-cap.sh:45`
  matches `Agent|Task` and `hooks/hooks.json` registers the same matcher, so the row
  understated the hook it describes — the row 0.36.3 rewrote to "say what the hook
  does" got the threshold right (one soft cap, then every doubling) and the tool set
  wrong. Regression review, 2026-09-17.

## 0.36.3

### Changed
- Marketplace trend audit, 2026-09-16 (`rationale/marketplace-trend-audit-2026-09-16.md`).
  B4: the README said `scope.sh` "enforces" a card's file list; `hooks/scope.sh` warns, once
  per edit outside the set, and never blocks — the README now says so. G12: `lane.tsv`'s
  `spawn-cap` trigger claimed a per-run budget of "20/40/80 by tier"; the hook counts per
  session against one soft cap (20) and then every doubling, no tiers, and the lane row now
  says what the hook does. C3: the README gains one boundary sentence each on the host's
  built-in `/run` (launches the project's app; unrelated to `/task-runner:run`) and `/batch`
  (one background subagent per worktree, PR each; `--tracks` keeps the sole-writer merge
  rule). D1: `behavioral-gate` carries `disable-model-invocation: true` — every consumer
  runs `scripts/behavioral-gate.sh` and nothing loads the skill by description, so its
  description no longer sits in always-on context. D5: `code-redteam`'s description leads
  with its gating clause (a boosted task-runner run only; an ad-hoc diff →
  `/code-review:review`) so an ordinary "red-team this diff" prompt no longer matches it.
  `commands/run.md` gains a `<!-- host-ok -->` line for the name it shares with the host's
  `/run`.

## 0.36.2

### Fixed
- `drift.sh`'s header said `CC_REMIND=off` silences "every advisory nudge here"; `scope.sh`, the run-scoped tripwire, reads no switch by design. The header now says which hooks the switch covers and that the tripwire is not among them.

## 0.36.1

### Changed
- **A boosted run now fans out on the Agent tool, not only on `Workflow`.** 0.35.1 fixed
  this in `verification-panels` and left it wrong in the two files that consume it plus the
  boost hook's own injected directive: `code-redteam`, `references/ultra-assess.md` and
  `.chassis.json` all keyed the uncorroborated inline fallback on the `Workflow` tool being
  absent. `Workflow` needs an explicit `ultracode` opt-in, so in an ordinary interactive
  session it usually IS absent — which meant the commonest way to invoke `ultra-assess` or a
  boosted red-team silently downgraded to one single-model pass while `verification-panels`
  said, correctly, to spawn the real panel through the Agent tool. The trigger is now what
  that skill already owned: no dispatch mechanism **at all**. Re-run
  `scripts/generate.sh --write` — `hooks/ultra-assess.sh` renders from the manifest.
- **`spawn-cap` is documented.** 0.35.0 shipped a `PreToolUse` hook that puts a permission
  prompt in front of subagent dispatch #20 and named it in no README, no description and no
  skill, so the first visible sign of it was an unexplained prompt mid-fan-out with no
  discoverable off switch. The README now states the thresholds, what it cannot see, and
  `CC_SPAWN_CAP`.
- `scripts/reduction-record.sh` accepts five `--kind` values (`redteam`, `dispatch`, `suite`,
  `coverage`, `other`); the README named the narrowed-suite case in prose while the only flag
  list on offer showed two of them.

### Fixed
- **`isolation-halt` was never a string the script prints.** Four files listed it beside
  `discriminating` / `vacuous` / `invalid-control` as if all four were stdout verdicts.
  The first three are echoed on stdout; `negative-control.sh`'s exit-5 path prints prose to
  **stderr with stdout empty**, and the token appears nowhere in the script — so a caller
  branching on stdout falls straight past its halt branch on the one result that must halt.
  All four sites now branch on the exit code, and `references/negative-control.md` says why.
- **A `--tracks` run could not stop clean.** The track-worker's negative-control invocation
  in `references/algorithm.md` omitted `--record-dir`/`--card`, so N done cards inside track
  leaves recorded zero controls and the completion gate refused the stop — the exact
  blocks-having-done-nothing-wrong failure that section's reviewer-record half exists to
  prevent. The record now goes to the MAIN repo's `nc/` by absolute path, because `.claude/`
  is gitignored and a worktree-local record merges nowhere.
- `references/negative-control.md`'s own copy-pasteable invocation dropped the two flags that
  write the record, so following it literally produced a control that ran and did not count.
- **The `task-executor` agent claimed "~40 chassis-generated `/…:review` commands" dispatch
  it without a discipline preamble.** One command in this marketplace is generated from
  `templates/review-command.md.tmpl`, and the commands that dispatch the executor are
  hand-written. The residual is real — none of them injects a preamble — so it now states
  that and gives the recount instead of a number.
- `delegation-contracts`' fleet-inventory table listed a11y, debugging and observability as
  having *neither* a worker nor a reviewer wired, long after all three shipped a worker
  agent — a stale table that would send a reader to build what already exists. Replaced by
  the decision it was for plus `ls plugins/*/agents/`.
- `role-floors.md` said "the seven above" over a six-row registry, and resolved `auto`
  through a taskmaster section heading that does not exist; both now point at this plugin's
  `verification-panels/references/dispatch-tier.md`, which owns the tier rule.
- `hooks/drift.sh` cited `scope.sh:32` for a guard that sits on line 40; `commands/run.md`
  said its two sentinels clear "at step 9" in a five-step procedure (they clear in step 4);
  `parallel-planning` said "this plugin's plugin's".

### Removed
- `scripts/_placeholder.sh`, which existed to reserve a directory that now holds seven
  shipped scripts.

## 0.35.1

### Fixed
- **`rv-consent`'s lane now declares `any`, not `build`.** It is armed by run state — a registered task-runner run whose reviewer verdict is unconsented — not by where you are in the arc, so a phase-specific claim was one no gate could check and no behaviour honoured. `pc_phase_guard` was widened the same day to cover deny-capable tool-channel hooks, which is what surfaced it.
- **`verification-panels` contradicted itself about when a panel is real.** One line keyed the inline fallback on the `Workflow` tool being absent, another correctly keyed it on whether N agents actually dispatched. The Agent tool is a real dispatch path, so the first line sent ordinary sessions to an uncorroborated single pass while `approach-deliberation` spawned the panel — the two disagreed on the same turn.

## 0.35.0

### Added
- **`spawn-cap`: an `ask` at 20 subagent dispatches, then at every doubling.**
  `scripts/turn-cost.sh` already states the fact this acts on — subagent turns do not
  appear in the transcript and they are billed — and nothing in this marketplace
  counted them, so a fan-out planned as three agents and grown to thirty was invisible
  until the invoice. `ask`, not `deny`: a large fan-out is sometimes right, and the
  claim is not that thirty is wrong but that thirty should be a decision. Thresholds
  double rather than firing every time, because asking at 21, 22, 23 trains reflexive
  approval, which is the same as not asking. It counts dispatches, not cost — twenty
  haiku calls and twenty opus calls are the same number here and not the same bill.
  `CC_SPAWN_CAP=<n>` moves the first threshold, `CC_SPAWN_CAP=off` disables it;
  `scripts/__tests__/spawn-cap.test.sh` drives 11 cases.

## 0.34.4

### Changed
- **`.claude/task-runner/` ignores itself.** The directory now writes a self-ignoring `.gitignore` (`*`) the first time a hook creates it. Plugin state under the user's `.claude/` showed up as untracked in `git status` in every repo without a hand-written ignore line — observed live, and named by overseer's acceptance protocol as "other plugins' scratch" — one `git add -A` away from being committed. One harness assertion per plugin. `hooks/scope.sh` and
  `hooks/drift.sh` drop the file as soon as they see the directory (a registered
  run's first edit), `scripts/review-skip.sh` and `scripts/reduction-record.sh` when
  a record lands under the default root (never under a `--record-dir` override), and
  `/task-runner:run` step 1 writes it at registration so a run interrupted before any
  hook fires leaves no untracked state either.
- A header comment in `hooks/drift.sh` no longer cites the removed `lean` plugin's hook.

## 0.34.3

### Changed
- `skills/task-execution/SKILL.md` and `skills/track-orchestration/SKILL.md` say whose
  gate "the completion gate" is: candor's clause 4, enforced only with candor installed.
  The README, `run.md` and `behavioral-gate` carried that condition since 0.33.0; the two
  bodies still read as an unconditional gate. `hooks/drift.sh`'s comment no longer cites
  the removed `lean` plugin as a live path. No behaviour change.

## 0.34.2

### Changed
- `plugin.json` description says what the README already said: the run-completion Stop
  gate is candor's clause 4 since 2026-09-14, so a by-name install without candor has no
  gate — the catalog and `/stack-scan:suggest` show the description, not the README.

## 0.34.1

### Changed
- `lane.tsv`: `/task-runner:plan` and `parallel-planning` declare the `plan` phase (the
  command yields to the skill); `behavioral-gate` declares `verify`. No behaviour change.

## 0.34.0

### Added
- **orchestration merged in** (2026-09-14 consolidation plan §3.1): the
  `delegation-contracts` and `verification-panels` skills with every reference
  (role-floors, discipline-preamble, fleet-and-apply, tree-wide-gates,
  dispatch-tier), `scripts/dispatch-lint.sh` with its harness, and the `ultra-assess`
  boost hook re-rendered from the boost-hook chassis as `task-runner:ultra-assess`
  (`ORCHESTRATION_BOOST` keeps its name). Every `orchestration:<skill>` citation in
  the marketplace now reads `task-runner:<skill>`; the role-floors resolution ladder
  probes this plugin's own root first. `lane.tsv` rows for both skills.

### Changed
- The `ultra-assess` skill body is `skills/verification-panels/references/ultra-assess.md`:
  the boost hook's directive names the path, so a listing entry was a second trigger
  for the same text.

### Removed
- Orchestration's review command. It reviewed prompts, not code; what it ran mechanically
  (`dispatch-lint.sh`) ships here, and its eight-point checklist is the
  delegation-contracts skill's own § Prompt contract.

## 0.33.0

### Removed
- `hooks/completion-gate.sh` and its `Stop` entry in `hooks/hooks.json`. The
  registered-run Stop gate is now clause 4 of candor's one Stop gate
  (`plugins/candor/hooks/gate.sh`): the same records check — gate pass for HEAD, card
  counts, per-card `nc/` and `rv/` coverage, `bg/` verdicts, red-team panel width,
  reduction disclosure — the same messages, the same `TASK_RUNNER_STOP_GATE` modes,
  the same per-HEAD nudge under `.claude/task-runner/`. Every writer of those records
  stays here (`run.md`, `rv-observe.sh`, `behavioral-gate.sh`, `review-skip.sh`,
  `reduction-record.sh`, `negative-control.sh`); only the Stop-time reader moved, and
  `scripts/smoke/completion-gate-hook-tests.sh` still drives the writers and the
  reader together. A run can end by narration if candor is not installed —
  process-suite and taskmaster-suite now carry it (2026-09-14 consolidation plan, §4.2).

## 0.32.0

### Added
- `Goal: true (boost=off)` — taskmaster's `goal-lean` marker. Hands-off autonomy (auto-take,
  run through, never merge) without the boost: no tier escalation, no code-redteam pass, and
  the completion gate owes no red-team panel. `boost-execution.md`, track-orchestration,
  code-redteam, the executor agent and `completion-gate.sh` read the suffix; an older
  runner reads a lone `Goal:` as boosted (overpays, never under-verifies). Smoke: a
  `boost=off` index with an empty panel is allowed.

## 0.31.6

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.31.5

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.31.4

### Changed
- `routing.md` and `reviewer-routing.md` resolve the `performance` and `observability`
  tags to resilience's workers and skills; both plugins merged into resilience on <!-- removed-ok -->
  2026-09-02.

## 0.31.3

### Changed
- The completion gate names `/api-design:drift`; api-docs-first merged into api-design <!-- removed-ok -->
  on 2026-09-02.

## 0.31.2

### Changed
- `reviewer-routing.md` primes `ui-ux:a11y-audit` for frontend and ui-ux cards; the a11y <!-- removed-ok -->
  plugin merged into ui-ux on 2026-09-02.

## 0.31.1

### Changed
- `reviewer-routing.md` primes `database:sql-best-practices` for database-tagged cards;
  the sql plugin merged into database on 2026-09-02. <!-- removed-ok -->

## 0.31.0

### Changed
- **`track-orchestration` names the harness as a second owner of `.claude/worktrees/`.**
  The cleanup guard already refused to touch worktrees outside this run's
  `<run-branch>-track-*` namespace, but it is one-directional — it stops the run
  touching someone else's trees, not the reverse. Claude Code's `EnterWorktree`
  creates trees in the same root and `ExitWorktree` prompts the user to keep or
  remove them at session exit, which can reach a live track worktree mid-run. The
  halt/handoff report now names the run's live track worktrees so that prompt is
  answerable.

## 0.30.1

### Changed
- **Meta-prose compressed to a one-line standing tag** (part of a marketplace-wide
  pass). No actionable rule changed; named cross-skill references preserved.

## 0.30.0

### Fixed
- **The scope lock no longer admits siblings that merely share a text prefix.** The
  allow-match was a raw `startswith`, so an entry was a prefix of arbitrarily many
  unrelated paths: `src/util.ts` admitted `src/util.tsx`, `src/api` admitted
  `src/apikeys.ts`, and a directory entry like `app/Models` admitted an entire
  parallel tree at `app/ModelsBackup/`. The lock reported nothing in every one of
  those cases — the near-miss paths a drifting edit actually produces. Matching is
  now equality or a true directory boundary (`$a + "/"`), with four boundary cases
  added to `scripts/__tests__/scope-hook.test.sh` (10 -> 14).

## 0.29.7

### Fixed
- **The run-start tier announcement is reachable again.** It is unconditional — every
  run announces its worker tier, boosted or not — but it had been displaced into
  `references/boost-execution.md`, whose own header reads "Read this when `00-INDEX.md`
  carries an `Ultra: true` or `Goal: true` marker. **On a standard run none of it
  applies.**" A rule for standard runs sat inside the one file that declares itself
  inapplicable to them, so a plain `/task-runner:run` had no reachable instruction to
  announce its tier while all four taskmaster commands carry their own.

## 0.29.6

### Changed
- **Every hook entry now declares a `timeout`.** `drift.sh` 5s, `rv-observe.sh` 5s, `scope.sh` 5s, `rv-consent.sh` 10s, `completion-gate.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.29.5

### Fixed
- `task-execution/SKILL.md:66` cited "`references/role-floors.md`" unqualified,
  which reads as this skill's own `references/` dir — where no such file exists.
  The registry lives in `orchestration:delegation-contracts`. Every sibling <!-- removed-ok --> <!-- history: orchestration merged into task-runner 2026-09-14 -->
  mention (`task-executor.md:25`, `routing.md:127`) already qualified it; this one
  did not, so a reader following it found nothing.

## 0.29.4

### Changed
- `code-redteam` now says WHY its N=3 is fixed while `orchestration:verification-panels` <!-- removed-ok --> <!-- history: same merge -->
  sizes N to blast radius. A conflict audit found the two shipped opposite verdicts on
  the same number: that skill declares itself "the sizing authority for every consumer"
  with 2 refuters for a small radius and forbids a consumer inventing its own N, while
  this one said "spawn exactly three" directly under "reuse it wholesale" — and
  `completion-gate.sh` hard-blocks a boosted run below 3 lenses. A proportionally sized
  2-refuter panel was therefore unstoppable except by filing a `reduction-record` that
  claims a degradation which did not happen. N here is the lens count, not a radius
  call, so the fix is to record the exception on both sides rather than change either
  number. `verification-panels` now carries it as a table row.

## 0.29.3

### Changed
- `parallel-planning`'s boundary sentence names plan-before-code as the owner of
  task decomposition; the skill it named was merged there. <!-- removed-ok -->

## 0.29.2

### Changed
- `task-execution`'s body is 9,907 bytes, down from 11,918. The Extreme Boost
  block (~1.9 kB, inert on every standard run) moved to
  `references/boost-execution.md` and the role-tier floor's resolution rules to
  `references/reviewer-routing.md`; both are cited at the decision point. No rule
  was deleted — the body had grown 31% under a frozen 154-line count, which is
  the growth the new byte ceiling exists to make visible.

## 0.29.1

### Changed
- `task-execution/references/reviewer-routing.md` routes the database track to
  `sql:sql-best-practices`. Its old target, `database:database-design`, was <!-- removed-ok --> <!-- history: sql moved into database, database-design merged away -->
  merged into that skill — the rubric moved, the routing follows it.

## 0.29.0

### Added
- **`hooks/drift.sh`** — the ad-hoc complement to `scope.sh`. **Standing: advisory.**

  `scope.sh` compares each edit against a card's declared file list, and its first
  line is `[ -r "$scope" ] || exit 0` — so on a one-line request typed straight into
  a session, which is most turns, nothing watched whether the work stayed near what
  was asked. This is the marketplace's only **stack-agnostic** discipline surface:
  it counts files against a request, so a Dockerfile turn, a SQL turn and a React
  turn are read identically.

  It asks one question, once per request, when all four hold: no declared scope, at
  least **12** distinct files edited since the last typed message, no breadth marker
  in that message (`everywhere`, `rename`, `migrate`, `all the files`, …), and at
  least half those files unnamed in it.

  **The threshold is measured, not chosen.** 400 local transcripts, 169 turns that
  edited a file: p50=2, p75=5, **p90=12**, p95=21, p99=40, max=157. An earlier draft
  of this idea proposed 4 — which would have fired on roughly a third of all turns,
  and is why it was refused the first time rather than shipped with a guess.
  Re-derive from your own transcripts before changing it.

  **Known limits, stated in the hook:** it counts **breadth only, never depth** — an
  unasked refactor inside the one file you named is invisible, and that is probably
  the commoner way to stray. A legitimately wide request phrased in words the marker
  list does not know is a false positive. It reads only the last typed message, so a
  request built over three turns is scored against its final sentence. And whether a
  given extra file was necessary needs a reader, which is why the message ends in a
  question rather than a verdict.

  Silence with `CC_DRIFT=off`, or `CC_REMIND=off` for every advisory here.

## 0.28.2

### Fixed
- **A sibling Stop gate's block no longer spends this one's enforcement.**
  `stop_hook_active` is a SHARED flag — Claude Code sets it on the continuation after
  ANY blocking Stop hook — and this gate exited on it unconditionally, before its own
  loop-bounding marker was ever reached. Two Stop gates ship in this marketplace, so
  one blocking first disarmed the other for that continuation. The gate now evaluates
  normally and bounds itself with its own marker; the shared flag is honoured only when
  that marker cannot be written, which is the one case where nothing else bounds the
  loop. Verified: with the flag set, the first stop still blocks and an identical second
  stop does not.

## 0.28.1

### Added
- **`lane.tsv`** — declares the territory and phase of `task-executor` and the
  completion-gate Stop hook, so no sibling can silently claim the same job.

### Changed
- **`/task-runner:run` writes `.claude/cc-phase.json`** (`phase: build`) alongside the
  existing `active-run.json`, and clears both at step 9. The two are deliberately
  separate: `active-run.json` registers a RUN for this plugin's own Stop gate, while
  `cc-phase.json` declares a PHASE that every installed reminder hook reads — including
  in installs that have neither task-runner nor taskmaster. It is what stops a
  "clarify before your first code edit" nudge firing on turn 40 of an executing run.
- **`completion-gate` is declared `phase: any`**, not `verify`: a Stop gate has to fire
  whenever a turn tries to end, and scoping it to one arc phase would have let a turn
  ending during `build` escape it entirely.

## 0.28.0

### Fixed

- **The card-agent resolution map did not bind on the `Workflow` path.**
  `skills/task-execution/references/routing.md` resolves a card's `Agent:` tag to
  a worker (`laravel:backend-engineer`, `security:security-engineer`, …, else
  `task-executor`) and said only "dispatch the resolved worker with that prompt".
  A `Workflow` `agent()` call without `agentType` spawns the generic workflow
  subagent: steps 1–2 run, the prompt arrives, and the worker's own contract does
  not. The whole map is decorative on that path, and nothing in the run says so.

  What went missing in practice, on a 30-card fan-out: `task-executor`'s *"match
  the surrounding file's naming, idiom, and comment density"* and its *"new
  behavior no test exercises is named as untested"* rule. Neither reached a
  single writing agent. The output carried roughly twice the repository's own
  comment density and eight times its tests-per-integration, and every gate
  passed green — the checks that existed measure correctness, not proportion.

  Step 5 now names both dispatch forms (`subagent_type` on the Agent path,
  `agentType` on the `Workflow` path), states what is lost when it is omitted,
  and requires the bound agent to be logged per card in the run report.

- `skills/track-orchestration/references/algorithm.md` step 3 — the wave batch
  now passes `agentType: 'task-runner:task-executor'` alongside `model:`/`effort:`,
  under the same "this is a parameter of the call, not prose in the prompt" rule
  the tier already had. Also records why a track worker stays `task-executor`
  rather than a specialist: it runs mixed cards inline as a leaf, so there is no
  per-card resolution to bind, and skill priming carries the framework knowledge.

### Notes

- **Standing: agent-graded.** `scripts/validate.sh` gates shipped `agent(<args>)`
  code samples (`pc_dispatch_binding`), which is what catches a recipe. It cannot
  read a prose dispatch instruction and confirm an orchestrator obeyed it, and it
  cannot see a `Workflow` script composed at runtime — which is how the original
  failure happened. The per-card run-report line is the only thing that makes an
  unbound dispatch visible after the fact.
- Not addressed here: nothing in this marketplace measures test or comment
  *proportion* against a repository's own house style. Every surface pushes test
  count up (`verify-teeth`, `behavioral-gate`, the negative control,
  `coverage-check`) and none pushes back.
