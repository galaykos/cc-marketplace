# Claude Desktop design surfaces vs this marketplace — 2026-09-22

**Question.** Claude Desktop offers five visual options — Slides, Design, Design in
codebase, Design System, Artifacts. What does each actually do, what does this
marketplace already ship in the same capacity for web/app development, and where
does a plugin of our own earn existence?

**Standing: `recorded`.** §1–6 are the study as written before any decision; every
proposal in §5 is sized against the README bar (a rule the model gets wrong from memory,
or a mechanism prose cannot replace) and the Admission law. §7 records what the user
decided the same day and what was built — read it before acting on §5.

**Method.** Four specialists ran in parallel — two web researchers (Slides+Artifacts;
Design/Design-in-codebase/Design System), the Claude Code docs guide, and a repo
explorer — plus direct reads of the primary docs, the CLI binary (2.1.278), the
official plugin marketplace cache and the claude.ai-synced skill directory on this
machine. Claims below carry a source; anything third-party-only is marked.

---

## 1. What each Desktop option is (sourced)

Timeline: Artifacts (2024, all plans, "over half a billion" made) → **Claude Design**
(Anthropic Labs, 2026-04-17, with its design-system store; June 17 update added
codebase import and `/design-sync`) → Claude Code `/design` artboards (w34, August) →
**Claude Docs and Claude Slides** (2026-09-16, the day Cowork folded into Claude:
"Claude Docs and Claude Slides are new today, and Claude Design now works inside your
conversations too"). Design, Slides and Docs are "in beta on paid plans"; Pro and Max
first, Enterprise admin-on; all share usage limits with Claude Code. Every one of them
is saved in the Artifacts tab, which is why the Desktop picker shows them side by side.

| Option | What it produces | Input | Mechanism | Export / handoff |
|---|---|---|---|---|
| **Slides** | **Claude Slides**, its own surface since 2026-09-16 ("Ask for a presentation, and Claude drafts the slides"; "edit directly, present straight from Claude, or download as PowerPoint or PDF"); the older Claude Design deck is "generated as interactive HTML rendered in the canvas" | Plain-language prompt, a Claude Doc ("turn a doc into a presentation"), uploads | Web-native deck at a shared link; org design system applied automatically; the mechanism (HTML→PPTX vs the `pptx` skill's `pptxgenjs`) is undocumented | PowerPoint, PDF, Google Slides; the Design-canvas deck also standalone HTML, .zip, Canva, **Hand off to Claude Code** |
| **Design** | "designs, prototypes, slides, one-pagers"; static mockups → "easily-shareable interactive prototypes" | Text, images, DOCX/PPTX/XLSX, or a codebase | Canvas beside chat: inline comments, direct text edits, "adjustment knobs to tweak spacing, color, and layout live"; drag/resize/align since June | PDF, PPTX, HTML, ~15 third-party targets (Vercel, v0, Lovable, Replit, Netlify, Miro, Canva…); **no Figma**; "Handoff to Claude Code (Send to local coding agent, Send to Claude Code Web)" as a bundle of "design files, chat, and a README" |
| **Design in codebase** | No Anthropic page uses this literal label. Closest: "Link a code repository so Claude understands your existing components, architecture, and styling patterns" (Import button: GitHub or local dir) and "Import a design into your codebase" | A repo | Claude Design reads the repo; `/design-sync` in Claude Code pushes a React component library up | The handoff bundle above |
| **Design System** | "a design system (UI kit)": colour palette, typography, components, layout patterns; org default for new projects; Settings › Design systems | Codebase (React library via `/design-sync`), brand uploads, decks/PDFs, assets | Extracted by Claude; edited by "Remix"; "checks its own output against your design system, and makes corrections before you see them" | Propagates to Slides and every new Design project |
| **Artifacts** | "a live, interactive web page that Claude Code publishes from your session to a private URL on claude.ai" | Any `.html`/`.md` the session writes | Built-in `Artifact` tool; versions; share within org or public; comments (Team/Enterprise) that reach the session live; MCP-connector calls at view time; file downloads; strict CSP, 16 MiB | Same gallery as claude.ai artifacts; `/artifacts` lists them; Compliance API |

Sources: anthropic.com/news/claude-design-anthropic-labs; claude.com/blog/cowork-is-now-claude;
support.claude.com articles 14604416 (Design), 14604397 (design system), 14604406 (admin),
9487310 (artifacts), 9547008 (sharing), 16923645 (Docs); academy.claude.com slides tutorial;
code.claude.com/docs/en/artifacts. No dedicated Claude Slides help article exists yet.

### 1a. The Claude Code side already exists — and is the part that matters here

Everything the Desktop app does for a repo has a host-owned counterpart **in the CLI
the user already runs**, verified on 2.1.278 on this machine:

| Host surface | What it is | Evidence |
|---|---|---|
| `/design <brief>` | "drafts the design as artboards on one canvas and publishes the canvas as a Design artifact"; edit in-browser, export PNG/PDF per artboard, then "tell Claude which option to implement". Research preview since v2.1.234 (w34); artifacts doc says v2.1.265+ | docs/en/artifacts, whats-new/2026-w34 |
| `/design sync\|login\|consent\|revoke\|import\|export\|status` | "Work with Claude Design (claude.ai/design) — create, import, export, sync, login". `import` = "Pull a Claude Design project into the working directory"; `export` = "Push the working directory into a new Claude Design project" | strings in the 2.1.278 binary |
| `/design-sync` skill | "Push a React design system to claude.ai/design. This runs a converter that bundles the real component code (from Storybook or a bare package) and uploads it." Discovery is heuristic with `.design-sync/config.json` overrides; a Storybook probe (`ts-morph`, `.design-sync/sb-reference`); generated previews in `.design-sync/.cache/previews/<Name>.tsx`; a `.render-check.json` self-check | binary; `DesignSync` tool schema |
| `DesignSync` tool | `list_projects / get_project / list_files / get_file / create_project / finalize_plan / write_files / delete_files / register_assets / report_validate` against claude.ai/design design-system projects. Cards come from a first-line `<!-- @dsCard group="…" -->` comment in each preview HTML, compiled into `_ds_manifest.json`; `register_assets` is the "legacy" path "for hand-authored projects without `@dsCard` markers" | tool schema loaded this session |
| `Artifact` tool | publishes `.html`/`.md`; **not loaded in this session** (no claude.ai login backing it — the docs say "the tool is not enabled for your session" in that case) | `ToolSearch select:Artifact` → no match |
| Built-in artifact design skill | "looks for an existing design system in your project before choosing its own … record them where Claude can find them, such as the project's CLAUDE.md or a theme file"; precedence: prompt > your design system > its own | docs/en/artifacts |
| Desktop app previews | `.claude/launch.json` (`runtimeExecutable`, `port`, `autoVerify` on by default: "takes screenshots, checks for errors, and confirms changes work") | docs/en/desktop |
| Synced Anthropic skills | `pptx`, `docx`, `xlsx`, `pdf`, `docs`, `theme-factory` (10 themes for "slides, docs, reportings, HTML landing pages"), `brand-guidelines` (Anthropic's own brand only), `web-artifacts-builder` (React+Tailwind+shadcn → one HTML), `skill-creator`, `morning`, `import-memory` | `~/.claude/skills/synced/*/` — the docs guide's reading that pptx/docx "do NOT auto-sync" is wrong on this machine; local evidence wins |
| Official plugins | `frontend-design` (anti-generic aesthetic prompt), `playground` (single-file HTML explorers incl. a `design-playground` template), `project-artifact` (tabbed status page published via `Artifact`) | `claude-plugins-official` cache |

Not in `github.com/anthropics/skills` today but Desktop-only: the Slides canvas
itself and the org Design System store. `canvas-design` (PNG/PDF art) is in the repo
and not synced here.

---

## 2. What this marketplace ships in the same capacity

Full inventory with paths, inputs, outputs and mechanism is in the explorer's report
(reproduced in condensed form). The shared substrate is **one local preview server**,
`plugins/taskmaster/skills/visual-decisions/assets/serve.py` on
`${PREVIEW_PORT:-8123}`, with reserved filenames per purpose (`current.html`,
`theme.html`, `walkthrough.html`, `diagram.html`, `api.html`, `modules.html`,
`compose.html`) and SSE reload.

| Desktop option | Coverage here | Where |
|---|---|---|
| **Slides** | **None.** Zero hits for slides/pptx/deck-as-output in any plugin | — |
| **Design** | **Strong, local-only, decision-scoped.** ASCII → shell HTML (`shell.html`, 8 starters, ~60 `vd-*` primitives, A/B/C frames, data-state and viewport toggles, gallery archive) → walkthrough; variants die at the pick | `taskmaster:visual-decisions`, `experience-walkthrough`, `craft-layer:sections`, `craft-layer:creative-direction` + `creative-director` |
| **Design in codebase** | **Strong on discipline, thin on rendering.** Multi-signal stack detection, registry-MCP lookups before naming a component, six per-library skills, a real worker; the real-component rung is a deleted `__design-preview__` scratch entry, Vite/Laravel only | `/ui-ux:build`, `visual-decisions/references/real-components.md`, `context-scout` `Theme tokens` table |
| **Design System** | **Strong on doctrine and values, zero on artifact.** Roles (`theming-system`) → scales (`design-tokens`) → values (`shadcn-theming`, `/ui-ux:theme` with live `theme.html`, writes `globals.css`/Tailwind/Sass/Astryx) → script gates (`contrast.mjs`, `divergence.mjs`). No extraction from a URL, no emitted token file, no component catalogue, no Storybook, no Figma | `plugins/ui-ux`, `plugins/craft-layer/template/craft-gates/` |
| **Artifacts** | **Inverted by design.** Two byte-identical `preview-guard.sh` PreToolUse hooks (taskmaster, ui-ux) intercept the host `Artifact` tool: reserved basenames or anything under the mockups docroot → `permissionDecision: "ask"` every time; `visual-decisions` lists "publishing the page as a remote artifact" as an anti-pattern. Screenshots exist only as `craft-layer` Playwright shots and `overseer` acceptance evidence | `plugins/*/hooks/preview-guard.sh`, `gates.spec.ts`, `overseer/.../acceptance.md` |

## 3. Decisions already on record that bind any proposal

- **A design plugin was retired on usage evidence 2026-09-14** (`marketplace-endgame-review-2026-09-14.md` §6): one real invocation of `/design-studio:*` across ten projects, zero registry-MCP calls, 793 always-on tokens, 140 KB of code, one MCP process per session. "Retire." Any proposal that re-creates a preview server, a component-registry MCP or a lookalike skin re-litigates that.
- **The craft-layer / `frontend-design` merge was killed** (`marketplace-necessity-review-2026-08-26.md` §8d; `official-plugins-gap-review-2026-09-02.md:51`): "two design doctrines in one session contradict on layout defaults." Installing the official `frontend-design` beside `craft-layer` is documented as an overlap, not a gap.
- **"Inventing a format — a JSON token-intent file nothing reads"** is a named anti-pattern in `craft-layer/skills/design-research`. That premise has changed: the host's artifact design skill now reads a design-system block in CLAUDE.md, and Claude Design reads the codebase. A token record now has two readers.
- **The four claws of this repo** (Proportionality, Honest limitation, Theater test, Admission) — a plugin that duplicates a host feature fails Admission; one whose only user is Team/Enterprise-with-login must say so.

## 4. Gap analysis — host-owned vs plugin-ownable

The single most important finding: **the mechanisms are host-owned.** Artboards
(`/design`), publishing (`Artifact`), the design-system store and its sync
(`DesignSync`), dev-server previews with auto-verify (`launch.json`), slide decks
(Claude Design + synced `pptx`). A marketplace plugin cannot ship an `Artifact`
tool, cannot reach claude.ai/design except through `DesignSync`, and re-implementing
any of them is design-studio again. What a plugin CAN own is the **seam** between
those host features and a real codebase — the place where the model, left to
memory, does the wrong thing.

| Seam | What the model gets wrong today | Host feature it plugs into | Ownable? |
|---|---|---|---|
| S1 Handoff intake | A Claude Design handoff bundle (design files + chat + README) lands in the repo and the model rebuilds it from the exported HTML/screenshot instead of the project's own components and tokens — the exact failure Anthropic's own copy warns about ("instead of starting over from a screenshot") | "Send to local coding agent" | **Yes** — nothing in the marketplace or the host reads a handoff bundle |
| S2 Design-system record | `/ui-ux:theme` writes CSS variables but no record the host's artifact skill or Claude Design reads; the built-in skill then "chooses its own" | artifacts doc precedence rule; Claude Design codebase import | **Yes, tiny** — emit the documented `## Design system` block on theme acceptance |
| S3 `/design-sync` for non-React stacks | `/design-sync` is "a React design system … from Storybook or a bare package". This marketplace's centre of gravity is Laravel/Inertia/Vue/Blade. The tool's `register_assets` path for "hand-authored projects without `@dsCard` markers" exists and nothing authors those previews | `DesignSync` hand-authored path | **Yes, but gated** — needs claude.ai login + design consent; Enterprise default-off |
| S4 Fidelity rung | `visual-decisions` ladder stops at shell HTML / scratch real components; `/design` artboards (editable, exportable, shareable) are a better mid rung when artifacts are available, and `Artifact` publish is the right way to put an accepted gallery page or walkthrough in front of a teammate — currently hook-blocked | `/design`, `Artifact` | **Yes** — a reference edit plus a hook tier change |
| S5 Slides | None — the host's synced `pptx` skill and Claude Design Slides already produce decks; a marketplace slides plugin has no rule the model gets wrong that they do not already carry | synced `pptx`, `theme-factory` | **No** (Admission fails) |
| S6 Discovery | `stack-scan`'s official-complements table (last verified 2026-09-02) does not know `/design`, `/design-sync`, `playground`, `project-artifact`, `theme-factory`, `web-artifacts-builder` exist, so plugin-scout cannot route a user to them | — | **Yes, tiny** — a doc row per feature |

## 5. Proposals, ranked

Sizes use the `approaches:estimation` classes. "Requires" names what the installer
must have; a proposal whose requirement is a paid plan says so up front.

| # | Proposal | Plugin | Size | Requires | Standing when shipped |
|---|---|---|---|---|---|
| P1 | **`handoff-intake` skill** (S1): detect a Claude Design handoff bundle (its README + design files), inventory screens, diff the bundle's palette/type against the repo's tokens (reuse `context-scout`'s `Theme tokens` extraction) into a drift table, then route each screen through `/ui-ux:build` with `Composition:` lines and forbid pasting exported HTML into the tree. Mechanism prose cannot replace: the token-drift diff script | `ui-ux` | M | a handoff bundle (Pro+) | drift script → gate; routing → agent-graded |
| P2 | **Design-system record on theme acceptance** (S2): `/ui-ux:theme` step "write tokens" also writes the documented `## Design system` block (colours, type, spacing/radius) to CLAUDE.md or `.claude/design-system.md`, so host artifacts, `/design` and Claude Design imports start from the accepted theme. Retire the "JSON nothing reads" anti-pattern line in `design-research` with a citation | `ui-ux`, `craft-layer` | S | nothing | recorded (the host reads it; no script of ours checks) |
| P3 | **`/design` and `Artifact` as fidelity rungs** (S4): `visual-decisions` ladder gains "artboards via `/design` when artifacts are available" between shell HTML and real components; `section-decisions` staging table routes to it; `preview-guard.sh` gets an explicit allow for `gallery/*.html` and `walkthrough.html` publish after a pick (WEAK tier, ask once) so an accepted decision can be shared and commented on. Twin hooks stay byte-identical (a `pc_*` check already asserts that) | `taskmaster`, `ui-ux`, `craft-layer` | S | claude.ai login for the rung; degrades to today's ladder without it | hook → gate; ladder → recorded |
| P4 | **`design-sync-prep` for Vue/Blade/Inertia** (S3): a script that inventories a non-React component library (Vue SFCs, Blade components), renders one static preview HTML per component with a first-line `@dsCard` marker via the project's own dev server, and hands the bundle to `DesignSync` (`finalize_plan` → `write_files`) — the hand-authored path the tool documents | `laravel` or `ui-ux` | L | claude.ai login, design consent, Team default-on / Enterprise admin-on | script → gate; upload → host-gated |
| P5 | **Official-complements rows** (S6): six rows naming `/design`, `/design-sync`, synced `pptx`/`theme-factory`/`web-artifacts-builder`, official `playground`/`project-artifact`, each with the marketplace surface it complements or overlaps (`playground` vs `visual-decisions`; `frontend-design` vs `craft-layer` already there) | `stack-scan` | S | nothing | recorded |
| — | **Slides plugin** | — | — | — | **Do not build** (S5) |
| — | **Preview server / registry MCP / design canvas of our own** | — | — | — | **Do not build** — retired 2026-09-14 on evidence |

Recommended order: P5 and P2 first (an afternoon, no plan requirement, both improve a
plugin someone installs), then P3, then P1. P4 only if a Laravel/Vue project actually
wants its kit in Claude Design — measure one request before spending L on it.

## 6. What this study did not do

- No web fetch of the Desktop app's own menu; the five labels came from the user. No
  Anthropic page groups "Design / Design in codebase / Design System" as one picker.
- `Artifact` and `/design` were not exercised: this session has no claude.ai-backed
  login, so the tool is absent. Every claim about them is from docs and the binary.
- `/design-sync` was not run against a repo; the `.design-sync/` layout is from strings
  in the 2.1.278 binary, not a run.
- Third-party claims that `/design-sync pull` writes `.claude/design-system/` with JSON
  tokens and a component manifest were **not** corroborated by any Anthropic source or
  the tool schema — treated as amplification of one unsourced post.
- The explorer read files only; none of `serve.py`, `theme-axis-check.py`,
  `contrast.mjs`, `divergence.mjs`, `gates.spec.ts` were executed in this pass.
- No usage evidence was gathered for any proposal. `scripts/turn-cost.sh --skills` is
  the retirement queue; P1–P4 should each earn a row there before a second version.

---

## 7. Decision and outcome — same day

The user read §4–5 and reaffirmed: **"we want our own solutions"**, and, on the
preview server, "creating our own preview server isn't viable?" — it is, and the repo
already had one. The concern in §3 (a design plugin was retired on usage evidence eight
days earlier) was stated once and the user's decision stands. Built on this branch as
**`plugins/design-kit` 0.1.0**, one leaf, five commands mirroring the Desktop picker:

| Desktop option | Command | Own mechanism |
|---|---|---|
| Slides | `/design-kit:slides` | `deck-build.py` outline → self-contained HTML deck; `deck-export.sh` PDF via a local Chromium-family browser, PPTX via consent-gated pptxgenjs |
| Design | `/design-kit:design` | `board-build.py` → artboard canvas (2–4 directions, editable text, knobs, pick + copy-as-prompt); `board-export.sh` PNG/PDF |
| Design in codebase | `/design-kit:in-codebase` | `codebase-scaffold.sh` marked scratch entry on the project's own dev server (Vite/Next/Nuxt/Laravel), `codebase-cleanup.sh --verify`; `handoff-drift.py` (P1 from §5, folded in) |
| Design System | `/design-kit:system` | `system-extract.py` repo/URL/brand → `design-system/tokens.json` (DTCG-shaped, sourced), `DESIGN-SYSTEM.md` (P2 from §5, folded in), `@dsCard` UI kit |
| Artifacts | `/design-kit:artifact` | `artifact-bundle.py` single-file, versioned; `artifact-publish.sh` orphan pages branch in a scratch worktree, push on a second yes |
| (substrate) | `scripts/serve.py` | own preview server: gallery, SSE reload, `/_index.json`, `--lan`; port 8124 |

Every script has a harness under `scripts/__tests__/` (CI runs the glob). Built by five
forked specialists in parallel on disjoint files, merged by hand; each returned its
untested list, carried into the plugin README's per-command limits.

Not done from §5: P3 (host `/design` as a fidelity rung; preview-guard tier change) and
P5 (official-complements rows) — both are edits to other plugins and were out of the
"own solutions" scope the user set. P4 is superseded: `/design-kit:system` emits the
`@dsCard`-marked cards the host's sync indexes, for any stack.

Standing of this section: `recorded`. The Measured section of the plugin README names
the retirement queue it must appear in before 0.2.0.
