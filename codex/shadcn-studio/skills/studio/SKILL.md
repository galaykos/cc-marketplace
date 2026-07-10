---
name: studio
description: Use when a visual or UI decision needs REAL interactive components but the project is greenfield or non-React — no runnable Vite+React app for design-preview to host. Stands up a self-contained shadcn + Vite (Tailwind v4) sandbox on its own dev server, renders agent-authored variants side by side with real interactivity (sort/filter/dialog), strict consent before any write, scratch outside the work tree, verified cleanup, and a static-shell fallback.
---

## Where this sits

This is the interactive vehicle for visual decisions that a static mockup cannot
carry, at the moment the codebase cannot host one itself. It renders real,
clicking shadcn components — not token-mimicking HTML — from a sandbox the
plugin ships, so it works with zero project scaffolding.

- Cheaper rungs first: layout structure, density, and flow feel stay in the
  taskmaster `visual-decisions` shell. Do not stand up a dev server for a choice
  ASCII or the shell already settles.
- Real components on an EXISTING app: that is `design-preview:real-preview`.
  shadcn-studio is its greenfield / non-React sibling, not a replacement.

The engine renders whatever JSX the authoring agent writes, so a layout variant
and a copy/concept variant are both just variants — it does not distinguish
them. Formal lanes, depth, and charts are a separate concern; this skill only
proves and serves the interactive vehicle.

## Detection and routing — lock beats memory

Decide the route BEFORE any consent or write:

| Condition | Route |
|-----------|-------|
| Runnable Vite+React host (`vite.config.*`, react plugin, `scripts.dev`, components present) | Defer to `design-preview:real-preview` |
| Node absent, or below `20.19` (the Vite 8 floor) | Static-shell fallback (before any write) |
| Empty/greenfield dir, or a non-React stack | shadcn-studio (this skill) |

Never `npm install` into the host to make a check pass. A too-old Node fails
Vite/Tailwind boot later, so gate on the Vite floor (Node `20.19+`) up front,
not presence.

## Consent gate — stricter than mockups

This flow runs `npm ci` and a dev server. Before ANY write, ask via
`AskUserQuestion`, naming the RESOLVED artifacts for the branch actually taken:

> Stand up an interactive shadcn sandbox? Copies a pinned template to
> `<scratch>`, runs `npm ci` there (never your source tree), and starts
> `vite dev` on port 8124. The scratch dir is deleted after the pick.

`<scratch>` is resolved and shown, not a placeholder. Options: proceed / use the
static shell mockup instead / skip. Ask once per session.

## Provision — isolated, outside the work tree

1. Stale recovery first: if a prior scratch dir survives a crashed session,
   run the cleanup search-and-delete before starting.
2. Scratch location: OUTSIDE the work tree by default (the session scratchpad),
   so it can never dirty git. If the user insists on an in-repo path, add a
   `.git/info/exclude` entry at provision time — never edit tracked `.gitignore`,
   never assume `.taskmaster/` is ignored (it is not).
3. Copy the plugin's `template/` to the scratch dir and run one isolated
   `npm ci` (consider `--ignore-scripts`; the pinned lockfile is the
   supply-chain control, but lifecycle scripts still run with your privileges).
4. Start `vite dev` on the dedicated port `8124` (`strictPort:false` bumps if
   busy). Read the RESOLVED port from Vite's output — never assume 8124 was
   granted. Bind `127.0.0.1` only.

## Author the variants

Write `src/variants/VariantA.tsx…` as real shadcn JSX — content only — following
`ui-ux:shadcn-best-practices` (composition over props, Radix preserved), and the
deep-staging skill for the lane (design / creative / dataviz) and which states to
build. Fill `src/harness/stage.config.ts` with the stage lane and each variant's
label + a serves/trades/breaks rationale. Use realistic data ("Invoice #4821 — $1,240.00 —
overdue 12 days"), never lorem ipsum. `<VariantStage>` renders variants side by
side; its state toggle follows the lane (data lanes: empty/loading/error/
populated; creative: populated only) — do not restyle it per variant.

## Serve and reuse

- Hand over `http://127.0.0.1:<resolved-port>/` — studio's OWN harness only. Do
  not serve, unify, or retire another skill's artifacts or the `:8123` server.
- Reuse on later stages: probe `GET /__studio` for the marker `shadcn-studio`
  before reusing a port — a bare PID from `lsof` cannot tell studio's server
  from the user's own app on that port.
- Concurrent sessions get their own scratch subdir; never share one dir.

## Asking for the pick

`AskUserQuestion`, one option per variant plus its serves/trades/breaks rationale. Record the pick
as a SELF-CONTAINED note: the label plus a short description, or copy the chosen
variant's JSX OUT of the scratch dir BEFORE cleanup. Never store a path into the
scratch dir — cleanup deletes it and the reference would dangle.

## Cleanup — guaranteed, verified

A run that leaves a scratch tree behind is a failed run, whatever was picked.
Ordered:

1. Kill studio's OWN Vite server first (release file handles) — only if this
   flow started it, identified by the `/__studio` marker.
2. Delete the scratch dir (a full `node_modules`, not two files).
3. Verify by search that nothing remains; in a git host, `git status` is clean.
   In a non-git greenfield dir, verify by search alone (no `git status`).
4. On delete failure (locked files/permissions): retry once, then report the
   exact path and surface it — never silently claim success.

## Fallback — the decision still happens

Node absent or too old, `npm ci` fails, or consent declined → offer the taskmaster
`visual-decisions` shell mockup (when installed) and state exactly which check
failed and the version found. Leave no partial scratch. Never leave the decision
undecided because the interactive path was unavailable.

## Anti-patterns

- Writing into the host source tree — the sandbox is self-contained or it does
  not happen.
- Killing or reusing the `:8123` server, or any server this flow did not start.
- Reusing a port by PID without the `/__studio` marker probe.
- Recording a pick as a path into the to-be-deleted scratch dir.
- Standing up the dev server for a choice ASCII or the static shell can carry.
- Using the sandbox as the implementation starting point — the pick is recorded;
  the scratch dies.
