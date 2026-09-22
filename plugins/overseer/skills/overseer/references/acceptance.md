# Acceptance — a milestone is done when a user could use it

`scripts/program.sh accept --id <id>` closes a milestone only when its kind's evidence
kinds are recorded — these nine for every kind with a screen (the `ui` evidence profile,
`kinds.tsv` column 4, the default; a kind with no screen is "Headless kinds" below) —
each with a `--file` that exists at record time and still exists at
accept time, and each recorded after the last gated worker or follow-up dispatch (**gate**,
exit 2 otherwise; a screenshot deleted after recording un-accepts; a walk before the last
fix cycle is re-run, not re-dated). Nine rows on one file and a milestone with no gated
reviewer dispatch each draw a WARN, not a refusal.
That the file was LOOKED AT is a **gate** since 0.4.0: `hooks/track-read.sh` ledgers every
`Read` while a program is open, and `evidence add` refuses a file no Read in this session
touched since it last changed (a re-captured screenshot is unread again). Open the artifact
with `Read` — a PNG renders — before recording it. What it must SHOW is judged by you
(**agent-graded**); that the run behind it was real stays **unenforceable**, which is why
every item names a file a human can open. Without a session id (a plain terminal) or with
no Read tracked for the session (hook not loaded) the gate says so and records — fail-open,
never silent.

| Kind | What was done | The file |
| --- | --- | --- |
| `tests` | the project's full suite plus types, lint and build ran on the milestone branch at HEAD | one saved output holding EVERY command's tail — a `tests.txt` with only the suite is a partial claim |
| `browser-happy` | every acceptance line's happy path performed in a real browser | screenshot per line under `milestones/<id>/evidence/`, **with the success feedback in frame** (toast, confirmation, new row); a screenshot after the toast has faded proves the page, not the feedback — capture within the toast's lifetime or freeze it |
| `browser-error` | every acceptance line's error path performed: invalid input, too large, wrong type, unauthorised | screenshot of the error state, input preserved; an error path the browser cannot reach with one user (a 403 for another member) is proven by a named test and said so in the note |
| `viewport:mobile` | the feature walked at 375 px wide | screenshot; no horizontal scroll; primary action reachable; tap targets measured |
| `viewport:tablet` | same at 768 px | screenshot |
| `viewport:desktop` | same at 1280 px | screenshot |
| `console-clean` | browser console and network panel read after the walk, since the last navigation | the dump — zero errors, or each one named and fixed |
| `keyboard` | the full path driven with Tab, Enter, Space and Escape only, from page load to the success feedback, including the destructive action's confirm | screenshot with the focus ring visible on the primary action, plus the key sequence in the note |
| `motion` | `prefers-reduced-motion: reduce` emulated — Playwright MCP: `browser_run_code_unsafe` with `await page.emulateMedia({ reducedMotion: 'reduce' })` (verified; `browser_evaluate` cannot), Chrome MCP: DevTools rendering — and the walk repeated | screenshot; the note says which animations stopped and that none looped |

## Headless kinds — the milestone with no screen

A kind whose `kinds.tsv` row carries the `headless` profile (`audit`, `library`) has no
viewport to walk, so `accept` requires exactly two kinds (**gate**) and none of the browser
rows above. Demanding the nine of a research pass or a CLI change is why every such
milestone used to end `parked`.

| Kind | What was done | The file |
| --- | --- | --- |
| `tests` | as above; on an `audit` milestone it is the baseline suite, proving the tree the pass read is still green and nothing was edited in passing | one saved output holding EVERY command's tail |
| `run-log` | the command the milestone exists to make work, run and captured: the CLI invocation, the script, the query, the harness, the analysis that produced the findings | the saved output with the command line at its head and the exit status at its foot — the run itself, not a note saying it ran |

Two kinds, two files: the suite tail and the run are different runs, and `accept` WARNs
when every row points at one file. Of the Protocol below, steps 2-5 (serve, walk three
widths, read the console) have nothing to act on; 1, 4's charter check, 6, 7 and 8 bind
unchanged — the file is still `Read` before it is recorded, the row is still newer than
the last gated worker dispatch, and a FAIL is still a finding, not a softened line. A
headless milestone may record any other kind too; only these two are demanded.

Optional kinds, recorded when produced: `a11y` (`/ui-ux:audit` result), `review` (the
reviewer pass), `perf` (a measured metric), `dark-mode` (required by judgment, not by
script, when the app ships a theme switch — one screenshot per width in the dark theme),
`progress` (an in-flight capture under a throttled network for any upload or long action;
the loading state the charter promised must be seen, not inferred from the code).

## Protocol

1. **Suite first.** Run the exact verify commands from the brief and save every tail into
   one file. Red → back to the fix loop; acceptance never starts on a red suite. Then
   `git status --short --untracked-files=all`: every untracked path is in the milestone's
   scope or explained (a worker left a compiled `a.out` in simulation 2; simulation 4 left
   other plugins' scratch — `.claude/candor-last-*`, `.claude/comment-discipline/`,
   `.claude/task-runner/`, `.claude/taskmaster/` — unnamed). Name them in the walk note or
   propose the ignore lines as a suggestion; "not mine" is an explanation only once written.
2. **Serve the app from the BUILT assets.** Kill any dev server a worker left (`lsof -i`
   on the Vite port), delete the framework's hot file (`public/hot` in Laravel) — a walk
   served from HMR modules is not a walk of what ships; then use the project's own serve
   command (`composer run dev`, a compose stack, `php artisan serve`); pick a port
   nothing else holds (the marketplace's preview server sits on 8123) and confirm the URL
   answers with the page you expect before opening a browser — a 404 on a route the suite
   passes is a wrong port, a 500 is usually a migration the tests ran and the dev database
   did not. Seed or register whatever the walk needs (a user, a team) through the app's own
   paths, not by editing the database.
3. **Walk it, three widths.** Prefer the Playwright MCP (`browser_resize`, `browser_snapshot`,
   `browser_take_screenshot`, `browser_console_messages`) or the Chrome MCP; delegate the
   walk with the browser-tester prompt when the walk is long. Without any browser tool,
   `npx playwright test` with a generated spec is the last resort — and if that is also
   unavailable, the milestone stays `accepting` and the board says why. Never substitute a
   `curl` of the HTML for a browser.
4. **Charter and product-truth check.** Open `charter.md` § Product decisions next to the
   running app: every state it promised (empty, loading, skeleton, progress, success,
   error) is either seen or the charter is amended through `program.sh decision add`
   before accept. For any marketing or summary surface (a homepage, a dashboard card, an
   onboarding screen): every capability, noun and count it shows exists in a done or
   queued milestone with the same words — the overseer is the only one who sees all the
   milestones, so this check is yours, not a reviewer's. For an `integration` milestone
   (or the last one when every branch already contains the others) the walk crosses
   features in one tree — landing page → sign in → each feature in the order a new user
   meets them — and that walk is the evidence, not a re-run of each milestone's own.
5. **Read the console** after the walk, not before: hydration warnings, 404s on assets,
   failed XHRs are findings. Read since the last navigation — a log carrying an earlier
   wrong-port error is not "clean because we fixed it".
6. **Record**, one call per item. A browser tool writes screenshots only inside its own
   allowed roots (the Playwright MCP: its `.playwright-mcp/` dir under the session cwd);
   save there, then move the files into `milestones/<id>/evidence/`, `Read` each one (the
   read gate refuses a file this session never opened), then record:
   `program.sh evidence add --id m1 --kind browser-happy --note "upload → toast" --file <png>`.
7. **Accept.** `program.sh accept --id m1`. Exit 2 lists what is missing; produce it.
   Take your own product look first (full-page screenshots at 1280 and 375, light and
   dark) — reviewers grade code against a spec; only you grade the spec against the
   product.
8. **A FAIL is a finding.** It goes back through the bounded fix loop (three cycles), then
   the milestone is parked with the failing line as the reason. Softening an acceptance
   line to make it pass is the one edit this protocol forbids.

## What the browser walk is checking for, beyond "it renders"

- The primary action is findable without instructions; the empty state tells a new user
  what to do; an error names the fix and keeps the input.
- Nothing depends on hover on the mobile width; tap targets ≥ 44 px; text does not
  overflow its container; images keep their aspect ratio.
- Animations respect `prefers-reduced-motion` (the `motion` kind) and nothing loops.
- Keyboard: the whole path, not one Tab (the `keyboard` kind); focus is visible and lands
  somewhere sensible after a destructive action removes the element that had it.
- After a reload the state the user created is still there.

Harness note (three simulations, three false alarms): a Playwright page has no focused element
until something is clicked — click a blank area before the first `Tab`, or the keyboard walk
"does nothing" and the finding is yours, not the product's.
