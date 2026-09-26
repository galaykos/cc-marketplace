# UI walk — a browser pass when a UI group closes

No per-card check sees a rendered page (why: `rationale/2026-09-25-task-runner-prose-derivations.md`).
**Standing: `recorded`** — nothing checks that a walk ran or what a shot shows; a skip
recorded with `reduction-record.sh` must be named in the closing report (candor's gate, when
installed). Full checklist and harness notes: overseer's `skills/overseer/references/acceptance.md`
when installed; this page is the minimum without it.

**When, who.** A UI group is a milestone (else the run) whose diff touches UI files. Walk
after its last card and the in-run a11y fixes (`reviewer-routing.md` § UI diffs), before its
full-suite verify; `<group>` is the milestone id or run slug (`[A-Za-z0-9._-]`). Only the
orchestrator walks (workers hold no MCP tools); under `--tracks`, the merged branch.

**Serve.** Build; serve the built assets (no `public/hot`) with the project's command on a
free port (not 8123/8124); confirm the URL answers. A 500 is usually a pending migration:
migrate, never fresh or reset, never touch `.env`. Ask before stopping a dev server you did
not start.

**Access.** Sign in through what the spec's Walk access row settled (the first UI card builds
it: an app-registered user with a generated password, a seeded walk user, or an env-guarded
local-only login route) — **never the user's own credentials**. None: ask (`AskUserQuestion`);
hands-off or declined: walk what you can reach and record
`reduction-record.sh --kind coverage --id walk-<group> --reason "…"`.

## Walk each surface

Surfaces: the union of the group's cards' `<walk>` lines, plus any changed route or new state
without one (unreachable → "not observed", below). Playwright MCP (a tool that cannot save a
PNG leaves `seen, not saved`). At **1280** (`browser_resize` 1280×800) and **375** (375×812),
a full-page screenshot, then:

1. Overflow probe, `browser_evaluate`:
   ```js
   () => { const w = document.documentElement.clientWidth, s = document.documentElement.scrollWidth;
     const scrolled = e => { for (let p = e.parentElement; p && p !== document.body; p = p.parentElement)
       if (/auto|scroll/.test(getComputedStyle(p).overflowX) && p.getBoundingClientRect().right <= w + 1) return true; return false; };
     const wide = [...document.body.querySelectorAll('*')].filter(e => e.getBoundingClientRect().right > w + 1 && !scrolled(e));
     return { overflow: s > w, scrollWidth: s, clientWidth: w, wide: wide.slice(0, 8).map(e => e.outerHTML.slice(0, 80)) }; }
   ```
   `overflow: true`, or anything in `wide` but a closed off-canvas drawer, is a finding; a
   squeezed column that does not overflow shows only in the 375 shot.
2. Keyboard: click a blank area, Tab to each new control (visible focus ring), Enter/Space
   activates; a dialog or menu closes on Escape with `document.activeElement` back on the trigger.
   A composite (grid, tree, tabs, listbox, board) is one tab stop and arrows move inside it.
   Finish every drag through its non-drag route (keys or a move control, SC 2.5.7): a
   mouse-only board is a finding. A live region announces a summary, never each tick or row.
3. Motion changed: `browser_run_code_unsafe` `await page.emulateMedia({ reducedMotion: 'reduce' })`,
   repeat; nothing moves beyond a fade.
4. Console after the walk, since the last navigation: name or fix every error.

A walk defect is a blocker on the card owning the file: its bounded fix loop, then re-walk
that surface — never a backlog line.

## Shots and the Screens table

`<repo>/.claude/task-runner/walk/<group>/{desktop,mobile}/<route>.png` (1280/375). Before set:
`walk/<group>-before/`, same layout, shots only, at group OPEN, of surfaces already rendering.
`<route>` is design-kit's slug (non-alphanumeric runs → `-`, ends trimmed, `/` → `index`; a
state appends a word). Save in `.playwright-mcp/`, `mv` into place, `Read` it before tabling.
Never pair with a `dk snapshot` set (1440/390). With design-kit,
`DESIGN_KIT_DIR=<repo>/.claude/task-runner/walk DESIGN_KIT_PORT=<free port> bash <design-kit>/scripts/snapshot.sh review --base <walk>/<group>-before --current <walk>/<group>`
prints `url=` (`<design-kit>`: `${CLAUDE_PLUGIN_ROOT}/../design-kit`, else the newest
`~/.claude/plugins/cache/*/design-kit/<version>/`).

Name every changed surface the walk did not see, what it needs (data, a key, a second actor,
access) and what covers it instead (a named test, or `nothing`). The group's closing message
carries one table, repeated in the completion report; absolute paths, `url=` beneath. A
before cell reads `new` for a surface the group creates, `not shot` for one never shot.

| screen | width | before | after | not observed |
|---|---|---|---|---|
| /settings/brand | 375 | /abs/…/walk/m2-before/mobile/settings-brand.png | /abs/…/walk/m2/mobile/settings-brand.png | — |
| /generate · failed tile | — | — | — | needs a failed row; `GenerationPropsTest` |

## No JS runner: the walk is the evidence

`no-behavioral-coverage` for UI files → the recorded exit from `run.md` step 4, adding
`--evidence .claude/task-runner/walk/<group>` (or `walk/` for several groups) to
`reduction-record.sh --kind coverage --id bg-<HEAD12> --reason "…"`. The path must exist
inside the repo, or the script exits 3. Re-walk a surface changed after its walk. Still a
disclosed reduction: the walk saw screens; nothing ran the code's branches.
