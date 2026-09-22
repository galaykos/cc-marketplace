<!-- Written by a fresh Fable agent on 2026-09-22 after reading plugins/design-kit, the
../design-kit-sim simulation and its screenshots, and rationale/claude-desktop-design-parity-2026-09-22.md.
Standing: recorded — ideas, none prototyped; sizes are estimates. Two invented example values the
agent first wrote were removed by the agent itself before this copy was taken. -->

# design-kit after the simulation — what would make it one workshop

Read: the plugin (README, five commands, five skills, scripts), `design-kit-sim/SIMULATION.md` and its evidence (six screenshots, `design-system/`, the board spec, the outline, the handoff bundle), the parity study §1–§7, the endgame review §6, and the marketplace precedents that bear on each idea (taskmaster's mockup `serve.py`, secret-scanning's write hooks, skill-router's ledger, `turn-cost.sh --skills`).

## 0. Five things the simulation shows that the files do not say

1. **The state flowed through a human three times.** "Northwind renewal — $84,000 · Proposal sent · 19 days · Owner: Priya N." is typed into the board spec, re-typed into the scratch JSX, and echoed in the readout artifact. The brief, the device, the theme path, the pick, and the component choices are all re-entered per command. Nothing under `.design-kit/` records the flow; the gallery (`shot-gallery.png`) shows three unrelated groups, not a sequence.
2. **The decision never reaches the session by machine.** The board's pick and knobs live in `localStorage` (`skills/design/assets/board-shell.html:191`), and "Copy edits as prompt" (`:304–331`) puts prose on the clipboard. `scripts/serve.py` has SSE out and, by its own header, "No write route of any kind". That is a design-kit choice, not a marketplace rule: taskmaster's `plugins/taskmaster/skills/visual-decisions/assets/serve.py` already carries one state-changing POST (`/_restore`, loopback-only, header-gated, 4 KiB cap, `:36–42`, `:272–318`). The precedent for a narrow write route exists in-repo.
3. **Step 5 needed a person.** `codebase-scaffold.sh --create` writes `Fill me with real components.` The inventory it could have used — `Button {variant: primary|secondary|ghost; size: sm|md|lg}`, `Card {title, footer, elevated}`, `StatTile {label, value, delta, trend}` — was already on disk in the fixture's `design-system/DESIGN-SYSTEM.md` from step 1, and nothing read it. `shot-in-codebase.png` is real components, but a human chose every prop. `DataTable`'s generic props (`DataTableProps<T>`, `src/components/DataTable.tsx` in the fixture) were invisible to the extractor, so the model would have guessed them.
4. **The retirement instrument is blind before it starts.** Recounted this session: `grep -c design-kit plugins/skill-router/rules.tsv` → `0`. The README's "Measured" section says `turn-cost.sh --skills` is the retirement queue and joins the router ledger; for design-kit that ledger will read zero by construction, not by disuse. The one thing the plugin promised to report at 0.2.0 cannot currently be measured.
5. **The interactive experience is a wall of permission prompts.** SIMULATION.md: "the plugin's own scripts are permission-denied; the real command run needed `--dangerously-skip-permissions`." Each command drives 3–6 separate script invocations (`commands/system.md` step 4 even has the model run `mkdir -p` and `cp` by hand). Five commands × N scripts = N allow prompts per command, or one blanket override.

Everything below is ranked by experience change per unit cost, grounded in those five.

---

## 1. Make the retirement question answerable before shipping anything else

The plugin's own README makes a promise it cannot keep: "the first version after this one should cite that table", and the table cannot see design-kit (zero rows, recounted above). Fix the instrument first, because every other idea here needs a kill trigger that can actually fire.

**Mechanism.** (a) Five rows in `plugins/skill-router/rules.tsv` (one per skill) so the router ledger counts offers — the prerequisite. (b) A single entry script `scripts/dk.sh <verb>` (see §3) appends one JSON line per verb to `.design-kit/usage.jsonl` — `{verb, ts, outcome, artifact}` — local, untracked, no network. (c) `scripts/dk-usage.sh [--projects DIR]` (or a `--design-kit` join inside `turn-cost.sh --skills`) walks every project's `.design-kit/` and `design-system/` and prints per surface: **created / revisited** (a page whose mtime moved more than a day after creation) **/ picked** (a decision row exists) **/ rendered** (a scratch slug in the ledger) **/ exported / shared** (pages-branch commits, zip files) **/ followed by a commit** — `git log --since=<decision ts> --until=<+7d> -- <component paths named in the decision>`. That last column is the only one that means "a design decision changed code".

**What the user sees.** Nothing new in-session. The maintainer sees one table instead of "it fired".

**Cost.** Five TSV rows (recount the router's always-on cost with the CLAUDE.md command rather than trusting a number here). One small script. `usage.jsonl` stays under `.design-kit/` so it is deleted with the rest.

**Kill trigger for the plugin itself, stated now:** 30 days, at least three projects with `.design-kit/` present, and `followed-by-commit = 0` **and** `shared = 0` → retire on the same evidence that retired design-studio. Say so in the README's Measured section so the number is a commitment, not a hope.

## 2. Give the board a way back: a decision channel, then a ledger the next command reads

The pick-and-bring-back moment is the loop's missing edge. Today the user picks, clicks "Copy edits as prompt", switches to the terminal, pastes. The board should tell the session; the session should not need the clipboard.

**Mechanism.** In `board-shell.html`, on "Pick this" and on any knob/text change (debounced 500 ms), `fetch('/_decision', {method:'POST', headers:{'X-Design-Kit-Decision':'1'}, body: JSON.stringify({board, picked, knobs, text, prompt: prompt()})})`, failing silently when the board is opened as a file. In `serve.py`, `do_POST /_decision`: accept only when `client_address[0]` is loopback, the header is present, and the body is ≤ 8 KiB; append one line to `<docroot>/decisions.jsonl`. Under `--lan` the route still accepts loopback only — a phone's pick is not recorded, and the launcher says so. `dk decision [--latest | --board <file>] [--consume]` prints exactly the prose the copy button produces (so the skill's "read every line as a requirement" rule is unchanged) and marks the row consumed. Two tiers of record: the raw `.design-kit/decisions.jsonl` (machine, untracked) and, once a command acts on a pick, one line appended to `design-system/DECISIONS.md` (tracked, human: date, board, artboard, knobs, which components rendered it, gap rows). The handoff drift `no token` answers go in the same tracked place (`design-system/drift-decisions.json`: `{value, decision: adopt|map:<token>|gap, at}`) and `handoff-drift.py` reads it to pre-fill rows as `decided` — today those answers are asked per row and forgotten, so the next bundle asks again.

Then the commands change shape: `commands/design.md` step 4 offers "I picked on the board — read it" as the first AskUserQuestion option, which runs `dk decision --latest`; `commands/in-codebase.md` with no argument means "the latest unconsumed pick". Optional second rung, its own kill trigger: a `UserPromptSubmit` hook that prints one line — for example `design-kit: board deal-detail has an unread pick (artboard 2)` — only when an unconsumed row exists. That is the "session watching the board" without polling.

**What the user sees.** Click "Pick this" → toast "Recorded — the session can read it". Back in the terminal, `/design-kit:in-codebase` with no arguments answers with the board, the artboard, the knob values and the text edits, then starts rendering.

**Cost.** This changes a stated contract — the README's "No write route exists" becomes "one loopback-only, header-gated, append-only route; export and publish stay scripts" — and the honest thing is to say that in the same sentence that used to deny it. ~40 lines in `serve.py`, ~15 in the shell, one `dk` verb, a harness case (loopback accept, non-loopback 403, oversize 413). The hook, if added, lands in the dynamic budget (`scripts/context-budget-dynamic-baseline.json`) and makes the plugin's `lane.tsv` a gate rather than a WARN (CLAUDE.md, "Lanes"); roughly a sentence per prompt, and only when a pick is unread.

**Kill trigger.** After a month, `decisions.jsonl` rows consumed by a command = 0 while copy-as-prompt pastes still appear in transcripts → people prefer the clipboard; remove the route, keep the copy button.

## 3. One entry point, one state file: `dk`

Five commands is the Desktop's picker, but on disk it is one workshop with one server, one design system, one gallery. Make the plumbing say so.

**Mechanism.** `scripts/dk.sh <verb>` wraps every deterministic sequence the commands currently spell out step by step: `dk system [target]` (dry-run → full → copy kit into previews → start server → print URL), `dk slides <outline>`, `dk board <spec>`, `dk scratch --detect|--create|--cleanup|--verify`, `dk bundle`, `dk share <page>` (the ladder, see §12), `dk export`, `dk decision`, `dk status`. Every verb reads and writes `.design-kit/workshop.json`: `{brief, device, theme, system: {stamp, at}, board: {file, picked, at}, scratch: {slug, at, kept}, artifacts: [...], deck: {...}}`. Commands default their arguments from it: `/design-kit:slides` with no brief offers "a review deck of the deal-detail decision"; `/design-kit:artifact` with no input offers "bring-back of the last pick" or "share the deck". The gallery gets a flow strip at the top, derived from `workshop.json` and `decisions.jsonl`: *system → board (picked N) → in-codebase (slug, cleaned) → artifact (slug vN) → deck (slug, PDF)*.

**What the user sees.** One permission rule — `Bash(bash */design-kit/scripts/dk.sh*)` — instead of a prompt per script. Commands that remember the brief, the device and the theme. A gallery that reads as a session, not as three folders.

**Cost.** One shell script (~150 lines) dispatching to the existing scripts, no new dependency; each command file gets shorter (fewer bytes loaded when it runs). `workshop.json` is untracked.

**Kill trigger.** If `dk status` shows the flow was never longer than one step in any project after a month, the workshop framing is wrong and the five tools were the truth; keep `dk` for the permission win only.

## 4. The scaffold reads the inventory it already has

The smallest mechanism that removes the human from step 5, and the one with the best cost ratio in this report.

**Mechanism.** `system-extract.py` also writes `design-system/components.json` — the table it already renders as markdown (`build_markdown`, around `scripts/system-extract.py:650`), machine-readable: name, source path, export name, props with types and defaults, variants, and which components are the library's empty/loading/error primitives if any. `codebase-scaffold.sh --create` (via a small Python helper, since bash should not compute relative import paths) then writes the scratch file with: an import line per component (relative path from `src/__design-kit__/` to the component, or the `@/` alias when `tsconfig` `paths` declares one), a comment block per component carrying its prop signature verbatim, and a `<section data-design-kit="strip">` that renders every component × every union-typed variant with children text taken from the brief in `workshop.json`. Where props were not extracted (the `DataTableProps<T>` case), it writes a comment naming the file to open before using the component, so the gap is visible instead of guessed.

**What the user sees.** The scratch page opens with every real component in every real variant, in the project's own tokens, before the model has written a line — a living kit that `kit.html`'s static cards can only imitate. The model's job shrinks to composition and data.

**Cost.** ~120 lines across the extractor and a helper; no dependency; `components.json` is one more tracked, deterministic file in `design-system/` (the byte-identical harness extends to it for free).

**Kill trigger.** If the generated imports fail to compile in two of the first five real projects (barrel-only exports, unusual aliases) — measurable from the dev server's error overlay or `vite.log` — the mechanism is net-negative; fall back to emitting the comment block only.

## 5. From a picked artboard to real components without guessing props: a map and a transpiler

§4 gives the model the components. This gives it the *composition*, deterministically, and refuses to let it invent a prop.

**Mechanism.** The board shell has a fixed vocabulary (`dk-btn`, `dk-btn-ghost`, `dk-card`, `dk-badge`, `dk-nav`, `dk-stack`, `dk-row`, `dk-input`…; `skills/design/references/primitives.md`). `dk map` proposes `design-system/map.json` from `components.json` by name heuristics (`dk-btn` → a component named Button/Btn with a `variant` prop; `dk-card` → Card; `dk-badge` → Badge/Chip/Tag/Pill; anything unmatched → `gap`), each row `{primitive, component, props, source, confidence}`; the command asks once per low-confidence row and the file is committed — the map is the living contract between the picker's vocabulary and the project's library. `board-to-scratch.py <spec> --board N --map design-system/map.json [--decision <row>]` walks the artboard's body with `html.parser` and emits JSX: mapped primitives become `<Button variant="ghost">Nudge legal</Button>`, text carried verbatim including the board's recorded text edits; unmapped elements stay as plain JSX with `{/* gap: dk-badge — no component in the library; ask */}`. It exits 2 naming the row if the map asks for a prop that `components.json` does not list. The scratch file from §4 gets this as its body instead of the strip.

**What the user sees.** The pick renders on the dev server with the right `Button`, `Card` and `StatTile` within seconds of choosing "read my pick", and the only questions left are the gap rows — which are the real design questions ("the library has no badge; add one or use text?").

**Cost.** ~250 lines of Python, one tracked JSON file, no dependency. The judgment that stays with the model is exactly what should: gaps, data, states.

**Kill trigger.** If in real projects more than half the primitives land as `gap` rows, the shell's vocabulary does not match real libraries and the transpiler produces HTML the model rewrites anyway → drop it, keep `map.json` as a prose table the skill cites.

## 6. Stamp every build with the tokens it used, and make `system` mostly implicit

The Desktop's design system "propagates to every deck". Here the builders already read `design-system/tokens.json` (`deck-build.py:193`, `board-build.py:237`) — but nothing tells you a deck was built against tokens that have since moved, and the user must remember to run `/design-kit:system` first.

**Mechanism.** `deck-build.py`, `board-build.py` and `artifact-bundle.py` (which already stamps `design-kit-artifact`, `:331–337`) add `<meta name="design-kit-tokens" content="<12-hex sha256 of tokens.json> <git short sha or none>">`; `serve.py` carries it in `_index.json` and the gallery shows a badge — green when it equals `sha256(design-system/tokens.json)` now, amber "tokens moved since build" with the rebuild verb otherwise. `dk check` runs `system-extract.py . --dry-run --check` and diffs against the committed `design-system/`, printing one line naming the token, its `path:line` source as `tokens.json` records it, and the old → new value — for example a moved `primary`, with no values invented here. Every other command runs `dk check` first and repeats that one line. `/design-kit:system` remains for the explicit extraction, the canonical-token question, and the CLAUDE.md append.

**What the user sees.** A gallery that knows which pages are stale. A `/design-kit:slides` that says "your design system is one commit behind" before building.

**Cost.** A sha per build (milliseconds); ~one line of context per command; no dependency.

**Kill trigger.** Amber badges shown for a month with no rebuild following → staleness is not a thing users act on; keep the stamp (it costs nothing), drop the badge.

## 7. Drift is measured everywhere a literal can enter, not only in a handoff bundle

`handoff-drift.py` already reads any directory of `.html/.css` against the repo's tokens. The one place drift actually enters a codebase — the model writing a literal colour into a component — is unmeasured.

**Mechanism.** Generalise to `dk drift <paths | --staged | --diff <base>>`; sources widen to `.tsx/.jsx/.vue/.blade.php/.scss`; `--ci` exits 1 on any `no token` row so a repo can wire it as a CI step beside lint. A `PostToolUse` hook on `Write|Edit` (`hooks/drift-warn.sh`; precedent: `plugins/secret-scanning/hooks/hooks.json`) runs only when `design-system/tokens.json` exists and the written file matches the extension list, prints at most three rows, once per file per session (marker under `.claude/design-kit/`), never denies. `board-build.py` and `deck-build.py` print a `drift:` line for any literal colour in a spec's `css` field or an outline's inline styles. The `no token` resolutions are recorded in `design-system/drift-decisions.json` (§2) so they are asked once.

**What the user sees.** After the model writes a literal: one row of the form "drift: <literal> — nearest token `<name>` <value> (Δ n); use `var(--…)`?" In CI, a failing check with the same table.

**Cost.** A new `hooks.json` for the plugin — a process per write (~30 ms of Python) and dynamic-budget tokens only on a hit; the lane declaration becomes a gate. Standing to state: advisory in-session, gate only where the repo wires `--ci`.

**Kill trigger.** If 80% of warned literals are still present at the next commit, the warning is noise → remove the hook, keep `dk drift --ci`.

## 8. The weekly job: a PR visual diff with the token drift of the diff

Nothing in the five commands recurs. The thing a web team does every week is open PRs, and every PR that touches UI raises "what does it look like now, and did it leak a colour?" — a question this plugin already has the parts to answer (headless Chrome location in `board-export.sh`, the dev URL from `codebase-scaffold.sh --detect`, the bundler, the pages branch, drift).

**Mechanism.** `dk snapshot [--routes a,b] [--device desktop,phone]` shoots each route on the running dev server into `.design-kit/snapshots/<branch>/`. `dk review --base <ref>` builds a compare artifact — before/after per route (the base side from the last snapshot on the pages branch for `main`, committed by a documented ten-line CI snippet; no second dev server), the `dk drift --diff <base>` table, and the tokens changed — bundles it, and offers the share ladder; on the pages rung it also offers `gh pr comment` with the URL. Ship it as a `dk` verb first; promote to `/design-kit:review` only after it is used, because a sixth command is a sixth always-on listing entry.

**What the user sees.** One URL per PR with every changed screen at two sizes, before and after, and a drift table — the design review a team actually holds, in the place they already hold it.

**Cost.** Chrome (already required for PDF/PNG), a running dev server, a CI snippet the user adds; size L. Network only on the share rung, on consent as today.

**Kill trigger.** Two months, no PR in any project carries the link → the team's review lives elsewhere; drop `review`, keep `snapshot`.

## 9. Comments without a cloud — two rungs, no auth theater

The Desktop's comments "reach the session live". The local-first analogue has to respect that the LAN rung already means "anyone on this network can read", and that a write route reachable from the LAN with no auth is a different claim.

**Mechanism.** Rung one, zero server change: `skills/artifact/assets/page-shell.html` (and the deck/board shells) gain a comment composer — click an element, type a note, stored in `localStorage`; "Copy comments" and "Download `<slug>.comments.json`". A phone reviewer on the LAN sends the file or pastes; `dk comments import <file>` prints reviewer, anchor, note as a table the session reads. Rung two, for the pages branch: `artifact-publish.sh` prints the commit URL with "comment on this page there"; `dk comments <slug>` fetches GitHub commit comments on the pages commits that touched `artifacts/<slug>.html` via `gh api`, and prints them. No `git notes` thread — it is the right shape and nobody will find it.

**What the user sees.** A reviewer's notes land in the session as rows with anchors, whether they came from a phone on the LAN or from GitHub.

**Cost.** Rung one: ~3 KB inline JS per shell; nothing in context until imported. Rung two: `gh`, network on request, GitHub-only.

**Kill trigger.** Thirty days after three or more artifacts were shared, zero comments imported or fetched → the share is read-only in practice; remove the composer.

## 10. Live data for an artifact, git-shaped

The Desktop artifact calls MCP connectors at view time. The local analogue is a JSON beside the page that something else keeps fresh.

**Mechanism.** The bundler recognises `data-design-kit-live="<file>.json"` on a `<script>` or `fetch` reference: it does not inline it, reports it as `live:` instead of `unresolved-link:`, and copies the file beside the artifact; `artifact-publish.sh` copies `artifacts/<slug>.data/*.json` too; a documented CI snippet commits fresh JSON to `design-kit-pages`. The dashboard pattern in `skills/artifact/references/patterns.md` shows "data as of <ts>" from the file.

**What the user sees.** A dashboard artifact that is still true next week without a rebuild.

**Cost.** S in the bundler and publisher; the user's CI does the refreshing. No server.

**Kill trigger.** Sixty days, no artifact declares a live file → remove the attribute, keep the `unresolved-link:` report.

## 11. A QR code for the LAN URL

Small, and the LAN rung's whole point is a phone.

**Mechanism.** The gallery page draws a QR of `location.href` when the host is not loopback (a ~1.6 KB MIT QR encoder vendored as a string in `serve.py`, no network); `preview.sh --lan` prints `qrencode -t ANSIUTF8` when the binary exists, else the URL as today.

**Cost.** 1.6 KB in the gallery page, none in context. **Kill trigger.** `--lan` never appears in `usage.jsonl`.

---

## 12. Which of the five should not be separate commands

- **`system`** should become mostly implicit (§6): every other command runs `dk check` and says one line. Keep the command for explicit extraction, the canonical-token question, and the CLAUDE.md append — those are judgment calls and consent, which is what a command is for.
- **`design` and `in-codebase`** are one decision flow at two fidelity rungs, and the sim ran them as one. Keep two commands anyway: `in-codebase` writes into the project tree behind a consent gate, and Proportionality says a different blast radius earns a different door. But `in-codebase` with no arguments must mean "the latest pick" (§2), and `design` must offer "read my pick" first.
- **`artifact`** is the weakest as a command: it is the bundler plus the share ladder, and the sim shows the cost of keeping both inside one command — `q3-deck-share` is a deck re-bundled as an artifact purely to reach the share ladder. Pull the ladder out as `dk share <any page>` reachable from slides, design and review; keep `/design-kit:artifact` narrowed to "make a page from this `.md`/`.html`/dir/brief". If the "brief → pattern page" path is only ever used for bring-backs, it belongs to §2's ledger, not a command.
- **`slides`** is the one the study said not to build (§5 S5: the host's synced `pptx` already carries every rule). Its only distinct claim is repo-sourced decks with the project's tokens. It earns its place if it connects to repo state — a release-notes deck from `CHANGELOG.md`'s top section (`dk slides --from-changelog` builds the outline skeleton, the model writes claims), a review deck from the decision ledger and board PNGs. If after a month every deck was built from a free-text brief, it is the host skill's job and should go.

## 13. Where a script must be the worker and where the model is the product

| Never the model (deterministic, cheap) | The model's judgment is the product |
|---|---|
| Token extraction, stamps, staleness check (§6) | Which axis the 2–4 directions diverge on; the `tradeoff` line |
| Deck/board/artifact builds, exports, bundling | Real copy in the product's voice; a headline that states a claim |
| Reading the pick, knobs and text edits back (§2) | Which component fills a `gap` row, or whether the library needs one |
| Import lines, prop signatures, the variant strip (§4) | Resolving a `no token` row: adopt, map, or leave a gap |
| Primitive → component transpile, prop existence check (§5) | Choosing what a deck's one number is |
| Drift tables, `--ci` verdicts (§7) | Reading a drift row as semantic misuse (right hex, wrong role) |
| Snapshots, compare pages, comment fetch (§8, §9) | Whether a page earns existence at all (the artifact skill's first rule) |
| `mkdir`/`cp`/server start (today in `commands/system.md` step 4 — move into `dk`) | The canonical-of-two-primaries question |

Two places the model is currently asked to do a script's job and it shows: `commands/system.md` step 4 (`mkdir -p … && cp …`) and every command's "start or reuse the server, print the URL plus `/path`" — URL assembly is where a model drops a segment. Both vanish behind `dk`.

## 14. Ranked, with what each costs the context budget

| # | Idea | Size | Context cost | Standing when shipped |
|---|---|---|---|---|
| 1 | Instrumentation: router rows, `usage.jsonl`, `dk-usage.sh`, the plugin's own kill trigger | S | none | recorded → measured |
| 2 | Decision channel + tracked `DECISIONS.md` / `drift-decisions.json`; optional unread-pick hook | M | hook only: one line per prompt when a pick is unread | route: gate (harness); hook: dynamic baseline |
| 3 | `dk` entry + `workshop.json` + gallery flow strip | M | negative (shorter command files) | recorded |
| 4 | Scaffold reads `components.json` (imports, signatures, strip) | S | none | gate (deterministic output) |
| 5 | `map.json` + `board-to-scratch.py` | M | none | prop check: gate; mapping: agent-graded |
| 6 | Token stamp, staleness badge, implicit `dk check` | S | one line per command | gate for the stamp; badge recorded |
| 7 | `dk drift` everywhere + PostToolUse warn + `--ci` | M | hook: tokens on hit only | advisory in-session; gate in CI |
| 8 | PR visual diff (`snapshot`, `review`) | L | none until promoted to a command | agent-graded compare; drift gate |
| 9 | Comments: in-page composer + GitHub commit comments | M | none | recorded |
| 10 | Live JSON beside an artifact | S | none | gate (bundler report) |
| 11 | QR for LAN | S | none | recorded |
| 12 | Consolidation verdicts (§12) | — | negative | — |

Do 1 before anything: it is the only item that makes the others' kill triggers real, and it costs an afternoon. 2–4 together turn the sim's five tools into the loop the sim actually ran. 8 is the one that would make someone open this weekly.

**What I did not verify.** No idea here was prototyped; sizes are estimates against the existing scripts' line counts. I did not run the plugin's harnesses or the marketplace gates, and I did not confirm that a UserPromptSubmit hook's dynamic-budget cost fits the current baseline — that is a `context-budget.sh` run once a hook exists. Every `path:line` above was read this session; the fixture paths (`src/index.css`, `src/components/*.tsx`) live under `design-kit-sim/`, not the marketplace. The skill-router count (`0`) was recounted with `grep -c design-kit plugins/skill-router/rules.tsv` immediately before this message.
