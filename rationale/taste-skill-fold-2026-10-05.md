# taste-skill fold — 2026-10-05

**Standing: `recorded`.** A dated record; nothing reads it back. Every rule it names ships
inside a plugin; this file holds only the per-skill provenance, the conflicts, the
measurements and the design history an installer never needs.

Source: [leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill) at commit `ce26fc25`
(2026-09-26), MIT, © 2026 Leonxlnx, read 2026-10-05. Three skills were copied unmodified into the
gitignored `taskmaster-docs/upstream/taste-skill-ce26fc25/` (`skills/taste-skill/SKILL.md` — v2,
named `design-taste-frontend` — `redesign-skill`, `output-skill`) with the LICENSE; nothing was
pasted into a plugin. Upstream's figures ("the #1 violated rule in production tests", "20 words",
"`pt-24`") are upstream's and unverified here. Released as marketplace 0.121.0: code-review 0.30.0,
craft-layer 0.56.0, ui-ux 0.29.0, ui-libraries 0.2.0, skill-router 0.23.1, stack-scan 0.11.3.

## What was asked

The user (2026-10-05) picked four pieces to fold — the elision-comment hook, redesign
preservation, the missing tells plus layout checks, official design systems — and accepted the
analysis that skips the rest and keeps the marketplace's side of every conflict. Standing rule for
the hook: a miss is acceptable, a false refusal is not.

## Every upstream skill → destination or skip reason

| upstream | went to | or skipped because |
|---|---|---|
| `output-skill` — the banned placeholder patterns in code blocks | code-review `hooks/scan.sh`: the elision deny and warning | — its prose and structural-shortcut bans were not selected in the brief, which picked the comment hook |
| `redesign-skill` — mode, audit, upgrade techniques, fix priority | craft-layer `creative-direction/references/redesign-preservation.md` (modes, read-before-touching, levers in order) | — its per-area design-audit checklists were not selected in the brief |
| `taste-skill` §11 redesign protocol | the same reference, `/craft-layer:craft` step 0 and `preserve.json`, `craft-reviewer`'s preservation row; the never-change rule in `/ui-ux:build` and `ui-ux-engineer` | — design-kit untouched (user, round 1) |
| `taste-skill` §9 AI tells | nine rows in craft-layer `sameness-fingerprint.md`; "Step 1 / Phase 01" merged into the `01 / 02 / 03` row; the worded scroll cue as a copy-lexicon row | tells already listed there were not added twice; §9.G is a conflict (below) |
| `taste-skill` §4.7 layout discipline, §4.11 page theme lock | craft-layer: `gates.spec.ts` measures five values into `layout-floors.json`; `craft-reviewer` judges seven floors | upstream calls them hard rules; here they are judged against the concept's argument and never fail the audit alone (user, round 1). The other §4.7 rules (subtext length, hero padding cap, hero stack, nav height, eyebrow quota, split-header ban, bento backgrounds) were not selected in the brief |
| `taste-skill` §2.A brief → design system | ui-libraries `component-libraries` §1 and five library-map rows; skill-router's import row | narrowed: only for the organisation's OWN service, and a lookalike brief never installs a restricted system. Fluent and Primer already had rows. Material, Bootstrap, Radix Themes, shadcn and Tailwind as brief-to-library picks are not taken — the scope is the organisation's own service (spec ledger #20), and `component-libraries` already builds in the library the project has |
| `taste-skill` §0 design read, §1/§7 the three dials | — | craft-layer's archetype dial-set and offer contract cover them (D1) |
| `taste-skill` §12 block library, the design-system appendices | — | non-goals (spec) |
| `taste-skill` §2.B, §3, §4.1–4.6, §4.8–4.10, §5, §6, §8, §10 | — | outside the four pieces the user picked; not reviewed for gaps here |
| the three style packs (minimalist, brutalist, soft) | — | a style catalog, which `creative-direction` forbids |
| imagegen-frontend-web, imagegen-frontend-mobile, image-to-code, brandkit | — | Claude Code generates no images |
| stitch-skill | — | `design-kit:system` covers it |
| gpt-tasteskill, taste-skill-v1 | — | by their names, other versions of `taste-skill`; skipped with the rest (D1). Names as recorded in the brief; not opened |

## Conflicts kept on the marketplace's side (nothing imported)

- **Custom cursors.** Upstream §9.A bans them; craft-layer's `interaction-fx` builds one when a
  bespoke pointer signature is genuinely the brand.
- **"Never pure black, use zinc-950."** Upstream §8.B/§9.A; craft-layer's fingerprint lists tinted
  near-black (`#0B0B0B`, `#111`) standing in for black as a tell.
- **A total em-dash ban on page copy.** Upstream §9.G, unsourced; craft-layer flags only labels
  shaped `WORD — fragment`.
- **Phosphor over Lucide.** Upstream §3.C/§9.E ranks icon sets; that swaps one default for another.

## The elision measurement (`evidence/elision-measure.txt`, final grammar)

Quoted, not rounded: `corpus-owner: files=14584 matches=3 genuine=3 false-positives=0`;
`corpus-system: files=1992 matches=0 genuine=0 false-positives=0`;
`replay: pairs=4758 denies=0 denies-unexplained=0`; `ellipsis-only: owner=2 system=8 (warn only;
4 and 15 before doc-comment lines stopped counting)`. Grammar checksum 3617991351 over `scan.sh`
file cksum 3919806934, after the phrase-then-filler rule (below). The one genuine system match before
that rule — a committed `// ... (rest of the file remains the same until …) ...` placeholder in
Homebrew sbcl 2.6.9 `src/runtime/arm64-win32-os.c` — is now missed, the rule's measured cost; the
three owner matches stay. The
replay drivers were rebuilt from the method lines for the final run (80 repos, 4,758 pairs, against
the earlier 85 and 4,783). Each replay sent the newest 100 governed-file modifications per
repository (the earlier run: 4,828 listed, 45 skipped as over 2 MB or holding a
5,000-character line) as `Write`s over their predecessors; a synthetic positive control was
denied. A separate review replayed 13,182 `Edit`s and 5,326 `Write`s from 69 repositories'
transcripts with 0 allow → deny under default settings, on the grammar before the last three
tightenings (an unquoted ellipsis at the start or end of the body; doc-comment lines and closing
ellipses; a listed phrase first and only filler after it), and they only removed matches.

Timing (`evidence/elision-timing.txt`, master `e50113f3` vs the build with `scan.sh` file cksum
3895726106 — the final phrase-then-filler rule was not re-timed — median of 20, macOS
bash 3.2.57 + BSD awk): a Bash call that writes nothing 19 → 19 ms (+1 ms); `PostToolUse`
`Write` with no marker 43 → 64 ms (+22 ms); short `Write` over a 1 MiB plain `.ts` 42 → 297 ms
(+255 ms); full-file `Write` 322 → 671 ms (+349 ms); `Edit` on it 43 → 812 ms (+768 ms); short
`Write` over a 1 MiB backtick-dense `.ts` 44 → 786 ms (+742 ms); full-file 252 → 1,633 ms
(+1,381 ms), the worst case measured. Not timed: an `Edit` on a backtick-dense 1 MiB file.

## How the Edit lane got its rule

Each step was forced by a false refusal a review reproduced (the run's reviews, kept in
`taskmaster-docs/`, untracked):

1. **old/new only.** An `Edit` was judged on `old_string` against `new_string`. Review: an `Edit`
   whose `new_string` starts inside a string the unchanged file opened (shell `echo done'`, a TS
   template literal, a Python triple quote) read the string's text as a comment and was denied.
2. **whole file.** The edits were applied to the disk file and the two whole files compared, so
   string state came from the real file. Re-review: a `/\/*$/` regex read as an opening block
   comment exposed an existing placeholder-shaped line inside a template literal, and an `Edit`
   elsewhere in the file was denied; master allowed it.
3. **agreement.** Deny only when both comparisons find an added placeholder; each one's false
   refusal is the other's allow. Cost, accepted under the standing rule: an `Edit` whose
   `new_string` opens by closing a template literal and then adds a placeholder is a stated miss.
4. **code loss.** Review of step 3: every false refusal reproduced was a pure addition — a
   placeholder-shaped line inside a misread string, nothing removed. So a write over an existing
   file is denied only when a non-blank replaced line is also gone; this does not depend on the
   string tracker. Two refusals remain pinned as stated (a misread string, prose an ellipsis opens
   with a listed phrase), each only when a line is removed; neither occurred in the samples.

The grammar then tightened twice on the transcript replay's findings: an ellipsis counts only
unquoted at the start or end of the comment body (its 20 elision denies were all a quoted or
described ellipsis, each already a comment deny on master), doc-comment lines never count, and a
closing ellipsis counts only after a code noun. The fresh pre-merge reviews (Opus and Fable)
then reproduced a TODO with a closing ellipsis after a code noun (`// TODO: handle the remaining
cases...`) refused while a line changed, so the phrase had to START the body and the body hold at
most six words. Re-review: short prose starting with a phrase (`// Other fields are omitted...`,
`// ... remaining cases return null`) was still refused, so the cap gave way to the final rule —
after the listed phrase only filler may follow (`unchanged`, `remain(s) the same`, `remain(s)
unchanged`, `goes here`, …; the README lists it), with every ellipsis, bracket, `,`, `;` and `:` set aside, which also brings
back the glued `// ...existing code...`. One stated refusal remains: placeholder-shaped text
inside a string the tracker misreads, with a line removed.

## Design-system facts, verified 2026-10-05 against npm and the official docs

- `govuk-frontend` 6.5.1, MIT (docs OGL 3.0). The service manual: a site on its three domain forms
  (`gov.uk/myservice`, `myservice.service.gov.uk`, `myblog.blog.gov.uk`) must look like GOV.UK;
  any other may use the patterns but not the crown or logotype, GDS Transport, the brand colours,
  or a suggestion that it is an official UK government site.
- `@uswds/uswds` 3.14.0 (`uswds` is the 2.x name). Banner guidance: "Do NOT use the banner on
  non-government domains such as a .com or .org."
- `@shopify/polaris` 13.9.5 is deprecated in favour of Polaris web components, loaded from
  `https://cdn.shopify.com/shopifycloud/polaris.js` (HTTP 200 that day); types
  `@shopify/polaris-types` 1.1.0. The use restriction is quoted from the package's LICENSE.md, and
  App Home's definition from the live shopify.dev page (a summarising fetch had paraphrased it).
- `@carbon/react` 1.117.0, `@carbon/styles` 1.116.0, `@carbon/web-components` 2.64.0 — Apache-2.0,
  no use restriction found.
- `@atlaskit/tokens` 20.2.0, `@atlaskit/primitives` 22.5.4, `@atlaskit/button` 25.4.4 — npm
  metadata Apache-2.0, used under the Atlassian Design System License (atlassian.design/license).
  Forge UI Kit apps use `@forge/react`; Custom UI uses `@atlaskit/*`. The Connect → `@atlaskit/*`
  pairing in the map row was not confirmed against Atlassian's docs. `@atlaskit/pragmatic-drag-and-drop`
  is a general-purpose library, not the design system, and is excluded from the rule and the route.

## What stays unmeasured

No eval with a control arm measures whether any folded rule changes what the model writes, builds
or installs. The layout-floor fixture proof runs only where a local Playwright Chromium launches;
CI SKIPs it. The preservation and floor rows are agent-graded.
