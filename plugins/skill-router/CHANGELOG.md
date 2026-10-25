# Changelog

All notable changes to the skill-router plugin.

## 0.27.0 — 2026-10-25

- **Removed: the stack-scoped skill listing** (`cc_route_scope`, `CC_ROUTE_SCOPE`, `hooks/listing.ts`, `hooks/stack-evidence.sh`). It shipped off by default because nothing showed a shorter listing helps, and the marketplace's own eviction probe measured 47/50 against 47/50 for a name-only listing; a default install carried it as code that never ran. Compaction steering is unchanged. A `cc_route_scope` you set is now ignored.
- **The shared mod kit exports `hostOf` and runs the git-root lookup once per hook call.** `hooks/cc-kit.ts` (byte-identical in every mod plugin) now exports the host adapter that seven feature files pasted, and remembers `stateRoot` per host object, so a hook that asked three times runs `git rev-parse` once. It also carries `countOutcome`, a counts-only `$.store` tally.

## 0.26.0 — 2026-10-14

### Fixed

- **The tool-fit check waits out questions and hands-off asks, and reads `error` as a symptom only where an incident names it.** It fired on "I have a question, don't work on anything"-shaped prompts, on `?`-ended error reports and on a crash question, because its work-shaped grep took a bare `error`, `errors`, `crash` or `crashing` as a request and nothing skipped a question: 1,770 bytes each time, in four measured sessions. A prompt ending in `?` now stays silent only when it holds no word of the work test's strong tier (a making verb, `500s`, `regressed`, `not working`) and no request form (`can`/`could`/`would`/`will` + `you`/`someone`/`anyone`, `please`, `why`, `any idea`); anything else reaches the work test as before: `can you fix the login bug?`, `is it possible to add pagination…?`, `why won't the page load after the deploy?`, `what's causing the 500s?`, `the checkout is broken, can someone look?` and `tests are failing after the merge — any idea?` fire. A hands-off ask stays silent when no strong-tier word outside it opens a clause or follows to, please, a modal or a conjunction: "don't work on anything|it|this|that" before punctuation, the end, `yet`, `for now`, `until` or `before`; "don't change anything yet"; or a whole prompt "(please) don't change anything". A noun beside it is not an ask (`I got a question about the deploy, don't work on it`). The work beside a hands-off clause fires (`Refactor the importer, but don't touch anything yet in the exporter`, `implement the hook in app/, never work on that`, `I need you to build the export, but don't change anything yet`), and a hands-off phrase about another object is a constraint (`do not work on the legacy importer`). A `<pasted_content>` span is cut first, as in ask-ledger and taskmaster: verbs only inside a paste beside typed text no longer make the prompt work, and a long paste no longer pushes the typed ask past the 400-character head; a prompt that is only a paste is read whole. `error`/`errors` and `crash` left the bare tier for the state-verb tier, whose verbs gained `an`, `with`, `see` and `throw`, and an `Error` opening a sentence still counts: `I'm getting an error when saving`, `the export throws errors`, `keeps throwing errors` and `Error: Cannot find module…` fire, `that error message in the log is from the old version` does not. The question and frame tests come from the byte-locked `templates/blocks/prompt-shape.md`, shared with ask-ledger, code-review and taskmaster; a `<task-notification` with attributes is now a frame, and the hand-back marker makes one only where a line opens with it. Residuals: a `?`-ended symptom report with no strong-tier word and no request form (`the login is broken?`) is read as a question and waits for the next work prompt; an error named with no state verb and not opening a sentence (`login error after the upgrade`) is missed; beside a hands-off clause, a strong-tier noun opening a clause still fires (`don't work on it; test setup question`) and an ask after an unlisted lead waits (`we'll fix it later, don't work on it yet`). Pinned by `scripts/smoke/prompt-route-tests.sh`: "question: ?-ended error report", "question: measured error report", "question: hands-off ask", "question: hands-off beside a question naming a noun", "question: hands-off first, a question naming a noun", "chat: bare error", "chat: bare crash" and "paste: verbs only inside a paste" stay silent (each red against the committed hook), eight cases from "symptom: getting an error" to "request: failing, can you take a look?" fire as 0.25.1 did, thirteen from "request: why isn't … passing?" to "work: implement …, never work on that" fire as 0.25.1 did after the first cut of this change had silenced them, and "paste: an ask after a long paste" fires where 0.25.1 was silent. Standing: gate for the shapes; the question test is a function call, which the four-prompt-grep budget does not count.

- **Every skill name the router prints is `plugin:skill`, and a project's same-named skill is called out.** The prime line, the per-edit nudge (whose `(X plugin)` tail is gone), the signals digest and the SessionEnd line printed bare names, and in nine measured sessions a bare `Skill("testing-best-practices")` loaded the project's own `.claude/skills/` copy (Laravel Boost ships several), so the plugin's file never reached the work; in one session subagents read the project copies 94 times and `laravel:laravel-best-practices` none. `prime.sh` now names each skill qualified and, when `<root>/.claude/skills/<name>/SKILL.md` exists for a primed skill, adds one line naming those skills. `pending_low` entries carry a `plugin` field; the ledger's skill lists are unchanged. Residual: a shadow under `~/.claude/skills` is not checked; whether the model then loads by the qualified name is agent-graded. Pinned by `subagent-skills.test.sh` case 9 and `route.test.sh` case 19.
- **A PostToolUse edit draws at most two nudges, none for a skill already loaded, and none for a file nobody reviews.** Nudges were followed 0 of 25 and 0 of 14 times in two measured sessions; seven fired on one vendored copy, others on skills already invoked, on `taskmaster-docs/` evidence files and on a gitignored scratch script. Now: import and command rows rank first, other file rows next, the language-wide `low-cognitive-load`, `solid-principles` and `a11y-audit` last, ties in `rules.tsv` order; a skill matched by more than one row takes its lowest rank and that row's subject; and a skill over the cap is not marked fired, so a later edit carries it. A skill whose `Base directory for this skill:` line, `SKILL.md` Read or qualified Skill call is in the context's transcript is skipped and recorded under a separate `loaded` key, so the context looks for it once and the SessionEnd ledger keeps it out of `fired`, which reports what this router surfaced (the ledger row gains a `loaded` field), one fixed-string grep over the whole file run only when a nudge is pending (measured +35 ms on a 56 MB transcript, about 1 ms at the median; a tail read would miss a skill loaded at session start). A target outside the project root, under `taskmaster-docs/` or `.claude/`, or ignored by git routes nothing and queues nothing; the `git check-ignore` call adds about 4 ms per edit. Residuals: a skill loaded before a compaction still counts as loaded; a path spelled through a different symlink than the root reads as outside; a committed vendored tree still routes; quoting the matching rule inline instead of "load X", and measuring compliance from the ledger, are not done. Pinned by `route.test.sh` cases 6 (cap and carry-over), 20 (exclusions, tracked file still routes) and 21 (three loaded shapes skip, the project's copy loaded does not), 20 assertions red against 0.25.2; case 22 pins the lowest rank (a `components/` stylesheet importing `tailwindcss` keeps Tailwind inside the cap; `shadcn add` beside `components.json` quotes the command) and case 23 the loaded mark (a second edit does not grep the transcript); `scripts/smoke/route-marker-tests.sh`'s case-insensitive directory fixture gained a `package.json` so its two `*.vue` canaries do not crowd the directory row out of the cap.
- **A `/loop` wakeup is no longer read as a new ask.** In two reviewed sessions every scheduled fire was text the model had passed to ScheduleWakeup, and it reached `route-prompt.sh` as plain prompt text: the payload carries no origin field, and the host writes its fire record after the hook starts. A host `/loop` tick (`# Autonomous loop check`, `# Autonomous loop tick`, `# /loop tick`) is now a harness frame and leaves the signal digest queued. A prompt equal to a ScheduleWakeup or CronCreate call's `prompt` in the transcript draws no tool-fit check, after the flush, the way the `/loop` slash command that set it did not. The transcript is read only when the once-per-session check would otherwise print, and a re-fire leaves that check for the next typed ask. Both tests come from the shared `templates/blocks/prompt-shape.md`. Residuals: a durable task from an earlier session, and a scheduled prompt ending in a newline, read as typed; a prompt the user retypes verbatim while its call is in the transcript is silenced. Pinned by `scripts/smoke/prompt-route-tests.sh` ("/loop tick", "ScheduleWakeup re-fire", both red against the hook before this change, beside "typed prompt beside a wakeup"; "a later work prompt reads no transcript", red before the read moved behind the marker test, beside "a re-fire first leaves the marker for the typed ask") and `route.test.sh` case 18's tick arm (flushed before). Standing: gate.

### Added

- **A file a Bash interpreter run wrote routes as an Edit of it would.** In four measured sessions 40–85% of code writes went through `python3 - <<'EOF'` heredocs, which no per-file hook saw; in one, auth logic written that way drew no security-review signal while it was being written. After a Bash call naming python, node, php, ruby, perl, deno, bun, cp, mv, install or patch as a word, `route.sh` asks git which files changed or appeared since its own previous call (`git status` under `GIT_OPTIONAL_LOCKS=0`, then an mtime test against a marker every call rewrites, Edit included) and routes up to eight (`MAX_BASH_EFFECTS`) through the same per-file path, deduped against the targets the command names. The detection is the new byte-locked `templates/blocks/bash-write-effects.md`. Measured, 20 runs, median: on the largest local repo (2,786 tracked files) a non-matching call 13.6 ms (7.5 ms before: it now reads the cwd and the state root to date the marker), a matching call that wrote nothing 18.5 ms, a python heredoc writing three PHP files 164 ms against 73 ms for one Edit of one of them; on a 100,000-file repo 13.5, 50 and 191 ms. Right after a clone, until any git command refreshes the index, the matching call's `git status` re-hashes every file (127.5 ms on the 2,786-file repo); an Edit costs what it did. A range review's second round on the block, folded in here: a command that exits non-zero fires `PostToolUseFailure`, not `PostToolUse`, so `route.sh` is registered on it for Bash and answers in that event's envelope (before, a red `python3 … && php artisan test` read nothing and the next call dated its writes away); `cat gen.py | python3`, `python3;ls` and `make && python3` now count (the word could not end the command or meet `;`); the marker holds the session's cksum and another session's reads as none, so the user's overnight edits are not the next session's first run; a `$HOME` root and a repo with `status.showUntrackedFiles=no` read nothing (a non-git folder under a dotfiles `$HOME` listed 150,000 files a hook); the block reads tracked `.claude/` files for the other adopters, plugin state staying out by its dir's `*` `.gitignore`, and `route.sh`'s own target rule still routes nothing under `.claude/`; a state dir that already existed gets its `.gitignore`; git's list goes to one `find` capped after it (30,000 untracked files: 281 → 51.5 ms a call), and the regex runs under `LC_ALL=C` (a 150 kB base64 `echo … > logo.png` 419 → 199 ms, a 1 MB token 15 s → 115 ms). Re-measured on a synthetic 2,786-file repo, 20 runs, median (max), before → after that round: a non-matching call 11.4 (11.7) → 12.8 (13.0) ms, a matching call that wrote nothing 18.2 (19.3) → 22.8 (25.1) ms. Residuals: the first call of each session that reaches the hook only sets the marker, and two sessions in one repo at once read nothing after each other's calls; a writer named another way (`npx prettier --write`, `make`, `git apply`), a gitignored output, a repo with no git, a submodule's files, a `mv` or `cp -p` destination (it keeps the source's mtime) and changed files past the eighth are missed, the cap counting files the router then skips; a `run_in_background` command's hook runs at launch, so its writes are read only by the next matching call; anything else that changed a file between two calls of the session (an IDE save, a parallel agent) is read as the run's write. In the repo-path fallback (no `CLAUDE_PLUGIN_DATA`) the marker creates `.claude/skill-router/`, self-ignored, on the first call in a git repo, so cases 2, 3, 14 and 14b of `route.test.sh` now assert no fired state and nothing git can see instead of no `.claude/` directory. Pinned by `route.test.sh` case 24 (a python write routes what an Edit does and queues security-review for an auth file; a matching run that wrote nothing, the first call in a repo and an Edit's file between two Bash calls stay silent), 5 assertions red against the committed hook, and case 25 (the `PostToolUseFailure` registration and envelope, the piped python, another session's marker, a `$HOME` root, `showUntrackedFiles=no`, an existing state dir's `.gitignore`, a 1 MB token within 3 s), all 8 red against 0.26.0's first cut. Standing: gate for those shapes and for the block's byte lock (`pc_shared_blocks`); the over-read is recorded.
- **`general-purpose` and `claude` subagents get the repo's stack skill paths when their dispatch names a repo file, and a surface skill rides only a dispatch naming its file kind.** The SubagentStart matcher skipped generic agents, which built money and role features with no stack skill, while Vite's path was handed to plugin agents 20 times and read twice and SQL's 23 times and read 7. The dispatch prompt is not on disk when SubagentStart fires (probed twice on CLI 2.1.299: the parent's Agent `tool_use` and the subagent's files are written after the hook), so `subagent-skills.sh` now also runs on `PreToolUse` of the Agent call, prints nothing, and appends which file kinds the prompt named to `dispatch-<ctx>.tsv` in the router's state directory (a dispatch of a type it does not handle, such as Explore, exits after one `jq` read, before any `git` call); `summary.sh` removes it at session end. Vite, SQL/MariaDB, package-hygiene, Docker and CI skills need a matching file named (`vite.config.*`; `.sql` or `migrations/`; `composer.json`/`package.json`; a Dockerfile or compose file; `.github/workflows/`), unless the agent declares nothing else, as `database:database-engineer` does. Residuals: dispatches of one agent type within 120 seconds share one record, so a parallel fan-out is judged as a whole; a dispatch held longer than that for approval reads as naming nothing; a migration described but not named by path does not count; a nested dispatch's keys are unmeasured. Pinned by `subagent-skills.test.sh` cases 1-1f and 10 (both `hooks.json` matchers included), 17 assertions red against 0.25.2, and case 11 for the early exit. Standing: gate for the record, the gate and the matchers; agent-graded whether the agent reads the paths.
- **Dependency updates and ReUI or Metronic copies route.** A 72-package `composer update` routed nothing, because an update rewrites only the lockfile, and a ReUI port of 78 components arrived by `cp` and drew shadcn and Tailwind but never `reui-best-practices`: the copied files import nothing from `@reui/`. A probe on this release's own Bash-write read confirmed the copy still routes only generic rows. New `command` rows: `(composer|npm) (update|upgrade)` → `stack-scan:package-hygiene`, and a `cp` or `rsync` naming a ReUI or Metronic path → `ui-libraries:reui-best-practices`. No `@reui/*` package.json prime: `@reui` is a shadcn registry namespace, not an npm package. Residuals: a quoted source path is masked and does not route; `pnpm`/`yarn` updates and `composer u` do not; a `/cp/` path segment before a ReUI path does route. Pinned by `route.test.sh` case 26 (six commands, each silent without the rows; five neighbours stay silent). Standing: gate.

## 0.25.2 — 2026-10-14

### Fixed

- **The "Signals from recent edits" digest waits for a human prompt, and doc and style files no longer feed it.** `route-prompt.sh` flushed the digest before its harness-prompt filter ran, so it landed on task notifications, subagent hand-backs, Stop hook feedback and system reminders, where nobody judged it: 45 of 65 digests in one measured session. Those frames, on ask-ledger's prefix list, now exit before the flush and the digest stays queued. Separately, `route.sh` queued a low-confidence content match from any file, so `token` or `password` in a spec, a runbook or a stylesheet queued `security-review`; a `.md`, `.mdx`, `.markdown`, `.txt`, `.rst` or `.css` file, or anything under `taskmaster-docs/`, now queues nothing, the exemption database's `guard.sh` already makes. `high` content rows still fire inline on a `.css` file. Residuals: a harness frame not on the list still flushes; a doc that really is about the concern (a security runbook) draws no signal; the "judge each in one line" clause is unchanged and unmeasured. Pinned by `scripts/__tests__/route.test.sh` case 18 (four doc/style files queue nothing and a `.php` edit still queues; five frames leave the digest unflushed, a human prompt quoting a frame marker flushes it), 16 assertions red against 0.25.1, plus case 15, where a `NOTES.md` match no longer reaches the digest and a `.py` match still does. `route-pins.test.sh`'s low-pass fixture moved off `.txt`, and `subagent-skills.test.sh` case 1c now expects web-developer's `inertia-best-practices` (web-dev change).

## 0.25.1 — 2026-10-09

- **Compaction steering leaves out a stale phase sentinel.** A `.claude/cc-phase.json` last written more than 120 minutes ago, the TTL its writer gives every reader, no longer reaches the summarizer's instructions; before, a sentinel left by a crashed or abandoned run was asked to be kept word for word in every compaction. The task-runner run file has no TTL and is still listed. Three new tests.

## 0.25.0 — 2026-10-08

- **A hooks module (Claude Code 2.1.291 or newer), `hooks/mods.ts`, with two features.**
- **Stack-scoped skill listing, opt-in** (`cc_route_scope` / `CC_ROUTE_SCOPE`, default off).
  - The listing the model reads drops the eight stack skills whose `prime.sh` evidence row does not hold here, naming them on one line.
  - A hidden skill still loads by name (measured).
- **Compaction steering** (`cc_compact_steer` / `CC_COMPACT_STEER`, default on). While pipeline state is on disk, the summarizer is told to keep the phase, run, card in progress, scope lock and done list.
- **Standing:**
  - **Gate:** `tests/listing.test.ts` and `tests/compact.test.ts`, 24 cases, each red against a stubbed copy, and `scripts/__tests__/stack-evidence.test.sh` for the evidence script on real directories.
  - **Recorded:** the live probe in `rationale/2026-10-08-skill-router-mods-probe.md`.
  - **Untested:** automatic compaction.

## 0.24.0 — 2026-10-06

- **`jsrepo add` routes `shadcn-best-practices`**, the way `shadcn add` already did: a new `command` row, so the copy-in rules in its `references/registries.md` (now with a jsrepo section, ui-ux 0.30.0) arrive with the install. `jsrepo init` stays silent.
- **Magic UI and React Bits installs also route `aceternity-best-practices`** (ui-libraries 0.3.0 widened it to them). A `shadcn add` or `jsrepo add` whose arguments include `@magicui/`, `@react-bits/` or a `https://reactbits.dev/r/` URL draws both skills in one envelope; a `jsrepo add` of any other registry draws shadcn's alone. No glob row: read 2026-10-06, 77 of 78 Magic UI items name no install target and React Bits targets only its `-CSS` stylesheets, so there is no fixed directory to match.
- **A `locomotive-scroll` import routes `scroll-orchestration`**, which now covers Locomotive Scroll 5 (craft-layer 0.57.0). The README's library and registry-install lines say so.
- **Standing: gate** — `scripts/__tests__/route.test.sh` pins the unquoted `@magicui/`, `@react-bits/` and `reactbits.dev/r/` installs, `jsrepo add` routing shadcn's skill and not Aceternity's, `jsrepo init` silent, the quoted-argument miss, the locomotive import, and the one-envelope assertion on the existing Magic UI case; it runs in CI's plugin-harness step. Residuals: a quoted install argument is masked, so `add "@magicui/x"` routes shadcn's skill alone (pinned as a stated miss); a later edit of an installed Magic UI or React Bits file routes no Aceternity rules; an `ogl` import routes nowhere, by decision. The command rows run on Bash calls, which the budget gate's Edit-only probes do not meter.
- **Credit and effect.** Found while reviewing freshtechbro/claudedesignskills @1da73feb (MIT, © 2025 Claude Skills Project); rewritten here, not copied. Unmeasured: whether the routed skills change what the model writes. No eval with a control arm covers it.

## 0.23.1 — 2026-10-05

- **Organisation design systems route `component-libraries`.** The library-agnostic `content` row now also matches quoted imports of `govuk-frontend`, `uswds` and `@uswds/`, `@shopify/polaris` and `@shopify/polaris-types`, `@carbon/`, and `@atlaskit/` except its `pragmatic-*` packages — a general-purpose drag-and-drop library apps outside Atlassian use. Pinned by new cases in `scripts/__tests__/route.test.sh`: GOV.UK, Carbon, Atlassian, USWDS and Polaris imports route; the two pragmatic-drag-and-drop imports and a backticked `govuk-frontend` in a code comment or in Markdown prose do not.
- Still missed: GOV.UK Frontend's Nunjucks templates and Sass entry points, and Polaris's CDN `<script>`, which name no quoted package (ui-libraries' README says so). Still matched: a lockfile, a docs page or a code comment holding a package name in quotes. The effect on what the model writes is unmeasured.

## 0.23.0 — 2026-10-05

- **`.php`, `.tsx`, `.jsx` and `.vue` edits route `low-cognitive-load`** when code-architecture is installed, as `.ts`/`.js`/`.py`/`.go`/`.rb`/`.rs` edits already did, so the skill that states the no-comment default in one line reaches PHP, React and Vue files. Once per session, beside the framework, library and accessibility skills those files already drew. `solid-principles` is not added for them.
- `low-cognitive-load` is not routed on a `.blade.php` view or on a `.php`/`.tsx`/`.jsx`/`.vue` file whose name starts with a dot (`.php-cs-fixer.php`); those files still draw their other skills. PHP config, routes and lang array files do route, on purpose — they are code.
- Cost: the first such edit in a context carries one more nudge — about +84 tokens on the largest probe shape. The dynamic meter does not see it (its probe spends the one-shot on a `.ts` edit first), so skill-router's baseline stays 651.
- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/route.sh`, `route-prompt.sh`, `prime.sh`, `summary.sh`, `compact-capsule.sh` and `subagent-skills.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. After this cut each hook parsed to the same code as before (bash's own parser, comments ignored); `route.sh` and `route-prompt.sh` were then refactored (next entry).
- **The rest of the hook and test comments are cut to a contract line per file, plus off-switch and `Misses:` lines where it reads one or had a residual; behaviour unchanged.** The derivations, measurements and history moved to the marketplace repository's `rationale/derivations/plugin-skill-router.md`, which an install does not contain. `route.sh`'s main block now runs as named steps (`nudge_high_matches`, `queue_low_matches`, `deliver_nudges`, `persist_state`) and caps Bash targets with `MAX_BASH_TARGETS=8`; `route-prompt.sh` names its marker age `MARKER_TTL_MIN=1440`. Those two hooks therefore differ in code, so instead of a parse comparison: new pin tests (8 in `route-pins.test.sh`, 2 in `route-prompt-pins.test.sh`) passed on the old and the new code, and a run of the old against the new hook found 0 divergences in 160 input pairs for `route.sh` and 70 for `route-prompt.sh` (output, exit status and every file left behind compared). The other 8 changed files parse to the same code as before. The README now says `CC_ROUTE=off` also stops the next-prompt flush of low-confidence signals, which then appear only in the SessionEnd line. Not tested: bash 5, and hooks firing in parallel.
- **Docs corrected.** The README said a `command` row matches the whole command string, heredoc bodies included; since 0.21.0 it matches with quoted text masked and heredoc bodies blanked, and the README now says so. It also no longer lists a `{ …; } > f` group as not caught: the shared write-target block reports the group's target.
- `scripts/__tests__/route-pins.test.sh` and `route-prompt-pins.test.sh` find their hook from their own plugin root; they looked four directories up for the repository, so they failed from an installed copy.

## 0.22.2 — 2026-10-01

- **A file written after a lone `&` routes:** the shared `cc_bash_write_targets` block now ends a command at a lone `&`, so a write after one is read (`echo x & sed -i s/a/b/ f.json` used to return nothing) and words after one are no longer taken for `sed`/`perl`/`tee` operands; `cmd |& tee f` is read; a `-`-led file after `sed … --` or `perl -i` is returned. So `route.sh` routes on the file the second command writes, and no longer on words that only follow a `&`.
- Still not read: a `>& file` redirect, a bare `-x` operand with no `/` or `.` in it, and operands after a `&` inside `$(( ))` or `${ }` (that `&` ends the command). Over-read, harmless: a `-`-led argument to a perl script that contains `/` or `.`.

## 0.22.1 — 2026-10-01

- **`sed -i` edits route to the file they edit:** the shared `cc_bash_write_targets` block now returns every file a `sed -i` / `perl -i` command edits instead of its last word, never a trailing redirect (`sed -i … tsconfig.json 2>/dev/null` used to yield `2>/dev/null`), and recognises GNU `--in-place[=SUF]` and BSD `-I`. So `route.sh` routes on each edited file rather than on a redirect word or only the last operand.
- Still not read: a globbed operand (`tests/*.js`), a `\` line continuation, sed or perl reached through another word (`gsed`, `/usr/bin/sed`, `xargs`, `find -exec`), and a dot-named file right after a bare `-i` when another file follows (read as BSD's backup suffix).

## 0.22.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_remind`, `cc_route`, `cc_subagent_skills`, `cc_surfaced_log`, under `/config` (or `/plugin configure skill-router`), each with today's default. The environment variable (`CC_REMIND`, `CC_ROUTE`, `CC_SUBAGENT_SKILLS`, `CC_SURFACED_LOG`) still overrides its option, and `CC_REMIND` / `CC_BOOST` set in the shell still mute every plugin at once. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.
- **Hook state moved out of your repo.** When the host sets `CLAUDE_PLUGIN_DATA`, `fired-<ctx>.json` and `compact-log.jsonl` live under `${CLAUDE_PLUGIN_DATA}/<project-key>/skill-router/` instead of `.claude/skill-router/`. An existing in-repo dir is left in place and stays ignored (it carries its own `.gitignore`); delete it by hand if you like. Without the variable, nothing moves.
- `compact-log.jsonl` moved with the rest; the README says where to grep it.

## 0.21.0 — 2026-09-26

- Library skills now arrive at the first file that uses them: a `content` row marked `high` fires
  inline once per context (previously every library row waited for the next user prompt, and never
  reached a subagent). mui, astryx, primereact, component-libraries, motion, threejs,
  scroll-orchestration, motion-tiers and information-design rows are `high`.
- Fixed wrong routes: R3F → `threejs-best-practices`, Lenis/ScrollTrigger → `scroll-orchestration`
  (both previously went to `motion-best-practices`, which names neither); the Aceternity row no
  longer fires on every `motion/react` import; the observability row no longer fires on JSX `<span>`.
- New routes: Rive/Lottie/dotLottie/Spline → `motion-tiers`; chart and grid packages and interaction
  libraries (dnd-kit, schedulers, maps, xyflow, Tiptap/Lexical, virtualizers) → `information-design`;
  Tailwind v4 CSS; `components.json`; auto-imported Vue libraries; PrimeReact →
  `ui-libraries:primereact-best-practices`; a new `command` row type routes `shadcn add`.
- The moved component-library skills are owned by `ui-libraries`. `route.test.sh`: 108 cases.
- Review fixes before release: `command` rows match the command with quoted strings and heredoc
  bodies masked (a commit message mentioning `shadcn add` no longer spends the one-shot);
  `content`+`high` rows fire inline only on code and style files (prose falls through to the digest);
  each target file is read once; `pc_rules_reachable` now compiles `command` rows. `route.test.sh`: 123.

## 0.20.0 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

### Added
- **Files written through Bash route.** `route.sh`'s PostToolUse matcher now includes
  `Bash`. For a Bash payload, each target the command writes (`>`/`>>`, including
  `cat > f <<'EOF'`, `tee`, `sed -i`/`perl -i`, from the shared
  `templates/blocks/bash-write-targets.md` parser) is routed exactly as if it had been
  Edited: high-confidence path matches go inline, and content matches are read from the
  file on disk into the pending digest. The one-shot per signal per context and the
  single envelope per call still hold. At most 8 targets are examined per command, and a
  target must exist afterwards as a regular file under the project root. Why:
  in one measured session 233 of 238 main-thread writes were Bash heredocs, and the router
  routed ONE edit in three weeks of auth, token and HTTP-client work
  (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 1). Not caught:
  interpreter writes, `cp`/`mv`/`install` destinations, `{ …; } > f` groups, a path
  held in a variable.
  Cost: a Bash call with no write target exits after reading the command, before
  `rules.tsv` or any state is touched.
- `scripts/__tests__/route.test.sh`: 38 assertions over real commands in temp git repos.
  It fails 18 of them against 0.19.0's hooks, and each of three targeted mutations (cap
  removed, manifests read from cwd, globs matched on the absolute path) fails exactly
  the case written for it. `compact-capsule.test.sh` gained a subdirectory-cwd case.
- **Plugin subagents get their stack's skill paths.** New `SubagentStart` hook
  `hooks/subagent-skills.sh`, matched to plugin-scoped agent types only
  (`^[a-z0-9-]+:`). It resolves the spawned agent's definition in this marketplace's
  install root (flat or versioned cache, through `hooks/plugins-dir.sh`), reads its
  `bestpractices-skill:` list, and keeps the skills `prime.sh`'s manifest-evidence rows
  find at the project root, with the owning plugin installed and the SKILL.md present. It
  injects one `additionalContext` of at most 700 characters: the line "Read these before
  working; a path the dispatcher already gave you needs no second Read" and one absolute
  path per kept skill. `web-dev:frontend-reviewer` in a Laravel/Inertia/Vite repo now gets
  the Inertia and Vite paths and not React Native or Next.js. Why: `bestpractices-skill:`
  is this marketplace's own key, and only task-runner's dispatcher read it. Three ad-hoc
  `ui-ux-reviewer` spawns in one measured session read zero SKILL.md files
  (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 6). A static `skills:`
  preload of these lists was rejected because it cannot see the stack. Silent for
  built-in and project agents, an agent with no list, nothing matching, a skill the
  agent already preloads through `skills:`, and under `CC_REMIND=off` or the new
  `CC_SUBAGENT_SKILLS=off`. A declared skill `prime.sh` has no evidence row for (motion,
  security-review, performance-tuning, observability-design) is never handed out. Cost:
  200-265 ms per plugin-agent spawn on two real Laravel/Inertia repos. Not metered:
  `scripts/context-budget.sh` does not execute SubagentStart hooks. Probed once live
  (CLI 2.1.282, haiku, `--plugin-dir`): the subagent's transcript carried exactly the
  Inertia and Vite paths, and the agent quoted them back. Whether an agent then Reads
  them on a real task is unmeasured. Lane row `subagent-stack-skill-paths`, phase `any`.
- `scripts/__tests__/subagent-skills.test.sh`: 37 assertions against a fake versioned
  install holding the real agent files. Six targeted mutations each fail their own case:
  stack filter removed, `prime.sh` reading the cwd, the hook resolving from the cwd, cap
  removed, `CC_SUBAGENT_SKILLS` ignored, and the preload check removed.

### Changed
- **`prime.sh` reads manifests at the project root**, through the shared `cc_state_root`
  block, the same root `route.sh` reads its markers at. SessionStart fires again on resume
  and compact, and the payload cwd follows the model's `cd`, so a session compacted inside
  `app/Enums` was re-primed from that directory and lost `laravel-best-practices`. Same
  trade as `route.sh`: a session started inside a monorepo workspace is now primed from the
  repo root's manifests. The evidence rows moved into a function, `sr_repo_skills`, which
  `subagent-skills.sh` sources. They stay in `prime.sh` because `pc_prime_coverage` and
  `validate.sh`'s resolution loop read the `add <skill>` lines from this file by path.
  Output is byte-identical on the fixtures compared.
- **State lives at the project root, not the payload cwd.** `route.sh`, `route-prompt.sh`
  (flush), `summary.sh` and `compact-capsule.sh` resolve one root through the shared
  `cc_state_root` block (`templates/blocks/state-root.md`): the git toplevel, else
  `CLAUDE_PROJECT_DIR` when the cwd sits under it, else the cwd. The payload cwd follows the
  model's `cd`. One measured session moved through `app/Enums`, `app/Models` and the repo
  root, and each directory got its own `.claude/`. The 0.19.0 entry deferred this move
  because the state file's address is a three-hook contract. All three hooks now move
  together, and so does the capsule's ledger read. `summary.sh` derives the
  `surfaced.jsonl` slug from the root, so one project no longer splits into a slug per
  directory. `turn-cost.sh --skills` globs every slug, so existing rows still count.
  The `-d "$cwd"` guard is unchanged.
- **Rules match the root-relative path.** `**/dir/**` globs and `@path` markers see the
  path relative to the project root. A file written after `cd app/Enums` still matches
  `**/app/**`, and a checkout that merely lives under a directory named `tests/` or `app/`
  no longer draws those rows on every file. A file outside the root keeps the payload's
  spelling, as before.
- **Stack-marker manifests are read at the project root**, not the payload cwd. Trade,
  stated: a session started inside a monorepo workspace used to read that workspace's
  `package.json`, and now reads the repo root's. Walking up from the file to the nearest
  manifest was considered and rejected. A Laravel app's per-module `composer.json` would
  then suppress the Laravel row on the files it is for.

## 0.19.0 — 2026-09-22

### Added
- **`?` marker prefix: a routing row can require its manifest.** `?package.json~"next"`
  makes an absent or unreadable manifest a decisive **suppress** instead of merely
  indecisive, so the chain reads "fire only on a manifest that exists and says yes".
  Until now an absent manifest was skipped and the row fired anyway: a `.tsx` in a repo
  with **no** `package.json` drew shadcn, React Native and Next.js in one envelope, and a
  `.tsx`/`.vue` in a Nuxt- or Next-only repo drew shadcn, because `components.json` was
  absent and absent meant maybe. `?` is per-row and opt-in; an unprefixed alternative
  keeps the fire-if-uncertain default, which is still the right default for a stack the
  router cannot see. Probed: `src/Widget.tsx` with no `package.json` → `a11y-audit`
  alone; the same file in a Nuxt-only repo → no shadcn; with `components.json` present →
  shadcn fires; an Expo repo still nudges `react-native-best-practices` and a Next repo
  still nudges `nextjs-best-practices` on `app/api/checkout/route.ts`.
- `prime.sh` primes `devops-practices` from a `.github/workflows/` directory and
  `mariadb-best-practices` from a compose file whose `image:` names mariadb — two rows
  `coding-entry/references/skill-map.md` declares and this hook never had, both standing
  `map-unprimed` WARNs. Probed: a workflows-only repo now names `devops-practices`
  (it named nothing before); `image: mariadb:11.4` names the engine skill and
  `image: mysql:8.4` does not.

### Changed
- Rows carrying the `||!@base~.` **default-deny tail** added in 0.18.0
  (`**/components/**` and the three Next.js server rows) now carry `?` instead: same
  behaviour, one mechanism rather than two spellings of it. The shadcn rows and the
  `*.tsx` React Native / Next.js rows gained it.
- `route.sh` exits before touching state when the payload's `cwd` is **not a directory**.
  It validated `-n` only, and the next write is `mkdir -p "$cwd/.claude/skill-router"` —
  which RE-CREATED a project directory the session had just deleted, reproduced here
  three levels deep against the previous revision of the hook (2026-09-22 panel review,
  architecture #1; `plugins/overseer/hooks/track-read.sh:30` is the pattern). The state
  root is deliberately still the payload `cwd` and not the git toplevel: the state file's
  address is a three-hook contract (`route.sh` writes it, `route-prompt.sh` flushes it,
  `summary.sh` ledgers and removes it), and moving one side of it is a separate change.

## 0.18.0 — 2026-09-22

### Added
- Next.js SERVER files route: `**/app/**`, `middleware.*`, `proxy.*` → `nextjs-best-practices`,
  marked `package.json~"next"`. The `*.tsx` row covered components only, so a route handler,
  a server action or `middleware.ts` — the files the skill's own
  server-actions-are-public-endpoints rule is about — drew `low-cognitive-load` and
  `solid-principles` and nothing else, while `web-dev/lane.tsv` already declared "an edit
  under app/" as the trigger. Probed: `app/api/checkout/route.ts` in a Next fixture nudges
  `nextjs-best-practices`; the same path in a Go module and in a Vite/React repo nudges
  nothing from web-dev.
- Server-rendered markup routes to the WCAG checklist: `*.html`, `*.erb`, `*.twig` →
  `a11y-audit`. The six component extensions were the whole list, so a Rails, Django, Twig
  or static-HTML project got the checklist on no file it edits. Built output is excluded by
  a new `@path` marker; probed both (`app/views/show.html.erb` fires, `build/page.twig` does not).
- API ROUTE files reach `api-design`: `**/app/api/**`, `**/server/api/**`, `+server.ts`.
  `api.php` and `openapi*.y*ml` covered the Laravel and spec-first shapes and no 2026
  JS-side server route. (The finding named `**/+server.ts`; that form is basename-matched
  by `route.sh` and can never fire — `pc_rules_reachable` rejects it — so the row is
  `+server.ts`.)
- Stylesheet and token rows for four previously unrouted theming skills: `globals.css`,
  `app.css`, `*.scss` → `shadcn-theming`; `*.tokens.json` and a `design-system/`-scoped
  `tokens.json` → `design-tokens`. The router could see a project DECLARE a theme
  (`tailwind.config.*` had a row) and not see anyone edit one.
- One `content` row at `low` for `component-libraries`, the floor skill for every library
  without a sibling skill — Mantine, Chakra, Ant Design, PrimeVue, Vuetify, Base UI, Ark,
  Reka, Nuxt UI and the rest. Alternatives mirror the Signal column of
  `ui-ux/skills/component-libraries/references/library-map.md`; **standing: recorded**,
  nothing reads that file back.
- `prime.sh` primes `nextjs-best-practices` and `vite-best-practices` from
  `package.json` `"next"` / `"vite"` — two rows `coding-entry/references/skill-map.md`
  has declared since it was written. A Next + Vite + Tailwind fixture used to be told
  about package-hygiene, a11y-audit and tailwind only.
- `@path` marker form: matches the ERE against the edited file's PATH instead of a
  manifest's content, which is the only way a row can exclude a build DIRECTORY —
  `dist/index.html` and `src/index.html` share a basename. Unknown to an older
  `route.sh`, where the alternative is skipped and the row fires, the same safe
  fallback `@base` has.

### Changed
- **The tool-fit check no longer rebuilds the command catalog.** It emitted 61 truncated
  frontmatter lines — 5,122 of 6,892 characters, measured against this repository's plugin
  tree — restating a listing the host had already sent, and growing by a row with every
  command installed. The numbered protocol is unchanged and is the part the model does not
  otherwise have; the header line now points at the host's listing. Measured after: 1,770
  characters. What went with it, stated rather than hidden: the catalog was filtered by
  repo evidence, so a Laravel repo was never shown the Next.js review, and the host listing
  has no such filter — rule 1 ("most requests fit none of them") is now the only thing
  holding that down, and it is agent-graded.
- The `**/components/** → tailwind-best-practices` row, the only stack row shipping no
  marker at all, now carries `package.json~"tailwindcss"||!@base~.`. A Go module with a
  `components/` directory, and a Blade app with no Tailwind in it, both drew the Tailwind
  skill; `prime.sh:62-69` had already removed exactly this falsehood from the sibling hook.
  The `!@base~.` tail is a **default-deny** alternative — a basename is never empty, so it
  is always decisive-suppress — which is what makes "no package.json" mean no instead of
  maybe. It is per-row and opt-in; the general absent-manifest behaviour is unchanged.

## 0.17.4 — 2026-09-22

### Added
- Five `**/dir/**` rows for `design-kit` (`design-system/`, `.design-kit/decks|boards|artifacts/`,
  `__design-kit__/`), so the router ledger can count that plugin's offers — its README names
  `turn-cost.sh --skills` as its retirement queue, and with no row that queue read zero by
  construction. Rows fire only in directories the plugin itself creates.

## 0.17.3 — 2026-09-22

### Fixed
- `plugin.json` description still promised a Livewire route; the `livewire` skill and its <!-- removed-ok -->
  `rules.tsv` row were deleted on 2026-08-26 (`cfef9c1`), so the always-on bytes
  advertised a route nothing could fire. Word removed; catalog and marketplace copies
  regenerated.

## 0.17.2 — 2026-09-16

### Fixed
- `hooks/route.sh`'s header still listed a per-session dedup hole as an honest
  limitation that the context-key one-shot closed on 2026-08-16 (trend audit G13,
  `rationale/marketplace-trend-audit-2026-09-16.md`). The stale limitation is deleted;
  the lock-free read-modify-write one stays. Comment only — no behaviour changed.

## 0.17.1 — 2026-09-16

### Fixed
- README named 1836 as the committed dynamic-channel figure; the baseline it cites reads 1822. Corrected; the sentence still tells you to recount rather than quote it.

## 0.17.0 — 2026-09-15

### Fixed
- **`CC_REMIND=off` now silences the per-edit nudges.** `route.sh` — this plugin's
  headline advisory channel — read no off switch at all, while this plugin's README
  and eight sibling READMEs promised `CC_REMIND=off` silences "every advisory nudge
  in this marketplace". Muting the marketplace still produced a nudge on every Edit.
  `CC_ROUTE=off` keeps its documented narrow scope (the prompt-level tool-fit check
  only); there is deliberately no file-routing-only switch, and the README now says
  which switch covers which channel.
- **The ReUI content row could not match a ReUI import.** `\b(@reui/|…)` put a word
  boundary immediately before `@`, so it matched only where a word character preceded
  the `@` (`x@reui/bar`) — never in `from "@reui/core"`. A project installing ReUI by
  package name got no `reui-best-practices` nudge unless the file also mentioned
  `reui.io` or imported from the `@/components/ui/data-grid` alias. Now
  `(@reui/|\breui\.io|\bfrom …)`.
- **The concurrency row's `.lock(` alternative needed an argument.** The trailing `\b`
  sat after `(`, so `mu.Lock()` and `data.lock().unwrap()` — the Go and Rust spellings
  — never matched, only `lock(key)` did. The alternations now carry their own
  boundaries and `\.[lL]ock\(` covers Go's capitalised form, which is the real signal
  in a Go file (source says `go func()`, not the word `goroutine`).

### Added
- **`tailwind.config.*` routes to `tailwind-best-practices`.** `next.config.*` and
  `vite.config.*` had their own rows; tailwind did not, and the `@base` exclusion
  added in 0.16.0 correctly suppresses the design-principle rows on any `*.config.*`
  — so editing `tailwind.config.js` routed nothing, even though `prime.sh` already
  sniffs that file for the SessionStart index. Verified end to end: one nudge,
  `tailwind-best-practices` only. Tailwind v4 is CSS-first and may ship no config
  file; there `**/components/**` remains its only route, stated in `rules.tsv`.

### Changed
- README: the dynamic-channel cost reads **1836 tokens**, the committed figure in
  `scripts/context-budget-dynamic-baseline.json`, instead of the stale "~2.6k"; the
  prompt-route harness is described as asserting six discipline *phrases* rather than
  "all six rules" (rules 3 and 4 have no assertion of their own); and the
  machine-local `surfaced.jsonl` ledger plus its `CC_SURFACED_LOG=off` switch are
  documented for the first time.
- `rules.tsv`: the craft-layer comment claimed "only information-design is routed" one
  screen above a blessing that names the second routed craft-layer skill,
  `threejs-best-practices`. Both are now named, and the motion row's corpus co-fire
  count is re-measured (still zero).

## 0.16.1

### Removed
- **The `**/.design-studio/**` routing row.** Its target skill, `design-session`, was <!-- removed-ok -->
  retired with its plugin on 2026-09-14; the row would have routed an edit to a skill
  no install can resolve. <!-- removed-ok -->

## 0.16.0 — 2026-09-14

- **`@base` stack-marker alternative.** `@base~<ERE>` in the manifest position matches
  the edited file's basename instead of a manifest's content, so a bare-extension row
  can exclude a file shape. The four `*.js`/`*.ts` rows for `low-cognitive-load` and
  `solid-principles` now carry `!@base~(^[a-z0-9_.-]*\.(config|conf|setup)\.[cm]?[jt]s$|
  ^[a-z0-9_.-]*rc\.[cm]?js$|\.d\.ts$|\.min\.[cm]?js$|^\.)`: editing `tailwind.config.js`,
  `eslint.config.mjs`, `.eslintrc.js`, `vitest.setup.ts`, `global.d.ts` or `app.min.js`
  no longer tells the model to load two design-principle skills (~14.6 KB) and review a
  tool config against SOLID. `vite.config.*` / `next.config.*` keep their own stack
  rows. Measured on a scratch project: 17 file shapes, the 11 config/declaration/
  minified shapes went from two nudges to none, the 6 source shapes unchanged. Six
  cases in `scripts/smoke/route-marker-tests.sh`. Backward-compatible: an older
  `route.sh` reads `@base` as an absent manifest and fires.
- **`.claude/skill-router/` ignores itself.** The README said "(gitignored)" of the
  per-session state file for as long as it existed; nothing made it so, and the file
  showed up as untracked in every repo without a hand-written ignore line.
  `route.sh` and `compact-capsule.sh` now drop a `.gitignore` containing `*` when they
  create the directory. One harness assertion.
- Hook comments no longer cite `lean/hooks/budget.sh` as a pattern source (the plugin
  was removed 2026-09-14); the same idiom is cited from `code-review/hooks/conventions.sh`.

## 0.15.4 — 2026-09-14

- `rules.tsv`: a payment-webhook content signal (`Stripe-Signature`, `constructEvent`,
  `stripe.webhooks`, `paddle`, `braintree`) routes to `security:security-review`. The
  consolidation plan (§3.1) said the row of `payments` (removed 2026-09-14) would be rewritten to <!-- removed-ok -->
  security-review; wave 1 deleted it instead, so a webhook handler edit routed nothing.


## 0.15.3

### Changed
- `rules.tsv`: the `design-session` glob row is `**/.design-studio/**` owned by <!-- removed-ok -->
  `design-studio` — theme-design was renamed and merged into that plugin and its
  working directory moved with it (2026-09-14 consolidation plan).

## 0.15.2

### Removed
- `rules.tsv`: the `payments` and `llm-app` content rows and their eight <!-- removed-ok -->
  `co-fire-ok` blessings — both plugins were removed from the marketplace
  (2026-09-14 consolidation plan). Payment-provider and LLM-provider edits now
  route through the co-firing skills that remain: `security-review`,
  `concurrency-safety`, `error-handling-design`, `resilience-design`.

## 0.15.1

### Added
- `rules.tsv`: edits under `.theme-design/` route the `design-session` skill <!-- removed-ok -->
  (theme-design), so a session's token or page edits made from the terminal load
  the loop contract instead of only the slash command reaching it.

## 0.15.0

### Added
- `hooks/compact-capsule.sh` on `SessionStart` matcher `compact`: re-states the
  phase sentinel, registered task-runner run, scope lock and open taskmaster
  ledgers after a compaction, one line each with the file path, and appends a
  `compact-log.jsonl` line recording whether the sentinel's session_id survived
  (backlog #6, recorded not read). 26 harness cases under `scripts/__tests__/`.

## 0.14.13

### Added
- `rules.tsv` content row for `@astryxdesign/(core|cli|theme-*)` → ui-ux's
  `astryx-best-practices` (low confidence, digest channel), matching the existing
  `@mui/*` row. Verified against `scripts/smoke/router-corpus` for co-fires: none.

## 0.14.12

### Fixed
- `rules.tsv` row for `observability-design` named `observability` as its owning plugin — a
  directory that has not existed since the fold into `resilience`. `route.sh` skips any
  row whose col-4 plugin is not installed, so the row was suppressed wherever the
  installed-plugin filter resolved — and named a non-existent plugin in its nudge where
  it did not. Col 4 now reads `resilience` and the row routes.

## 0.14.11

### Added
- `*.vue` and `*.jsx` glob rows → `a11y-audit` (ui-ux). Vue single-file components and
  untyped React files routed nothing before; the a11y lane in ui-ux already named
  `.vue`, the router did not. Laravel + Inertia apps on the Vue or React adapter are the
  case this closes.

## 0.14.10

### Changed
- **The Three.js content row names `craft-layer` as owner** of `threejs-best-practices`
  (the threejs plugin merged into craft-layer on 2026-09-02). <!-- removed-ok -->

## 0.14.9

### Changed
- **The `*.tsx` accessibility row and the primer name `ui-ux` as owner** of
  `a11y-audit` (the a11y plugin merged into ui-ux on 2026-09-02). <!-- removed-ok -->

## 0.14.8

### Changed
- **The two manifest routing rows and the primer name `stack-scan` as owner** of
  `package-hygiene` (the packages plugin merged into stack-scan on 2026-09-02). <!-- removed-ok -->

## 0.14.7

### Changed
- **The three Docker routing rows and the primer name `devops` as owner** of
  `docker-best-practices` (dev-env merged into devops on 2026-09-02). <!-- removed-ok -->

## 0.14.6

### Changed
- **The four SQL routing rows and the primer name `database` as owner** of
  `sql-best-practices` and `mariadb-best-practices` (the sql and mariadb plugins <!-- removed-ok -->
  merged into database on 2026-09-02). Patterns, markers, confidence unchanged.

## 0.14.5

### Changed
- **The Inertia routing row and primer name `laravel` as owner** of <!-- removed-ok -->
  `inertia-best-practices` (the inertia plugin merged into laravel on 2026-09-02). <!-- removed-ok -->
  Pattern and confidence unchanged.

## 0.14.4

### Changed
- **Six routing rows and the SessionStart primer name `web-dev` as owner** of
  `nextjs-best-practices`, `react-native-best-practices` and `vite-best-practices`
  (the three plugins merged into web-dev on 2026-09-02). Patterns, confidence and
  stack markers are unchanged. The catalog relevance filter now drops
  `/web-dev:review` from a repo with none of the three stacks and keeps it when any
  one is present — asserted both ways in `prompt-route-tests.sh`.

## 0.14.3

### Fixed
- **The command catalog is no longer lost when `TMPDIR` is unwritable.** The
  once-per-session marker was written with `mkdir "$seen" || exit 0`, which answers
  two opposite situations the same way: the marker already exists (suppress — the
  point of the marker) and the marker *cannot* exist (suppress — wrong, and the
  catalog is then silently dropped on every prompt of every session). The failed
  `mkdir` now distinguishes them, matching this plugin's own doctrine at
  `hooks/route.sh:156`: an unwritable state dir must not swallow a payload the model
  should have seen. Both outcomes are asserted in `scripts/smoke/prompt-route-tests.sh`
  — the dedup case alone passes on the broken version, so only the pair pins it.
- **A plain file squatting the marker path no longer re-injects the catalog on
  every prompt.** The first version of the fix above tested for a directory, so
  an EEXIST-as-file fell through both branches — worse than the bug it fixed.
  Anything at the path now suppresses (one lost catalog beats ~9 KB per prompt);
  the fail-open branch fires only when the path is genuinely vacant. Third case
  asserted in the same harness.
- README: dropped the removed `everything` bundle from the install line. <!-- removed-ok -->
- `hooks/summary.sh`'s comments now name `scripts/turn-cost.sh --skills` as the
  ledger's reader — `scripts/retirement-queue.sh` was folded into it (the ledger
  format and surfaced/invoked semantics are unchanged).

## 0.14.2

### Changed
- **Every hook entry now declares a `timeout`.** `route.sh` 5s, `summary.sh` 5s, `prime.sh` 10s, `route-prompt.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.14.1

### Added
- **`*.tsx` routing for `nextjs-best-practices`** (marker
  `package.json~"next"`), with co-fire blessings against the a11y and
  react-native rows. When 0.14.0 removed react-server-state's `*.tsx` row, <!-- removed-ok -->
  Next.js app-code edits stopped firing anything from the router — coverage had
  regressed to `next.config.*` only. This row is new coverage, not a restore:
  nextjs-best-practices was never `*.tsx`-routed itself. <!-- removed-ok -->

### Fixed
- Engine-detection comments in `rules.tsv` no longer describe the removed
  mysql/postgresql skills as live routing targets; mariadb is named as the only
  dialect skill left.

## 0.14.0

### Removed
- All routing surface for the nine stack plugins removed from the marketplace
  in 0.93.0 (see the root CHANGELOG and
  `rationale/marketplace-necessity-review-2026-08-26.md`): 32 `rules.tsv` lines
  — glob/content rows and their co-fire blessings — for `php-best-practices`, <!-- removed-ok -->
  `vue3-best-practices`, `nuxt-best-practices`, `node-backend-best-practices`, <!-- removed-ok -->
  `livewire-best-practices`, `mysql-best-practices`, `postgresql-best-practices`, <!-- removed-ok -->
  `react-server-state`, `react-data-grid`, and `i18n`. <!-- removed-ok -->
- `hooks/prime.sh` no longer primes those skills: the plain-PHP branch, the
  Livewire branch, and the React server-state branch are gone; the Laravel and
  react-native exclusivity branches remain. `scripts/smoke/prime-map-tests.sh`
  now asserts the removed skills are OMITTED, so a stale priming line cannot
  return silently.

### Changed
- README example rows swapped to surviving skills (`mariadb-best-practices`,
  `laravel-best-practices`) so the documented `stack_marker` format no longer
  demonstrates rows that cannot resolve.

## 0.13.7

### Fixed
- The command catalog advertised commands that cannot be invoked. `pr_plugin_roots`
  walks every directory under the resolved plugins root; on a real install that
  root is the versioned CACHE, which keeps every plugin ever installed — including
  plugins later dropped from the marketplace and bundles the user switched off.
  Version dedup ran over that list and the stack filter ran over it, but
  enablement never did. Measured on a HEAD install: 82 plugins and 108 commands
  offered, of which 17 commands belonged to plugins that are not enabled, 16 of
  them owned by plugins absent from `marketplace.json` entirely. Those rows landed
  at the exact surface where the model picks a tool, so the cost was not only the
  ~400 tokens — it was pointing the model at `/estimation:size` and <!-- removed-ok -->
  `/design-patterns:suggest`, which resolve to nothing. Naming them here is the <!-- removed-ok -->
  point: both are exactly the removed artifacts the catalog was still offering. The same install now
  resolves 65 plugins and 91 commands.
- `pr_plugin_installed` had the same blind spot and is filtered on the same rule,
  so a rule can no longer nudge toward a plugin the user has turned off.

### Added
- `pr_load_enabled` / `pr_is_enabled` in `hooks/plugins-dir.sh`. The enabled set is
  the UNION of `enabledPlugins` across `<config>/settings.json`, the project's
  `.claude/settings.json` and `.claude/settings.local.json`, so a plugin enabled at
  any layer counts as enabled.
- `scripts/smoke/enablement-filter-tests.sh` (14 assertions), registered in
  `.github/workflows/validate.yml`. It asserts BOTH directions — suppression and
  fail-open — under both install layouts. Asserting only one direction proves
  nothing: a filter that always suppresses passes the suppression cases, and the
  previous behaviour passes the fail-open ones.

### Notes on scope, stated rather than implied
- Fail open is preserved everywhere it already existed. No jq, no settings file, no
  `enabledPlugins` key, or unparseable JSON all yield an empty set, and an empty
  set filters nothing — byte-for-byte the previous behaviour.
- A SCOPE GUARD limits the enabled set to trees under the config dir. `enabledPlugins`
  describes the user's own install; a smoke fixture, a vendored checkout or a second
  marketplace is not governed by it. This was found the hard way — the first version
  shipped without the guard and turned `versioned-layout-tests.sh` and
  `route-marker-tests.sh` red, because both build scratch roots under `$TMPDIR` while
  the ambient `~/.claude/settings.json` named entirely different plugins. A
  name-overlap heuristic was tried first and rejected: a scratch tree containing one
  real plugin name would activate the filter and suppress every fixture-only sibling.
- Managed-policy settings are not read. On a fleet that enables plugins ONLY through
  managed policy, those plugins would be filtered out whenever another layer lists
  anything at all. That is the one case where this can suppress a live plugin.

## 0.13.6

### Fixed
- The low-confidence signal channel was dead. `route.sh` writes its state file as
  `fired-<cksum(transcript_path // session_id)>.json`, but `summary.sh` and
  `route-prompt.sh` both read `fired-<raw session_id>.json` — spellings that can
  never agree, because the cksum is applied to the fallback branch too. Since
  2026-08-16 that meant: the 11 low-confidence content rules accumulated signals
  no model turn ever saw, the `surfaced.jsonl` ledger got no rows from a HEAD
  install (freezing the denominator `scripts/retirement-queue.sh` ranks by), and
  the state files were never cleaned up. Both readers now derive the same key.
  `session_id` stays the raw value where it is a recorded ledger FIELD rather
  than an address.
- `summary.sh`'s comment claimed `/hindsight:harvest` reads `surfaced.jsonl`.
  It never has; the only reader is `scripts/retirement-queue.sh:63`.

### Added
- A cross-hook round-trip case in `scripts/smoke/route-marker-tests.sh`: it runs
  `route.sh` → `route-prompt.sh` → `summary.sh` on one host-shaped payload and
  asserts the digest and the ledger row. Every prior assertion drove one hook
  alone, and the existing state-file check was name-agnostic (`find -name
  'fired-*.json'`), which is why the suite stayed green through the break.
  Verified against the old code: the new case fails on it.

## 0.13.5

### Changed
- Catalog text follows two merges: `opinion-round` is now <!-- removed-ok -->
  approach-deliberation's blind-panel mechanism and `task-orchestration` is <!-- removed-ok -->
  plan-before-code's "Split into tasks". No routing rows changed — neither skill
  had one.

## 0.13.4

### Changed
- `**/migrations/**` now routes to `sql-best-practices` alone. The <!-- removed-ok -->
  `database-design` row and its three co-fire blessings are gone with the skill: <!-- removed-ok -->
  a migration file in a MySQL project used to load `sql` + `database-design` + <!-- removed-ok -->
  `mysql` at once, 4,333 tokens of bodies, with "index every foreign key" stated <!-- removed-ok -->
  in six places across the family.

## 0.13.3

### Fixed
- **Directory globs matched case-sensitively, which silently disabled a whole
  plugin.** `match_glob` tested `**/dir/**` with a case-SENSITIVE substring
  comparison, and `**/resources/js/Pages/**` is inertia's ONLY routing row. On a
  project scaffolded by Laravel's current starter kits — which generate
  `resources/js/pages/` — the router matched nothing, the 2,134-token skill never
  loaded, and `/inertia:review` had to be typed by hand. <!-- removed-ok --> `**/Livewire/**` had the
  same exposure, masked only by livewire's second row. Directory segments now
  match case-insensitively; the `nocasematch` shell option is saved and restored
  rather than left on. Residual, stated in the code: case is checkable, a wrong
  directory NAME is not.
- **The surfaced ledger could not tell "shown to the model" from "accumulated".**
  `summary.sh` wrote `pending_low` after dropping the `flushed` flag that
  `route-prompt.sh` sets when it actually prints the digest, so
  `scripts/retirement-queue.sh` counted both states as surfacing — for exactly
  the skills a retirement queue ranks first. The ledger line now carries
  `pending_low_flushed` and `pending_low_unflushed`; `pending_low` stays as the
  union so an older reader keeps working.

## 0.13.2

### Fixed
- **The `fired` ledger never persisted, so every edit re-injected directives the model
  already had.** 0.13.1 keyed the marker on `transcript_path` falling back to
  `session_id`, then interpolated the value raw into `fired-$session_id.json`. An
  absolute transcript path makes that a nested filename whose parents are never created,
  so the write failed on every call and `fired` was empty every time — the property that
  the same skill is not re-nudged on a later edit did not hold. Cost was paid in the
  dynamic context channel, repeatedly, per edit. The key is now hashed with `cksum`, the
  idiom `code-review/hooks/conventions.sh` and `lean/hooks/budget.sh` already used.
- **`route-marker-tests.sh` could not have caught it**: its helper used a fresh session
  id per call and wiped `.claude` between calls, so the dedup ledger was never exercised
  at all. It now has a case that holds one context across two edits, sends a path-shaped
  `transcript_path`, and asserts both the suppression and that the ledger file lands.

## 0.13.1

### Fixed
- **One-shot markers now key on `transcript_path`, falling back to `session_id`.**
  PostToolUse is the only hook channel that reaches subagents at all, and a subagent
  shares its parent's `session_id` while getting its own transcript — so a
  session-keyed marker the parent already claimed deduped the worker's nudge away.
  The advisory was structurally silent in the one context where most fan-out code is
  written. `scripts/lib/plugin-checks.sh`'s new `pc_context_key` gates it.

## 0.13.0

### Added

- **`lane.tsv`** — declares `route-prompt` as the owner of `tool-fit-catalog` at
  phase `any`, yielding to `taskmaster:remind`. The yield is not a new decision:
  the charter this hook injects already tells the model "clarification outranks
  tool-fit", so the row records a deference the plugin was shipping in prose and
  nothing could check. `prime.sh` (SessionStart), `route.sh` (PostToolUse) and
  `summary.sh` (SessionEnd) are outside the gated channel and carry no row.

### Changed

- **The work-shaped gate now reaches symptom phrasing.** `hooks/route-prompt.sh`
  asked "is there a making verb here?", so `fix the checkout crash` was work and
  `why is the checkout page broken` was not. Nine realistic incident prompts were
  run against it: seven were dropped — `production is down`, `users are seeing
  500s on login`, `this query got really slow after the last release`, `something
  regressed in the cart total`, `investigate the memory leak`, `the payment
  webhook keeps failing intermittently`, and the one above. An incident is
  normally reported by its effect, not by a verb, so the one moment where picking
  the right tool matters most was the moment the catalog never reached.

  The symptom alternation is appended to the existing verb alternation inside the
  **same** grep, not given a line of its own: `scripts/validate.sh` allows this
  hook four prompt-matching greps and calls a fifth a routing table regrowing in
  shell. That budget is unchanged.

  **The symptom tier is split in two, and the weak half is bound.** Written flat,
  it made `scroll down and tell me what you see` and `the meeting ran slow today`
  work-shaped, because `down` and `slow` are ordinary English long before they are
  incident vocabulary. So: `error`, `crash`, `500s`, `regress(ed|ion)`, `why is`,
  `investigate` and `not working` match bare — a prompt carrying one is about a
  defect whatever the grammar around it. `down`, `slow`, `broken`, `failing`,
  `fails`, `leak` and `stuck` match only after a state verb (`is`, `are`, `went`,
  `keeps`, `got`, `am`, …) with at most one word between. A system in a bad state
  says so with a state verb; a sentence that merely contains the word does not.
  Same shape as `taskmaster/hooks/preview-guard.sh`'s bounded weak `.html` tier.

  *Limitation:* the bound is grammatical, not semantic. `payment failures spiking`
  is missed, and `the build is slow to watch` still fires. Recall on the weak tier
  is traded for the silence of the plain-prompt path; the strong tier is unbounded
  and is what carries recall.

  **Cost, stated plainly:** the catalog is ~2.6k tokens and it now fires in
  symptom-phrased sessions that previously paid nothing. It is still bounded by
  the existing once-per-session `mkdir`, so the increase is one injection per
  session, not per prompt. `scripts/context-budget.sh` cannot see this — it
  measures one fixed making-verb prompt in an empty sandbox, and that prompt
  already fired before this change. Every false positive is therefore a real,
  structurally unmeasurable cost, which is the whole reason the weak tier is
  bound rather than shipped flat.

## 0.12.1

### Fixed

- `README.md` § Adding a file route told you to put prompt routes in
  `prompt-rules.tsv`. **That file has never existed in this plugin.**
  Prompt-shaped routing was removed deliberately —
  `hooks/route-prompt.sh`'s header records the reason ("a table only ever routes
  the phrasings its author thought of, and every new plugin needed a new row")
  and the command catalog plus model judgment replaced it. The section now says
  so explicitly, including that adding such a table is a decided-against design,
  so the next person to look does not go build the file the docs promised.

## 0.12.0

### Added

- **Engine-specific database routing.** `mysql-best-practices`, <!-- removed-ok -->
  `mariadb-best-practices` and `postgresql-best-practices` shipped with no <!-- removed-ok -->
  file-routing channel at all — they were named in this file's own limitation
  block as unrouted. Six rows now route them on `*.sql` and `**/migrations/**`,
  discriminated by a compose-image-first marker chain (compose → `.env.example`
  `DB_CONNECTION` → composer.json → package.json).

  The last two links are deliberate and invert the router's usual
  fire-if-uncertain bias, for these rows only: the three engine skills are
  mutually exclusive and their advice conflicts, so a repo with a composer.json
  and no database hint gets none of them rather than all three. A bare directory
  of `.sql` files with no manifests still fires all three — no signal, fail-open,
  and the one place the conflicting-advice cost is accepted. Three known misses
  are listed in `rules.tsv` rather than left to be discovered.

- **Plain-source rows for Go, Ruby and Rust** — `*.go`, `*.rb`, `*.rs` route to
  `low-cognitive-load` + `solid-principles`, matching what `*.ts` / `*.js` /
  `*.py` already did. The limitation block recorded this gap; it is now closed
  and the text says so.

- Twelve `# co-fire-ok:` declarations for the new pairs. Generic + engine on one
  file is intended (portable SQL vs what only that engine does); the engine rows
  discriminate against each other by distinct markers and need no blessing.

### Notes

- Correction to 0.11.0's note: `*.php` was NOT missing. Lines 78-79 have carried
  Laravel and plain-PHP rows behind `composer.json` markers all along.
- Still unrouted, deliberately: `code-smells`, `reuse-hygiene`, `yagni-check`,
  `plan-before-code`. `comment-discipline` stays absent by design — its own
  PreToolUse/PostToolUse hook is its delivery channel.
- No context-budget change: the dynamic channel measures a synthetic edit to
  `src/example.ts`, which no new row matches.

## 0.11.0

### Fixed

- **The router was inert on every real install.** `prime.sh`, `route.sh` and
  `route-prompt.sh` each resolved the installed-plugins root as
  `dirname "$CLAUDE_PLUGIN_ROOT"`. That is correct only under a flat
  `<plugins>/<plugin>` layout; a real install is versioned
  (`<marketplace>/<plugin>/<version>`), so the result was
  `<marketplace>/<plugin>` — a directory whose only children are version
  numbers. Consequences, all silent:
  - every `owning_plugin` was reported not-installed, so **every glob rule was
    suppressed** and no edit ever produced a nudge;
  - `route-prompt.sh`'s catalog glob (`<root>/*/commands/*.md`) was one path
    segment short, matched nothing, and the hook exited before printing —
    **no command catalog was ever injected**;
  - `prime.sh`'s session index was filtered down to nothing.

  Resolution now lives in one place, `hooks/plugins-dir.sh`, and handles both
  layouts. Skill and command paths resolve through the version segment, and a
  cache holding several releases of one plugin contributes exactly one catalog
  entry (the highest version it can order).

### Added

- `hooks/plugins-dir.sh` — layout detection plus `pr_plugin_installed`,
  `pr_plugin_root` and `pr_plugin_roots`, sourced by all three hooks. Absent or
  unsourceable, every caller falls back to fire-if-uncertain; the router's
  declared bias is toward surfacing, never toward silence.
- `scripts/smoke/versioned-layout-tests.sh`, wired as its own CI step. It runs
  the firing, suppression, catalog-uniqueness and skill-path assertions against
  **both** layouts. This is the gate that was missing: the three existing router
  harnesses build a flat scratch layout by construction, so 73 green assertions
  could not see a bug that only exists under the layout users actually have.

### Notes

- The `~2.6k` dynamic-token figure in the README and in
  `context-budget-dynamic-baseline.json` is measured against a flat checkout. It
  is the cost a *working* router pays; before 0.11.0 a real install paid nothing,
  because nothing was emitted.
- Not addressed here: `rules.tsv` coverage. There is still no plain `*.php` row
  (only `*.blade.php`), and 44 glob + 11 content rows cover 127 shipped skills.
  A working router with sparse rules is a different problem from a dead one.
