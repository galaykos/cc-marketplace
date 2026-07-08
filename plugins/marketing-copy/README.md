# marketing-copy

Marketing words grounded in what the product actually is. Reads the README,
manifests, a short brief, and any capture shotlist captions, then writes
`docs/marketing/copy.md` with slogans, feature blurbs, and a demo script.
Pure text — no browser, no screenshots. Pair it with `marketing-capture` for
the visuals.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install marketing-copy@cc-plugins-marketplace
```

## Skills

| Skill | What it does |
|-------|--------------|
| `marketing-copy` | Read README + manifests + brief + shotlist captions, write `docs/marketing/copy.md` (slogans, feature blurbs, demo script) |

## How it works

1. **Grounds in the product**, never invents: README, `plugin.json` /
   `package.json` / `composer.json`, and a one-sentence user brief.
2. **Reads the shotlist captions** in `docs/marketing/` when `marketing-capture`
   has run, so the demo script and blurbs match what the reader will see. Runs
   standalone when there are none.
3. **Writes three sections** — slogans (one recommended), benefit-first feature
   blurbs, and a demo script whose beats follow the shot order.
4. **Claim-checks itself** — every blurb traces to a real capability; no
   superlatives the product can't back.

## Pairs well with

- **marketing-capture** — its shotlist captions keep copy and visuals in sync.
- **marketing-suite** — bundles this with capture as one install.
