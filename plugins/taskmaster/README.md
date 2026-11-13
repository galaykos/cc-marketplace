# taskmaster

Task clarification that starts by asking you questions. It asks them in batches,
working through a list of what is still unclear (the ambiguity ledger). Visual
decisions get theme-aware shell mockups on a single always-live preview URL. They
render in the project's own colors when it can detect them, with compare modes and
tradeoff callouts. You choose once per session: full mockups, ASCII only, or none.
Then it writes a spec and task cards, each one runnable as a single prompt.

**Not sure where to start? Start with `/work <what you want done>`** (or `/code-architecture:work`): it sends work that needs a spec here and does small changes inline.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install taskmaster@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/taskmaster:task <description>` | Run the full pipeline: interrogate → spec → task cards |
| `/taskmaster <description>` | Shorthand alias for the same pipeline |
| `/taskmaster:brainstorm <idea>` | Upstream of the pipeline: shape a fuzzy idea into an approved design doc (one question at a time, 2–3 explored approaches, sectional approval), then hand off to `/taskmaster:task` |

Run it with a one-paragraph task description:

```bash
/taskmaster Add CSV export to the orders page with date-range filtering
```

Without arguments it asks for a description first. The pipeline then:

1. Runs the stack-scan inventory first when that plugin is installed, so
   constraints come from lockfiles instead of guesses
2. Dispatches the context-scout agent to scan the codebase before asking you anything
3. Asks batched clarifying questions until every item in the ambiguity ledger is
   resolved. Round 1 always asks the detail level (Guided: the worker picks the
   implementation; Exact: cards prescribe the edits) and lists the known bugs of what
   the task builds (a form's double submit, a list's empty state) as rows with
   recommended defaults, so each becomes a success criterion. Choices between options that look or flow differently are decided via
   shell-based mockups on a live preview URL — built from a shipped template with
   a sticky decision header, side-by-side/stacked/flip compare modes, and numbered
   callouts pairing tradeoff bullets to mockup regions, rendered in the project's
   own theme tokens when context-scout detects them (toggleable against a neutral
   baseline). Context-scout's visual-surface report decides what counts as visual,
   and a one-time fidelity question (full mockups / ASCII only / none) runs before
   any mockup is built; whole-experience tasks get sliced into screens/flows first
   and grilled slice by slice
4. For multi-screen work, assembles the accepted picks into an **interactive
   clickable walkthrough demo** on the same preview URL — every screen, state
   variant, and failure exit navigable — and walks you through it with a task
   script; gaps found by clicking become ledger rows before the spec freezes
5. Writes a spec to `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md` (including the walkthrough
   path and cross-screen contracts when one was built)
6. When code-architecture is installed, runs a plan check on the spec before
   card-splitting
7. Emits single-prompt task cards to `taskmaster-docs/tasks/YYYY-MM-DD-<slug>/` with a
   `00-INDEX.md` — each card stamped with the stack skills it needs as `plugin:skill`
   (from the stack-scan inventory; `skills-stamp-lint.sh` warns when a same-named
   project skill, such as Laravel Boost's, shadows a bare stamp), sized S/M/L/XL against task-cards' anchor rule, and
   grouped into independently shippable milestones on big runs. On UI work the
   first UI card builds how an agent signs in and the seeded states the grill
   settled, and each UI card names the screen, widths and state the browser walk
   at group close must see
8. When task-runner is installed, asks "Start execution now?" — in the same batch of
   questions as the coverage check's recommended fixes when it found gaps — one approval and
   it invokes `/task-runner:run` on the index itself, so the run registers for the
   completion gate, no manual command needed (still printed as the fallback if you decline)

A priority directive fires on work-shaped prompts
(build/add/implement/fix/update/change/write…) — not when every verb is create or add
governing a PR or commit ("create the PR"), or a branch, push, merge, tag or release once
the prompt also names a PR, a commit or `git`, or a joined name sits beside the noun ("add
fix-login branch"); nor on verbs inside a `<pasted_content>` paste or on a subagent
hand-back. "fix the failing PR", "add tags to the blog" and "add PRs to the dashboard" (a
ship noun before to, into, onto or with is a feature object) still fire. Before the first code edit,
run one batched clarifying round to zero ambiguity or state in one line why
the task is trivial. It holds `arcRank` 25 in the shared reminder-rank election
(bounded at one line per eligible hook, never a guarantee of one per prompt) — no plugin is privileged there, so it earns its place by arc position:
clarification is `shape`, ahead of build-vs-buy (`decide`, 30) and the API docs
check (`build`, 40), behind only the two `any`-phase guards, a stuck-loop nudge
(10) and an irreversible-command warning (20). Between 2026-08-16 and 2026-09-14
it carried rank 90 — last — while this paragraph claimed an exemption that had
been retired, so on a prompt like "build auth" the build-vs-buy nudge spoke and
this directive did not. Silenced by `CC_REMIND=off`.
Opt-in stricter contract: `CC_CLARIFY_GATE=block` arms a PreToolUse gate that
denies the FIRST code write of such a session once, forcing one
clarify-or-declare-trivial turn before code exists. Off by default.

## Invocation cheat sheet — boost, and the two knobs Claude Code owns

Three separate knobs, easy to confuse because they all start with `ultra`:

| Token | What it moves | Owned by |
|---|---|---|
| `ultra-task` / `ultra-goal`, or a bare `ultra` (boost) / `goal` (boost + hands-off) as a command's first argument | subagent tier floor, mandatory red-team + coverage, bounded fan-out ceilings, goal ledger | this plugin |
| `ultracode`, or the Ultracode toggle in `/effort` | permission and bias to actually call the `Workflow` tool — real parallel fan-out instead of the inline fallback. Since CLI 2.1.284 a switch of its own: it no longer raises effort | Claude Code |
| `ultrathink` | main-thread reasoning depth: the clarifying rounds, spec judgment, synthesis | Claude Code |

They compose; none substitutes for another. The boost never changes your session
model. Its `effort=xhigh` reaches the reasoning subagents on either dispatch path from
CLI 2.1.292, when the Agent tool took an `effort` parameter (passed only when the tool lists it); below that it binds only on
the `Workflow` path, so an unpaired boost escalates the model alone. Two forms work:

```bash
# All three knobs. Keywords must precede everything, so no slash command.
ultracode ultrathink ultra-task run the taskmaster pipeline: <one-paragraph task>

# Deterministic command dispatch. Boost only — no ultracode/ultrathink here.
/taskmaster:task ultra <one-paragraph task>
```

Three rules that catch people out:

- **A slash command must be the first character of the message.** `ultracode /taskmaster:task …`
  is plain text — the command never dispatches (the boost hook still fires, which is
  what makes the failure look like it worked).
- **Never put `ultracode` / `ultrathink` inside a slash command's arguments.** They are
  harness keywords, not taskmaster flags; there they become part of your task description.
  To pair a slash command with a fan-out, toggle Ultracode on in `/effort` first.
- **One deliverable per run.** Two unrelated goals share one ambiguity ledger and the
  clarifying rounds interleave. Run them separately, or state the dependency explicitly
  so the split produces ordered milestones.

With no dispatch mechanism at all (no `Workflow` tool and no Agent tool) every fan-out
phase degrades to a single inline agent,
reported as `inline heuristic pass — single model, uncorroborated` — never as a panel.
Full rules, including the workflow-size ceiling and why interactive phases never fan
out: the `task-runner` plugin's `verification-panels` skill,
`references/dispatch-tier.md` § Native harness interop.

## Ultra-goal — hands-off mode

Put a bare `goal` first in any taskmaster command's arguments to run the pipeline
**hands-off** with the full `ultra-task` boost. An `ultra-goal`/`ultragoal` token does
the same anywhere in a taskmaster command's arguments, or within the first 200
characters of a free-text prompt. The tier is fixed at auto/xhigh (the session model
or opus, whichever is higher — there is no per-token tier suffix). For hands-off
without the boost, use `goal-lean` (below). The `ultra` skill (Goal mode) owns the
full contract.
Not the host's built-in `/goal`: that is a session-scoped prompt-based Stop hook
("keep going until X"), while this `goal` token is a taskmaster argument that
auto-takes the pipeline's recommendations — the two share a word, not a mechanism.

Under goal the pipeline **auto-takes every recommendation** instead of asking:
AskUserQuestion gates resolve to the "(Recommended)" option, unmarked forks (variant
picks, erd/hole resolutions) resolve by deriving a recommendation first, binding
contracts self-approve, visual decisions auto-answer "Full mockups" and keep the
gallery as evidence, and the "Start execution now?" handoff auto-selects "Run now" —
running through to a green full suite.

Every auto-take is auditable through three sinks:

- **Goal ledger** — `.claude/taskmaster/goal-ledger-<slug>.md`, appended live per
  decision (options, pick, rationale, source)
- **Spec appendix** — a `## Auto-decisions` summary inside the frozen spec
- **Index marker** — `Goal: true (model=…, effort=…)` in `00-INDEX.md`, carrying
  hands-off into execution

**`goal-lean`** — the same hands-off mode without the boost: a bare `goal-lean` as a
command's first argument (no free-text token). Every auto-take rule and the ledger apply;
the tier stays the session's, spec-redteam and coverage run by their own gates, and no
code red-team runs at execution. The index marker is `Goal: true (boost=off)`, read by
task-runner ≥ 0.32.0 (older runners treat any `Goal:` as boosted). The overseer plugin
picks between `goal` and `goal-lean` per milestone from its rigour profile.

Safety floor: goal mode **never** runs a branch merge/PR (the git surface stays
manual), never suppresses the never-suppress set defined in the `ultra` skill's Goal
contract, and never auto-accepts as known risk a security red-team hole, any hole touching
auth or stored data (loss, corruption, schema or migration, personal data) whatever its
lens, or a statement-fidelity hole (it amends the spec or halts). Hands-off execution requires task-runner ≥ 0.11.0; older
runners fall back to interactive.

## Conversation example

A good starting prompt is one paragraph: the goal, hard constraints, and pointers
to existing code if you know them. Don't pre-answer design questions — the
interrogation surfaces those. Here's how a session flows:

```text
You:     /taskmaster Add CSV export to the orders page. Users should be able
         to export the current filtered view with a date range. Needs to handle
         large order sets. Follow existing export patterns if any exist.

Claude:  Scanned the codebase first (context-scout): orders page at
         resources/js/Pages/Orders/Index.vue, an existing queued + chunked XLSX
         export in app/Exports/InvoiceExport.php, Laravel 13.20 and
         maatwebsite/excel 3.1 installed (composer.lock).

         Round 1 — 4 questions:
         1. Columns: all 14 order fields, or the 6 visible in the table?
         2. Large sets: stream the download, or queue + email a link like
            InvoiceExport does?
         3. Date range filters on created_at or updated_at?
         4. Who can export — every role that sees the page, or admin only?

You:     1: the visible 6. 2: queue + email, same as invoices.
         3: created_at. 4: admin and manager.

Claude:  Round 2 — 1 question, 1 assumption:
         1. Filename: orders-2026-07-05.csv okay?
         A1. Assuming UTF-8 with BOM for Excel compatibility (matches
             InvoiceExport) — accept as ASSUMED?

You:     Both fine.

Claude:  Ledger: 5 CLEAR, 1 ASSUMED.
         Spec: taskmaster-docs/specs/2026-07-05-orders-csv-export.md
         Cards: taskmaster-docs/tasks/2026-07-05-orders-csv-export/
           01 export class · 02 controller + route + policy · 03 UI button ·
           04 feature tests (02 and 03 run in parallel after 01)
         Start: /task-runner:run taskmaster-docs/tasks/2026-07-05-orders-csv-export/00-INDEX.md
```

Notice what the starting prompt does and doesn't do: it states the goal, one
performance constraint, and a pointer ("follow existing export patterns") — but
leaves column choice, delivery mechanism, and permissions open. Those come out
grounded in what context-scout actually found, so the answers become decisions
in the spec instead of assumptions buried in code.

## Companion plugins

taskmaster works standalone but reaches full potential alongside
[stack-scan](../stack-scan/), [task-runner](../task-runner/), and
code-architecture — install each by name (nothing pulls them in; the suite that did was
retired 2026-09-26), or see the [marketplace README](../../README.md#choosing-in-one-page)
for the whole-pipeline set.

A spec whose surface is a landing page or marketing site is craft-layer's input:
`/craft-layer:craft` consumes the spec and its section-decisions never re-interrogates
it (recorded; the router is the only nudge).

Credit: grill's frontier rule adapts one from an earlier (2026-09-02) read of [mattpocock/skills](https://github.com/mattpocock/skills). grill's contradicted-statement row, mid-round background lookup and third-party questionnaire (`references/questionnaire.md`), and task-cards' expand–migrate–contract sequencing and prefactor cards, adapt rules from mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock), rewritten here rather than copied.

## Contents

- **Skills**: grill (interrogation + ambiguity ledger + big-task slicing),
  visual-decisions (theme-aware shell mockups — `assets/shell.html` — with
  compare modes, callouts, and motion passes on a live preview URL; variety across
  theme/density/type axes and dark/viewport/RTL/print modes, a
  chart/media/type/prose/marketing/code/stepper/icon primitive library, 8 starter
  layouts, and dedicated preview pages), experience-walkthrough
  (interactive clickable demo of the whole assembled flow), task-cards
  (spec → milestone-grouped single-prompt cards), coverage-check (every success
  criterion has a card, no card proves what the spec never asked), verify-teeth
  (a card's Verify line names an assertion that would fail were the feature absent),
  erd (a mermaid diagram approved before any migration exists), spec-redteam (blind
  adversaries attack the frozen spec), ultra (the boost protocol)
- **Agents**: context-scout — read-only codebase reconnaissance before questioning;
  spec-adversary — the blind attacker spec-redteam fans out
- **Commands**: `/taskmaster:task` (and its `/taskmaster:taskmaster` alias),
  `:brainstorm` (fuzzy idea → approved design doc, upstream of everything),
  `:coverage`, `:redteam`
- **Hooks**, five: the clarify-first directive and the boost detector on
  UserPromptSubmit; the artifact preview guard (ask) and the opt-in clarify gate
  (`CC_CLARIFY_GATE=block`, deny once) on PreToolUse; the card-shape observer
  (warn) on PostToolUse
- **Scripts**: `verify-teeth-lint.sh`, `spec-ledger-lint.sh`, `goal-ledger-check.sh`,
  `skills-stamp-lint.sh`, `card-lint-record.sh`, `preview-cleanup.sh`, `preview.sh`,
  `preview-feedback.sh`, `preview-check.sh`, `theme-axis-check.py` — each with a harness under `scripts/__tests__/`
  (`card-lint-record.sh` is covered by `card-lint-observability.test.sh`, which
  drives both its writers and its reader; `serve.test.sh` drives the preview server itself;
  `find-browser.sh` is the browser lookup both preview scripts source)
- **Vendored**: `vendor/axe-core/` — axe-core 4.14.0, which the render checks run (see below)

Every hook fails open and every one has an off switch. `CC_REMIND=off` silences the
clarify directive, the clarify gate and the card observer; `CC_CARDLINT=off` just the
observer; `CC_PREVIEW_GUARD=off` the artifact guard; `CC_BOOST=off` (or
`TASKMASTER_BOOST=off`) the boost detector.
The clarify gate is additionally off
unless `CC_CLARIFY_GATE=block`. `PREVIEW_PORT` moves the preview server off 8123.

### The preview server

`skills/visual-decisions/assets/serve.py`, started through `scripts/preview.sh`. Each rule below
names its standing; "gate" means a harness under `scripts/__tests__/` that CI runs.

- **Private paths.** A dot-prefixed file or folder, the server's own `.preview.*` state files and
  directory listings answer 404; dot files never appear on the session map, in the version list or in
  a reload event. Gate: `serve.test.sh`. Misses: a symlink in the docroot is followed out of it.
- **Launcher.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh" [--docroot DIR] [--port N] [--lan]`
  starts the server only when this docroot's server is not running and prints its URL either way;
  `--stop` ends it after checking the recorded pid really is serve.py on that docroot (by `ps`, else
  `/proc`; a live pid neither can name is exit 6 and left alone). Two starts at once take turns on
  `.preview.lock`, so they leave one server and print one URL. Exit codes are in its header. Gate:
  `preview.test.sh`. That the skills call it instead of starting serve.py by
  hand is recorded only.
- **LAN key.** With `--lan`, a device on the network needs the key carried in the printed URL (then a
  cookie); without it, 403. Restore works from this machine only, and only from a page opened on the
  loopback URL the launcher prints as `On this machine:`; at your desk, open that one, not the network
  URL. The key lives in `.preview.key` and survives restarts; delete it to rotate. A symlink or a file
  that is not a key there is replaced, never followed. Gate: `serve.test.sh`, where the remote
  peer is the machine's own network address (skipped on a machine with none) plus a unit test of the
  peer rule. Misses: plain HTTP, so the key is readable on the network; the cookie is per host, not
  per port.
- **Time limits.** A LAN server exits after `PREVIEW_LAN_MINUTES` (default 60), and every server
  after `PREVIEW_IDLE_MINUTES` (default 240) with no request and no open event stream; a request
  refused for want of the key does not count; 0 turns either off. An open tab holds a stream, so it keeps the server up. Gate: `serve.test.sh`, with limits of
  seconds.
- **Reconnect.** A page built from the shell shows a "Preview server stopped" bar when serve.py's
  event stream drops, and reloads once the server answers again; on the lower rungs it polls as
  before. Recorded: driven once in Chromium on 2026-11-12, and no harness runs a browser. Pages not
  built from the shell (`diagram.html`, `walkthrough.html` and the like) carry no reload client.
- **Feedback: picks and notes from the page.** `POST /_feedback` appends one row to the docroot's
  `.feedback.jsonl` (a dot file, so never served): a pick of variant A–C, or a note with its text, the
  variant, the element it points at (CSS selector, tag, text, bounding box), the viewport, theme, width and
  state toggles in effect and the last five console errors. Every field is clamped (numbers to ±10,000,000)
  and unknown keys are dropped; a pick keeps no text and no element; a lone surrogate is stored as `?`. The
  route takes the same guards as Restore: a loopback peer (a LAN key does not help), a local Host and Origin,
  the `X-Preview-Feedback` header, 1 to 8192 bytes of a JSON object; else 403, 413 or 400. Once
  `.feedback.jsonl` would pass 2 MiB a post gets 507 until the file is moved aside. `GET /_feedback?page=`
  returns that page's rows, loopback only. Gate: `serve.test.sh`.
- **Feedback: the page's controls.** When that GET answers with JSON, a page built from the shell shows
  Pick and Note on each variant, a "Point & note" toggle (Alt+Shift+P) that outlines the element under the
  pointer or the arrow keys, and a Notes list with each note's status and reply. On a lower rung, over
  `file://` and with `?static=1` none of it appears, and `?static=1` also turns the reload client off.
  Recorded: driven in Playwright Chromium on 2026-11-13, and again after the review fixes (a data attribute
  holding a newline, a console object with no `toString`, cuts by code point); no harness runs a browser.
- **Feedback: the reader.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview-feedback.sh"` with `list [--all]`
  (unread open rows), `wait [--timeout S]` (blocks until one exists, prints it, then marks it handed out
  with the time; exit 3 after 600 s), `reply --id ID --status addressed|dismissed [--text LINE]`, and
  `shot --id ID` (a PNG of the noted element outlined, from a local Chromium-family browser; exit 4 without
  one). A row handed out more than 15 minutes ago and still open is unread again, so a waiter that died or
  was never read loses nothing. `shot` loads the page from `http://127.0.0.1:<port>/` when `preview.sh`'s
  server answers, else from disk; it runs Chrome with its sandbox on (off only as root or with
  `PREVIEW_BROWSER_NO_SANDBOX=1`) in a throwaway profile for at most 30 s, and reports a browser that fails
  (exit 1). Rows print as JSON lines with control, invisible and blank-rendering characters escaped.
  Rewrites go through a temp file and a rename under the server's lock, so a note posted meanwhile is kept. Gate: `preview-feedback.test.sh`; that the model
  starts `wait` and acts on what it reads is agent-graded.
  Misses: any script on a served page, third-party script included, can post a pick or note; note text is
  whatever was typed and nothing verifies it; the screenshot uses the default theme and states, not the
  row's; console errors thrown before the shell's own script runs are not captured; a lower rung serves
  `.feedback.jsonl` (`python3 -m http.server` serves dot files).

### Render checks

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview-check.sh" [--docroot DIR] [--page PATH] [--widths 375,768,1280]`
loads one page (default `current.html`) from this docroot's serve.py, starting it through `preview.sh` when
none answers, in a headless Chromium-family browser at each width. Every line it prints is one escaped JSON
object: a finding, an E6 advisory, a `{"not_reported": width, "reason": ...}`, then the summary. Exit 0 means
no findings, 1 findings, 3 to 6 not checked or not at every width (the header lists them). Each width's record
and a full-page PNG land in the docroot's `.checks/<page>-<hash>/` (a dot folder, never served), and the
folders of pages deleted since go. Three widths took under a second on a two-variant page here. Findings
carry page text, so they print with control and invisible characters escaped. visual-decisions runs it on
each pass before asking for the pick, fixes what it shows, re-runs once and names what is left.

| Check | Reports | Misses |
| --- | --- | --- |
| E1 load | a body with no text or media; console errors, uncaught errors and rejections, read from the browser from the first script on (ten, the rest counted as dropped); a resource that failed (an error event, or a 4xx/5xx in the resource timing; not the browser's own `/favicon.ico` probe) | a failed cross-origin CSS background or font; a page that renders the wrong thing |
| E2 layout | the page, or a shell variant box, scrolling sideways, naming the outermost element past the edge or the one whose unbroken text runs past it; a box wider than the viewport that is cut off; text cut by `overflow: hidden` or `clip` (an ellipsis whose full text is in a `title` or `aria-label` passes); text of in-flow block siblings whose lines' 0.8 em glyph bands overlap by 4 px each way and 35% of the smaller band (design-kit's rule, so the shell's `.vd-display` above `.vd-t1` passes); a focusable target under 24 by 24 px with another target within 12 px of its centre (the WCAG 2.5.8 spacing, inline and native-control exceptions) | overlap caused by absolute or fixed positioning, floats or inline runs; another scroll box that scrolls sideways by accident; clipping within 2 px; the off-screen slides of a carousel read as clipped |
| E3 accessibility | axe-core's WCAG 2.0 to 2.2 A and AA rules at impact serious or critical: rule id, first element, help text, element count (`target-size` is off, E2 measures it) | moderate and minor impacts; best-practice rules; what axe marks incomplete; data-state blocks the page does not show by default |
| E4 stand-in content | lorem ipsum, "placeholder", TODO, TBD or FIXME, "your text here" and the like, a whole text that is a generic word plus a number ("Item 3", "Row N"); three or more sibling rows or cards (`tr`, `li`, `article`, or blocks of two or more elements) with the same text outside a `data-state="loading"` block; a table with no filled cell or a list with no filled item outside a `data-state="empty"` block | realistic-looking wrong data; stand-ins in attributes such as `alt`; such a word used on purpose |
| E5 variants, advisory | two variants with the same text, markup (tags, classes, attributes), colours and fonts; two variants sharing less than half of their words, of their parent-child tag pairs and of their colour and font values | two axes changed while a third stays close; the axis the header names; anything outside `.vd-frame > .vd-content` |
| E6 change, advisory | for `current.html` or a ledger pass: the share of pixels that differ from the newest older ledger pass whose bytes differ, at the widest width, and the box around them; printed with `"advisory": true`, not counted as a finding | whether the change was the one asked for; a page that grew or shrank shifts everything below it, so the box covers it all; that pass can belong to another decision |

Thresholds and the reasons for them: `rationale/derivations/plugin-taskmaster.md`, section
`plugins/taskmaster/scripts/preview-check.sh`.

- **Standing.** Gate for each check against its own fixture page, and for a clean shell page reporting
  nothing, in `scripts/__tests__/preview-check.test.sh` with a real browser (it prints SKIP and passes on a
  machine without one). Agent-graded: that the model runs the script and acts on what it prints; no eval
  measures it.
- **How the page runs it.** The script registers `check.js` in an isolated world of every page it loads
  (DevTools `Page.addScriptToEvaluateOnNewDocument` with a world name), evaluates the vendored axe-core there
  after `load`, calls the check and reads its findings back over DevTools, then writes each width's record
  itself. No route serves the check or takes findings (`/_check.js`, `/_axe.js` and `POST /_check` are gone)
  and the shell carries no loader, so any page in the docroot can be checked. Gate: `preview-check.test.sh`.
- **Exact widths.** Chrome's headless mode will not make a window narrower than 500 px, so the script
  drives the browser over its DevTools pipe and emulates each width; stdlib Python, no Node, no Playwright.
- **No network.** During a check every host but 127.0.0.1 fails to resolve, a dead proxy at 127.0.0.1:9
  overrides any proxy in the environment, WebRTC sends no UDP past it and downloads are refused, so a page
  that needs a CDN or a hosted font is reported as a failed load. A web font the page starts late holds the
  check 3 s at most; a page with more than 4000 elements is measured on its first 4000 (`capped` in the
  summary). Gate: `preview-check.test.sh`, with a proxy in the environment, a download and a STUN address.
- **What a hostile page can still do.** Its script runs while it is measured: it can change the DOM it is
  measured on (hide a defect, show a headless browser something else), keep the browser busy so a width reads
  not reported, log errors, open dialogs (accepted) and reach any service on 127.0.0.1, this server's
  `POST /_feedback` included. It cannot read, replace or answer for the check, nor write a record. A clean
  check is not proof the page is fine.
- **Badge.** A page built from the shell shows "checked: N findings" or "not checked" in its header, from
  `GET /_checks?page=`. A result counts only while the page's bytes are the ones checked, and a check run
  updates an open tab without a reload (serve.py streams `checked` when the run's `run.json` appears).
  Absent on the lower rungs and with `?static=1`. Gate for the route and the event; the badge itself was
  driven once in Chrome on 2026-11-13 (recorded).
- **Vendored library.** `vendor/axe-core/` holds axe-core 4.14.0, `axe.min.js` unmodified (652 KB), under
  the Mozilla Public License 2.0 (`LICENSE`), with its third-party notices (`LICENSE-3RD-PARTY.txt`) and a
  `VERSION` line. The harness fails if the file's SHA-256 changes.
