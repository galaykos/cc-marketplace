# web-dev

Web development in one plugin: a **web-developer** worker for routing, REST/API
integration, forms, state management, and SSR/CSR decisions; a **frontend-reviewer**
that audits component and view logic; and three version-pinned stack skills —
**Next.js**, **React Native** (with the Expo inversions), and **Vite** — behind one
`/web-dev:review` that detects the stack from the lockfile.

Laravel keeps its own plugin and Inertia lives there — a PHP-side pairing — and the
worker and reviewer defer to it when installed. Plain JavaScript and TypeScript
need no stack skill — that shape measured zero against a blind control
(`rationale/measured-zero-shapes.md`), which is why there is none here.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install web-dev@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/web-dev:review [files-or-diff]` | Detect Next.js / React Native / Vite from the manifests, load every matching skill, and review the scope pinned to the installed versions — severity-sorted one-line findings with fixes |

```bash
/web-dev:review app/products/page.tsx app/actions/checkout.ts
/web-dev:review vite.config.ts
/web-dev:review                    # reviews the current diff
```

A scope that spans other stacks hands up to `/code-review:review`, the fan-in that
loads every installed stack skill in one pass.

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

`/web-dev:review` reads it when `expo` is in the manifest, and `skill-router` routes
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

The worker recommends the matching review command after implementing; the reviewer
hands accessibility to `/a11y:audit` and design-system concerns to `/ui-ux:review`.

## Model tiers — why the reviewer is floored

`frontend-reviewer` pins `model: opus` as a **floor** (row in
`orchestration:delegation-contracts` `references/role-floors.md`): dispatch runs it at
`max(session model, opus)`. In an Opus or Fable session that changes nothing. In a
Sonnet session the verdict is still produced by an Opus-class judge, which is the
mechanism this marketplace uses to keep review quality constant while the session
model varies. The worker stays `inherit`: implementation tracks the session, judgment
does not drop below it.

The skills carry the same split in prose. Everything marked **All models** is a fact
or a boundary no tier may skip; the short **Compensation (worker-tier)** blocks are the
procedure a Sonnet-class session follows in full and a Fable-class session may compress
once the skip-clause holds. Standing: **recorded** — no script reads the markers
(`claude-authoring` `references/model-tier-scoping.md`).

## Pairs well with

- **laravel** — the PHP side, and the home of `inertia-best-practices`, which both agents load when installed
- **ui-ux** — visual and design-system review the frontend-reviewer defers to
- **a11y** — full WCAG audit; the agents only enforce a semantic baseline
- **performance** — bundle size and Core Web Vitals beyond the framework defaults
- **stack-scan** — supplies the locked versions the advice pins against
