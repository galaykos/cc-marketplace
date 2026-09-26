# web-dev

Web development in one plugin: a **web-developer** worker for routing, REST/API
integration, forms, state management, and SSR/CSR decisions; a **frontend-reviewer**
that audits component and view logic; and three version-pinned stack skills —
**Next.js**, **React Native** (with the Expo inversions), and **Vite**. Review runs
through `/code-review:review`, the fan-in that detects the stack from the lockfile and
loads every matching skill in one pass (the plugin's own review entry was
retired on 2026-09-14 — it was a second name for that pass).

Laravel keeps its own plugin and Inertia lives there — a PHP-side pairing — and the
worker and reviewer defer to it when installed. Plain JavaScript and TypeScript
need no stack skill — that shape measured zero against a blind control
(`rationale/measured-zero-shapes.md`), which is why there is none here.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install web-dev@cc-plugins-marketplace
```

## Review

```bash
/code-review:review app/products/page.tsx app/actions/checkout.ts
/code-review:review vite.config.ts
/code-review:review                    # reviews the current diff
```

`/code-review:review` (the code-review plugin) detects Next.js / React Native / Vite
from the manifests, loads every matching skill here, and reviews the scope pinned to
the installed versions — severity-sorted one-line findings with fixes. On an apply pick
it dispatches that list down its **own** static chain (`task-runner:task-executor` if
installed, else inline), not to `web-developer`: code-review ships a reviewer and no
worker of its own, and its chain is stack-agnostic by design. Dispatch `web-developer`
directly for the implementation half. The skills also fire on their own while editing
when `skill-router` is installed.

## Skills

| Skill | Reach for it when |
|---|---|
| `nextjs-best-practices` | App Router work — server/client boundaries, the opt-in caching model (`fetch`, `revalidate`, tags, `use cache` behind `cacheComponents`), server actions as public endpoints, route handlers, streaming, metadata, `next/image` / `next/font`; version leverage 14 → 15 → 16 |
| `react-native-best-practices` | Screens and lists — FlatList/FlashList virtualization, typed and shallow navigation, `Platform.select` and file splits, native-driver animation, image sizing, JS-to-native crossings; New Architecture gating from 0.76 to 0.82 |
| `vite-best-practices` | `vite.config.*` and the build layer — `VITE_` env security, `optimizeDeps`, dynamic `import()` and `manualChunks`, `base` for sub-path deploys, `server.proxy`, `define` stringify traps, SSR, library mode; Node floors and defaults across Vite 5 → 8 |

Every skill pins its advice to the version in the lockfile, not the version the
model remembers: caching flipped between Next 14 and 15, the New Architecture became
the only option at RN 0.82, and Vite 7 raised the default `build.target`. With
`skill-router` installed the skills load on their own as matching files are edited.

### Expo / EAS

`skills/react-native-best-practices/references/expo.md` carries only the Expo facts
whose standard remediation has **inverted** — it is deliberately not a second
best-practices body:

- From SDK 55 the New Architecture is always on, so `newArchEnabled: false` is a
  silently accepted no-op rather than the fix it was in 2024/2025.
- `expo install` resolves against the SDK's compatibility matrix; `npm install` does
  not, and the failure surfaces later as a native crash.
- Under CNG, `expo prebuild --clean` overwrites hand edits to `ios/`/`android/` —
  native changes belong in a config plugin.
- An EAS Update published against a mismatched `runtimeVersion` is never delivered,
  with no error anywhere.

The `/code-review:review` fan-in reads it when `expo` is in the manifest, and `skill-router` routes
the skill on `app.config.*` and `eas.json` edits in an Expo project.

## Agents

- **web-developer** (worker, can edit) — implements general web work end to end when
  no single framework plugin owns the task: detects the stack from manifests and entry
  files, plans the smallest file-level change, implements it, and verifies with the
  project's own tests/linter/build. Applies a cross-cutting checklist: routing, REST
  error/timeout handling, form validation + CSRF, server-vs-client state, SSR/CSR
  trade-off, and an accessibility baseline.
- **frontend-reviewer** (read-only) — after component or view code changes, detects
  the framework, loads every matching skill, and checks state/effects, list keys, data
  fetching, TS types, and vite config. Returns severity-ranked `path:line` findings;
  never edits.

The worker recommends `/code-review:review` after implementing. The reviewer
preloads ui-ux's `a11y-audit` skill through the host's `skills:` frontmatter
(`skills: [ui-ux:a11y-audit]`). That adds a 7,140-byte body, about 1.8k tokens at 4
bytes/token (about 2.4k at 3), to every spawn. The reviewer flags the rules that skill
lists in the same review, for example focus returning to a dialog's trigger on close,
or a typeless button inside a form. It hands only a full WCAG audit to `/ui-ux:audit`,
and design-system concerns to ui-ux's reviewer. With ui-ux not installed, the host
skips the preload without an error (measured on CLI 2.1.282), and the reviewer runs
without those rules.

## Model tiers — why the reviewer is floored

`frontend-reviewer` pins `model: opus` as a **floor** (row in
`task-runner:delegation-contracts` `references/role-floors.md`): dispatch runs it at
`max(session model, opus)`. In an Opus or Fable session that changes nothing. In a
Sonnet session the verdict is still produced by an Opus-class judge, which is the
mechanism this marketplace uses to keep review quality constant while the session
model varies. The worker stays `inherit`: implementation tracks the session, judgment
does not drop below it.

The skills carry the same split in prose. Everything marked **All models** is a fact
or a boundary no tier may skip; the short **Compensation (worker-tier)** blocks are the
procedure a Sonnet-class session follows in full and a Fable-class session may compress
once the skip-clause holds. Standing: **recorded** — no script reads the markers
(`.claude/skills/authoring-skills/references/model-tier-scoping.md` in the marketplace repository).

## Pairs well with

- **laravel** — the PHP side, and the home of `inertia-best-practices`, which both agents load when installed
- **ui-ux** — visual and design-system review the frontend-reviewer defers to
- **ui-ux** also carries `/ui-ux:audit`, the full WCAG pass; the agents only enforce a semantic baseline
- **resilience** — `/resilience:review --concern performance` for bundle size and Core Web Vitals beyond the framework defaults
- **stack-scan** — supplies the locked versions the advice pins against

## Evals

`evals/` holds control-arm probes from the 2026-09-25 design-capability corpus
(`rationale/2026-09-25-design-capability-corpus/`): each case names a rule the base model
is expected to get wrong from memory, and a new artifact for that rule ships only if the
no-plugin arm fails it. Run them with the write grant — the cases write files, and
`Write`/`Edit` are gated tools the runner will not hand a plugin without it:

```bash
claude plugin eval ./plugins/web-dev --ablation with-without --runs 5 \
  --allow-tools Write Edit --no-publish --trust-plugin
```

Without the grant the suite still loads and then declines the case, so a clean-looking run
has measured nothing. State the run count and vote spread with any delta.
