# demo-flow-creator

A **smart demo-flow generator**. It captures a live web flow, hosts a local replica, and
swaps the replica's register store to a local SQLite database — so you get the *full
experience* of the original flow, running entirely on your machine, for the development stage.

## What it is — and is not

- **Is:** capture a rendered page (you clear any gate in a real browser), host it locally,
  point its signup form at a local SQLite store, replay the experience for dev/demo.
- **Is not:** an anti-bot bypass. There is **no headless CF-defeat, no anti-detect browser,
  no proxy rotation**. The capture step opens a *real* browser window; a human clears any
  challenge. The tool only reads the rendered DOM after you pass the gate.

The one hard line: this tool never programmatically defeats a site's bot controls, and never
submits to the origin. Every "register" lands in your local `store.sqlite`.

## Install

```bash
cd demo-flow-creator
npm install
npx playwright install chromium   # one-time browser download
```

## Use (multi-step)

A registration flow usually has several stages. Capture each stage into ONE output dir, then
scaffold, then serve or drive.

```bash
# 1. Capture — a real browser opens. Walk the flow one stage at a time:
#    reach a stage, press ENTER to capture it; advance; capture again; type 'd' when done.
#    Every stage is captured in the SAME session, so cookies/state carry across steps.
node bin/dfc.js capture --url https://example.com/register --out captured

# 2. Scaffold — for each stage, rewrite its form action to the local sequencer + init SQLite.
node bin/dfc.js scaffold --in captured

# 3a. Serve — run the staged demo on localhost, click through it yourself.
node bin/dfc.js serve --in captured --port 3000

# 3b. Drive — let an agent walk the whole flow end to end (see below).
node bin/dfc.js drive --in captured
```

Open `http://localhost:3000/` and the server sequences you step 0 → step 1 → … → done. Each
submission writes to `captured/store.sqlite`, keyed by a session id, never to the origin.

- `http://localhost:3000/admin/submissions` — human view of the local store

### Non-interactive / multi-step capture (`--wait`, `--append`)

For **gate-free** pages or CI, capture without the prompt, and add stages with `--append`:

```bash
node bin/dfc.js capture --url https://SITE/step1 --out captured --wait 500 --headless
node bin/dfc.js capture --url https://SITE/step2 --out captured --append --wait 500 --headless
```

`--wait` just loads, waits, and extracts. It is **not** a bypass — no anti-detect, no
challenge-solving. Point it at a gated page and it will simply be blocked, which is correct.

## Agentic control — the JSON API

`serve` exposes a deterministic API so a prompt/agent can drive the whole staged flow. This is
what `dfc drive` uses:

| Call | Does |
|---|---|
| `GET /api/flow` | describe every stage: index, title, fields (name + type), submit URL |
| `POST /api/session` | start a run → `{ sid, currentStep, stepCount }` |
| `POST /api/session/:sid/step/:n` | submit stage `n` (JSON body of field values) → `{ ok, done, nextStep, progress }` |
| `GET /api/session/:sid` | current state: status, current step, all submissions so far |

Order is **enforced**: submitting a stage out of sequence, or after completion, returns `409`.
`dfc drive [--data <file>]` walks the flow via this API, filling each field from `--data`
(JSON keyed by step index) or auto-generating values from field name/type.

## How the pieces map to the idea

| Idea | Implementation |
|---|---|
| "copies the website" | `capture` — headed Playwright, human clears gate, dumps hydrated DOM per stage + inlines same-origin CSS |
| "multi-stage flow" | `steps.json` manifest, one snapshot per stage, captured in one session |
| "hosts it" | `serve` — Express sequences stages on localhost |
| "changes the register store" | `scaffold` — rewrites each stage's form action to `/api/step/N` → SQLite `sessions` + `submissions` |
| "more agentic control" | `drive` + the JSON session API — deterministic, order-enforced, inspectable |
| "shows the full experience" | click through step 0 → done, backed entirely by your own store |

## Tests

```bash
npm test   # scaffold -> agentic API -> order enforcement -> browser flow -> drive, on example/
```

Battle-tested end-to-end: live capture of a real external form (httpbin), a **JS-hydrated**
SPA whose form only exists post-render (beats Save-Page-As), a **live 3-stage** flow with a
display-only middle step captured via `--append` and driven to completion, multi-value fields
(checkbox arrays), out-of-order / post-completion rejection (`409`), the interactive capture
loop (piped + EOF safe), the missing-scaffold error path, and formless pages.

## Limits (honest)

- Cross-origin assets (images, third-party scripts) still load from their origin, or 404 if
  gated. Same-origin CSS is inlined. This is a demo replica, not a byte-perfect mirror.
- The form heuristic picks the form with the most fields per stage. Override by editing
  `replica.json` / `replica-step-N.html` if it guesses wrong.
- Stage order is the capture order. Client-side (no-URL-change) SPA steps: reach each state in
  the browser and press ENTER to capture it before advancing.

## Scope

Local dev only. Nothing here is built to be deployed as a live, branded lookalike — that
would be a trademark/phishing problem independent of this tool. Keep it on `localhost`.
