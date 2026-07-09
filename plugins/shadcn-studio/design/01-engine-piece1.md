# shadcn-studio — Engine Design (Piece 1)

- **Date:** 2026-07-09
- **Status:** Draft v2 — red-teamed (3 lenses), pending user approval
- **Slug:** shadcn-studio-engine
- **Scope:** Piece 1 of 5 (the enabling interactive-demo engine, and ONLY that). Deferred to their own cycles: Piece 2 brainstorm always-on doctrine · Piece 3 visual-decisions **lanes + depth** (design/creative/dataviz, multi-state, charts) · Piece 4 durable visual contract into spec/cards · Piece 5 question/output quality. A red-team pass moved several things OUT of this doc into those pieces — see "What the red-team changed".

## Problem

A 6-agent survey of the taskmaster suite converged on seven gaps between what taskmaster does today and an always-on staging area covering design **and** creative options with real depth and a live interactive demo:

1. **Not always-on** — mockups are triple-gated (brainstorm fires visuals only "when genuinely visual"; visual-decisions' consent gate allows "No mockups → dormant"; context-scout can return Visual surface = None).
2. **No creative lane** — visual-decisions bans text-native/creative options ("a mockup of a sentence is theater").
3. **No data-viz** — only JSON "data shapes"; the shell ships KPI tiles but no chart primitive. (Note: a `dataviz` skill exists as an ambient host skill but is **not** a plugin in this marketplace — see risks.)
4. **Shallow doctrine** — "at most 3 variants, one axis, one-line tradeoff, die at the pick."
5. **Static, not interactive** — the "live" server is `python3 -m http.server` over static shell HTML. The one real-component tier (`design-preview`) is Vite+React-project-only, so greenfield-blind and unreachable from brainstorm.
6. **Theming already held constant** — the one existing alignment; preserve it.
7. **Visual picks get no binding contract** — data does (erd → binding `## Data Model`); visual/creative picks die at the pick.

**This piece addresses gap 5 only** — the interactive vehicle. Gaps 1–4, 7 are Pieces 2–5.

## Feasibility framing (corrected)

`design-preview` is a **prose-only** skill (no code/template): it assumes the host is already a Vite+React app, **reuses the host's own dev server**, writes 2 scratch files, and **explicitly bans `npm install`**. So what shadcn-studio reuses from it is the **consent + verified-cleanup discipline (a prose pattern)** — not a provisioning mechanism. The provisioning/serving engine (vendored template, isolated `npm ci`, owning its own server, cross-OS install, deleting a full `node_modules`, cleanup guarantees) is **net-new and is the bulk of the work**, not a 20% add-on. No code is inherited.

## Goal

Ship a new plugin, **shadcn-studio**, that stands up a live, interactive shadcn sandbox **on demand** so a session can render real, interactive, agent-authored component variants — even greenfield (empty dir, or a non-React stack).

The engine renders **arbitrary agent-authored JSX**. It is therefore already **lane-agnostic**: a "design" variant (differing layout) and a "creative" variant (differing copy/concept) are both just JSX and need no special engine support. Formal lanes and depth are Piece 3; the engine does not distinguish them.

## Non-goals

- **Theming / color decisions** — the sandbox uses shadcn default neutral tokens; color is never a decision axis.
- **Implementation start** — staged variants die at the pick; the feature is built from the spec.
- **Lanes / depth / charts** — the design/creative/dataviz taxonomy, the multi-state depth matrix, and Recharts data-viz are **Piece 3**, not the engine.
- **One-URL pipeline unification** — serving visual-decisions/erd/walkthrough artifacts under the Vite origin, and retiring the python `:8123` server, is **cross-skill integration deferred to a later piece**. Piece 1 serves only its own harness at its own port and **never touches another skill's server or files**.
- **Host projects that are already runnable Vite+React** — defer to `design-preview:real-preview` (renders the project's own components, zero install).
- **Auto-invocation from brainstorm** — that is Piece 2. Piece 1 is invoked explicitly (`/shadcn-studio:stage`).

## Chosen approach

A **new sibling plugin** that ships a pinned, self-contained shadcn + Vite (Tailwind v4, CSS-first) template as *source* (never `node_modules`), materializes it into an isolated scratch dir **outside the work tree** on first use via one `npm ci`, and renders agent-authored real-JSX variants side-by-side in a shipped `<VariantStage>` harness on its **own** Vite dev server.

### Alternatives rejected

| Decision | Chosen | Rejected | Why |
|---|---|---|---|
| Engine home | New sibling plugin | Extend `design-preview` | Keeps design-preview single-purpose; avoids one skill doing two jobs. |
| Engine home | Local Vite dev server | Artifact-hosted bundle | Artifact CSP blocks CDNs → must pre-bundle; no HMR. Live dev server gives real HMR. |
| Provisioning | Vendor template source + `npm ci` | Commit `node_modules` | Committed native binaries are cross-OS brittle, huge, rot. |
| Provisioning | Pinned vendored components; registry at build-time | shadcn registry/MCP at stage-time | Per-component network mid-session, non-reproducible, slower. |
| Authoring | Agent real JSX + harness | Manifest DSL / slot templates only | A DSL/template caps depth → recreates thin-options. Real JSX = max depth. |
| Server | Studio's own server, own port | One-URL unification in Piece 1 | Unification is cross-skill, violates the cloned "never kill a server you didn't start" rule, and rests on unproven Vite config. Deferred. |

## Architecture / component map

```
plugins/shadcn-studio/
  .claude-plugin/plugin.json
  README.md
  commands/stage.md            # /shadcn-studio:stage <decision>
  skills/studio/SKILL.md       # stage lifecycle, authoring contract, consent, cleanup
  template/                    # vendored, pinned, SOURCE ONLY (no node_modules)
    package.json               # pinned: vite, @vitejs/plugin-react, @tailwindcss/vite, tailwindcss v4,
    package-lock.json          #   @radix-ui/react-dialog, lucide-react  (NO recharts in Piece 1)
    vite.config.ts             # react + @tailwindcss/vite; server.port=8124 strictPort:false;
                              #   server.host='127.0.0.1'; server.fs.allow=[scratch root only]
    index.html
    src/
      index.css                # @import "tailwindcss"; @theme { default neutral tokens light+dark }
      components/ui/*.tsx       # ~5 vendored shadcn primitives: button, card, table, dialog, input
      lib/                      # cn(), realistic-data fixtures
      harness/
        VariantStage.tsx        # side-by-side compare; per-variant label + one-line tradeoff;
                               #   minimal populated<->empty state toggle; marker route /__studio
        stage.config.ts         # per-stage: variant labels + tradeoff lines (NO lane field)
      variants/                 # AGENT WRITES HERE: VariantA.tsx, VariantB.tsx…
```

There is **no** `tailwind.config.js` / PostCSS pipeline (Tailwind v4 is CSS-first via `@tailwindcss/vite` + `@theme`), and `components.json` carries `tailwind.config: ""`. Vendored primitives are the **v4 (CSS-var) variants**.

Scratch (runtime) lives **outside the work tree by default** so it can never dirty git:

```
<session scratchpad>/shadcn-studio/<session-id>/   # default; never in host repo
  <copy of template/> + node_modules/ (from npm ci) + src/variants/*.tsx
```

If a user insists on an in-repo scratch, provisioning writes a `.git/info/exclude` entry (untracked, non-invasive) — it never edits the tracked `.gitignore` and never assumes `.taskmaster/` is ignored (it is not in this repo; the convention is `.claude/taskmaster/`).

### The `<VariantStage>` harness (lean)

- **One presentation mode:** side-by-side `compare` (proven sufficient by design-preview). No tabs mode.
- **Per-variant:** a label + a **one-line tradeoff** (matches the sibling; richer rationale is Piece 5).
- **Minimal state toggle:** `populated ↔ empty` only — proves live state re-render works. The four-state matrix (loading/error, skeleton) is Piece 3 depth.
- **Marker route** `/__studio` returns a known token so a server can be positively identified as shadcn-studio's before any reuse.
- No motion / reduced-motion handling in Piece 1 (no animated variants in scope).

## Data flow — the stage lifecycle

1. **Detect host.** Runnable Vite+React app (vite config + react plugin + dev script + components present)? → hand off to `design-preview:real-preview` (renders their own components; covers the "Vite+React with or without shadcn" cases). Else (empty/greenfield dir, or non-React stack) → shadcn-studio. Also gate on **Node ≥ 20.19** (the Vite 8 floor); too-old/absent → straight to static-shell fallback, before any write.
2. **Consent** (clone design-preview's discipline). Render and name **the resolved scratch path actually taken** (scratchpad vs in-repo), the `npm ci`/`vite dev` commands, and the port. No write before consent.
3. **Provision (first stage only).** Stale-scratch recovery first (remove any leftover from a crashed session). Copy `template/` → scratch; run one isolated `npm ci` (consider `--ignore-scripts`; see security). Start `vite dev` on the dedicated port. Reuse on later stages via the `/__studio` marker probe — never bare PID. Concurrent sessions get their own `<session-id>` scratch subdir (no clobber).
4. **Author variants.** Agent (following `ui-ux:shadcn-best-practices`) writes `src/variants/VariantA.tsx…` as real shadcn JSX, and fills `stage.config.ts` (labels + one-line tradeoffs).
5. **Serve.** Vite renders the harness at `http://127.0.0.1:<resolved-port>/` — **studio's own harness only**. It does not serve or unify other skills' artifacts and does not kill the `:8123` server.
6. **Iterate.** User views live; edits reflect via HMR; "mix of A and C" → one merged variant, one re-serve.
7. **Pick.** Record the pick as a **self-contained inline note** — the chosen variant's label + a short description (or copy the chosen JSX out of scratch **before** cleanup). Never store a path into the scratch dir (it gets deleted). Turning the record into a durable, enforced spec contract is Piece 4.
8. **Cleanup (guaranteed, verified).** Ordered: kill studio's own Vite server (release file handles) → delete the scratch dir → verify by search that nothing remains. On delete failure (locked files/permissions): retry once, then report the exact path and surface it — never silently claim success. Kill the Vite server **only if shadcn-studio started it**; never touch `:8123`.

## Skill activations wired

- **`ui-ux:shadcn-best-practices`** — composition-over-props / Radix-preservation rules when authoring variants. (In-marketplace, safe to depend on.)
- **`ui-ux:shadcn-theming`** — used once at **template-build time** to install a coherent default neutral token set; color stays out of the decision axes.
- **`dataviz`** — **deferred to Piece 3** (and it is an ambient host skill, not a marketplace plugin, so it will be an *optional* activation that degrades gracefully, or its guidance gets vendored into shadcn-studio's own skill). Not a Piece-1 dependency.

## Error handling / fallback

- **Node absent or below 20.19, or `npm ci` fails (incl. native-binary failure)** → degrade to the existing static shell mockup; state the reason and the version found; leave no partial scratch.
- **Port busy** → `lsof -ti :<port>`; reuse only if the `/__studio` marker confirms it is studio's; else Vite `strictPort:false` bumps and we read the resolved port from Vite output.
- **Broken template cache / consent declined** → static-shell (or ASCII) fallback; surface the cache path.

## Security posture

- `server.host = '127.0.0.1'` (never `0.0.0.0`) — the dev server is not exposed on the network.
- `server.fs.allow` restricted to the scratch root; nothing outside it is reachable via `/@fs/`.
- **`npm ci` runs dependency lifecycle scripts with the user's privileges** — "isolated" means directory-isolated, not privilege-isolated. The pinned lockfile is the supply-chain control; use `--ignore-scripts` if the vendored template needs no build-time scripts, and state that residual script-execution risk remains.
- The committed lockfile must record **all-platform optional binaries** (esbuild/rollup/tailwind-oxide/lightningcss); refresh it only with a recent npm, and add a CI check that runs a cross-OS `npm ci` from it so a bad regeneration is caught before shipping.

## Success criteria (verifiable)

1. **Greenfield interactivity.** In an empty non-React dir, after consent, `/shadcn-studio:stage` brings up ≥2 real interactive shadcn variants (working table sort/filter + dialog open/close) at studio's own URL. **Infra bring-up** (npm ci + vite boot, *excluding* agent variant-authoring time): warm ~1–2s, fast-net cold <10s; honest slow/corporate-net worst case 60–180s (static-shell degrade covers slow provisioning).
2. **Live re-render.** A variant toggles `populated ↔ empty` and re-renders live.
3. **Isolation.** No file is written into the host tree; scratch is outside the work tree by default; consent named the resolved path before any write.
4. **Cleanup.** After the pick: studio's Vite server is killed, the scratch dir is removed and verified gone; in a git host, `git status` is clean; a delete failure retries then reports (never a silent pass). In a non-git greenfield dir, cleanup is verified by search (no `git status` dependency).
5. **Fallback.** With node forced absent/too-old, the flow degrades to the static shell with a clear message and no partial scratch — never a hard error.
6. **Handoff.** A runnable Vite+React host causes deferral to `design-preview:real-preview`; studio does not run.

## What the red-team changed (v1 → v2)

- **Cut dataviz/Recharts from Piece 1** — `dataviz` is not a marketplace plugin; charts are Piece 3 and drag the heaviest dep. Removed the lane and its success criterion.
- **Cut the lane taxonomy** — design/creative/dataviz is Piece 3 by name; the engine is lane-agnostic (still renders both design and creative variants natively).
- **Dropped one-URL unification / killing `:8123`** — cross-skill integration that violated the cloned "never kill a server you didn't start" rule; deferred. Studio serves only its own harness.
- **Fixed scratch location + gitignore** — `.taskmaster/` is not ignored here; scratch now defaults **outside the work tree**, with `.git/info/exclude` if in-repo.
- **Trimmed the harness** — one presentation mode, one-line tradeoff, minimal populated↔empty toggle; dropped tabs/4-state/rationale-panel/reduced-motion into later pieces. Vendored set 11 → ~5.
- **Corrected feasibility framing** — engine is net-new, not "20%"; only the discipline is reused.
- **Hardened lifecycle** — server identity via marker route (not PID), concurrency subdirs, ordered cleanup + delete-failure path + stale recovery, Node-version gate, Tailwind-v4 CSS-first shape, recharts-floor moot (removed), 127.0.0.1 + fs.allow, npm-ci script-execution note, cross-OS lockfile CI check.

## Open risks (residual)

- Keeping the vendored template current without rot (maintainer refresh cadence + the cross-OS `npm ci` CI check).
- Whether `--ignore-scripts` is safe for the exact pinned dep set (verify at build time).
- **Stack currency:** the template tracks `create-vite` defaults — as built it is Vite 8 (Rolldown, not Rollup/esbuild), TypeScript 6, React 19.2, oxlint. Verified working and lockfile-pinned, and the native matrix is captured under `@rolldown/binding-*` / `@tailwindcss/oxide-*` / `lightningcss-*` (11–15 platforms). Two implications: the Node floor is **20.19+** (not 18), and several brand-new majors raise the refresh surface. A more conservative pin (Vite 6/7) would widen Node compat at the cost of staleness — revisit if Node-18 hosts must be supported.
- `button` omits `asChild`/`@radix-ui/react-slot` to honor the minimal dep set; the dialog is driven by controlled `open` state instead. Fine for the sandbox; note it if a variant ever needs Slot composition.
