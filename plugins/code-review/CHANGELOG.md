# Changelog — code-review

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first.

## 0.22.1

### Changed
- **A `critical` or `high` finding says how to show it fails.** The prose line's problem
  clause now carries the input or state that produces the wrong output — the content
  `ReportFindings`' `failure_scenario` already required, so the prose line stops being the
  poorer copy on hosts without the tool. Format unchanged (`path:line — severity — problem
  — fix`); the fan-in still merges on it. From the Opus 5.5 playbook's review prompt
  (claude.dev, 2026-09-22): "give the file and line, why it's wrong, and how to show it
  fails".

## 0.22.0

### Added
- **The two comment DENIES have an off switch, and every refusal names it.**
  `scan.sh` and `density.sh` read `CC_REMIND` on their advisory lane only, so the
  `PreToolUse` block — the one that actually stops a write — could be silenced by nothing
  and told the blocked reader nothing. Both now read `CC_COMMENT_GUARD=off` on the deny
  lane and name it in the deny reason; the advisory messages name `CC_REMIND`. The two
  lanes switch separately on purpose: turning the block off leaves the finding visible.
  Documented in the README (panel finding UX 1; `pc_offswitch_named` reports the file, not
  the branch, so which message carries the name stays agent-graded).

## 0.21.1

### Changed
- **`commands/comment-review.md` is hand-maintained now, not generated.** It was the only
  file in the marketplace rendered by the review-command chassis — a 24-line template,
  four partials and nine opt-out justifications producing one artifact, which is more
  prose in the machinery than in the thing it made. The rendered output is inlined
  verbatim (the `generated from templates/...` header is gone); nothing else about the
  command changed. `.chassis.json` keeps the entry as a plain opt-out note, and its lane
  row moved from the generated block into the hand rows of `lane.tsv`.

## 0.21.0

### Added
- **`conventions.sh` reads five more CI formats.** It swept `.github/workflows/` and nothing else, so every GitLab, CircleCI, Jenkins, Azure Pipelines and Bitbucket repo got the configs half of the message and no `CI runs:` line — while the same message told the reader that whatever CI invokes is the standard. `.gitlab-ci.yml`, `.circleci/config.yml`, `Jenkinsfile`, `azure-pipelines.yml` and `bitbucket-pipelines.yml` are now read with the prefix each format uses for a shell command. Its header names what still escapes: any other runner, a composite or reusable workflow, a command built from a variable, and anything past the first hit.

### Fixed
- **A deleted project directory is no longer recreated by a hook.** `verbosity.sh`, `density.sh` and `scan.sh` took the payload's `cwd` on trust and ran `mkdir -p "$cwd/.claude/comment-discipline"` — which rebuilds every missing parent. A session outlives the directory it started in, and a deleted project came back three levels deep holding nothing but hook state. All three now require the directory to exist. `scripts/__tests__/cwd-guard.test.sh` reproduces the old behaviour and keeps it closed.

## 0.20.1

### Fixed
- **The stack fan-in roster omitted the CSS and accessibility analyzers.** It named phpstan/psalm/phpcs and tsc/eslint/biome/vue-tsc, so toolchain-experts' `ui-expert` — the agent whose whole job is running stylelint, pa11y, axe and lighthouse-ci — sat in no dispatch path from this command. The analyzer row now names those four tools and the agent that owns them, which by this file's own rule ("a plugin that ships a review command and is not named here is a defect in this file") it should have from the start.

## 0.20.0

### Changed
- **`reuse-hygiene` now fires on the words you actually type.** Its description promised "the deep pass" without naming what the deep pass is, so "find the unused exports in this module" or "run knip on this repo" routed nowhere. It now names unused exports, export-aware orphan detection, and the three tools it shells out to (knip, vulture, deadcode) — all of which its body already documented.
- **`/code-review:review` shows its arguments in the slash menu.** It was the only command here with no `argument-hint`, so the UI gave no sign that a path, a PR number, a branch, or `--debt` is accepted.

### Fixed
- **The README documented three of the four hooks this plugin ships.** `conventions.sh` — the `PostToolUse` one-shot that emits the paths of your formatter/linter configs and the CI command that invokes them — was described only in this changelog, so an installer had no way to learn it exists, what it emits, or that `CC_CONVENTIONS=off` silences it alone. Also fixed the closing verdict: the README called the middle verdict `merge-after-blockers` while the command and the agent that emit it both say `merge-after-criticals`.

## 0.19.1

### Fixed
- **A co-firing deny no longer costs you the comment check.** `scan.sh` and `density.sh` recorded their once-per-file bound when they DENIED — but a deny does not mean the write landed. Any sibling PreToolUse hook denying the same call (testing's test guard, secret-scanning, command-guard) blocked it too, the bound was already spent, and the next edit of that file went through unchecked. Measured with all 31 marketplace plugins installed; unreachable with this plugin alone, which is how it survived. The bound is now two denies per file, which survives one co-firing deny and bounds a loop exactly as before, and it is kept in atomic `mkdir` markers rather than a counter file — the read-modify-write version let two parallel subagents editing one file both read the same count and exceed the cap. Residual, stated in the hook: the bound is still spent on a DENY, so two co-firing siblings can exhaust it. **Every shipped statement of the bound now says two, not one** — the two hook headers, both LIMITATION blocks, this plugin's description, its README, frontend-suite's, and the comment-discipline skill's has-teeth block. That last one was missed on the first sweep and caught on the second. They all still said "once per file per session" after the behaviour changed, which understated the cost of a false positive by exactly half in the blocks a reader consults to price one.
- **`/code-review:review` stops dropping findings CI never catches.** Its refute list dropped anything a linter or type-checker "would report", on the premise that CI runs those. In a repo with a configured-but-unenforced analyzer, CI runs nothing and the finding was dropped anyway. The row now requires the tool to be one CI ACTUALLY runs, and points at toolchain-experts' analyzer-triage, which reads the workflow to decide.
- **`toolchain-experts` added to the fan-in roster.** The roster calls itself the contract and says an unnamed review plugin is a defect in that file; the letter of it excused a plugin shipping review AGENTS and no review command, so toolchain-experts was missing for the 12 days it existed.
- **`comment-discipline`'s description named an override that does not exist.** It promised a house style in CLAUDE.md overrides the default; neither hook parses CLAUDE.md. The real lever is `COMMENT_DISCIPLINE_CEILING_TENTHS`, which the skill body already documented.

## 0.19.0

### Fixed
- **The fan-in now reaches two rubrics that claimed it already did.** `resilience`'s
  `event-driven` skill (which arrived in 0.6.0) and `laravel`'s `inertia-best-practices`
  were named by their own plugins as loaded by this command and were not in its load
  list: a broker-touching diff lost the delivery/ordering rubric, and a Laravel+Inertia
  diff lost the Inertia rubric because an Inertia page is a `.vue`/`.tsx` file the
  language row sends nowhere. Both are now loaded, Inertia gated on the manifest.
- **`CC_REMIND=off` works on every advisory this plugin ships.** The README promised it
  marketplace-wide while only `conventions.sh` read it; `scan.sh`, `density.sh` and
  `verbosity.sh` ignored it. They honour it now in their WARN lanes only — a PreToolUse
  deny is not an advisory, and an env var must not turn a block into a pass.

### Changed
- **MCP file writes reach the comment-discipline detectors.** Nothing here; see
  `secret-scanning` 0.6.0 for the same change to the write guards.
## 0.18.3

### Changed
- **`.claude/comment-discipline/` ignores itself.** The directory now writes a self-ignoring `.gitignore` (`*`) the first time a hook creates it. Plugin state under the user's `.claude/` showed up as untracked in `git status` in every repo without a hand-written ignore line — observed live, and named by overseer's acceptance protocol as "other plugins' scratch" — one `git add -A` away from being committed. One harness assertion per plugin. Written by `scan.sh`
  (deny markers), `density.sh` and `verbosity.sh` (per-session state).
- Hook comments no longer cite the removed `lean` plugin's hook as a pattern source;
  the idiom is cited from `hooks/conventions.sh`. No behaviour change.

## 0.18.2

### Changed
- README no longer names terse-crew as a `code-reviewer` dispatcher — that skill was <!-- removed-ok -->
  dropped with the terse merge into candor (2026-09-14). Prose only.

## 0.18.1

### Changed
- The fan-in list no longer names `payments` or `llm-app`; both plugins were removed
  from the marketplace on 2026-09-14. A `hooks/density.sh` comment no longer cites the
  removed lean plugin's hook as its pattern source; behaviour unchanged.

## 0.18.0

### Fixed
- **The fan-in now names every rubric the per-stack commands hand up to.** Every
  generated review command tells the model "the aggregator reaches this plugin's
  rubric too" — and for testing, devops, api-design, craft-layer (three.js),
  payments and llm-app the fan-in list never named their skills, so a mixed diff
  with tests silently lost the test rubric. The stack fan-in list now carries all
  of them, with the file or content shape that triggers each, and states that a
  review command not named there is a defect in this file.
- **The resilience deferral loop is closed.** The concern-axis rule said resilience
  owns failure-mode, error-handling, concurrency, observability and performance
  findings and this review "does not duplicate" them, while every `/resilience:*`
  command hands its whole scope back to this one — a loop in which nobody ran the
  rubric. The fan-in now LOADS resilience's skills in the same pass and reports each
  finding once under the owning skill; when resilience is absent, step 2 keeps it.

## 0.17.0

### Changed
- **`/code-review:review` delegates its generic pass to the host's built-in
  `/code-review` skill** (Claude Code 2.1.259+) when the session has it, and keeps
  the scope resolution, the hunk read, the history pass, the stack fan-in and the merge; without the built-in
  it runs the generic pass inline as before. Output contract unchanged.
- The `code-reviewer` agent is **kept**, deliberately: it is the dispatchable
  reviewer that task-runner's reviewer pass, terse-crew, orchestration's fleet <!-- removed-ok -->
  routing and every per-stack review command yield to, and a host skill cannot be
  spawned as a subagent. The 2026-09-03 marketplace review had planned to delete
  it; the plan was wrong and is recorded as declined there.

## 0.16.3

### Changed
- Citations of the four-laws / has-teeth doctrine now point at
  `.claude/skills/authoring-skills/SKILL.md` in the marketplace repository — the
  authoring plugin was demoted to a tracked project skill on 2026-09-03. Prose only;
  no behaviour change.

## 0.16.2

### Changed
- The generated lane block from 0.16.1 is now the marketplace-wide form: the same
  `# generated:start` … `# generated:end` markers every plugin's `lane.tsv` carries,
  rendered by the sweep that gave the eight suites their first `lane.tsv`. No row of
  this plugin changed; no behaviour change for a user of the plugin.

## 0.16.1

### Changed
- `lane.tsv`'s row for `/code-review:comment-review` is now rendered by
  `scripts/generate.sh` from the `lane` key on its `.chassis.json` object (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand.
  Same territory, same trigger; `generate.sh --check` now fails if the two drift.
  No behaviour change for a user of the plugin.

## 0.16.0

### Changed
- **The self-refute pass covers `high` as well as `critical`, and has a checklist.**
  `/code-review:review` and the `code-reviewer` agent now refute each finding against
  a six-row false-positive taxonomy — pre-existing, silenced, tooling-caught,
  intentional, senior-reviewer nit, unstated style preference — and drop a match
  rather than downgrade it. Ported from the official `code-review` plugin's rubric
  and its false-positive list; the numeric 0-100 confidence score was not ported, the
  marketplace-wide `CONFIRMED`/`PLAUSIBLE` verdict already carries that distinction.
- **History pass.** When a diff edits or removes existing lines, the review reads the
  blame of the touched hunks and reports any reversal of a line a bug-fix or
  workaround commit added, naming that commit. Additions-only diffs skip it.

## 0.15.0

### Changed
- **The default is no comment.** `comment-discipline` now states an absolute default
  — code speaks for itself; a comment is one line for a fact the code cannot show; a
  docblock exists only for what the signature cannot state — and names the one override:
  a house style stated in the project's `CLAUDE.md`. "Match the surrounding file's
  comment density" is gone from the skill and from every worker agent's preamble.
- **`scan.sh` denies a third category.** A docblock tag that repeats the signature
  (`@param $id The id`, `@return void`) is now denied on the `PreToolUse` lane, same
  one-per-file-per-session bound as restatement and commented-out code.
- **`density.sh` has a ceiling and a deny lane.** The comment-to-code limit is now
  min(2x the committed siblings' median, 0.4:1); a file with no committed siblings
  is judged against the ceiling instead of skipped; the sibling floor dropped from
  0.8 to 0.3. On `PreToolUse` the hook denies a whole `Write` over the ceiling, once
  per file per session. Override per project with `COMMENT_DISCIPLINE_CEILING_TENTHS`
  in settings `env` (10 for 1:1, 0 for the sibling test only).
- Warning and deny messages changed; anything asserting the old "judged against the
  surrounding code, not a constant" wording must update.

## 0.14.1

### Added
- **comment-discipline merged in.** The `comment-discipline` skill, <!-- removed-ok -->
  `/code-review:comment-review` (was `/comment-discipline:review`), and the three <!-- removed-ok -->
  write-time hooks (scan, density, verbosity) ship here. Hook behaviour, messages, and
  the `.claude/comment-discipline/` state paths are unchanged. The absorbed plugin's
  own changelog history stays in git history under its old directory. <!-- removed-ok -->

## 0.13.4

### Changed
- The fan-in's defer list names resilience for observability and performance findings; <!-- removed-ok -->
  both plugins merged into resilience on 2026-09-02.

## 0.13.3

### Changed
- `reuse-hygiene` names stack-scan's package-hygiene for yanked or deprecated packages;
  the packages plugin merged into stack-scan on 2026-09-02. <!-- removed-ok -->

## 0.13.2

### Changed
- **The stack fan-in loads database's sql and mariadb skills** for `.sql` files and
  migrations; the two plugins merged into database on 2026-09-02. Same signals,
  same finding format.

## 0.13.1

### Changed
- **The stack fan-in names web-dev's skills where it used to name three plugins.**
  `nextjs`, `react-native` and `vite` merged into `web-dev` (2026-09-02); the skills
  keep their names, so the fan-in loads `web-dev`'s `nextjs-best-practices`,
  `react-native-best-practices` and `vite-best-practices` under the same file and
  manifest signals as before. No finding format or severity change.

## 0.13.0

### Added
- **`/code-review:review` emits through `ReportFindings` when the host provides it.**
  Claude Code ships a typed findings tool whose usage rule waits for an active
  code-review instruction to ask for it; this command is that instruction. Findings
  now go out both ways — the typed array for the host UI, and the existing
  `path:line — severity — problem — fix` prose, unchanged, because the prose format
  is what the stack fan-in merges on. Absent the tool, nothing changes.
- **A stated boundary against Claude Code's built-in `/code-review`** in the README.
  The names collide and the deliverables genuinely differ: the built-in is deeper on
  one diff (effort levels, `ultra`, `--comment`, `--fix`), this plugin is the fan-in
  across every installed stack review, plus the `--debt` lane. The plugin already
  stated its boundary against the built-in `simplify`; this closes the larger gap.

## 0.12.6

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.12.5

### Changed
- **Every hook entry now declares a `timeout`.** `conventions.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.12.4

### Changed
- **The debt ratchet names its standing**: `unenforceable` against the model
  itself — `--update-baseline` is runnable by any session, so the command now
  states the line can be reset by the session that crossed it, and forbids
  running it to green a red report. The gate that would block that write does
  not exist yet.
- **Stack fan-in routing** no longer names removed plugins (react, php, vue3,
  livewire); `.tsx`/`.jsx`/`.vue` now fall to the baseline pass, laravel rides
  composer.json, and the sql lane pairs with mariadb only.

## 0.12.3

### Changed
- No behaviour change. `conventions.sh` was already correct — it hashes the
  context key through `cksum` before that key becomes a filename, which is what
  keeps its one-shot working when the host sends a `transcript_path` (an
  absolute path). Nothing had ever tested that: every case in its harness sent
  `session_id` only, so the branch that runs in production never executed. Three
  sibling hooks in this marketplace lacked the same hashing and shipped broken
  behind an equally green suite. The harness now proves the hook still speaks and
  still bounds its one-shot under a path-shaped key, and `pc_harness_payload`
  fails the build if that coverage is ever removed.

## 0.12.2

### Fixed
- **One-shot markers now key on `transcript_path`, falling back to `session_id`.**
  PostToolUse is the only hook channel that reaches subagents at all, and a subagent
  shares its parent's `session_id` while getting its own transcript — so a
  session-keyed marker the parent already claimed deduped the worker's nudge away.
  The advisory was structurally silent in the one context where most fan-out code is
  written. `scripts/lib/plugin-checks.sh`'s new `pc_context_key` gates it.

## 0.12.1 — 2026-08-16

### Added
- **`lane.tsv`** — `code-reviewer` declares `stack-agnostic-diff-review` and the
  deference edges it already documented in prose (architecture, security, frontend and
  UI reviewers). `terse:terse-reviewer` declares the same territory and yields to this <!-- removed-ok -->
  one, so the two no longer both claim a diff with nothing arbitrating.

## 0.12.0 — 2026-08-15

### Changed
- **`code-reviewer` now triages before the deep read**, on the same thresholds
  `commands/review.md` already used. The command had the triage; the agent did not — and
  the agent is the one dispatched automatically, on every task's diff, with no condition
  (`task-runner`'s execution skill and its reviewer-routing reference both say *always*).
  It ships `model: opus` / `effort: xhigh`, so a 20-line mechanical change was drawing a
  full neighbourhood read that the same plugin's command would have answered in one line.

  The short lane is a **conjunction**: single-file AND purely mechanical AND under the
  thresholds (5 files / 300 changed lines). Any doubt on any clause takes the full pass,
  and since this agent has no `Bash`, a dispatch naming a path rather than a diff counts
  as doubt. The full pass is mandatory regardless of size on auth, data, migrations,
  concurrency, **money, PII, and irreversible operations** — the last three are new here,
  added so this list, `coding-entry`'s risk clause and `lean:cost-model`'s blast-radius
  trigger name the same set.

  Two deliberate limits on the saving. The short lane closes with `not reviewed —
  mechanical, below triage threshold`, never `merge-ready`: a verdict on an unread diff
  would be a claim the agent did not earn. And it **never** drops the per-criterion lines
  that `task-runner`'s reviewer dispatch injects — that audit is the review's floor, and
  a return without it is re-dispatched, which would have cost more than the full pass.

  **Upgrade note.** Automated per-task reviews of mechanical diffs get shorter and now
  say so explicitly. Thresholds are restated here rather than only referenced, so they
  can drift from `commands/review.md`; nothing checks that they agree.

### Added
- One rule: **a finding that would not change what the author does next is not a
  finding.** Review output is itself a cost, and the marketplace had no statement of that
  anywhere. This is the theater test applied to findings rather than to gates.

## 0.11.0 — 2026-08-14

### Fixed
- **`scripts/debt-scan.sh` now counts Pest skips.** `P_SKIP` covered PHPUnit's
  `markTestSkipped`/`markTestIncomplete` but not Pest's chained `->skip()` /
  `->todo()`, which is the idiomatic form in Pest — so a Pest suite's quarantined
  tests counted **zero** while the same project's PHPUnit-style skips counted
  normally. Pest is not fringe in this marketplace: it ships `php` and `laravel` <!-- removed-ok -->
  plugins, and `testing`'s flake-hunt runner table lists Pest by name.

  **Upgrade note.** `skipped_tests` will RISE on any Pest project the first time
  this version runs, so an existing `.claude/debt-baseline.json` may fail
  `--check` on a tree nobody changed. That is the ratchet reporting debt it
  previously could not see, not new debt — re-run `--update-baseline` once to
  re-level, and read the delta as a one-off correction.

### Added
- **Per-runner skip fixtures** in `scripts/__tests__/debt-scan.test.sh`. The
  aggregate assertion was satisfied by a single `it.skip` in one TypeScript
  fixture, which is precisely how the Pest gap survived a green harness — nothing
  ever asked whether a PHP suite's skips were visible at all. Seven runners
  (Pest ×2, PHPUnit, vitest, pytest, go, JUnit) are now each asserted in an
  isolated tree.

## 0.10.0 — 2026-08-02

### Added
- **`hooks/conventions.sh`** — a PostToolUse hook that fires once per session, on
  the first code write, naming the PATHS of the files defining this project's
  conventions (`.editorconfig`, formatter, linter, pre-commit) plus the CI command
  that enforces them. It emits locations, never a summary of their contents: a
  distilled checklist injected before the model reads the source measurably
  narrows the review. Silence it with `CC_CONVENTIONS=off`, or `CC_REMIND=off` for
  every advisory nudge in this marketplace.
- **`scripts/debt-scan.sh`** and a `--debt` lane on `/code-review:review` — five
  language-agnostic debt categories (suppressions, skipped tests, bare markers,
  deprecated-symbol references, feature flags) counted against a committed
  `.claude/debt-baseline.json`. `--check` exits 2 when any category GREW;
  `--update-baseline` accepts growth deliberately. `--age` resolves first-seen
  dates by git pickaxe, which turns "340 TODOs" into "11 older than two years".

### Changed
- `/code-review:review`'s apply pick now names a dispatch target
  (`task-runner:task-executor if installed → inline`). It was the flagship
  fan-in command and the only one whose apply pick named nothing, so findings
  died in chat while 31 chassis siblings routed theirs.
- `code-smells` now states its boundary with Claude Code's built-in `simplify`
  skill, which covers overlapping ground and applies fixes. Use the host skill for
  a quick cleanup pass; use this one when the question is which smell, and whether
  it is a smell at all.

### Notes
- The debt scanner counts OCCURRENCES, not severity. It answers "is this getting
  worse", never "is this bad".
